-- Fil de la room : ce que le MJ pousse sur l'accueil.
--
-- Textes d'ambiance, révélations, illustrations de scène — le MJ choisit pour
-- chaque publication qui la reçoit : toute la table, ou quelques joueurs
-- seulement. Un message glissé à un seul joueur est un ressort de jeu courant
-- (« toi seul remarques que… ») et n'existait nulle part dans l'app.
--
-- Même convention de destinataires que `images.visible_to` :
--   * `null`  → tous les membres de la room
--   * `{...}` → seulement les joueurs listés
--
-- Le tableau vide, qui signifie « personne » pour une image préparée à
-- l'avance, n'a pas de sens ici : on ne publie pas une annonce à destination
-- de personne. Rien ne l'interdit pour autant — la lecture se comporterait
-- alors comme un brouillon visible du seul MJ.

create table if not exists public.room_posts (
  id uuid primary key default gen_random_uuid(),
  campaign_id uuid not null references public.campaigns(id) on delete cascade,
  author_id uuid not null references auth.users(id) on delete cascade,
  body text,
  -- L'image d'une publication est portée par la publication, pas par la table
  -- `images` : sans quoi elle apparaîtrait aussi dans la galerie, où le MJ ne
  -- l'a pas mise.
  image_url text,
  image_bucket text,
  image_path text,
  visible_to uuid[],
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  -- Une publication vide n'apprendrait rien à personne.
  constraint room_posts_not_empty check (
    (body is not null and length(trim(body)) > 0)
    or image_url is not null
  )
);

create index if not exists room_posts_campaign_created_idx
  on public.room_posts (campaign_id, created_at desc);

create index if not exists room_posts_visible_to_idx
  on public.room_posts using gin (visible_to);

-- `updated_at` tenu par la base : une date de modification qui dépend de ce
-- que le client a bien voulu envoyer ne veut rien dire.
create or replace function public.touch_room_post()
returns trigger
language plpgsql
as $$
begin
  new.updated_at := now();
  return new;
end;
$$;

drop trigger if exists room_posts_touch on public.room_posts;
create trigger room_posts_touch
  before update on public.room_posts
  for each row execute function public.touch_room_post();

alter table public.room_posts enable row level security;

drop policy if exists "room_posts_select_audience" on public.room_posts;
drop policy if exists "room_posts_insert_mj" on public.room_posts;
drop policy if exists "room_posts_update_mj" on public.room_posts;
drop policy if exists "room_posts_delete_mj" on public.room_posts;

-- Lecture : les membres de la room, à condition d'être destinataires. Le MJ
-- voit tout son fil, y compris ce qu'il n'a adressé qu'à un seul joueur.
create policy "room_posts_select_audience" on public.room_posts
  for select to authenticated
  using (
    public.is_campaign_member(campaign_id)
    and (
      public.is_campaign_mj(campaign_id)
      or visible_to is null
      or auth.uid() = any (visible_to)
    )
  );

-- Écriture réservée au MJ : le fil est sa voix. Les joueurs ont le chat pour
-- s'exprimer.
create policy "room_posts_insert_mj" on public.room_posts
  for insert to authenticated
  with check (
    author_id = auth.uid()
    and public.is_campaign_mj(campaign_id)
  );

create policy "room_posts_update_mj" on public.room_posts
  for update to authenticated
  using (public.is_campaign_mj(campaign_id))
  with check (public.is_campaign_mj(campaign_id));

create policy "room_posts_delete_mj" on public.room_posts
  for delete to authenticated
  using (public.is_campaign_mj(campaign_id));
