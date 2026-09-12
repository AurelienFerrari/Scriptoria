-- Sondages dans le chat.
--
-- Le MJ comme les joueurs peuvent lancer un sondage : une question, de deux à
-- dix réponses, à choix unique ou multiple. Un sondage est un message du chat
-- (`kind = 'poll'`, la question dans `body`) : il prend sa place dans la
-- conversation, arrive en temps réel, et disparaît avec son message.
--
-- Trois règles, toutes tenues par la base.
--
-- Anonymat. Personne, pas même le MJ, ne peut savoir qui a voté quoi. La table
-- des votes n'est lisible que par son propre votant ; les compteurs ne sortent
-- que par `get_room_polls`, qui ne renvoie que des totaux.
--
-- Résultats après le vote. Les pourcentages ne sont révélés qu'à ceux qui ont
-- voté, ou à tous une fois le sondage clos. C'est la fonction qui en décide,
-- pas l'écran : voir les résultats avant de voter influencerait le vote.
--
-- Vote modifiable jusqu'à la clôture. L'auteur du sondage ou le MJ le clôt, et
-- les votes sont alors figés.
--
-- Toutes les écritures passent par des fonctions `security definer` : un vote
-- à choix unique ne peut pas cocher deux réponses, une réponse ne peut pas
-- appartenir à un autre sondage, et un sondage ne peut pas naître sans ses
-- réponses. Aucune policy d'écriture n'est donc ouverte sur ces tables.

-- ---------- Messages : nature du message ----------

alter table public.room_messages
  add column if not exists kind text not null default 'text';

alter table public.room_messages
  drop constraint if exists room_messages_kind_check;
alter table public.room_messages
  add constraint room_messages_kind_check check (kind in ('text', 'poll'));

-- Un sondage s'adresse à toute la table, et ne répond à rien.
alter table public.room_messages
  drop constraint if exists room_messages_poll_is_public;
alter table public.room_messages
  add constraint room_messages_poll_is_public
    check (kind = 'text' or (visible_to is null and reply_to is null));

-- Un client n'écrit que des messages texte : un message de sondage sans son
-- sondage n'aurait aucun sens, il ne naît que par `create_room_poll`.
drop policy if exists "room_messages_insert_member" on public.room_messages;

create policy "room_messages_insert_member" on public.room_messages
  for insert to authenticated
  with check (
    author_id = auth.uid()
    and kind = 'text'
    and public.is_campaign_member(campaign_id)
    and (visible_to is null or public.is_campaign_mj(campaign_id))
    and (
      reply_to is null
      or exists (
        select 1
        from public.room_messages original
        where original.id = room_messages.reply_to
          and original.campaign_id = room_messages.campaign_id
      )
    )
  );

-- ---------- Tables ----------

create table if not exists public.room_polls (
  id uuid primary key default gen_random_uuid(),
  message_id uuid not null unique
    references public.room_messages(id) on delete cascade,
  campaign_id uuid not null references public.campaigns(id) on delete cascade,
  multiple boolean not null default false,
  closed_at timestamptz,
  -- Touché à chaque vote et à la clôture : c'est cette mise à jour que le
  -- temps réel diffuse, pour que les résultats se rafraîchissent chez tous
  -- sans jamais faire circuler les votes eux-mêmes.
  updated_at timestamptz not null default now()
);

create index if not exists room_polls_campaign_idx
  on public.room_polls (campaign_id);

create table if not exists public.room_poll_options (
  id uuid primary key default gen_random_uuid(),
  poll_id uuid not null references public.room_polls(id) on delete cascade,
  label text not null,
  position integer not null,
  constraint room_poll_options_label_not_blank check (length(btrim(label)) > 0),
  constraint room_poll_options_label_length check (length(label) <= 100),
  constraint room_poll_options_position_unique unique (poll_id, position)
);

create table if not exists public.room_poll_votes (
  poll_id uuid not null references public.room_polls(id) on delete cascade,
  option_id uuid not null
    references public.room_poll_options(id) on delete cascade,
  voter_id uuid not null references auth.users(id) on delete cascade,
  created_at timestamptz not null default now(),
  primary key (option_id, voter_id)
);

create index if not exists room_poll_votes_poll_voter_idx
  on public.room_poll_votes (poll_id, voter_id);

-- ---------- Lecture ----------

alter table public.room_polls enable row level security;
alter table public.room_poll_options enable row level security;
alter table public.room_poll_votes enable row level security;

drop policy if exists "room_polls_select_member" on public.room_polls;
drop policy if exists "room_poll_options_select_member" on public.room_poll_options;
drop policy if exists "room_poll_votes_select_own" on public.room_poll_votes;

create policy "room_polls_select_member" on public.room_polls
  for select to authenticated
  using (public.is_campaign_member(campaign_id));

create policy "room_poll_options_select_member" on public.room_poll_options
  for select to authenticated
  using (
    exists (
      select 1 from public.room_polls p
      where p.id = room_poll_options.poll_id
        and public.is_campaign_member(p.campaign_id)
    )
  );

-- L'anonymat tient ici : chacun ne lit que ses propres votes.
create policy "room_poll_votes_select_own" on public.room_poll_votes
  for select to authenticated
  using (voter_id = auth.uid());

-- ---------- Fonctions ----------

-- Crée le message, le sondage et ses réponses d'un seul tenant.
create or replace function public.create_room_poll(
  p_campaign_id uuid,
  p_question text,
  p_options text[],
  p_multiple boolean default false
)
returns public.room_messages
language plpgsql
security definer
set search_path = public
as $$
declare
  v_question text := btrim(coalesce(p_question, ''));
  v_options text[];
  v_message public.room_messages%rowtype;
  v_poll_id uuid;
begin
  if auth.uid() is null or not public.is_campaign_member(p_campaign_id) then
    raise exception 'Vous ne faites pas partie de cette room.'
      using errcode = '42501';
  end if;

  if length(v_question) = 0 or length(v_question) > 300 then
    raise exception 'La question doit faire entre 1 et 300 caractères.'
      using errcode = '22023';
  end if;

  select array_agg(label order by ord) into v_options
  from (
    select btrim(raw) as label, ord
    from unnest(p_options) with ordinality as t(raw, ord)
  ) cleaned
  where length(label) > 0;

  if coalesce(cardinality(v_options), 0) not between 2 and 10 then
    raise exception 'Un sondage propose entre 2 et 10 réponses.'
      using errcode = '22023';
  end if;

  if exists (select 1 from unnest(v_options) as l(label) where length(label) > 100) then
    raise exception 'Une réponse ne dépasse pas 100 caractères.'
      using errcode = '22023';
  end if;

  if (select count(distinct lower(label)) from unnest(v_options) as l(label))
       <> cardinality(v_options) then
    raise exception 'Deux réponses sont identiques.' using errcode = '22023';
  end if;

  insert into public.room_messages (campaign_id, author_id, body, kind)
  values (p_campaign_id, auth.uid(), v_question, 'poll')
  returning * into v_message;

  insert into public.room_polls (message_id, campaign_id, multiple)
  values (v_message.id, p_campaign_id, coalesce(p_multiple, false))
  returning id into v_poll_id;

  insert into public.room_poll_options (poll_id, label, position)
  select v_poll_id, label, (ord - 1)::integer
  from unnest(v_options) with ordinality as t(label, ord);

  return v_message;
end;
$$;

-- Remplace le vote de l'utilisateur : voter à nouveau, c'est changer d'avis.
create or replace function public.vote_room_poll(
  p_poll_id uuid,
  p_option_ids uuid[]
)
returns void
language plpgsql
security definer
set search_path = public
as $$
declare
  v_poll public.room_polls%rowtype;
  v_count integer := coalesce(cardinality(p_option_ids), 0);
begin
  select * into v_poll from public.room_polls where id = p_poll_id;
  if not found or not public.is_campaign_member(v_poll.campaign_id) then
    raise exception 'Sondage introuvable.' using errcode = '42501';
  end if;

  if v_poll.closed_at is not null then
    raise exception 'Ce sondage est clos.' using errcode = '42501';
  end if;

  if v_count = 0 then
    raise exception 'Choisissez au moins une réponse.' using errcode = '22023';
  end if;

  if not v_poll.multiple and v_count > 1 then
    raise exception 'Ce sondage n''accepte qu''une réponse.'
      using errcode = '22023';
  end if;

  -- Des id en double, ou appartenant à un autre sondage, ne tombent pas juste.
  if (
    select count(distinct o.id)
    from public.room_poll_options o
    where o.poll_id = p_poll_id and o.id = any (p_option_ids)
  ) <> v_count then
    raise exception 'Réponse inconnue pour ce sondage.' using errcode = '22023';
  end if;

  delete from public.room_poll_votes
  where poll_id = p_poll_id and voter_id = auth.uid();

  insert into public.room_poll_votes (poll_id, option_id, voter_id)
  select p_poll_id, option_id, auth.uid()
  from unnest(p_option_ids) as t(option_id);

  update public.room_polls set updated_at = now() where id = p_poll_id;
end;
$$;

-- Fige un sondage. Réservé à son auteur, tant qu'il est membre, et au MJ.
create or replace function public.close_room_poll(p_poll_id uuid)
returns void
language plpgsql
security definer
set search_path = public
as $$
declare
  v_poll public.room_polls%rowtype;
  v_author uuid;
begin
  select * into v_poll from public.room_polls where id = p_poll_id;
  if not found then
    raise exception 'Sondage introuvable.' using errcode = '42501';
  end if;

  select author_id into v_author
  from public.room_messages where id = v_poll.message_id;

  if not (
    (v_author = auth.uid() and public.is_campaign_member(v_poll.campaign_id))
    or public.is_campaign_mj(v_poll.campaign_id)
  ) then
    raise exception 'Seuls l''auteur du sondage et le MJ peuvent le clore.'
      using errcode = '42501';
  end if;

  update public.room_polls
  set closed_at = coalesce(closed_at, now()), updated_at = now()
  where id = p_poll_id;
end;
$$;

-- Sondages des messages demandés, avec leurs réponses.
--
-- Ne renvoie que des totaux, jamais de votants. Les compteurs par réponse
-- valent `null` tant que l'utilisateur n'a pas voté et que le sondage est
-- ouvert : l'écran ne peut pas afficher ce qu'il n'a pas reçu.
create or replace function public.get_room_polls(p_message_ids uuid[])
returns jsonb
language sql
stable
security definer
set search_path = public
as $$
  select coalesce(jsonb_agg(poll_json), '[]'::jsonb)
  from (
    select jsonb_build_object(
      'poll_id', p.id,
      'message_id', p.message_id,
      'multiple', p.multiple,
      'closed', p.closed_at is not null,
      'revealed', revealed.value,
      'total_voters', (
        select count(distinct v.voter_id)
        from public.room_poll_votes v where v.poll_id = p.id
      ),
      'my_votes', coalesce((
        select jsonb_agg(v.option_id)
        from public.room_poll_votes v
        where v.poll_id = p.id and v.voter_id = auth.uid()
      ), '[]'::jsonb),
      'options', (
        select jsonb_agg(
          jsonb_build_object(
            'id', o.id,
            'label', o.label,
            'position', o.position,
            'votes', case when revealed.value then (
              select count(*) from public.room_poll_votes v
              where v.option_id = o.id
            ) end
          )
          order by o.position
        )
        from public.room_poll_options o where o.poll_id = p.id
      )
    ) as poll_json
    from public.room_polls p
    cross join lateral (
      select (
        p.closed_at is not null
        or exists (
          select 1 from public.room_poll_votes v
          where v.poll_id = p.id and v.voter_id = auth.uid()
        )
      ) as value
    ) revealed
    where p.message_id = any (p_message_ids)
      and public.is_campaign_member(p.campaign_id)
  ) polls;
$$;

-- Seuls les utilisateurs connectés appellent ces fonctions.
revoke all on function public.create_room_poll(uuid, text, text[], boolean) from public, anon;
revoke all on function public.vote_room_poll(uuid, uuid[]) from public, anon;
revoke all on function public.close_room_poll(uuid) from public, anon;
revoke all on function public.get_room_polls(uuid[]) from public, anon;

grant execute on function public.create_room_poll(uuid, text, text[], boolean) to authenticated;
grant execute on function public.vote_room_poll(uuid, uuid[]) to authenticated;
grant execute on function public.close_room_poll(uuid) to authenticated;
grant execute on function public.get_room_polls(uuid[]) to authenticated;

-- ---------- Temps réel ----------

-- `room_polls` seulement : chaque vote y touche `updated_at`, ce qui suffit à
-- prévenir les écrans. `room_poll_votes` n'est volontairement pas publiée :
-- diffuser les votes, ce serait diffuser les votants.
do $$
begin
  if not exists (
    select 1 from pg_publication_tables
    where pubname = 'supabase_realtime'
      and schemaname = 'public'
      and tablename = 'room_polls'
  ) then
    alter publication supabase_realtime add table public.room_polls;
  end if;
end;
$$;
