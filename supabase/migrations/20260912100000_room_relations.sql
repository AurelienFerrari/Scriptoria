-- Carte des relations de la room.
--
-- Inspirée du journal de bord d'Outer Wilds : des ronds — personnages, lieux,
-- objets, évènements — reliés par des liens de couleur, et sur chaque rond des
-- informations que le MJ dévoile à mesure que les joueurs les découvrent.
--
-- La carte est la même pour tout le monde : mêmes ronds, mêmes liens, mêmes
-- positions. Ce qui change d'un joueur à l'autre, ce sont les informations
-- découvertes.
--
-- Le masquage est fait par la base, jamais par l'écran. Un joueur ne reçoit
-- que le texte des informations qu'il a découvertes, plus le nombre de celles
-- qui lui restent à trouver — de quoi afficher les « ??? » sans jamais
-- transporter le secret. Tout renvoyer puis masquer à l'affichage reviendrait
-- à publier les notes du MJ dans l'API.

-- ---------- Catégories de lien (la légende) ----------

create table if not exists public.room_relation_categories (
  id uuid primary key default gen_random_uuid(),
  campaign_id uuid not null references public.campaigns(id) on delete cascade,
  name text not null,
  -- Couleur ARGB, telle que Flutter la manipule.
  color bigint not null,
  position integer not null default 0,
  created_at timestamptz not null default now(),
  constraint room_relation_categories_name_not_blank
    check (length(btrim(name)) > 0),
  constraint room_relation_categories_name_length check (length(name) <= 40)
);

create index if not exists room_relation_categories_campaign_idx
  on public.room_relation_categories (campaign_id, position);

-- ---------- Ronds ----------

create table if not exists public.room_relation_nodes (
  id uuid primary key default gen_random_uuid(),
  campaign_id uuid not null references public.campaigns(id) on delete cascade,
  label text not null,
  kind text not null default 'person',
  -- Position posée par le MJ, en unités de la carte.
  x double precision not null default 0,
  y double precision not null default 0,
  created_at timestamptz not null default now(),
  -- Touché aussi quand les informations du rond changent : c'est ce signal
  -- que le temps réel diffuse, sans jamais faire circuler leur contenu.
  updated_at timestamptz not null default now(),
  constraint room_relation_nodes_label_not_blank check (length(btrim(label)) > 0),
  constraint room_relation_nodes_label_length check (length(label) <= 60),
  constraint room_relation_nodes_kind_check
    check (kind in ('person', 'place', 'thing', 'event'))
);

create index if not exists room_relation_nodes_campaign_idx
  on public.room_relation_nodes (campaign_id);

-- ---------- Liens ----------

create table if not exists public.room_relation_links (
  id uuid primary key default gen_random_uuid(),
  campaign_id uuid not null references public.campaigns(id) on delete cascade,
  from_node_id uuid not null
    references public.room_relation_nodes(id) on delete cascade,
  to_node_id uuid not null
    references public.room_relation_nodes(id) on delete cascade,
  category_id uuid
    references public.room_relation_categories(id) on delete set null,
  label text,
  created_at timestamptz not null default now(),
  constraint room_relation_links_not_self check (from_node_id <> to_node_id),
  constraint room_relation_links_label_length
    check (label is null or length(label) <= 60),
  -- Deux ronds peuvent être reliés plusieurs fois, mais pas deux fois par la
  -- même catégorie.
  constraint room_relation_links_unique
    unique (from_node_id, to_node_id, category_id)
);

create index if not exists room_relation_links_campaign_idx
  on public.room_relation_links (campaign_id);

-- ---------- Informations, et qui les a découvertes ----------

create table if not exists public.room_relation_facts (
  id uuid primary key default gen_random_uuid(),
  campaign_id uuid not null references public.campaigns(id) on delete cascade,
  node_id uuid not null
    references public.room_relation_nodes(id) on delete cascade,
  content text not null,
  position integer not null default 0,
  created_at timestamptz not null default now(),
  constraint room_relation_facts_content_not_blank
    check (length(btrim(content)) > 0),
  constraint room_relation_facts_content_length check (length(content) <= 1000)
);

create index if not exists room_relation_facts_node_idx
  on public.room_relation_facts (node_id, position);

create table if not exists public.room_relation_discoveries (
  fact_id uuid not null
    references public.room_relation_facts(id) on delete cascade,
  user_id uuid not null references auth.users(id) on delete cascade,
  discovered_at timestamptz not null default now(),
  primary key (fact_id, user_id)
);

create index if not exists room_relation_discoveries_user_idx
  on public.room_relation_discoveries (user_id);

-- ---------- Lecture et écriture ----------

alter table public.room_relation_categories enable row level security;
alter table public.room_relation_nodes enable row level security;
alter table public.room_relation_links enable row level security;
alter table public.room_relation_facts enable row level security;
alter table public.room_relation_discoveries enable row level security;

drop policy if exists "relation_categories_select_member" on public.room_relation_categories;
drop policy if exists "relation_categories_write_mj" on public.room_relation_categories;
drop policy if exists "relation_nodes_select_member" on public.room_relation_nodes;
drop policy if exists "relation_nodes_write_mj" on public.room_relation_nodes;
drop policy if exists "relation_links_select_member" on public.room_relation_links;
drop policy if exists "relation_links_write_mj" on public.room_relation_links;
drop policy if exists "relation_facts_select_discovered" on public.room_relation_facts;
drop policy if exists "relation_facts_write_mj" on public.room_relation_facts;
drop policy if exists "relation_discoveries_select_own" on public.room_relation_discoveries;
drop policy if exists "relation_discoveries_write_mj" on public.room_relation_discoveries;

-- La carte est la même pour tous les membres : ronds, liens et légende.
create policy "relation_categories_select_member"
  on public.room_relation_categories
  for select to authenticated
  using (public.is_campaign_member(campaign_id));

create policy "relation_categories_write_mj"
  on public.room_relation_categories
  for all to authenticated
  using (public.is_campaign_mj(campaign_id))
  with check (public.is_campaign_mj(campaign_id));

create policy "relation_nodes_select_member" on public.room_relation_nodes
  for select to authenticated
  using (public.is_campaign_member(campaign_id));

create policy "relation_nodes_write_mj" on public.room_relation_nodes
  for all to authenticated
  using (public.is_campaign_mj(campaign_id))
  with check (public.is_campaign_mj(campaign_id));

create policy "relation_links_select_member" on public.room_relation_links
  for select to authenticated
  using (public.is_campaign_member(campaign_id));

create policy "relation_links_write_mj" on public.room_relation_links
  for all to authenticated
  using (public.is_campaign_mj(campaign_id))
  with check (public.is_campaign_mj(campaign_id));

-- Le secret tient ici : une information n'est lisible que par le MJ et par
-- ceux qui l'ont découverte. Même en interrogeant l'API directement, un
-- joueur ne peut pas lire ce qu'il n'a pas trouvé.
create policy "relation_facts_select_discovered" on public.room_relation_facts
  for select to authenticated
  using (
    public.is_campaign_mj(campaign_id)
    or exists (
      select 1 from public.room_relation_discoveries d
      where d.fact_id = room_relation_facts.id and d.user_id = auth.uid()
    )
  );

create policy "relation_facts_write_mj" on public.room_relation_facts
  for all to authenticated
  using (public.is_campaign_mj(campaign_id))
  with check (public.is_campaign_mj(campaign_id));

-- Chacun voit ses propres découvertes ; le MJ tient le registre.
create policy "relation_discoveries_select_own"
  on public.room_relation_discoveries
  for select to authenticated
  using (
    user_id = auth.uid()
    or exists (
      select 1 from public.room_relation_facts f
      where f.id = room_relation_discoveries.fact_id
        and public.is_campaign_mj(f.campaign_id)
    )
  );

create policy "relation_discoveries_write_mj"
  on public.room_relation_discoveries
  for all to authenticated
  using (
    exists (
      select 1 from public.room_relation_facts f
      where f.id = room_relation_discoveries.fact_id
        and public.is_campaign_mj(f.campaign_id)
    )
  )
  with check (
    exists (
      select 1 from public.room_relation_facts f
      where f.id = room_relation_discoveries.fact_id
        and public.is_campaign_mj(f.campaign_id)
    )
  );

-- ---------- Le rond change quand ses informations changent ----------

create or replace function public.touch_relation_node()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
declare
  v_node uuid;
  v_fact uuid;
begin
  if tg_table_name = 'room_relation_facts' then
    v_node := case when tg_op = 'DELETE' then old.node_id else new.node_id end;
  else
    v_fact := case when tg_op = 'DELETE' then old.fact_id else new.fact_id end;
    select node_id into v_node from room_relation_facts where id = v_fact;
  end if;

  if v_node is not null then
    update room_relation_nodes set updated_at = now() where id = v_node;
  end if;

  return case when tg_op = 'DELETE' then old else new end;
end;
$$;

create or replace function public.touch_relation_node_self()
returns trigger
language plpgsql
as $$
begin
  new.updated_at := now();
  return new;
end;
$$;

drop trigger if exists room_relation_nodes_touch on public.room_relation_nodes;
create trigger room_relation_nodes_touch
  before update on public.room_relation_nodes
  for each row execute function public.touch_relation_node_self();

drop trigger if exists room_relation_facts_touch on public.room_relation_facts;
create trigger room_relation_facts_touch
  after insert or update or delete on public.room_relation_facts
  for each row execute function public.touch_relation_node();

drop trigger if exists room_relation_discoveries_touch
  on public.room_relation_discoveries;
create trigger room_relation_discoveries_touch
  after insert or delete on public.room_relation_discoveries
  for each row execute function public.touch_relation_node();

-- ---------- La carte, telle que chacun a le droit de la voir ----------

create or replace function public.get_relation_graph(p_campaign_id uuid)
returns jsonb
language plpgsql
stable
security definer
set search_path = public
as $$
declare
  v_is_mj boolean;
begin
  if auth.uid() is null or not public.is_campaign_member(p_campaign_id) then
    raise exception 'Vous ne faites pas partie de cette room.'
      using errcode = '42501';
  end if;

  v_is_mj := public.is_campaign_mj(p_campaign_id);

  return jsonb_build_object(
    'is_mj', v_is_mj,
    'categories', coalesce((
      select jsonb_agg(
        jsonb_build_object(
          'id', c.id,
          'name', c.name,
          'color', c.color,
          'position', c.position
        )
        order by c.position, c.name
      )
      from room_relation_categories c
      where c.campaign_id = p_campaign_id
    ), '[]'::jsonb),
    'links', coalesce((
      select jsonb_agg(
        jsonb_build_object(
          'id', l.id,
          'from_node_id', l.from_node_id,
          'to_node_id', l.to_node_id,
          'category_id', l.category_id,
          'label', l.label
        )
      )
      from room_relation_links l
      where l.campaign_id = p_campaign_id
    ), '[]'::jsonb),
    'nodes', coalesce((
      select jsonb_agg(
        jsonb_build_object(
          'id', n.id,
          'label', n.label,
          'kind', n.kind,
          'x', n.x,
          'y', n.y,
          -- Le nombre d'informations est connu de tous : c'est lui qui fait
          -- apparaître les « ??? », et qui dit qu'il reste à chercher.
          'fact_count', (
            select count(*) from room_relation_facts f where f.node_id = n.id
          ),
          'discovered_count', (
            select count(*)
            from room_relation_facts f
            where f.node_id = n.id
              and (
                v_is_mj
                or exists (
                  select 1 from room_relation_discoveries d
                  where d.fact_id = f.id and d.user_id = auth.uid()
                )
              )
          ),
          'facts', coalesce((
            select jsonb_agg(
              jsonb_build_object(
                'id', f.id,
                'position', f.position,
                -- Le texte ne sort que pour qui l'a découvert. Sinon rien :
                -- l'écran affiche « ??? » sans avoir reçu le secret.
                'content', case
                  when v_is_mj or exists (
                    select 1 from room_relation_discoveries d
                    where d.fact_id = f.id and d.user_id = auth.uid()
                  ) then f.content
                end,
                -- Le registre des découvertes n'est utile qu'au MJ, pour
                -- savoir à qui il a déjà révélé quoi.
                'discovered_by', case when v_is_mj then coalesce((
                  select jsonb_agg(d.user_id)
                  from room_relation_discoveries d where d.fact_id = f.id
                ), '[]'::jsonb) end
              )
              order by f.position, f.created_at
            )
            from room_relation_facts f
            where f.node_id = n.id
          ), '[]'::jsonb)
        )
        order by n.created_at
      )
      from room_relation_nodes n
      where n.campaign_id = p_campaign_id
    ), '[]'::jsonb)
  );
end;
$$;

-- Fixe, d'un seul geste, qui a découvert une information.
create or replace function public.set_fact_discoverers(
  p_fact_id uuid,
  p_user_ids uuid[]
)
returns void
language plpgsql
security definer
set search_path = public
as $$
declare
  v_campaign uuid;
  v_node uuid;
  v_users uuid[] := coalesce(p_user_ids, '{}'::uuid[]);
begin
  select campaign_id, node_id into v_campaign, v_node
  from room_relation_facts where id = p_fact_id;

  if not found or not public.is_campaign_mj(v_campaign) then
    raise exception 'Information introuvable.' using errcode = '42501';
  end if;

  delete from room_relation_discoveries
  where fact_id = p_fact_id and not (user_id = any (v_users));

  -- Seuls les membres de la room peuvent découvrir quelque chose.
  insert into room_relation_discoveries (fact_id, user_id)
  select p_fact_id, candidate
  from unnest(v_users) as t(candidate)
  where exists (
    select 1 from campaign_members m
    where m.campaign_id = v_campaign and m.user_id = candidate
  )
  on conflict do nothing;

  update room_relation_nodes set updated_at = now() where id = v_node;
end;
$$;

revoke all on function public.get_relation_graph(uuid) from public, anon;
revoke all on function public.set_fact_discoverers(uuid, uuid[]) from public, anon;

grant execute on function public.get_relation_graph(uuid) to authenticated;
grant execute on function public.set_fact_discoverers(uuid, uuid[]) to authenticated;

-- ---------- Temps réel ----------

-- Les ronds, les liens et la légende suffisent : une information révélée
-- touche son rond, et c'est ce signal qui fait recharger la carte. Ni les
-- informations ni les découvertes ne sont publiées — les diffuser
-- reviendrait à diffuser les secrets du MJ.
do $$
declare
  t text;
begin
  foreach t in array array[
    'room_relation_nodes',
    'room_relation_links',
    'room_relation_categories'
  ] loop
    if not exists (
      select 1 from pg_publication_tables
      where pubname = 'supabase_realtime'
        and schemaname = 'public'
        and tablename = t
    ) then
      execute format(
        'alter publication supabase_realtime add table public.%I', t
      );
    end if;
  end loop;
end;
$$;
