// Minimal PGlite reproduction for the mission evaluation bug:
//   column reference "mission_id" is ambiguous
// The old INSERT ... ON CONFLICT (mission_id, user_id, progress_date) target
// becomes ambiguous when mission_progress also has the partial unique index
// (mission_id, progress_date) WHERE user_id IS NULL.  The corrected function
// qualifies every target with ON CONFLICT ON CONSTRAINT, which PostgreSQL
// resolves without ambiguity.
//
// Usage:
//   node supabase/scripts/verify_mission_eval_pglite.mjs
// Requires: npm install @electric-sql/pglite (dev tooling only, not shipped).

import { readFile } from 'node:fs/promises'
import { fileURLToPath } from 'node:url'
import { dirname, join } from 'node:path'
import { createRequire } from 'node:module'
const require = createRequire(import.meta.url)
const PGlite = require('@electric-sql/pglite').PGlite

const __dirname = dirname(fileURLToPath(import.meta.url))
const root = join(__dirname, '..')
const migrationPath = join(
  root,
  'migrations',
  '20260827100001_fix_evaluate_missions_ambiguity.sql',
)

const schema = `
do $$ begin
  if not exists (select 1 from pg_roles where rolname = 'anon') then
    create role anon nologin;
  end if;
  if not exists (select 1 from pg_roles where rolname = 'authenticated') then
    create role authenticated nologin;
  end if;
  if not exists (select 1 from pg_roles where rolname = 'service_role') then
    create role service_role nologin;
  end if;
end $$;

create table public.mission_progress (
  id uuid primary key default gen_random_uuid(),
  mission_id uuid not null,
  user_id uuid,
  progress_date date not null default current_date,
  progress jsonb not null default '{}'::jsonb,
  completed boolean not null default false,
  completed_at timestamptz
);
alter table public.mission_progress
  add constraint mission_progress_mission_user_date_unique
  unique (mission_id, user_id, progress_date);
create unique index mission_progress_group_date_unique
  on public.mission_progress (mission_id, progress_date)
  where user_id is null;

create table public.profiles (
  id uuid primary key default gen_random_uuid(),
  display_name text not null,
  daily_step_target integer not null default 10000,
  daily_calorie_target integer not null default 2200
);

create table public.daily_activity (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null,
  activity_date date not null,
  daily_steps integer not null default 0,
  morning_steps integer not null default 0,
  afternoon_steps integer not null default 0,
  night_steps integer not null default 0,
  distance_meters numeric not null default 0,
  manual_entry_detected boolean not null default false
);

create table public.missions (
  id uuid primary key default gen_random_uuid(),
  name text not null,
  description text not null,
  mission_type text not null,
  rules jsonb not null default '{}'::jsonb,
  reward_points integer not null default 0,
  starts_at timestamptz not null,
  ends_at timestamptz not null
);

create table public.posts (
  id uuid primary key default gen_random_uuid(),
  author_id uuid,
  post_type text not null,
  caption text not null,
  system_generated boolean not null default false
);

create table public.app_config (
  config_key text primary key,
  config_value jsonb
);
insert into public.app_config (config_key, config_value)
values ('competition_timezone', '"America/Santiago"');

create table public.seasons (
  id uuid primary key default gen_random_uuid(),
  status text not null,
  starts_at timestamptz not null,
  ends_at timestamptz not null
);
insert into public.seasons (status, starts_at, ends_at)
values ('active', now() - interval '1 day', now() + interval '30 days');

insert into public.profiles (display_name, daily_step_target, daily_calorie_target)
values ('Pipe', 10000, 2200), ('Freddy', 10000, 2200);

insert into public.daily_activity
  (user_id, activity_date, daily_steps, morning_steps, afternoon_steps, night_steps, distance_meters)
select p.id, current_date, 12000, 3000, 6000, 3000, 8000
from public.profiles p;

insert into public.missions (name, description, mission_type, rules, reward_points, starts_at, ends_at)
values (
  'Reto de distancia',
  'Gana quien recorra más distancia del día.',
  'competitive',
  '{"metric":"distance_meters"}'::jsonb,
  10,
  now() - interval '1 day',
  now() + interval '30 days'
);
`

// Exact copy of the broken function body from 20260811120200, reduced to the
// mission evaluation loop so PGlite proves the ambiguity is gone.
const brokenFromMigration = `
create or replace function public.daily_missions_for_date(p_date date)
returns setof public.missions
language sql
stable
as $$
  select * from public.missions
  where p_date::date between starts_at::date and ends_at::date;
$$;

create or replace function public.gen_deterministic_mission_ref(
  p_mission_id uuid, p_user_id uuid, p_date date
) returns uuid
language sql
immutable
as $$
  select ('00000000-0000-4000-8000-' ||
          substr(md5(p_mission_id::text || p_user_id::text || p_date::text), 1, 12))::uuid;
$$;

create or replace function public.award_points(
  p_season_id uuid, p_user_id uuid, p_points integer,
  p_reason text, p_reference_type text, p_reference_id uuid
) returns void
language plpgsql
as $$
begin
  null;
end;
$$;

create or replace function public.evaluate_missions(p_date date)
returns table (mission_id uuid, completed_count integer)
language plpgsql
set search_path = pg_catalog, public
as $$
declare
  v_mission record;
  v_profile record;
  v_target numeric;
  v_tz text;
  v_day_start timestamptz;
  v_day_end timestamptz;
  v_metric_value numeric;
  v_steps numeric;
  v_workouts integer;
  v_consumed numeric;
  v_group_value numeric;
  v_group_members integer;
  v_winner_id uuid;
  v_best numeric;
  v_completed boolean;
  v_season_id uuid;
  v_ref_id uuid;
  v_author uuid;
  v_count integer;
begin
  select config_value #>> '{}' into v_tz from public.app_config
  where config_key = 'competition_timezone';
  v_tz := coalesce(v_tz, 'America/Santiago');
  v_day_start := (p_date::text || 'T00:00:00')::timestamp at time zone v_tz;
  v_day_end := ((p_date + 1)::text || 'T00:00:00')::timestamp at time zone v_tz;

  select id into v_season_id
  from public.seasons
  where status = 'active'
    and starts_at <= now()
    and ends_at > now()
  order by starts_at desc
  limit 1;
  if v_season_id is null then
    return;
  end if;

  for v_mission in
    select * from public.daily_missions_for_date(p_date)
  loop
    v_count := 0;
    v_best := null;
    v_winner_id := null;

    if v_mission.mission_type = 'cooperative' then
      v_group_value := 0;
      v_group_members := 0;
      if (v_mission.rules->>'metric') = 'distance_meters' then
        select coalesce(sum(a.distance_meters), 0) into v_group_value
        from public.daily_activity a
        where a.activity_date = p_date and a.manual_entry_detected = false;
      elsif (v_mission.rules->>'metric') = 'members_with_workout' then
        select count(distinct w.user_id) into v_group_members
        from public.workouts w
        where w.started_at >= v_day_start and w.started_at < v_day_end;
        v_group_value := v_group_members;
      else
        select coalesce(sum(a.daily_steps), 0) into v_group_value
        from public.daily_activity a
        where a.activity_date = p_date and a.manual_entry_detected = false;
      end if;
      v_completed := v_group_value >= (v_mission.rules->>'target')::numeric;
      insert into public.mission_progress
        (mission_id, user_id, progress_date, progress, completed, completed_at)
      values (
        v_mission.id, null, p_date,
        jsonb_build_object(v_mission.rules->>'metric', v_group_value),
        v_completed, case when v_completed then now() else null end
      )
      on conflict (mission_id, progress_date) where user_id is null
      do update set progress = excluded.progress,
        completed = excluded.completed,
        completed_at = excluded.completed_at;
      mission_id := v_mission.id;
      completed_count := v_count;
      return next;
      continue;
    end if;

    for v_profile in
      select p.id, p.daily_step_target, p.daily_calorie_target
      from public.profiles p
    loop
      v_metric_value := 0;
      v_completed := false;
      case v_mission.rules->>'metric'
        when 'morning_steps' then
          select coalesce(a.morning_steps, 0) into v_metric_value
          from public.daily_activity a
          where a.user_id = v_profile.id
            and a.activity_date = p_date
            and a.manual_entry_detected = false;
        when 'distance_meters' then
          select coalesce(a.distance_meters, 0) into v_metric_value
          from public.daily_activity a
          where a.user_id = v_profile.id
            and a.activity_date = p_date
            and a.manual_entry_detected = false;
        else
          v_metric_value := 0;
      end case;

      if v_mission.mission_type = 'competitive' then
        if v_best is null or v_metric_value > v_best then
          v_best := v_metric_value;
          v_winner_id := v_profile.id;
        end if;
        insert into public.mission_progress
          (mission_id, user_id, progress_date, progress, completed, completed_at)
        values (
          v_mission.id, v_profile.id, p_date,
          jsonb_build_object(v_mission.rules->>'metric', v_metric_value),
          false, null
        )
        on conflict (mission_id, user_id, progress_date) do update
          set progress = excluded.progress;
        continue;
      end if;

      v_completed := v_metric_value >= (v_mission.rules->>'target')::numeric;
      insert into public.mission_progress
        (mission_id, user_id, progress_date, progress, completed, completed_at)
      values (
        v_mission.id, v_profile.id, p_date,
        jsonb_build_object(v_mission.rules->>'metric', v_metric_value),
        v_completed, case when v_completed then now() else null end
      )
      on conflict (mission_id, user_id, progress_date) do update
        set progress = excluded.progress,
            completed = excluded.completed,
            completed_at = excluded.completed_at;
    end loop;

    mission_id := v_mission.id;
    completed_count := v_count;
    return next;
  end loop;
end;
$$;
`

const db = new PGlite('memory://')

async function main() {
  await db.exec(schema)

  // 1. Prove the broken target really is ambiguous at execution time.
  await db.exec(brokenFromMigration)
  let brokenError = null
  try {
    await db.query('select * from public.evaluate_missions(current_date)')
  } catch (error) {
    brokenError = String(error?.message ?? error)
  }
  if (!brokenError || !brokenError.includes('ambiguous')) {
    console.error('Expected the broken function to raise an ambiguity error')
    process.exit(1)
  }
  console.log('broken function raised ambiguity as expected')

  // 2. Apply the actual migration and verify it runs cleanly.  The fixed
  //    function renames the OUT column (mission_id -> out_mission_id) to
  //    remove the ambiguity, so PostgreSQL requires DROP before CREATE.
  const fixed = await readFile(migrationPath, 'utf8')
  await db.exec(`drop function if exists public.evaluate_missions(date);\n${fixed}`)
  const rows = await db.query(
    'select * from public.evaluate_missions(current_date)',
  )
  if (!rows.rows?.length) {
    console.error('Expected evaluate_missions to return rows')
    process.exit(1)
  }
  const progress = await db.query(
    `select count(*)::int as n from public.mission_progress
     where progress_date = current_date`,
  )
  if (!progress.rows?.[0] || progress.rows[0].n < 1) {
    console.error('Expected mission_progress rows after evaluation')
    process.exit(1)
  }
  console.log(
    `fixed function ran clean; mission_progress rows=${progress.rows[0].n}`,
  )
  console.log('PGLITE MISSION EVAL VERIFY PASSED')
}

main().catch((error) => {
  console.error(error)
  process.exit(1)
})
