insert into storage.buckets (id, name, public)
values ('avatars', 'avatars', true),
       ('images', 'images', true),
       ('maps', 'maps', true)
on conflict (id) do nothing;

create policy "avatars_owner_write" on storage.objects for insert to authenticated
  with check (bucket_id = 'avatars' and (storage.foldername(name))[1] = auth.uid()::text);
create policy "avatars_owner_update" on storage.objects for update to authenticated
  using (bucket_id = 'avatars' and (storage.foldername(name))[1] = auth.uid()::text);
create policy "avatars_owner_delete" on storage.objects for delete to authenticated
  using (bucket_id = 'avatars' and (storage.foldername(name))[1] = auth.uid()::text);

create policy "images_owner_write" on storage.objects for insert to authenticated
  with check (bucket_id = 'images' and (storage.foldername(name))[1] = auth.uid()::text);
create policy "images_owner_update" on storage.objects for update to authenticated
  using (bucket_id = 'images' and (storage.foldername(name))[1] = auth.uid()::text);
create policy "images_owner_delete" on storage.objects for delete to authenticated
  using (bucket_id = 'images' and (storage.foldername(name))[1] = auth.uid()::text);

create policy "maps_owner_write" on storage.objects for insert to authenticated
  with check (bucket_id = 'maps' and (storage.foldername(name))[1] = auth.uid()::text);
create policy "maps_owner_update" on storage.objects for update to authenticated
  using (bucket_id = 'maps' and (storage.foldername(name))[1] = auth.uid()::text);
create policy "maps_owner_delete" on storage.objects for delete to authenticated
  using (bucket_id = 'maps' and (storage.foldername(name))[1] = auth.uid()::text);

-- NB: pas de policy de lecture ici : les buckets sont publics (public = true),
-- ce qui suffit à servir les fichiers via leur URL publique sans passer par une
-- policy SELECT sur storage.objects. En ajouter une élargirait inutilement les
-- droits en autorisant le LISTING de tous les fichiers du bucket (voir la
-- migration suivante, qui corrige justement ce point détecté par l'audit
-- sécurité automatique de Supabase).
