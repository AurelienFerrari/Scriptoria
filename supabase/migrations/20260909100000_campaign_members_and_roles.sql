-- Appartenance à une campagne, avec rôle (MJ / joueur).
--
-- Contexte : la table `campaign_members` était déjà utilisée par le code
-- applicatif (`joinCampaign`, `getVisibleCampaigns`) sans avoir jamais été
-- versionnée — elle avait été créée à la main dans le dashboard. Cette
-- migration rétablit la traçabilité ET introduit la notion de rôle, sur
-- laquelle reposent désormais toutes les règles d'accès aux contenus d'une
-- room (notes, galerie, frise, relations).
--
-- Elle est écrite pour être rejouable : elle fonctionne aussi bien sur une
-- base où la table n'existe pas que sur une base où elle a été créée à la main.

-- ---------------------------------------------------------------------------
-- 1. Table
-- ---------------------------------------------------------------------------

create table if not exists public.campaign_members (
  campaign_id uuid not null references public.campaigns(id) on delete cascade,
  user_id uuid not null references auth.users(id) on delete cascade,
  role text not null default 'player',
  joined_at timestamptz not null default now(),
  primary key (campaign_id, user_id)
);

-- Colonnes potentiellement absentes si la table préexistait.
alter table public.campaign_members
  add column if not exists role text not null default 'player';
alter table public.campaign_members
  add column if not exists joined_at timestamptz not null default now();

-- Contrainte de domaine sur le rôle (ajoutée seulement si absente).
do $$
begin
  if not exists (
    select 1 from pg_constraint where conname = 'campaign_members_role_check'
  ) then
    alter table public.campaign_members
      add constraint campaign_members_role_check check (role in ('mj', 'player'));
  end if;
end $$;

-- Garantit la cible du `on conflict (campaign_id, user_id)` utilisé plus bas
-- et par `joinCampaign()`, même si la table préexistante avait une autre clé.
create unique index if not exists campaign_members_campaign_user_uidx
  on public.campaign_members (campaign_id, user_id);

create index if not exists campaign_members_user_id_idx
  on public.campaign_members (user_id);

-- ---------------------------------------------------------------------------
-- 2. Fonctions d'appartenance
-- ---------------------------------------------------------------------------
--
-- `security definer` est indispensable : une policy RLS posée sur
-- `campaign_members` qui interrogerait `campaign_members` déclencherait une
-- récursion infinie. Ces fonctions s'exécutent avec les droits du
-- propriétaire et court-circuitent donc la RLS ; `search_path` est figé pour
-- éviter tout détournement par un schéma tiers.

create or replace function public.is_campaign_member(p_campaign_id uuid)
returns boolean
language sql
security definer
set search_path = public
stable
as $$
  select exists (
    select 1
    from public.campaign_members m
    where m.campaign_id = p_campaign_id
      and m.user_id = auth.uid()
  );
$$;

create or replace function public.is_campaign_mj(p_campaign_id uuid)
returns boolean
language sql
security definer
set search_path = public
stable
as $$
  select exists (
    select 1
    from public.campaign_members m
    where m.campaign_id = p_campaign_id
      and m.user_id = auth.uid()
      and m.role = 'mj'
  );
$$;

revoke all on function public.is_campaign_member(uuid) from public;
revoke all on function public.is_campaign_mj(uuid) from public;
grant execute on function public.is_campaign_member(uuid) to authenticated;
grant execute on function public.is_campaign_mj(uuid) to authenticated;

-- ---------------------------------------------------------------------------
-- 3. Le créateur d'une campagne en est le MJ, garanti par la base
-- ---------------------------------------------------------------------------
--
-- Confier cette insertion au client laisserait la porte ouverte à une
-- campagne sans MJ (échec réseau entre les deux appels). Un trigger rend
-- l'invariant indépendant du client.

create or replace function public.add_creator_as_mj()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  insert into public.campaign_members (campaign_id, user_id, role)
  values (new.id, new.creator_id, 'mj')
  on conflict (campaign_id, user_id) do update set role = 'mj';
  return new;
end;
$$;

drop trigger if exists campaigns_add_creator_as_mj on public.campaigns;
create trigger campaigns_add_creator_as_mj
  after insert on public.campaigns
  for each row execute function public.add_creator_as_mj();

-- Reprise de l'existant : les campagnes déjà créées n'ont pas déclenché le
-- trigger, leurs créateurs sont rattachés ici.
insert into public.campaign_members (campaign_id, user_id, role)
select c.id, c.creator_id, 'mj'
from public.campaigns c
on conflict (campaign_id, user_id) do update set role = 'mj';

-- ---------------------------------------------------------------------------
-- 4. Row Level Security
-- ---------------------------------------------------------------------------

alter table public.campaign_members enable row level security;

drop policy if exists "campaign_members_select_members" on public.campaign_members;
drop policy if exists "campaign_members_insert_self_or_mj" on public.campaign_members;
drop policy if exists "campaign_members_update_mj" on public.campaign_members;
drop policy if exists "campaign_members_delete_self_or_mj" on public.campaign_members;

-- Lecture : les membres d'une même campagne se voient entre eux.
create policy "campaign_members_select_members" on public.campaign_members
  for select to authenticated
  using (public.is_campaign_member(campaign_id));

-- Insertion : on se rattache soi-même comme joueur (rejoindre par code), ou
-- le MJ rattache quelqu'un. Le rôle `mj` initial passe par le trigger, pas
-- par le client.
create policy "campaign_members_insert_self_or_mj" on public.campaign_members
  for insert to authenticated
  with check (
    (user_id = auth.uid() and role = 'player')
    or public.is_campaign_mj(campaign_id)
  );

-- Modification (changement de rôle) : réservée au MJ.
create policy "campaign_members_update_mj" on public.campaign_members
  for update to authenticated
  using (public.is_campaign_mj(campaign_id))
  with check (public.is_campaign_mj(campaign_id));

-- Suppression : un joueur peut quitter la room, le MJ peut exclure un joueur.
-- Dans les deux cas la ligne visée ne peut pas être celle d'un MJ : une
-- campagne ne doit jamais se retrouver sans meneur.
create policy "campaign_members_delete_self_or_mj" on public.campaign_members
  for delete to authenticated
  using (
    role <> 'mj'
    and (user_id = auth.uid() or public.is_campaign_mj(campaign_id))
  );
