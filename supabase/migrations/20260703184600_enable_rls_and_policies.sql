alter table public.users enable row level security;
alter table public.campaigns enable row level security;
alter table public.characters enable row level security;
alter table public.images enable row level security;

-- users: lecture publique (nécessaire pour la vérification de disponibilité du username avant connexion,
-- et pour que les joueurs se voient entre eux), écriture réservée au propriétaire
create policy "users_select_all" on public.users for select using (true);
create policy "users_insert_own" on public.users for insert with check (auth.uid() = id);
create policy "users_update_own" on public.users for update using (auth.uid() = id) with check (auth.uid() = id);
create policy "users_delete_own" on public.users for delete using (auth.uid() = id);

-- campaigns: tout utilisateur connecté peut parcourir/rejoindre par code, seul le créateur écrit
create policy "campaigns_select_authenticated" on public.campaigns for select to authenticated using (true);
create policy "campaigns_insert_own" on public.campaigns for insert with check (auth.uid() = creator_id);
create policy "campaigns_update_own" on public.campaigns for update using (auth.uid() = creator_id) with check (auth.uid() = creator_id);
create policy "campaigns_delete_own" on public.campaigns for delete using (auth.uid() = creator_id);

-- characters: privé au créateur (pas encore de table de membres de campagne)
create policy "characters_select_own" on public.characters for select using (auth.uid() = creator_id);
create policy "characters_insert_own" on public.characters for insert with check (auth.uid() = creator_id);
create policy "characters_update_own" on public.characters for update using (auth.uid() = creator_id) with check (auth.uid() = creator_id);
create policy "characters_delete_own" on public.characters for delete using (auth.uid() = creator_id);

-- images: privées au propriétaire (la RPC get_user_accessible_images l'élargit de façon contrôlée)
create policy "images_select_own" on public.images for select using (auth.uid() = owner_id);
create policy "images_insert_own" on public.images for insert with check (auth.uid() = owner_id);
create policy "images_update_own" on public.images for update using (auth.uid() = owner_id) with check (auth.uid() = owner_id);
create policy "images_delete_own" on public.images for delete using (auth.uid() = owner_id);
