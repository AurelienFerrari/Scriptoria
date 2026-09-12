-- Réponses dans le chat.
--
-- Un message peut désormais répondre à un autre, en le citant. Seul l'id du
-- message cité est enregistré, jamais son texte, et c'est une règle de
-- sécurité : un joueur qui répond à un chuchotement qu'il a reçu écrit à
-- toute la table. Si la citation recopiait le texte d'origine, elle révélerait
-- le chuchotement à tout le monde. Chaque écran n'affiche la citation que s'il
-- a lui-même le droit de lire l'original.

alter table public.room_messages
  add column if not exists reply_to uuid
    references public.room_messages(id) on delete set null;

-- Retrouver les réponses d'un message, et laisser le `on delete set null`
-- trouver vite ses lignes.
create index if not exists room_messages_reply_to_idx
  on public.room_messages (reply_to);

-- La policy d'écriture gagne une condition : on ne répond qu'à un message de
-- la même room, et qu'on a le droit de lire. La sous-requête passe par la
-- policy de lecture de l'utilisateur : répondre à un chuchotement qui ne lui
-- est pas adressé lui est impossible, même par l'API.
drop policy if exists "room_messages_insert_member" on public.room_messages;

create policy "room_messages_insert_member" on public.room_messages
  for insert to authenticated
  with check (
    author_id = auth.uid()
    and public.is_campaign_member(campaign_id)
    and (visible_to is null or public.is_campaign_mj(campaign_id))
    and (
      reply_to is null
      or exists (
        select 1
        from public.room_messages original
        where original.id = room_messages.reply_to
          and original.campaign_id = room_messages.campaign_id
      )
    )
  );
