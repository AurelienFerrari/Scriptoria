create table public.users (
  id uuid primary key references auth.users(id) on delete cascade,
  email text not null unique,
  username text not null unique,
  display_name text,
  bio text,
  avatar_url text,
  created_at timestamptz not null default now(),
  updated_at timestamptz
);

create table public.campaigns (
  id uuid primary key default gen_random_uuid(),
  creator_id uuid not null references auth.users(id) on delete cascade,
  title text not null,
  description text,
  icon_url text,
  max_players int not null default 4,
  join_code text unique,
  created_at timestamptz not null default now(),
  updated_at timestamptz
);

create table public.characters (
  id uuid primary key default gen_random_uuid(),
  creator_id uuid not null references auth.users(id) on delete cascade,
  campaign_id uuid references public.campaigns(id) on delete set null,
  name text not null,
  avatar_url text,
  bio text,
  created_at timestamptz not null default now(),
  updated_at timestamptz
);

create table public.images (
  id uuid primary key default gen_random_uuid(),
  owner_id uuid not null references auth.users(id) on delete cascade,
  campaign_id uuid references public.campaigns(id) on delete cascade,
  bucket text not null,
  path text not null,
  url text,
  created_at timestamptz not null default now()
);

create index campaigns_creator_id_idx on public.campaigns(creator_id);
create index characters_creator_id_idx on public.characters(creator_id);
create index characters_campaign_id_idx on public.characters(campaign_id);
create index images_owner_id_idx on public.images(owner_id);
create index images_campaign_id_idx on public.images(campaign_id);
