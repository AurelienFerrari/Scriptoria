-- Rompt une récursion infinie entre les policies des informations et des
-- découvertes.
--
-- `relation_facts_select_discovered` lisait `room_relation_discoveries`, dont
-- la policy `relation_discoveries_select_own` lisait `room_relation_facts` :
-- chacune appelait l'autre, et Postgres refusait la requête avec
-- « infinite recursion detected in policy for relation "room_relation_facts" ».
--
-- Le défaut restait invisible presque partout. Lire la carte passe par
-- `get_relation_graph`, qui est `security definer` et ne consulte aucune
-- policy. Créer une information est un `insert` sans relecture, qui n'évalue
-- aucune policy de select. Mais un `update ... where id = ...` doit d'abord
-- retrouver sa ligne, donc évaluer la policy de select : corriger une
-- information échouait, là où l'ajouter réussissait.
--
-- Même remède que pour `is_campaign_member` et `is_campaign_mj` : chaque test
-- passe par une fonction `security definer`, qui lit la table sans repasser
-- par ses policies. Le cycle est coupé des deux côtés, et non d'un seul, pour
-- qu'aucune évolution de l'une des deux policies ne le rouvre.
--
-- Aucun secret n'est élargi : les fonctions ne répondent que par oui ou non,
-- sur la ligne demandée, et seulement au sujet de l'appelant.

create or replace function public.has_discovered_fact(p_fact_id uuid)
returns boolean
language sql
stable
security definer
set search_path = public
as $$
  select exists (
    select 1 from room_relation_discoveries d
    where d.fact_id = p_fact_id and d.user_id = auth.uid()
  );
$$;

create or replace function public.is_relation_fact_mj(p_fact_id uuid)
returns boolean
language sql
stable
security definer
set search_path = public
as $$
  select exists (
    select 1 from room_relation_facts f
    where f.id = p_fact_id and public.is_campaign_mj(f.campaign_id)
  );
$$;

revoke all on function public.has_discovered_fact(uuid) from public, anon;
revoke all on function public.is_relation_fact_mj(uuid) from public, anon;
grant execute on function public.has_discovered_fact(uuid) to authenticated;
grant execute on function public.is_relation_fact_mj(uuid) to authenticated;

-- Le secret tient toujours ici : une information n'est lisible que par le MJ
-- et par ceux qui l'ont découverte. Seule la façon de poser la question
-- change.
drop policy if exists "relation_facts_select_discovered"
  on public.room_relation_facts;

create policy "relation_facts_select_discovered" on public.room_relation_facts
  for select to authenticated
  using (
    public.is_campaign_mj(campaign_id)
    or public.has_discovered_fact(id)
  );

-- Chacun voit ses propres découvertes ; le MJ tient le registre.
drop policy if exists "relation_discoveries_select_own"
  on public.room_relation_discoveries;

create policy "relation_discoveries_select_own"
  on public.room_relation_discoveries
  for select to authenticated
  using (
    user_id = auth.uid()
    or public.is_relation_fact_mj(fact_id)
  );

drop policy if exists "relation_discoveries_write_mj"
  on public.room_relation_discoveries;

create policy "relation_discoveries_write_mj"
  on public.room_relation_discoveries
  for all to authenticated
  using (public.is_relation_fact_mj(fact_id))
  with check (public.is_relation_fact_mj(fact_id));
