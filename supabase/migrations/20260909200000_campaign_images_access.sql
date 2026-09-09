-- Galerie d'une room : le MJ publie, les membres consultent.
--
-- Jusqu'ici les lignes de `public.images` étaient strictement privées à leur
-- propriétaire, ce qui rendait toute galerie partagée impossible. Les règles
-- s'alignent désormais sur les rôles introduits par
-- `20260909100000_campaign_members_and_roles.sql`.
--
-- À noter : le bucket `images` est public, les fichiers sont donc servis par
-- leur URL sans passer par une policy. Ce que gouverne cette table, c'est la
-- capacité à **découvrir** une image — sans ligne lisible, un membre ne peut
-- pas connaître l'URL.

create index if not exists images_campaign_id_idx on public.images (campaign_id);

drop policy if exists "images_select_own" on public.images;
drop policy if exists "images_insert_own" on public.images;
drop policy if exists "images_update_own" on public.images;
drop policy if exists "images_delete_own" on public.images;

drop policy if exists "images_select_own_or_campaign" on public.images;
drop policy if exists "images_insert_own_mj" on public.images;
drop policy if exists "images_update_own_mj" on public.images;
drop policy if exists "images_delete_own_or_mj" on public.images;

-- Lecture : ses propres images, plus celles publiées dans une room dont on est
-- membre.
create policy "images_select_own_or_campaign" on public.images
  for select to authenticated
  using (
    owner_id = auth.uid()
    or (campaign_id is not null and public.is_campaign_member(campaign_id))
  );

-- Insertion : on n'enregistre que ses propres images, et seul le MJ publie
-- dans une room. Une image sans campagne (icône de room, avatar) reste
-- rattachée à son seul propriétaire.
create policy "images_insert_own_mj" on public.images
  for insert to authenticated
  with check (
    owner_id = auth.uid()
    and (campaign_id is null or public.is_campaign_mj(campaign_id))
  );

create policy "images_update_own_mj" on public.images
  for update to authenticated
  using (
    owner_id = auth.uid()
    and (campaign_id is null or public.is_campaign_mj(campaign_id))
  )
  with check (
    owner_id = auth.uid()
    and (campaign_id is null or public.is_campaign_mj(campaign_id))
  );

-- Suppression : le propriétaire, ou le MJ de la room où l'image est publiée —
-- il doit pouvoir retirer une image de sa table même s'il ne l'a pas posée
-- lui-même.
--
-- Limite assumée : le fichier dans Storage reste la propriété de celui qui l'a
-- téléversé (policy `images_owner_delete`). Un MJ qui retire l'image d'un
-- autre efface la ligne mais laisse le fichier orphelin dans le bucket. Le cas
-- suppose un changement de meneur, qui n'existe pas encore.
create policy "images_delete_own_or_mj" on public.images
  for delete to authenticated
  using (
    owner_id = auth.uid()
    or (campaign_id is not null and public.is_campaign_mj(campaign_id))
  );

-- La RPC suivait l'ancienne règle (propriétaire, ou créateur de la campagne).
-- La laisser en l'état ferait coexister deux définitions divergentes de
-- « image accessible », dans une fonction `security definer` de surcroît.
create or replace function public.get_user_accessible_images(p_user_id uuid)
returns setof public.images
language sql
security definer
set search_path = public
as $$
  select i.*
  from public.images i
  where p_user_id = auth.uid()
    and (
      i.owner_id = p_user_id
      or (i.campaign_id is not null and public.is_campaign_member(i.campaign_id))
    );
$$;
