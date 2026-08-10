-- Phase 0 foundation: four-user allowlist, daily activity, and shared config.
-- Applied migrations are forward-only. Corrective changes belong in a new migration.

create extension if not exists "pgcrypto";

create table public.app_config (
  config_key text primary key,
  config_value jsonb not null,
  description text not null default '',
  updated_at timestamptz not null default now(),
  constraint app_config_key_format check (
    config_key ~ '^[a-z][a-z0-9_]*$'
  )
);

create table public.profiles (
  id uuid primary key references auth.users (id) on delete cascade,
  display_name text not null,
  avatar_url text,
  platform text not null default 'unknown',
  timezone text not null default 'UTC',
  daily_calorie_target integer not null default 2200,
  daily_step_target integer not null default 10000,
  weekly_workout_target integer not null default 3,
  preferred_units text not null default 'metric',
  notification_preferences jsonb not null default '{}'::jsonb,
  default_meal_visibility text not null default 'group',
  default_workout_visibility text not null default 'group',
  allow_post_location boolean not null default false,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  constraint profiles_display_name_length check (
    char_length(btrim(display_name)) between 1 and 80
  ),
  constraint profiles_platform_check check (
    platform in ('ios', 'android', 'unknown')
  ),
  constraint profiles_timezone_not_blank check (
    char_length(btrim(timezone)) > 0
  ),
  constraint profiles_daily_calorie_target_check check (
    daily_calorie_target > 0
  ),
  constraint profiles_daily_step_target_check check (
    daily_step_target > 0
  ),
  constraint profiles_weekly_workout_target_check check (
    weekly_workout_target >= 0
  ),
  constraint profiles_preferred_units_check check (
    preferred_units in ('metric', 'imperial')
  ),
  constraint profiles_meal_visibility_check check (
    default_meal_visibility = 'group'
  ),
  constraint profiles_workout_visibility_check check (
    default_workout_visibility = 'group'
  )
);

create table public.daily_activity (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references public.profiles (id) on delete cascade,
  activity_date date not null,
  morning_steps integer not null default 0,
  afternoon_steps integer not null default 0,
  night_steps integer not null default 0,
  daily_steps integer not null default 0,
  active_calories numeric(12, 2) not null default 0,
  distance_meters numeric(14, 2) not null default 0,
  exercise_minutes numeric(10, 2) not null default 0,
  synced_at timestamptz not null default now(),
  source_platform text not null,
  source_app text,
  source_device text,
  recording_method text,
  manual_entry_detected boolean not null default false,
  source_metadata jsonb not null default '{}'::jsonb,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  constraint daily_activity_user_date_unique unique (user_id, activity_date),
  constraint daily_activity_step_counts_check check (
    morning_steps >= 0
    and afternoon_steps >= 0
    and night_steps >= 0
    and daily_steps >= 0
  ),
  constraint daily_activity_measurements_check check (
    active_calories >= 0
    and distance_meters >= 0
    and exercise_minutes >= 0
  ),
  constraint daily_activity_source_platform_check check (
    source_platform in ('ios', 'android')
  )
);

comment on table public.app_config is
  'Non-secret tuning values used by the competition. Mutations are service-role only.';

comment on table public.profiles is
  'The four authenticated and allowlisted app users. Rows are provisioned server-side.';

comment on table public.daily_activity is
  'Idempotent daily aggregates of accepted automatic health activity.';

comment on column public.daily_activity.daily_steps is
  'Full competition-day total. It may include 00:00-06:00 steps not represented by the three round columns.';

comment on column public.daily_activity.manual_entry_detected is
  'Diagnostic flag indicating that the source window contained a detectable manual record; manual records must not be included in aggregates.';

comment on column public.daily_activity.source_metadata is
  'Diagnostic-only source metadata. Do not expose raw health records or unnecessary identifiers in the client UI.';

create index daily_activity_date_steps_idx
  on public.daily_activity (activity_date, daily_steps desc, user_id);

create index daily_activity_user_date_idx
  on public.daily_activity (user_id, activity_date desc);

create index daily_activity_synced_at_idx
  on public.daily_activity (synced_at desc);

create index daily_activity_source_metadata_gin_idx
  on public.daily_activity using gin (source_metadata jsonb_path_ops);

create index profiles_display_name_idx
  on public.profiles (display_name);

create or replace function public.set_updated_at()
returns trigger
language plpgsql
security definer
set search_path = pg_catalog, public
as $$
begin
  new.updated_at := now();
  return new;
end;
$$;

create trigger profiles_set_updated_at
before update on public.profiles
for each row
execute function public.set_updated_at();

create trigger daily_activity_set_updated_at
before update on public.daily_activity
for each row
execute function public.set_updated_at();

create trigger app_config_set_updated_at
before update on public.app_config
for each row
execute function public.set_updated_at();

create or replace function public.enforce_four_profile_cap()
returns trigger
language plpgsql
security definer
set search_path = pg_catalog, public
as $$
begin
  if tg_op = 'INSERT' then
    -- Serialize provisioning so concurrent inserts cannot exceed the four-user cap.
    perform pg_advisory_xact_lock(
      hashtextextended('public.profiles.four_user_cap', 0)
    );

    if (select count(*) from public.profiles) >= 4 then
      raise exception 'The application allowlist is limited to exactly four profiles'
        using errcode = 'check_violation';
    end if;
  end if;

  return new;
end;
$$;

create trigger profiles_enforce_four_user_cap
before insert on public.profiles
for each row
execute function public.enforce_four_profile_cap();

create or replace function public.is_allowlisted_user()
returns boolean
language sql
stable
security definer
set search_path = pg_catalog, public
as $$
  select auth.uid() is not null
    and (
      select count(*) <= 4
      from public.profiles
    )
    and exists (
      select 1
      from public.profiles
      where id = auth.uid()
    );
$$;

comment on function public.is_allowlisted_user() is
  'Returns true only for an authenticated identity present in the four-profile allowlist. It also fails closed if the cap is violated.';

revoke all on function public.set_updated_at() from public;
revoke all on function public.enforce_four_profile_cap() from public;
revoke all on function public.is_allowlisted_user() from public;
grant execute on function public.is_allowlisted_user() to authenticated;

insert into public.app_config (config_key, config_value, description)
values
  (
    'competition_timezone',
    '"UTC"'::jsonb,
    'Provisional shared timezone. Set the group timezone before real competitions.'
  ),
  ('morning_start', '"06:00"'::jsonb, 'Inclusive start of the morning competition window.'),
  ('morning_end', '"12:00"'::jsonb, 'Exclusive end of the morning competition window.'),
  ('afternoon_start', '"12:00"'::jsonb, 'Inclusive start of the afternoon competition window.'),
  ('afternoon_end', '"18:00"'::jsonb, 'Exclusive end of the afternoon competition window.'),
  ('night_start', '"18:00"'::jsonb, 'Inclusive start of the night competition window.'),
  ('night_end', '"24:00"'::jsonb, 'Exclusive end of the night competition window.'),
  ('season_type', '"monthly"'::jsonb, 'Default season cadence.'),
  ('step_goal_default', '10000'::jsonb, 'Default daily step target for new profiles.'),
  ('leader_event_cooldown', '"00:05:00"'::jsonb, 'Minimum time between repeated leader-change events.'),
  ('daily_rank_points', '{"1": 10, "2": 7, "3": 4, "4": 2}'::jsonb, 'Points awarded by full-day rank.'),
  ('round_win_points', '3'::jsonb, 'Points awarded for a morning, afternoon, or night round win.'),
  ('workout_points', '3'::jsonb, 'Points awarded for a completed workout.'),
  ('calorie_target_points', '2'::jsonb, 'Points awarded for staying within the configured calorie target.')
on conflict (config_key) do nothing;

alter table public.app_config enable row level security;
alter table public.profiles enable row level security;
alter table public.daily_activity enable row level security;

create policy app_config_select_for_allowlisted_users
on public.app_config
for select
to authenticated
using (public.is_allowlisted_user());

create policy profiles_select_for_allowlisted_users
on public.profiles
for select
to authenticated
using (public.is_allowlisted_user());

create policy profiles_update_own_row
on public.profiles
for update
to authenticated
using (
  public.is_allowlisted_user()
  and id = auth.uid()
)
with check (
  public.is_allowlisted_user()
  and id = auth.uid()
);

create policy daily_activity_select_for_allowlisted_users
on public.daily_activity
for select
to authenticated
using (public.is_allowlisted_user());

create policy daily_activity_insert_own_row
on public.daily_activity
for insert
to authenticated
with check (
  public.is_allowlisted_user()
  and user_id = auth.uid()
);

create policy daily_activity_update_own_row
on public.daily_activity
for update
to authenticated
using (
  public.is_allowlisted_user()
  and user_id = auth.uid()
)
with check (
  public.is_allowlisted_user()
  and user_id = auth.uid()
);

revoke all on table public.app_config from anon;
revoke all on table public.profiles from anon;
revoke all on table public.daily_activity from anon;

grant select on table public.app_config to authenticated;
grant select, update on table public.profiles to authenticated;
grant select, insert, update on table public.daily_activity to authenticated;
