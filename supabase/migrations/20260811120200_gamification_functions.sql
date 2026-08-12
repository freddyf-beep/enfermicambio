-- Gamification engine functions. Evaluators are security definer and
-- service-role-only (clients never award points). Claims are the one
-- authenticated entry point. Forward-only.

-- 1) Daily mission rotation: deterministic per date, no storage.
create or replace function public.daily_missions_for_date(p_date date)
returns setof public.missions
language sql
stable
security definer
set search_path = pg_catalog, public
as $$
  with pool as (
    select m.*, md5(m.id::text || p_date::text) as sort_key
    from public.missions m
    where m.starts_at::date <= p_date
      and m.ends_at::date >= p_date
  ), ranked as (
    select pool.*, row_number() over (
      partition by pool.mission_type order by pool.sort_key
    ) as rn
    from pool
  )
  select r.id, r.name, r.description, r.mission_type, r.rules,
         r.reward_points, r.starts_at, r.ends_at
  from ranked r
  where (r.mission_type = 'individual' and r.rn <= 2)
     or (r.mission_type = 'cooperative' and r.rn <= 1)
     or (r.mission_type = 'competitive' and r.rn <= 1)
  order by r.mission_type, r.rn;
$$;

grant execute on function public.daily_missions_for_date(date) to authenticated;
grant execute on function public.daily_missions_for_date(date) to service_role;

-- Helper: deterministic reference id for mission awards (idempotent retries).
create or replace function public.gen_deterministic_mission_ref(
  p_mission_id uuid, p_user_id uuid, p_date date
) returns uuid
language sql
immutable
as $$
  select ('00000000-0000-4000-8000-' ||
          substr(md5(p_mission_id::text || p_user_id::text || p_date::text), 1, 12))::uuid;
$$;

grant execute on function public.gen_deterministic_mission_ref(uuid, uuid, date) to service_role;

-- 2) Mission evaluation. Writes mission_progress, awards points on
-- completion, publishes system feed posts. Idempotent via the ledger.
create or replace function public.evaluate_missions(p_date date)
returns table (mission_id uuid, completed_count integer)
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
  select config_value into v_tz from public.app_config
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

      mission_id := v_mission.id;
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
      on conflict (mission_id, user_id, progress_date) do update
        set completed = true, completed_at = excluded.completed_at;

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

    mission_id := v_mission.id;
    completed_count := v_count;
    return next;
  end loop;
end;
$$;

grant execute on function public.evaluate_missions(date) to service_role;

-- 3) Achievement evaluation for one user.
create or replace function public.evaluate_achievements(p_user_id uuid, p_date date)
returns table (achievement_code text)
language plpgsql
security definer
set search_path = pg_catalog, public
as $$
declare
  v_ach record;
  v_metric_value numeric;
  v_season_id uuid;
  v_ref_id uuid;
  v_target_steps numeric;
  v_tz text;
  v_week_start timestamptz;
  v_new_id uuid;
begin
  select config_value into v_tz from public.app_config
  where config_key = 'competition_timezone';
  v_tz := coalesce(v_tz, 'America/Santiago');
  v_week_start := ((p_date - 6)::text || 'T00:00:00')::timestamp at time zone v_tz;

  select id into v_season_id
  from public.seasons
  where status = 'active'
    and starts_at <= now()
    and ends_at > now()
  order by starts_at desc
  limit 1;

  select coalesce(p.daily_step_target, 10000) into v_target_steps
  from public.profiles p where p.id = p_user_id;

  for v_ach in select * from public.achievements order by threshold
  loop
    case v_ach.metric
      when 'workouts_synced' then
        select count(*) into v_metric_value from public.workouts
        where user_id = p_user_id;
      when 'daily_steps' then
        select coalesce(max(a.daily_steps), 0) into v_metric_value
        from public.daily_activity a
        where a.user_id = p_user_id and a.manual_entry_detected = false;
      when 'night_steps' then
        select coalesce(max(a.night_steps), 0) into v_metric_value
        from public.daily_activity a
        where a.user_id = p_user_id and a.manual_entry_detected = false;
      when 'morning_round_wins' then
        select count(*) into v_metric_value from public.season_points sp
        where sp.user_id = p_user_id and sp.reason = 'morning_round_win';
      when 'rounds_and_total_wins' then
        with day_wins as (
          select sp.reason, sp.created_at::date as d
          from public.season_points sp
          where sp.user_id = p_user_id
            and sp.reason in ('morning_round_win', 'afternoon_round_win', 'night_round_win')
        ), wins_per_day as (
          select d, count(*) as n from day_wins group by d
        ), days_total as (
          select a.activity_date as d, a.daily_steps,
                 row_number() over (partition by a.activity_date
                   order by a.daily_steps desc, a.user_id) as rn
          from public.daily_activity a
          where a.user_id = p_user_id and a.manual_entry_detected = false
        )
        select count(*) into v_metric_value
        from wins_per_day wp
        join days_total dt on dt.d = wp.d and dt.rn = 1
        where wp.n = 3;
      when 'step_goal_streak' then
        select coalesce(max(current_count), 0) into v_metric_value
        from public.streaks where user_id = p_user_id and streak_type = 'step_goal';
      when 'workouts_7d' then
        select count(*) into v_metric_value
        from public.workouts w
        where w.user_id = p_user_id and w.started_at >= v_week_start;
      when 'workout_distance_m' then
        select coalesce(max(w.distance_meters), 0) into v_metric_value
        from public.workouts w where w.user_id = p_user_id;
      when 'last_place_streak' then
        with daily_ranks as (
          select a.activity_date as d,
                 row_number() over (partition by a.activity_date
                   order by a.daily_steps desc, a.user_id) as rn,
                 count(*) over (partition by a.activity_date) as participants
          from public.daily_activity a
          where a.manual_entry_detected = false
        ), user_last_days as (
          select d from daily_ranks dr
          where dr.rn = dr.participants
            and exists (
              select 1 from public.daily_activity a
              where a.activity_date = dr.d and a.user_id = p_user_id
                and a.manual_entry_detected = false
            )
        ), grouped as (
          select d, d - (row_number() over (order by d))::int as grp
          from user_last_days
        )
        select coalesce(max(c), 0) into v_metric_value
        from (select count(*) as c from grouped group by grp) t;
      when 'perfect_day' then
        with days as (
          select a.activity_date as d,
                 a.daily_steps >= v_target_steps as step_ok,
                 exists (
                   select 1 from public.workouts w
                   where w.user_id = a.user_id
                     and w.started_at >= (a.activity_date::text || 'T00:00:00')::timestamp at time zone v_tz
                     and w.started_at < ((a.activity_date + 1)::text || 'T00:00:00')::timestamp at time zone v_tz
                 ) as workout_ok,
                 coalesce((
                   select sum(f.calories) from public.food_entries f
                   where f.user_id = a.user_id
                     and f.logged_at >= (a.activity_date::text || 'T00:00:00')::timestamp at time zone v_tz
                     and f.logged_at < ((a.activity_date + 1)::text || 'T00:00:00')::timestamp at time zone v_tz
                 ), 0) as consumed,
                 coalesce((select p.daily_calorie_target from public.profiles p
                           where p.id = a.user_id), 2200) as cal_target
          from public.daily_activity a
          where a.user_id = p_user_id and a.manual_entry_detected = false
        )
        select count(*) into v_metric_value
        from days
        where step_ok and workout_ok
          and consumed > 0 and consumed <= cal_target;
      when 'season_wins' then
        select count(*) into v_metric_value from public.season_results sr
        where sr.user_id = p_user_id and sr.position = 1;
      when 'lifetime_distance_m' then
        select coalesce(sum(a.distance_meters), 0) into v_metric_value
        from public.daily_activity a
        where a.user_id = p_user_id and a.manual_entry_detected = false;
      else
        v_metric_value := 0;
    end case;

    if v_metric_value >= v_ach.threshold then
      v_new_id := null;
      insert into public.user_achievements (user_id, achievement_id, context)
      values (
        p_user_id, v_ach.id,
        jsonb_build_object('metric', v_ach.metric, 'value', v_metric_value)
      )
      on conflict (user_id, achievement_id) do nothing
      returning id into v_new_id;

      if v_new_id is not null then
        if v_ach.season_points > 0 and v_season_id is not null then
          v_ref_id := ('00000000-0000-4000-8000-' ||
            substr(md5('achievement:' || v_ach.code || ':' || p_user_id::text), 1, 12))::uuid;
          begin
            perform public.award_points(
              v_season_id, p_user_id, v_ach.season_points,
              'achievement', 'achievement', v_ref_id);
          exception when unique_violation then
            null;
          end;
        end if;
        insert into public.posts (author_id, post_type, caption, achievement_id, system_generated)
        values (
          p_user_id, 'achievement',
          format('Logro desbloqueado: %s', v_ach.name),
          v_ach.id, true
        );
        achievement_code := v_ach.code;
        return next;
      end if;
    end if;
  end loop;
end;
$$;

grant execute on function public.evaluate_achievements(uuid, date) to service_role;

-- 4) Battle pass claim: verifies the threshold against the ledger, records
-- the claim, applies title rewards. Authenticated users may call this.
create or replace function public.claim_battle_pass_reward(
  p_season_id uuid,
  p_tier integer
)
returns text
language plpgsql
security definer
set search_path = pg_catalog, public
as $$
declare
  v_user_id uuid := auth.uid();
  v_total numeric;
  v_tier record;
  v_claim_id uuid;
begin
  if v_user_id is null then
    raise exception 'Not authenticated';
  end if;

  select coalesce(sum(sp.points), 0) into v_total
  from public.season_points sp
  where sp.season_id = p_season_id and sp.user_id = v_user_id;

  select * into v_tier from public.battle_pass_tiers where tier = p_tier;
  if v_tier.id is null then
    raise exception 'Unknown battle pass tier' using errcode = 'check_violation';
  end if;
  if v_total < v_tier.threshold_points then
    raise exception 'Threshold not reached'
      using errcode = 'check_violation';
  end if;

  select id into v_claim_id from public.battle_pass_claims
  where season_id = p_season_id and user_id = v_user_id and tier = p_tier;
  if v_claim_id is not null then
    return 'already_claimed';
  end if;

  insert into public.battle_pass_claims (season_id, user_id, tier)
  values (p_season_id, v_user_id, p_tier);

  if v_tier.reward_type = 'title' then
    update public.profiles
    set profile_title = v_tier.reward_name
    where id = v_user_id;
  end if;

  return 'claimed:' || v_tier.reward_type;
end;
$$;

grant execute on function public.claim_battle_pass_reward(uuid, integer) to authenticated;
grant execute on function public.claim_battle_pass_reward(uuid, integer) to service_role;
