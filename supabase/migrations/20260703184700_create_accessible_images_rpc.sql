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
      or i.campaign_id in (select c.id from public.campaigns c where c.creator_id = p_user_id)
    );
$$;

-- Supabase accorde EXECUTE à anon/authenticated par défaut sur les fonctions
-- du schéma public, indépendamment du rôle PUBLIC de Postgres : il faut donc
-- révoquer anon explicitement, pas seulement "from public".
revoke all on function public.get_user_accessible_images(uuid) from public;
revoke execute on function public.get_user_accessible_images(uuid) from anon;
grant execute on function public.get_user_accessible_images(uuid) to authenticated;
