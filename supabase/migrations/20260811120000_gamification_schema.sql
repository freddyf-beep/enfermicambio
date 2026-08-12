-- Gamification schema: daily mission progress, battle pass tiers/claims,
-- profile titles, and realtime for progress tables. Forward-only.

-- Daily mission progress: progress resets per competition day.
alter table public.mission_progress
  add column progress_date date not null default current_date;

alter table public.mission_progress
  drop constraint mission_progress_mission_user_unique;

alter table public.mission_progress
  add constraint mission_progress_mission_user_date_unique
  unique (mission_id, user_id, progress_date);

create unique index mission_progress_group_date_unique
  on public.mission_progress (mission_id, progress_date)
  where user_id is null;

-- Battle pass: season progression rewards by points thresholds.
create table public.battle_pass_tiers (
  id uuid primary key default gen_random_uuid(),
  tier integer not null,
  threshold_points integer not null,
  reward_type text not null,
  reward_key text not null,
  reward_name text not null,
  reward_icon text not null,
  created_at timestamptz not null default now(),
  constraint battle_pass_tiers_tier_unique unique (tier),
  constraint battle_pass_tiers_threshold_positive check (threshold_points >= 0),
  constraint battle_pass_tiers_reward_type_check check (
    reward_type in ('badge', 'title', 'emoji')
  )
);

create table public.battle_pass_claims (
  id uuid primary key default gen_random_uuid(),
  season_id uuid not null references public.seasons (id) on delete cascade,
  user_id uuid not null references public.profiles (id) on delete cascade,
  tier integer not null,
  claimed_at timestamptz not null default now(),
  constraint battle_pass_claims_season_user_tier_unique
    unique (season_id, user_id, tier)
);

create index battle_pass_claims_user_idx
  on public.battle_pass_claims (user_id);

-- Profile titles awarded by the battle pass (shown in NOSOTROS).
alter table public.profiles
  add column profile_title text;

-- RLS: tiers readable by the four allowlisted users; claims are read by
-- peers and inserted ONLY through the security definer claim function.
alter table public.battle_pass_tiers enable row level security;
alter table public.battle_pass_claims enable row level security;

create policy battle_pass_tiers_read_allowlisted
  on public.battle_pass_tiers
  for select
  using (public.is_allowlisted_user());

create policy battle_pass_claims_read_allowlisted
  on public.battle_pass_claims
  for select
  using (public.is_allowlisted_user());

-- No insert/update policies: writes flow through claim_battle_pass_reward.

-- Realtime for progress surfaces (database stays authoritative).
alter publication supabase_realtime add table public.mission_progress;
alter publication supabase_realtime add table public.user_achievements;
alter publication supabase_realtime add table public.battle_pass_claims;
