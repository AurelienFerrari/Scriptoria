-- Journal des jets de dés d'une room.
--
-- Les jets ne quittaient jamais le téléphone : chacun lançait dans son coin,
-- et le MJ n'avait aucun moyen de savoir ce qui s'était passé. Ils sont
-- désormais enregistrés et partagés, comme des dés qui roulent sur la table.
--
-- Le MJ peut lancer en secret : c'est le seul à en avoir besoin, et il en a
-- réellement besoin — un jet de rencontre aléatoire perd tout son sens si les
-- joueurs le voient tomber.

create table if not exists public.dice_rolls (
  id uuid primary key default gen_random_uuid(),
  campaign_id uuid not null references public.campaigns(id) on delete cascade,
  user_id uuid not null references auth.users(id) on delete cascade,
  sides int not null,
  dice_count int not null,
  modifier int not null default 0,
  -- Chaque dé conservé séparément : le total seul empêcherait de relire le
  -- détail d'un jet, qui est précisément ce qu'on vérifie à une table.
  results int[] not null,
  is_secret boolean not null default false,
  created_at timestamptz not null default now()
);

-- Le total et la notation ne sont pas stockés : ils se déduisent des colonnes
-- ci-dessus, et les dupliquer ouvrirait la porte à une divergence entre le
-- détail affiché et la somme annoncée.

create index if not exists dice_rolls_campaign_created_idx
  on public.dice_rolls (campaign_id, created_at desc);

alter table public.dice_rolls enable row level security;

drop policy if exists "dice_rolls_select_members" on public.dice_rolls;
drop policy if exists "dice_rolls_insert_self" on public.dice_rolls;
drop policy if exists "dice_rolls_delete_mj" on public.dice_rolls;

-- Lecture : les membres de la room voient les jets, sauf ceux marqués secrets
-- qui restent au seul MJ.
create policy "dice_rolls_select_members" on public.dice_rolls
  for select to authenticated
  using (
    public.is_campaign_member(campaign_id)
    and (
      is_secret = false
      or public.is_campaign_mj(campaign_id)
    )
  );

-- Écriture : on n'enregistre que ses propres jets, dans une room dont on est
-- membre. Le drapeau secret est réservé au MJ, sinon n'importe quel joueur
-- pourrait masquer un résultat qui l'arrange.
create policy "dice_rolls_insert_self" on public.dice_rolls
  for insert to authenticated
  with check (
    user_id = auth.uid()
    and public.is_campaign_member(campaign_id)
    and (
      is_secret = false
      or public.is_campaign_mj(campaign_id)
    )
  );

-- Aucune policy de mise à jour : un jet est immuable. Personne ne réécrit un
-- résultat après coup, pas même le MJ.

-- Suppression : le MJ vide le journal entre deux séances.
create policy "dice_rolls_delete_mj" on public.dice_rolls
  for delete to authenticated
  using (public.is_campaign_mj(campaign_id));
