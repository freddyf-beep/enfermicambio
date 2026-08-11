-- Seed the initial achievement pack from SPECS.md section 65.
-- Applied migrations are forward-only.

insert into public.achievements (code, name, description, icon, metric, operator, threshold, time_window, repeatable, hidden, season_points)
values
  ('FIRST_BLOOD', 'FIRST BLOOD', 'First workout synced', 'fitness_center', 'workouts_synced', 'gte', 1, null, false, false, 0),
  ('5K_CLUB', '5K CLUB', '5,000 steps in one day', 'directions_walk', 'daily_steps', 'gte', 5000, null, false, false, 0),
  ('10K_CLUB', '10K CLUB', '10,000 steps in one day', 'directions_walk', 'daily_steps', 'gte', 10000, null, false, false, 0),
  ('20K_CLUB', '20K CLUB', '20,000 steps in one day', 'directions_run', 'daily_steps', 'gte', 20000, null, false, false, 0),
  ('MARATHON_LEGS', 'MARATHON LEGS', '25,000 steps in one day', 'directions_run', 'daily_steps', 'gte', 25000, null, false, false, 0),
  ('GALLO', 'GALLO', 'Win 5 morning rounds', 'wb_twilight', 'morning_round_wins', 'gte', 5, null, false, false, 0),
  ('VAMPIRO', 'VAMPIRO', '5,000 steps after 22:00', 'nightlight', 'night_steps', 'gte', 5000, null, false, false, 0),
  ('DICTATOR', 'DICTATOR', 'Win all 3 rounds + total in one day', 'emoji_events', 'rounds_and_total_wins', 'gte', 4, null, false, false, 0),
  ('ON_FIRE', 'ON FIRE', '7-day step-goal streak', 'local_fire_department', 'step_goal_streak', 'gte', 7, null, false, false, 0),
  ('GYM_RAT', 'GYM RAT', '5 workouts in 7 days', 'fitness_center', 'workouts_7d', 'gte', 5, '7d', false, false, 0),
  ('RUN_FORREST', 'RUN FORREST', 'Run 5 km in one workout', 'directions_run', 'workout_distance_m', 'gte', 5000, null, false, false, 0),
  ('DOUBLE_DIGITS', 'DOUBLE DIGITS', 'Run 10 km in one workout', 'directions_run', 'workout_distance_m', 'gte', 10000, null, false, false, 0),
  ('SOFA_DE_ORO', 'SOFA DE ORO', 'Finish last 3 days in a row', 'weekend', 'last_place_streak', 'gte', 3, null, false, false, 0),
  ('PERFECT_DAY', 'PERFECT DAY', 'Step goal + workout + calorie target + meals logged', 'star', 'perfect_day', 'gte', 1, null, false, false, 0),
  ('SEASON_CHAMPION', 'SEASON CHAMPION', 'Finish first in a season', 'workspace_premium', 'season_wins', 'gte', 1, null, false, false, 0)
on conflict (code) do nothing;

-- Seed the initial mission pack from SPECS.md section 66.
insert into public.missions (name, description, mission_type, rules, reward_points, starts_at, ends_at)
select * from (values
  ('EARLY BIRD', '2,500 steps before 09:00', 'individual', '{"metric":"steps_before_9","target":2500}'::jsonb, 10, '2026-08-01T00:00:00Z'::timestamptz, '2026-12-31T23:59:59Z'::timestamptz),
  ('MORNING PUSH', '3,000 steps before 12:00', 'individual', '{"metric":"steps_before_12","target":3000}'::jsonb, 10, '2026-08-01T00:00:00Z'::timestamptz, '2026-12-31T23:59:59Z'::timestamptz),
  ('BEAT YOURSELF', 'Beat your 14-day average by 20%', 'individual', '{"metric":"vs_14d_avg","target":1.2}'::jsonb, 15, '2026-08-01T00:00:00Z'::timestamptz, '2026-12-31T23:59:59Z'::timestamptz),
  ('RUN FORREST', 'Run at least 5 km', 'individual', '{"metric":"workout_distance_m","target":5000}'::jsonb, 10, '2026-08-01T00:00:00Z'::timestamptz, '2026-12-31T23:59:59Z'::timestamptz),
  ('ACTIVE DAY', 'Hit step goal + one workout', 'individual', '{"metric":"active_day","target":1}'::jsonb, 10, '2026-08-01T00:00:00Z'::timestamptz, '2026-12-31T23:59:59Z'::timestamptz),
  ('BALANCED DAY', 'Hit step goal + stay within calorie target', 'individual', '{"metric":"balanced_day","target":1}'::jsonb, 10, '2026-08-01T00:00:00Z'::timestamptz, '2026-12-31T23:59:59Z'::timestamptz),
  ('THE FOUR', 'Combined 40,000 steps', 'cooperative', '{"metric":"steps","target":40000}'::jsonb, 20, '2026-08-01T00:00:00Z'::timestamptz, '2026-12-31T23:59:59Z'::timestamptz),
  ('TEAM TRAINING', 'At least 3 of 4 users complete a workout', 'cooperative', '{"metric":"members_with_workout","target":3}'::jsonb, 20, '2026-08-01T00:00:00Z'::timestamptz, '2026-12-31T23:59:59Z'::timestamptz),
  ('LAST CHANCE', 'Most steps from 20:00-23:59', 'competitive', '{"metric":"evening_steps","target":1}'::jsonb, 10, '2026-08-01T00:00:00Z'::timestamptz, '2026-12-31T23:59:59Z'::timestamptz),
  ('DUEL', 'Random pair: most steps in a 2-hour window', 'competitive', '{"metric":"duel_win","target":1}'::jsonb, 10, '2026-08-01T00:00:00Z'::timestamptz, '2026-12-31T23:59:59Z'::timestamptz)
) as v(name, description, mission_type, rules, reward_points, starts_at, ends_at)
where not exists (select 1 from public.missions m where m.name = v.name);
