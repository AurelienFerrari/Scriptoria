-- Visibilité d'une image, choisie par le MJ.
--
-- La galerie n'est plus un mur partagé mais un outil de mise en scène : le MJ
-- prépare ses images à l'avance et décide, image par image, qui les voit.
--
-- Trois états, portés par une seule colonne :
--   * `null`  → tous les membres de la room (valeur des images déjà publiées,
--               dont le comportement ne change donc pas)
--   * `'{}'`  → personne, hormis le MJ : l'image est préparée mais pas encore
--               révélée. C'est l'état par défaut à la publication.
--   * `{...}` → seulement les joueurs listés.
--
-- La distinction `null` / tableau vide est subtile en SQL et mérite d'être
-- gardée en tête : `auth.uid() = any('{}')` est faux, tandis qu'un test sur
-- `null` doit être explicite.

alter table public.images
  add column if not exists visible_to uuid[];

comment on column public.images.visible_to is
  'Destinataires de l''image : null = tous les membres, {} = personne (hors MJ), sinon la liste des joueurs autorisés.';

create index if not exists images_visible_to_idx
  on public.images using gin (visible_to);

drop policy if exists "images_select_own_or_campaign" on public.images;
drop policy if exists "images_update_own_mj" on public.images;

-- Lecture : ses propres images ; celles d'une room dont on est membre, à
-- condition d'en être destinataire. Le MJ voit toute sa table, y compris ce
-- qu'il n'a pas encore révélé.
create policy "images_select_own_or_campaign" on public.images
  for select to authenticated
  using (
    owner_id = auth.uid()
    or (
      campaign_id is not null
      and public.is_campaign_member(campaign_id)
      and (
        public.is_campaign_mj(campaign_id)
        or visible_to is null
        or auth.uid() = any (visible_to)
      )
    )
  );

-- Modification : le propriétaire, ou le MJ de la room. Élargi au MJ non
-- propriétaire pour rester cohérent avec la suppression : celui qui mène la
-- table doit pouvoir en régler la visibilité, même sur une image qu'il n'a pas
-- lui-même déposée.
create policy "images_update_own_mj" on public.images
  for update to authenticated
  using (
    owner_id = auth.uid()
    or (campaign_id is not null and public.is_campaign_mj(campaign_id))
  )
  with check (
    owner_id = auth.uid()
    or (campaign_id is not null and public.is_campaign_mj(campaign_id))
  );

-- La RPC doit suivre la même règle, sans quoi deux définitions divergentes de
-- « image accessible » coexisteraient — dans une fonction `security definer`
-- de surcroît.
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
      or (
        i.campaign_id is not null
        and public.is_campaign_member(i.campaign_id)
        and (
          public.is_campaign_mj(i.campaign_id)
          or i.visible_to is null
          or p_user_id = any (i.visible_to)
        )
      )
    );
$$;
