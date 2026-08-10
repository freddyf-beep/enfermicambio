-- Phase 1 full schema: workouts, nutrition, feed, game, seasons.
-- Applied migrations are forward-only. Corrective changes belong in a new migration.

create table public.workouts (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references public.profiles (id) on delete cascade,
  external_id text,
  source text not null,
  workout_type text not null,
  started_at timestamptz not null,
  ended_at timestamptz not null,
  duration_seconds integer not null,
  distance_meters numeric(14, 2),
  active_calories numeric(12, 2),
  avg_pace numeric(10, 2),
  avg_speed numeric(10, 2),
  route_available boolean not null default false,
  created_at timestamptz not null default now(),
  constraint workouts_source_external_id_unique unique (source, external_id),
  constraint workouts_duration_positive check (duration_seconds > 0),
  constraint workouts_time_order check (ended_at > started_at),
  constraint workouts_distance_positive check (
    distance_meters is null or distance_meters >= 0
  ),
  constraint workouts_source_not_blank check (char_length(btrim(source)) > 0)
);

create index workouts_user_started_idx
  on public.workouts (user_id, started_at desc);

create index workouts_ended_at_idx
  on public.workouts (ended_at desc);

create table public.workout_route_points (
  id bigint generated always as identity primary key,
  workout_id uuid not null references public.workouts (id) on delete cascade,
  "timestamp" timestamptz not null,
  latitude double precision not null,
  longitude double precision not null,
  altitude numeric(10, 2),
  accuracy numeric(10, 2),
  bearing numeric(10, 2),
  constraint workout_route_points_coordinates_check check (
    latitude between -90 and 90 and longitude between -180 and 180
  )
);

create index workout_route_points_workout_timestamp_idx
  on public.workout_route_points (workout_id, "timestamp");

create table public.foods (
  id uuid primary key default gen_random_uuid(),
  barcode text,
  name text not null,
  brand text,
  serving_size numeric(12, 2) not null default 100,
  serving_unit text not null default 'g',
  calories numeric(12, 2) not null default 0,
  protein_g numeric(12, 2) not null default 0,
  carbs_g numeric(12, 2) not null default 0,
  fat_g numeric(12, 2) not null default 0,
  source text not null,
  created_by uuid references public.profiles (id) on delete set null,
  created_at timestamptz not null default now(),
  constraint foods_barcode_unique unique (barcode),
  constraint foods_name_not_blank check (char_length(btrim(name)) > 0),
  constraint foods_source_not_blank check (char_length(btrim(source)) > 0),
  constraint foods_macros_positive check (
    calories >= 0 and protein_g >= 0 and carbs_g >= 0 and fat_g >= 0
  ),
  constraint foods_serving_positive check (serving_size > 0)
);

create index foods_name_idx
  on public.foods (name);

create table public.food_entries (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references public.profiles (id) on delete cascade,
  food_id uuid references public.foods (id) on delete set null,
  logged_at timestamptz not null,
  meal_type text not null,
  quantity numeric(12, 2) not null default 1,
  unit text not null default 'serving',
  calories numeric(12, 2) not null default 0,
  protein_g numeric(12, 2) not null default 0,
  carbs_g numeric(12, 2) not null default 0,
  fat_g numeric(12, 2) not null default 0,
  photo_url text,
  notes text,
  source text not null,
  created_at timestamptz not null default now(),
  constraint food_entries_meal_type_check check (
    meal_type in ('breakfast', 'lunch', 'dinner', 'snack', 'other')
  ),
  constraint food_entries_quantity_positive check (quantity > 0),
  constraint food_entries_nutrition_positive check (
    calories >= 0 and protein_g >= 0 and carbs_g >= 0 and fat_g >= 0
  ),
  constraint food_entries_source_not_blank check (char_length(btrim(source)) > 0)
);

create index food_entries_user_logged_at_idx
  on public.food_entries (user_id, logged_at desc);

create table public.posts (
  id uuid primary key default gen_random_uuid(),
  author_id uuid not null references public.profiles (id) on delete cascade,
  post_type text not null,
  caption text,
  workout_id uuid references public.workouts (id) on delete set null,
  food_entry_id uuid references public.food_entries (id) on delete set null,
  achievement_id uuid,
  location_name text,
  latitude double precision,
  longitude double precision,
  created_at timestamptz not null default now(),
  system_generated boolean not null default false,
  constraint posts_post_type_check check (
    post_type in (
      'text', 'photo', 'meal', 'workout', 'route', 'achievement',
      'steps', 'ranking_change', 'round_result', 'mission', 'season'
    )
  ),
  constraint posts_caption_length check (
    caption is null or char_length(caption) between 1 and 1000
  ),
  constraint posts_location_complete check (
    (location_name is null and latitude is null and longitude is null)
    or (location_name is not null and latitude is not null and longitude is not null)
  )
);

create index posts_created_at_idx
  on public.posts (created_at desc);

create index posts_author_created_at_idx
  on public.posts (author_id, created_at desc);

create table public.post_media (
  id uuid primary key default gen_random_uuid(),
  post_id uuid not null references public.posts (id) on delete cascade,
  url text not null,
  media_type text not null,
  sort_order integer not null default 0,
  constraint post_media_media_type_check check (
    media_type in ('image', 'video')
  )
);

create index post_media_post_sort_idx
  on public.post_media (post_id, sort_order);

create table public.comments (
  id uuid primary key default gen_random_uuid(),
  post_id uuid not null references public.posts (id) on delete cascade,
  author_id uuid not null references public.profiles (id) on delete cascade,
  body text not null,
  created_at timestamptz not null default now(),
  constraint comments_body_length check (
    char_length(body) between 1 and 1000
  )
);

create index comments_post_created_idx
  on public.comments (post_id, created_at);

create table public.reactions (
  post_id uuid not null references public.posts (id) on delete cascade,
  user_id uuid not null references public.profiles (id) on delete cascade,
  emoji text not null,
  created_at timestamptz not null default now(),
  primary key (post_id, user_id, emoji),
  constraint reactions_emoji_length check (
    char_length(emoji) between 1 and 8
  )
);

create table public.achievements (
  id uuid primary key default gen_random_uuid(),
  code text not null unique,
  name text not null,
  description text not null,
  icon text not null,
  metric text not null,
  operator text not null,
  threshold numeric(14, 2) not null,
  time_window text,
  repeatable boolean not null default false,
  hidden boolean not null default false,
  season_points integer not null default 0,
  constraint achievements_code_not_blank check (char_length(btrim(code)) > 0),
  constraint achievements_operator_check check (
    operator in ('gte', 'gt', 'lte', 'lt', 'eq')
  ),
  constraint achievements_threshold_positive check (threshold >= 0)
);

create index achievements_code_idx
  on public.achievements (code);

create table public.user_achievements (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references public.profiles (id) on delete cascade,
  achievement_id uuid not null references public.achievements (id) on delete cascade,
  unlocked_at timestamptz not null default now(),
  context jsonb not null default '{}'::jsonb,
  constraint user_achievements_user_achievement_unique unique (user_id, achievement_id)
);

create index user_achievements_user_unlocked_idx
  on public.user_achievements (user_id, unlocked_at desc);

create table public.streaks (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references public.profiles (id) on delete cascade,
  streak_type text not null,
  current_count integer not null default 0,
  longest_count integer not null default 0,
  last_qualified_date date,
  updated_at timestamptz not null default now(),
  constraint streaks_user_type_unique unique (user_id, streak_type),
  constraint streaks_counts_positive check (
    current_count >= 0 and longest_count >= 0
  )
);

create table public.missions (
  id uuid primary key default gen_random_uuid(),
  name text not null,
  description text not null,
  mission_type text not null,
  rules jsonb not null default '{}'::jsonb,
  reward_points integer not null default 0,
  starts_at timestamptz not null,
  ends_at timestamptz not null,
  constraint missions_type_check check (
    mission_type in ('individual', 'competitive', 'cooperative')
  ),
  constraint missions_time_order check (ends_at > starts_at),
  constraint missions_reward_positive check (reward_points >= 0)
);

create index missions_active_idx
  on public.missions (starts_at, ends_at);

create table public.mission_progress (
  id uuid primary key default gen_random_uuid(),
  mission_id uuid not null references public.missions (id) on delete cascade,
  user_id uuid references public.profiles (id) on delete cascade,
  progress jsonb not null default '{}'::jsonb,
  completed boolean not null default false,
  completed_at timestamptz,
  constraint mission_progress_mission_user_unique unique (mission_id, user_id)
);

create table public.seasons (
  id uuid primary key default gen_random_uuid(),
  name text not null,
  starts_at timestamptz not null,
  ends_at timestamptz not null,
  status text not null default 'active',
  constraint seasons_status_check check (
    status in ('active', 'closed', 'pending')
  ),
  constraint seasons_time_order check (ends_at > starts_at)
);

create table public.season_points (
  id uuid primary key default gen_random_uuid(),
  season_id uuid not null references public.seasons (id) on delete cascade,
  user_id uuid not null references public.profiles (id) on delete cascade,
  points integer not null default 0,
  reason text not null,
  reference_type text,
  reference_id uuid,
  created_at timestamptz not null default now(),
  constraint season_points_unique_ledger_entry unique (
    season_id, user_id, reason, reference_type, reference_id
  ),
  constraint season_points_positive check (points >= 0)
);

create index season_points_season_user_idx
  on public.season_points (season_id, user_id, created_at);

create table public.season_results (
  season_id uuid not null references public.seasons (id) on delete cascade,
  user_id uuid not null references public.profiles (id) on delete cascade,
  final_points integer not null default 0,
  final_rank integer not null,
  primary key (season_id, user_id),
  constraint season_results_rank_positive check (final_rank > 0)
);

create view public.season_standings
with (security_invoker = true)
as
  select
    sp.season_id,
    sp.user_id,
    sum(sp.points) as total_points,
    p.display_name
  from public.season_points sp
  join public.profiles p on p.id = sp.user_id
  group by sp.season_id, sp.user_id, p.display_name;

-- Timestamp maintenance for the new mutable tables.
create trigger workouts_set_updated_at
before update on public.workouts
for each row
execute function public.set_updated_at();

create trigger food_entries_set_updated_at
before update on public.food_entries
for each row
execute function public.set_updated_at();

create trigger streaks_set_updated_at
before update on public.streaks
for each row
execute function public.set_updated_at();

-- Row Level Security on every table.
alter table public.workouts enable row level security;
alter table public.workout_route_points enable row level security;
alter table public.foods enable row level security;
alter table public.food_entries enable row level security;
alter table public.posts enable row level security;
alter table public.post_media enable row level security;
alter table public.comments enable row level security;
alter table public.reactions enable row level security;
alter table public.achievements enable row level security;
alter table public.user_achievements enable row level security;
alter table public.streaks enable row level security;
alter table public.missions enable row level security;
alter table public.mission_progress enable row level security;
alter table public.seasons enable row level security;
alter table public.season_points enable row level security;
alter table public.season_results enable row level security;

-- Shared read for all allowlisted users.
create policy workouts_select_for_allowlisted
on public.workouts for select to authenticated
using (public.is_allowlisted_user());

create policy workout_route_points_select_for_allowlisted
on public.workout_route_points for select to authenticated
using (
  public.is_allowlisted_user()
  and exists (
    select 1 from public.workouts w
    where w.id = workout_route_points.workout_id
  )
);

create policy foods_select_for_allowlisted
on public.foods for select to authenticated
using (public.is_allowlisted_user());

create policy food_entries_select_for_allowlisted
on public.food_entries for select to authenticated
using (public.is_allowlisted_user());

create policy posts_select_for_allowlisted
on public.posts for select to authenticated
using (public.is_allowlisted_user());

create policy post_media_select_for_allowlisted
on public.post_media for select to authenticated
using (
  public.is_allowlisted_user()
  and exists (
    select 1 from public.posts p where p.id = post_media.post_id
  )
);

create policy comments_select_for_allowlisted
on public.comments for select to authenticated
using (public.is_allowlisted_user());

create policy reactions_select_for_allowlisted
on public.reactions for select to authenticated
using (public.is_allowlisted_user());

create policy achievements_select_for_allowlisted
on public.achievements for select to authenticated
using (public.is_allowlisted_user());

create policy user_achievements_select_for_allowlisted
on public.user_achievements for select to authenticated
using (public.is_allowlisted_user());

create policy streaks_select_for_allowlisted
on public.streaks for select to authenticated
using (public.is_allowlisted_user());

create policy missions_select_for_allowlisted
on public.missions for select to authenticated
using (public.is_allowlisted_user());

create policy mission_progress_select_for_allowlisted
on public.mission_progress for select to authenticated
using (public.is_allowlisted_user());

create policy seasons_select_for_allowlisted
on public.seasons for select to authenticated
using (public.is_allowlisted_user());

create policy season_points_select_for_allowlisted
on public.season_points for select to authenticated
using (public.is_allowlisted_user());

create policy season_results_select_for_allowlisted
on public.season_results for select to authenticated
using (public.is_allowlisted_user());

-- Owner-scoped writes: workouts, food entries.
create policy workouts_insert_own
on public.workouts for insert to authenticated
with check (
  public.is_allowlisted_user() and user_id = auth.uid()
);

create policy workouts_update_own
on public.workouts for update to authenticated
using (
  public.is_allowlisted_user() and user_id = auth.uid()
)
with check (
  public.is_allowlisted_user() and user_id = auth.uid()
);

create policy workouts_delete_own
on public.workouts for delete to authenticated
using (
  public.is_allowlisted_user() and user_id = auth.uid()
);

create policy food_entries_insert_own
on public.food_entries for insert to authenticated
with check (
  public.is_allowlisted_user() and user_id = auth.uid()
);

create policy food_entries_update_own
on public.food_entries for update to authenticated
using (
  public.is_allowlisted_user() and user_id = auth.uid()
)
with check (
  public.is_allowlisted_user() and user_id = auth.uid()
);

create policy food_entries_delete_own
on public.food_entries for delete to authenticated
using (
  public.is_allowlisted_user() and user_id = auth.uid()
);

-- Route points follow the owning workout.
create policy workout_route_points_write_with_own_workout
on public.workout_route_points for insert to authenticated
with check (
  public.is_allowlisted_user()
  and exists (
    select 1 from public.workouts w
    where w.id = workout_route_points.workout_id and w.user_id = auth.uid()
  )
);

-- Posts: allowlisted authors create; authors manage own manual posts.
create policy posts_insert_allowlisted
on public.posts for insert to authenticated
with check (
  public.is_allowlisted_user()
  and author_id = auth.uid()
  and system_generated = false
);

create policy posts_update_own_manual
on public.posts for update to authenticated
using (
  public.is_allowlisted_user()
  and author_id = auth.uid()
  and system_generated = false
)
with check (
  public.is_allowlisted_user()
  and author_id = auth.uid()
  and system_generated = false
);

create policy posts_delete_own_manual
on public.posts for delete to authenticated
using (
  public.is_allowlisted_user()
  and author_id = auth.uid()
  and system_generated = false
);

-- Post media owned through the author's post.
create policy post_media_write_own_post
on public.post_media for insert to authenticated
with check (
  public.is_allowlisted_user()
  and exists (
    select 1 from public.posts p
    where p.id = post_media.post_id and p.author_id = auth.uid()
  )
);

-- Comments and reactions: create and delete own.
create policy comments_insert_allowlisted
on public.comments for insert to authenticated
with check (
  public.is_allowlisted_user() and author_id = auth.uid()
);

create policy comments_delete_own
on public.comments for delete to authenticated
using (
  public.is_allowlisted_user() and author_id = auth.uid()
);

create policy reactions_insert_allowlisted
on public.reactions for insert to authenticated
with check (
  public.is_allowlisted_user() and user_id = auth.uid()
);

create policy reactions_delete_own
on public.reactions for delete to authenticated
using (
  public.is_allowlisted_user() and user_id = auth.uid()
);

-- Revoke anonymous access on all new tables.
revoke all on table public.workouts from anon;
revoke all on table public.workout_route_points from anon;
revoke all on table public.foods from anon;
revoke all on table public.food_entries from anon;
revoke all on table public.posts from anon;
revoke all on table public.post_media from anon;
revoke all on table public.comments from anon;
revoke all on table public.reactions from anon;
revoke all on table public.achievements from anon;
revoke all on table public.user_achievements from anon;
revoke all on table public.streaks from anon;
revoke all on table public.missions from anon;
revoke all on table public.mission_progress from anon;
revoke all on table public.seasons from anon;
revoke all on table public.season_points from anon;
revoke all on table public.season_results from anon;

-- Authenticated role grants. Game/system tables are read-only for clients.
grant select on table public.workouts to authenticated;
grant select on table public.workout_route_points to authenticated;
grant select on table public.foods to authenticated;
grant select, insert, update, delete on table public.food_entries to authenticated;
grant select, insert, update, delete on table public.posts to authenticated;
grant select, insert, delete on table public.post_media to authenticated;
grant select, insert, delete on table public.comments to authenticated;
grant select, insert, delete on table public.reactions to authenticated;
grant select on table public.achievements to authenticated;
grant select on table public.user_achievements to authenticated;
grant select on table public.streaks to authenticated;
grant select on table public.missions to authenticated;
grant select on table public.mission_progress to authenticated;
grant select on table public.seasons to authenticated;
grant select on table public.season_points to authenticated;
grant select on table public.season_results to authenticated;
grant select on table public.season_standings to authenticated;

-- The four private storage buckets, readable only through signed URLs.
insert into storage.buckets (id, name, public)
values
  ('avatars', 'avatars', false),
  ('feed-media', 'feed-media', false),
  ('meal-media', 'meal-media', false),
  ('workout-media', 'workout-media', false)
on conflict (id) do nothing;

create policy avatars_storage_select_auth
on storage.objects for select to authenticated
using (bucket_id = 'avatars' and public.is_allowlisted_user());

create policy avatars_storage_insert_auth
on storage.objects for insert to authenticated
with check (
  bucket_id = 'avatars'
  and public.is_allowlisted_user()
  and (storage.foldername(name))[1] = auth.uid()::text
);

create policy feed_media_storage_select_auth
on storage.objects for select to authenticated
using (bucket_id = 'feed-media' and public.is_allowlisted_user());

create policy feed_media_storage_insert_auth
on storage.objects for insert to authenticated
with check (
  bucket_id = 'feed-media'
  and public.is_allowlisted_user()
);

create policy meal_media_storage_select_auth
on storage.objects for select to authenticated
using (bucket_id = 'meal-media' and public.is_allowlisted_user());

create policy meal_media_storage_insert_auth
on storage.objects for insert to authenticated
with check (
  bucket_id = 'meal-media'
  and public.is_allowlisted_user()
);

create policy workout_media_storage_select_auth
on storage.objects for select to authenticated
using (bucket_id = 'workout-media' and public.is_allowlisted_user());

create policy workout_media_storage_insert_auth
on storage.objects for insert to authenticated
with check (
  bucket_id = 'workout-media'
  and public.is_allowlisted_user()
);

revoke all on table storage.objects from anon;
revoke all on table storage.buckets from anon;
