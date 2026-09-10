-- Compteurs affichés sur les cartes de room de l'accueil.
--
-- Sans cette vue, remplir une carte demanderait trois requêtes de comptage par
-- campagne : la liste d'accueil en ferait une dizaine pour trois rooms.
--
-- `security_invoker = true` est le point important : la vue s'exécute avec les
-- droits de celui qui l'interroge, donc la RLS des tables sous-jacentes
-- s'applique. Chacun voit ainsi ses propres compteurs — un joueur ne compte
-- que les images qu'on lui a ouvertes, et ne voit aucune note. Sans ce
-- réglage, une vue s'exécute avec les droits de son propriétaire et
-- divulguerait exactement ce que les policies protègent.

create or replace view public.campaign_overview
with (security_invoker = true) as
select
  c.id as campaign_id,
  (
    select count(*)
    from public.campaign_members m
    where m.campaign_id = c.id
  ) as member_count,
  (
    select count(*)
    from public.images i
    where i.campaign_id = c.id
  ) as image_count,
  (
    select count(*)
    from public.room_notes n
    where n.campaign_id = c.id
  ) as note_count
from public.campaigns c;

revoke all on public.campaign_overview from public;
revoke all on public.campaign_overview from anon;
grant select on public.campaign_overview to authenticated;
