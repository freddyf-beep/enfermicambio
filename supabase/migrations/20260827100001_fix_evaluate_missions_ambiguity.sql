-- evaluate_missions fails at runtime with:
--   column reference "mission_id" is ambiguous
-- The INSERT ... ON CONFLICT (mission_id, user_id, progress_date) targets are
-- ambiguous because mission_progress also carries a partial unique index on
-- (mission_id, progress_date) where user_id is null.  Qualify every conflict
-- target with the named constraint so PostgreSQL resolves it unambiguously.
-- No behaviour changes: row values, updates and the cooperative group path
-- keep the exact same semantics.

-- The fixed function renames the OUT column (mission_id -> out_mission_id) to
-- remove the ambiguity, so PostgreSQL requires DROP before CREATE.
drop function if exists public.evaluate_missions(date);

create or replace function public.evaluate_missions(p_date date)
returns table (out_mission_id uuid, completed_count integer)
language plpgsql
security definer
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
  v_avg numeric;
  v_today numeric;
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
      -- Group row: user_id null, progress_date p_date.
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

      if v_completed then
        -- Everyone who contributed earns the reward.
        for v_profile in
          select distinct a.user_id
          from public.daily_activity a
          where a.activity_date = p_date and a.manual_entry_detected = false
          order by a.user_id
        loop
          v_ref_id := public.gen_deterministic_mission_ref(
            v_mission.id, v_profile.user_id, p_date);
          begin
            perform public.award_points(
              v_season_id, v_profile.user_id, v_mission.reward_points,
              'mission', 'mission', v_ref_id);
            v_count := v_count + 1;
          exception when unique_violation then
            null; -- already awarded on a retry
          end;
        end loop;

        if v_count > 0 then
          select user_id into v_author from public.daily_activity
          where activity_date = p_date and manual_entry_detected = false
          order by daily_steps desc nulls last
          limit 1;
          insert into public.posts (author_id, post_type, caption, system_generated)
          values (
            coalesce(v_author, (select id from public.profiles order by created_at limit 1)),
            'mission',
            format('Misión completada: %s (%s puntos)', v_mission.name, v_mission.reward_points),
            true
          );
        end if;
      end if;

      out_mission_id := v_mission.id;
      completed_count := v_count;
      return next;
      continue;
    end if;

    -- Individual and competitive: per user.
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
        when 'night_steps' then
          select coalesce(a.night_steps, 0) into v_metric_value
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
        when 'workout_distance_m' then
          select coalesce(max(w.distance_meters), 0) into v_metric_value
          from public.workouts w
          where w.user_id = v_profile.id
            and w.started_at >= v_day_start and w.started_at < v_day_end;
        when 'vs_14d_avg' then
          select coalesce(avg(a.daily_steps), 0) into v_avg
          from public.daily_activity a
          where a.user_id = v_profile.id
            and a.activity_date < p_date
            and a.activity_date >= p_date - 14
            and a.manual_entry_detected = false;
          select coalesce(a.daily_steps, 0) into v_today
          from public.daily_activity a
          where a.user_id = v_profile.id
            and a.activity_date = p_date
            and a.manual_entry_detected = false;
          v_metric_value := case when v_avg > 0 then v_today / v_avg else 0 end;
        when 'active_day' then
          select coalesce(a.daily_steps, 0) into v_steps
          from public.daily_activity a
          where a.user_id = v_profile.id
            and a.activity_date = p_date
            and a.manual_entry_detected = false;
          select count(*) into v_workouts
          from public.workouts w
          where w.user_id = v_profile.id
            and w.started_at >= v_day_start and w.started_at < v_day_end;
          v_target := coalesce(v_profile.daily_step_target, 10000);
          v_metric_value := case
            when v_steps >= v_target and v_workouts >= 1 then 1 else 0 end;
        when 'balanced_day' then
          select coalesce(a.daily_steps, 0) into v_steps
          from public.daily_activity a
          where a.user_id = v_profile.id
            and a.activity_date = p_date
            and a.manual_entry_detected = false;
          select coalesce(sum(f.calories), 0) into v_consumed
          from public.food_entries f
          where f.user_id = v_profile.id
            and f.logged_at >= v_day_start and f.logged_at < v_day_end;
          v_target := coalesce(v_profile.daily_step_target, 10000);
          v_metric_value := case
            when v_steps >= v_target
             and v_consumed > 0
             and v_consumed <= coalesce(v_profile.daily_calorie_target, 2200)
            then 1 else 0 end;
        when 'steps' then
          select coalesce(a.daily_steps, 0) into v_metric_value
          from public.daily_activity a
          where a.user_id = v_profile.id
            and a.activity_date = p_date
            and a.manual_entry_detected = false;
        else
          v_metric_value := 0;
      end case;
      -- PL/pgSQL sets the target to NULL when a SELECT INTO finds no rows,
      -- even if the variable was just reset to 0.  Normalize it back so that
      -- mission progress and completion never carry NULL.
      v_metric_value := coalesce(v_metric_value, 0);

      if v_mission.mission_type = 'competitive' then
        -- Track the best; completion is decided after the loop.
        if v_best is null or v_metric_value > v_best then
          v_best := v_metric_value;
          v_winner_id := v_profile.id;
        end if;
        -- Record per-user progress so the UI can show the race.
        insert into public.mission_progress
          (mission_id, user_id, progress_date, progress, completed, completed_at)
        values (
          v_mission.id, v_profile.id, p_date,
          jsonb_build_object(v_mission.rules->>'metric', v_metric_value),
          false, null
        )
        on conflict on constraint mission_progress_mission_user_date_unique
        do update set progress = excluded.progress;
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
      on conflict on constraint mission_progress_mission_user_date_unique
      do update set progress = excluded.progress,
          completed = excluded.completed,
          completed_at = excluded.completed_at;

      if v_completed then
        v_ref_id := public.gen_deterministic_mission_ref(
          v_mission.id, v_profile.id, p_date);
        begin
          perform public.award_points(
            v_season_id, v_profile.id, v_mission.reward_points,
            'mission', 'mission', v_ref_id);
          v_count := v_count + 1;
          insert into public.posts (author_id, post_type, caption, system_generated)
          values (
            v_profile.id, 'mission',
            format('Misión completada: %s (%s puntos)', v_mission.name, v_mission.reward_points),
            true
          );
        exception when unique_violation then
          null; -- duplicate award on retry; post already published
        end;
      end if;
    end loop;

    -- Competitive winner resolution.
    if v_mission.mission_type = 'competitive' and v_winner_id is not null then
      insert into public.mission_progress
        (mission_id, user_id, progress_date, progress, completed, completed_at)
      values (
        v_mission.id, v_winner_id, p_date,
        jsonb_build_object(v_mission.rules->>'metric', v_best),
        true, now()
      )
      on conflict on constraint mission_progress_mission_user_date_unique
      do update set completed = true, completed_at = excluded.completed_at;

      v_ref_id := public.gen_deterministic_mission_ref(
        v_mission.id, v_winner_id, p_date);
      begin
        perform public.award_points(
          v_season_id, v_winner_id, v_mission.reward_points,
          'mission', 'mission', v_ref_id);
        v_count := v_count + 1;
        insert into public.posts (author_id, post_type, caption, system_generated)
        values (
          v_winner_id, 'mission',
          format('Misión competitiva ganada: %s (%s puntos)', v_mission.name, v_mission.reward_points),
          true
        );
      exception when unique_violation then
        null;
      end;
    end if;

    out_mission_id := v_mission.id;
    completed_count := v_count;
    return next;
  end loop;
end;
$$;

revoke all on function public.evaluate_missions(date) from public, anon;
grant execute on function public.evaluate_missions(date) to service_role;

