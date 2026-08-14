-- Keep immutable helpers deterministic even if a role changes its default
-- search_path. These functions are called by security-definer game code.
create or replace function public.gen_deterministic_mission_ref(
  p_mission_id uuid, p_user_id uuid, p_date date
) returns uuid
language sql
immutable
set search_path = pg_catalog, public
as $$
  select ('00000000-0000-4000-8000-' ||
          substr(md5(p_mission_id::text || p_user_id::text || p_date::text), 1, 12))::uuid;
$$;

create or replace function public.notification_category(p_type text)
returns text
language sql
immutable
set search_path = pg_catalog, public
as $$
  select case p_type
    when 'overtake' then 'overtakes'
    when 'leader_change' then 'overtakes'
    when 'round_result' then 'rounds'
    when 'round_ending_soon' then 'rounds'
    when 'achievement' then 'achievements'
    when 'workout' then 'workouts'
    when 'feed_post' then 'feed'
    when 'comment' then 'social'
    when 'reaction' then 'social'
    when 'mission' then 'missions'
    when 'season' then 'season'
    when 'steps_milestone' then 'personal'
    when 'personal_record' then 'personal'
    when 'daily_goal' then 'personal'
    when 'weight_entry_goal' then 'weight'
    when 'weight_change' then 'weight'
    else 'other'
  end;
$$;
