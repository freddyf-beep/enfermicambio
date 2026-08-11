-- Rate-limited leader-change events (Phase 4.7).
--
-- maybe_publish_leader_change(competition_date) checks whether the top user
-- for that day changed since the last published ranking_change post, and
-- respects the leader_event_cooldown from app_config. Publishes at most one
-- event per (pair, window): the previous leader and current leader are encoded
-- in the post caption, and the cooldown is enforced by comparing timestamps
-- against the most recent ranking_change post for the same pair.

create or replace function public.maybe_publish_leader_change(p_date date)
returns text
language plpgsql
security definer
set search_path = pg_catalog, public
as $$
declare
  v_winner_id uuid;
  v_winner_name text;
  v_prev_leader_id uuid;
  v_prev_leader_name text;
  v_cooldown interval;
  v_last_post timestamptz;
  v_caption text;
begin
  -- Winner of the day by accepted automatic steps.
  select da.user_id
  into v_winner_id
  from public.daily_activity da
  where da.activity_date = p_date
    and da.manual_entry_detected = false
  order by da.daily_steps desc, da.user_id
  limit 1;

  if v_winner_id is null then
    return 'no_activity';
  end if;

  select display_name into v_winner_name
  from public.profiles where id = v_winner_id;

  -- Previous leader: the author of the most recent ranking_change post.
  select p.author_id, p.created_at
  into v_prev_leader_id, v_last_post
  from public.posts p
  where p.post_type = 'ranking_change'
  order by p.created_at desc
  limit 1;

  -- Cooldown window between repeated leader-change events.
  select (config_value #>> '{}')::interval
  into v_cooldown
  from public.app_config
  where config_key = 'leader_event_cooldown';

  if v_cooldown is null then
    v_cooldown := interval '5 minutes';
  end if;

  -- No prior event: publish the first one.
  if v_prev_leader_id is null then
    insert into public.posts (author_id, post_type, caption, system_generated)
    values (v_winner_id, 'ranking_change', v_winner_name || ' takes the lead.', true);
    return 'published_first';
  end if;

  -- Same leader: nothing to publish.
  if v_prev_leader_id = v_winner_id then
    return 'no_change';
  end if;

  -- Different leader, but still inside the cooldown window: skip.
  if v_last_post is not null and now() - v_last_post < v_cooldown then
    return 'cooldown';
  end if;

  select display_name into v_prev_leader_name
  from public.profiles where id = v_prev_leader_id;

  v_caption := v_winner_name || ' overtakes ' || v_prev_leader_name || '.';
  insert into public.posts (author_id, post_type, caption, system_generated)
  values (v_winner_id, 'ranking_change', v_caption, true);

  return 'published';
end;
$$;

revoke all on function public.maybe_publish_leader_change(date) from public;
revoke all on function public.maybe_publish_leader_change(date) from anon;
revoke all on function public.maybe_publish_leader_change(date) from authenticated;
grant execute on function public.maybe_publish_leader_change(date) to service_role;
