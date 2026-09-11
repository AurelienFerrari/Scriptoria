-- Frise chronologique de la room.
--
-- Le MJ y consigne l'histoire de la campagne : ce que la table a vécu, et ce
-- qu'elle vivra. Les joueurs la consultent sans jamais pouvoir l'écrire — la
-- règle est portée par les policies, pas par des boutons masqués.
--
-- Deux choix méritent d'être explicités.
--
-- `date_label` est du texte libre, pas une `date`. Une campagne se déroule
-- « au printemps de l'an 1247 », « trois lunes plus tard » ou « avant la
-- Chute » : contraindre ces repères à un calendrier grégorien obligerait le MJ
-- à inventer des dates réelles pour un monde qui n'en a pas.
--
-- L'ordre est donc porté par `position`, une colonne à part. La frise se lit
-- dans l'ordre voulu par le MJ, qui reste seul juge de la chronologie de son
-- monde.

create table if not exists public.room_timeline_events (
  id uuid primary key default gen_random_uuid(),
  campaign_id uuid not null references public.campaigns(id) on delete cascade,
  author_id uuid not null references auth.users(id) on delete cascade,
  date_label text not null default '',
  title text not null,
  description text not null default '',
  position integer not null default 0,
  -- Même convention que `images.visible_to` et `room_posts.visible_to` :
  -- `null` pour tous les membres, tableau vide pour personne, sinon les
  -- joueurs choisis. Un évènement préparé à l'avance se garde ainsi au chaud
  -- jusqu'à la séance où il se révèle.
  visible_to uuid[],
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  constraint room_timeline_events_title_not_blank
    check (length(btrim(title)) > 0)
);

-- La frise se lit toujours entière et dans l'ordre : c'est exactement ce que
-- cet index sert.
create index if not exists room_timeline_events_campaign_position_idx
  on public.room_timeline_events (campaign_id, position);

-- `visible_to` est interrogé par `= any(...)` dans la policy de lecture, sur
-- chaque ligne de la frise.
create index if not exists room_timeline_events_visible_to_idx
  on public.room_timeline_events using gin (visible_to);

-- `updated_at` tenu par la base, comme pour les notes : une date de
-- modification que le client choisit ne prouve rien.
create or replace function public.touch_room_timeline_event()
returns trigger
language plpgsql
as $$
begin
  new.updated_at := now();
  return new;
end;
$$;

drop trigger if exists room_timeline_events_touch on public.room_timeline_events;
create trigger room_timeline_events_touch
  before update on public.room_timeline_events
  for each row execute function public.touch_room_timeline_event();

alter table public.room_timeline_events enable row level security;

drop policy if exists "room_timeline_select_member" on public.room_timeline_events;
drop policy if exists "room_timeline_insert_mj" on public.room_timeline_events;
drop policy if exists "room_timeline_update_mj" on public.room_timeline_events;
drop policy if exists "room_timeline_delete_mj" on public.room_timeline_events;

-- Lecture : réservée aux membres de la room, et filtrée évènement par
-- évènement. Le MJ voit tout, y compris ce qu'il n'a pas encore révélé.
create policy "room_timeline_select_member" on public.room_timeline_events
  for select to authenticated
  using (
    public.is_campaign_member(campaign_id)
    and (
      public.is_campaign_mj(campaign_id)
      or visible_to is null
      or auth.uid() = any(visible_to)
    )
  );

-- Écriture : le MJ seul. `author_id = auth.uid()` empêche d'attribuer un
-- évènement à quelqu'un d'autre.
create policy "room_timeline_insert_mj" on public.room_timeline_events
  for insert to authenticated
  with check (
    author_id = auth.uid()
    and public.is_campaign_mj(campaign_id)
  );

create policy "room_timeline_update_mj" on public.room_timeline_events
  for update to authenticated
  using (public.is_campaign_mj(campaign_id))
  with check (public.is_campaign_mj(campaign_id));

create policy "room_timeline_delete_mj" on public.room_timeline_events
  for delete to authenticated
  using (public.is_campaign_mj(campaign_id));
