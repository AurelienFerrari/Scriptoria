-- Chat de la room, et temps réel pour le chat et le journal des dés.
--
-- Le chat ne vivait qu'en mémoire, avec trois messages codés en dur : rien
-- n'était enregistré, ni partagé avec le reste de la table. Les messages sont
-- désormais en base, et diffusés en temps réel.
--
-- Deux règles portent tout le reste, et elles vivent dans les policies, pas
-- dans l'interface.
--
-- Chuchotements. Le MJ peut adresser un message à des joueurs choisis :
-- `visible_to` suit la convention des images et du fil — `null` pour toute la
-- table, sinon les destinataires. Seul le MJ peut en poser un. Un joueur qui
-- interrogerait l'API ne pourrait ni chuchoter, ni lire un chuchotement qui ne
-- lui est pas adressé.
--
-- Modération. L'auteur retire ses propres messages, le MJ ceux de tout le
-- monde. Personne ne modifie un message : comme pour un jet de dé, ce qui a
-- été dit à la table a été dit.

create table if not exists public.room_messages (
  id uuid primary key default gen_random_uuid(),
  campaign_id uuid not null references public.campaigns(id) on delete cascade,
  author_id uuid not null references auth.users(id) on delete cascade,
  body text not null,
  visible_to uuid[],
  created_at timestamptz not null default now(),
  constraint room_messages_body_not_blank check (length(btrim(body)) > 0),
  -- Un message de chat reste un message : au-delà, c'est une note.
  constraint room_messages_body_length check (length(body) <= 2000),
  -- Un chuchotement à personne n'a pas de sens : `visible_to` vaut `null`
  -- (toute la table) ou nomme au moins un destinataire.
  constraint room_messages_whisper_has_recipient
    check (visible_to is null or cardinality(visible_to) > 0)
);

-- Le chat se lit par les derniers messages d'une room.
create index if not exists room_messages_campaign_created_idx
  on public.room_messages (campaign_id, created_at desc);

-- `visible_to` est interrogé par `= any(...)` dans la policy de lecture.
create index if not exists room_messages_visible_to_idx
  on public.room_messages using gin (visible_to);

alter table public.room_messages enable row level security;

drop policy if exists "room_messages_select_audience" on public.room_messages;
drop policy if exists "room_messages_insert_member" on public.room_messages;
drop policy if exists "room_messages_delete_author_or_mj" on public.room_messages;

-- Lecture : les membres de la room. Pour un chuchotement, ses seuls
-- destinataires — plus le MJ, qui voit tout ce qui se dit à sa table, et
-- l'auteur, qui voit ce qu'il a écrit.
create policy "room_messages_select_audience" on public.room_messages
  for select to authenticated
  using (
    public.is_campaign_member(campaign_id)
    and (
      public.is_campaign_mj(campaign_id)
      or author_id = auth.uid()
      or visible_to is null
      or auth.uid() = any (visible_to)
    )
  );

-- Écriture : tout membre, en son propre nom. Chuchoter est réservé au MJ.
create policy "room_messages_insert_member" on public.room_messages
  for insert to authenticated
  with check (
    author_id = auth.uid()
    and public.is_campaign_member(campaign_id)
    and (visible_to is null or public.is_campaign_mj(campaign_id))
  );

-- Suppression : l'auteur pour les siens tant qu'il est membre, le MJ pour tous.
create policy "room_messages_delete_author_or_mj" on public.room_messages
  for delete to authenticated
  using (
    (author_id = auth.uid() and public.is_campaign_member(campaign_id))
    or public.is_campaign_mj(campaign_id)
  );

-- Aucune policy d'update : un message ne se modifie pas.

-- Temps réel. Realtime applique la policy de lecture à chaque abonné : un
-- chuchotement n'est poussé qu'à ceux qui ont le droit de le lire, et un jet
-- secret qu'au MJ.
--
-- Les deux tables gardent volontairement leur `replica identity` par défaut.
-- Realtime n'applique pas la RLS aux suppressions : en `replica identity
-- full`, l'événement emporterait la ligne entière, et un chuchotement
-- supprimé partirait en clair chez tous les abonnés. Par défaut, il ne
-- contient que l'id.
--
-- Le bloc est rejouable : ajouter deux fois une table à la publication
-- échouerait, et ces migrations s'appliquent à la main.
do $$
begin
  if not exists (
    select 1 from pg_publication_tables
    where pubname = 'supabase_realtime'
      and schemaname = 'public'
      and tablename = 'room_messages'
  ) then
    alter publication supabase_realtime add table public.room_messages;
  end if;

  if not exists (
    select 1 from pg_publication_tables
    where pubname = 'supabase_realtime'
      and schemaname = 'public'
      and tablename = 'dice_rolls'
  ) then
    alter publication supabase_realtime add table public.dice_rolls;
  end if;
end;
$$;
