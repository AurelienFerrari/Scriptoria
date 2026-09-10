-- Notes du maître du jeu.
--
-- Le MJ prépare sa séance : intrigues, PNJ, révélations à venir. Ces notes lui
-- sont strictement privées — c'est tout leur intérêt — et le sont **au niveau
-- de la base**, pas seulement dans l'interface. Un joueur qui interrogerait
-- l'API directement n'en verrait aucune.
--
-- Le contenu est stocké en Markdown, pas en fichier : une note importée depuis
-- un `.md` et une note écrite dans l'app deviennent ainsi le même objet,
-- éditable de la même façon, cherchable par la base, et sans fichier orphelin
-- à nettoyer dans Storage.

create table if not exists public.room_notes (
  id uuid primary key default gen_random_uuid(),
  campaign_id uuid not null references public.campaigns(id) on delete cascade,
  author_id uuid not null references auth.users(id) on delete cascade,
  title text not null,
  content_md text not null default '',
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

-- Les notes se consultent par date de dernière modification : c'est ce qu'on
-- cherche en reprenant une séance.
create index if not exists room_notes_campaign_updated_idx
  on public.room_notes (campaign_id, updated_at desc);

-- `updated_at` tenu par la base plutôt que par le client : une note dont la
-- date de modification dépend de ce que le client a bien voulu envoyer ne veut
-- rien dire.
create or replace function public.touch_room_note()
returns trigger
language plpgsql
as $$
begin
  new.updated_at := now();
  return new;
end;
$$;

drop trigger if exists room_notes_touch on public.room_notes;
create trigger room_notes_touch
  before update on public.room_notes
  for each row execute function public.touch_room_note();

alter table public.room_notes enable row level security;

drop policy if exists "room_notes_select_mj" on public.room_notes;
drop policy if exists "room_notes_insert_mj" on public.room_notes;
drop policy if exists "room_notes_update_mj" on public.room_notes;
drop policy if exists "room_notes_delete_mj" on public.room_notes;

-- Les quatre opérations sont réservées au MJ de la room. Aucune n'ouvre quoi
-- que ce soit aux joueurs : une note n'a pas de mode « partagée ». Le MJ qui
-- veut montrer quelque chose passe par la galerie, dont la visibilité est
-- réglable image par image.
create policy "room_notes_select_mj" on public.room_notes
  for select to authenticated
  using (public.is_campaign_mj(campaign_id));

create policy "room_notes_insert_mj" on public.room_notes
  for insert to authenticated
  with check (
    author_id = auth.uid()
    and public.is_campaign_mj(campaign_id)
  );

create policy "room_notes_update_mj" on public.room_notes
  for update to authenticated
  using (public.is_campaign_mj(campaign_id))
  with check (public.is_campaign_mj(campaign_id));

create policy "room_notes_delete_mj" on public.room_notes
  for delete to authenticated
  using (public.is_campaign_mj(campaign_id));
