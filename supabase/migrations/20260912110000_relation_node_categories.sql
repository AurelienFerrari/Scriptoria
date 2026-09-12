-- Une couleur de catégorie sur les ronds, et plus seulement sur les liens.
--
-- Les catégories rangeaient les liens ; elles rangent désormais aussi les
-- ronds, pour qu'une même couleur réunisse une famille, un camp ou une
-- intrigue d'un coup d'œil.
--
-- La couleur du rond ne remplace pas le signal des découvertes : c'est la
-- pastille de comptage qui le porte, et elle reste ambre tant qu'il reste
-- quelque chose à trouver sur ce rond.
--
-- `on delete set null` : supprimer une catégorie décolore les ronds qui la
-- portaient, sans les emporter avec elle.

alter table public.room_relation_nodes
  add column if not exists category_id uuid
    references public.room_relation_categories(id) on delete set null;

create index if not exists room_relation_nodes_category_idx
  on public.room_relation_nodes (category_id);

-- La carte renvoie désormais la catégorie de chaque rond. Le reste de la
-- fonction est inchangé : le texte d'une information non découverte n'en sort
-- toujours pas, seul son nombre est connu.
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
          'category_id', n.category_id,
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
