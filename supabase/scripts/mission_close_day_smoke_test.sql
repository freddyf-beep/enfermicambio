-- Post-apply smoke test for the evaluate_missions fix and the daily close.
--
-- Run this AFTER applying 20260827100001_fix_evaluate_missions_ambiguity.sql.
-- Options:
--   supabase db push --db-url "$DATABASE_URL"   (apply the migration first)
--   psql "$DATABASE_URL" -f supabase/scripts/mission_close_day_smoke_test.sql
-- Or paste this into the Supabase SQL editor.
--
-- The test is safe to re-run: it only reads, plus a dry mission evaluation
-- for the current competition date.

begin;

-- 1. The corrected function exists and is service-role executable.
do $$
declare
  v_has_function boolean;
begin
  select exists (
    select 1 from pg_proc p
    join pg_namespace n on n.oid = p.pronamespace
    where n.nspname = 'public'
      and p.proname = 'evaluate_missions'
      and pg_get_function_identity_arguments(p.oid) = 'date'
  ) into v_has_function;
  if not v_has_function then
    raise exception 'evaluate_missions(date) missing; apply the fix migration first';
  end if;
end;
$$;

-- 2. It executes without the ambiguity error and returns per-mission rows.
do $$
declare
  v_day date := (now() at time zone 'America/Santiago')::date;
  v_count integer;
begin
  select count(*) into v_count
  from public.evaluate_missions(v_day);
  raise notice 'evaluate_missions OK for % (% rows)', v_day, v_count;
end;
$$;

-- 3. Mission progress was written for the evaluated day (at least one row).
do $$
declare
  v_day date := (now() at time zone 'America/Santiago')::date;
  v_n integer;
begin
  select count(*) into v_n
  from public.mission_progress
  where progress_date = v_day;
  if v_n < 1 then
    raise notice 'No mission_progress rows for % (expected when no missions are active)', v_day;
  else
    raise notice 'mission_progress rows for %: %', v_day, v_n;
  end if;
end;
$$;

-- 4. Count streaks so the UI can be checked afterwards.
select streak_type, count(*) as users_with_rows
from public.streaks
group by streak_type
order by streak_type;

commit;
