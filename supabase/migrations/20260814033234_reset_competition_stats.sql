-- Reset only user-generated and derived competition data for a fresh run.
-- Profiles, auth users, app configuration, game definitions, nutrition
-- settings, the shared food catalog and Health Auto Export tokens remain.
-- The function is deliberately service-role-only and requires an explicit
-- confirmation string because it removes private user data and media.
create or replace function public.reset_private_demo_data(
  p_confirmation text
)
returns jsonb
language plpgsql
security definer
set search_path = pg_catalog, public
as $$
declare
  deleted_count bigint;
  result jsonb := jsonb_build_object(
    'reset', false,
    'foods_preserved', true,
    'profiles_preserved', true,
    'auth_users_preserved', true,
    'health_ingestion_tokens_preserved', true
  );
begin
  if current_user <> 'service_role' then
    raise exception 'service_role is required';
  end if;

  if p_confirmation <> 'RESET_ENFERMICAMBIO_TEST_DATA' then
    raise exception 'confirmation string does not match';
  end if;

  delete from storage.objects
  where bucket_id in ('feed-media', 'meal-media', 'workout-media');
  get diagnostics deleted_count = row_count;
  result := result || jsonb_build_object('media_objects', deleted_count);

  delete from public.post_media;
  get diagnostics deleted_count = row_count;
  result := result || jsonb_build_object('post_media', deleted_count);

  delete from public.reactions;
  get diagnostics deleted_count = row_count;
  result := result || jsonb_build_object('reactions', deleted_count);

  delete from public.comments;
  get diagnostics deleted_count = row_count;
  result := result || jsonb_build_object('comments', deleted_count);

  delete from public.posts;
  get diagnostics deleted_count = row_count;
  result := result || jsonb_build_object('posts', deleted_count);

  delete from public.food_entries;
  get diagnostics deleted_count = row_count;
  result := result || jsonb_build_object('food_entries', deleted_count);

  delete from public.workout_route_points;
  get diagnostics deleted_count = row_count;
  result := result || jsonb_build_object('workout_route_points', deleted_count);

  delete from public.workouts;
  get diagnostics deleted_count = row_count;
  result := result || jsonb_build_object('workouts', deleted_count);

  delete from public.daily_activity;
  get diagnostics deleted_count = row_count;
  result := result || jsonb_build_object('daily_activity', deleted_count);

  delete from public.weight_entries;
  get diagnostics deleted_count = row_count;
  result := result || jsonb_build_object('weight_entries', deleted_count);

  delete from public.notifications;
  get diagnostics deleted_count = row_count;
  result := result || jsonb_build_object('notifications', deleted_count);

  delete from public.rank_positions;
  get diagnostics deleted_count = row_count;
  result := result || jsonb_build_object('rank_positions', deleted_count);

  delete from public.user_achievements;
  get diagnostics deleted_count = row_count;
  result := result || jsonb_build_object('user_achievements', deleted_count);

  delete from public.streaks;
  get diagnostics deleted_count = row_count;
  result := result || jsonb_build_object('streaks', deleted_count);

  delete from public.mission_progress;
  get diagnostics deleted_count = row_count;
  result := result || jsonb_build_object('mission_progress', deleted_count);

  delete from public.battle_pass_claims;
  get diagnostics deleted_count = row_count;
  result := result || jsonb_build_object('battle_pass_claims', deleted_count);

  delete from public.season_points;
  get diagnostics deleted_count = row_count;
  result := result || jsonb_build_object('season_points', deleted_count);

  delete from public.season_standings;
  get diagnostics deleted_count = row_count;
  result := result || jsonb_build_object('season_standings', deleted_count);

  delete from public.season_results;
  get diagnostics deleted_count = row_count;
  result := result || jsonb_build_object('season_results', deleted_count);

  delete from public.health_ingestion_runs;
  get diagnostics deleted_count = row_count;
  result := result || jsonb_build_object('health_ingestion_runs', deleted_count);

  return result || jsonb_build_object('reset', true);
end;
$$;

revoke all on function public.reset_private_demo_data(text)
  from public, anon, authenticated;
grant execute on function public.reset_private_demo_data(text)
  to service_role;

comment on function public.reset_private_demo_data(text) is
  'Service-role-only reset for a fresh private competition run. Keeps auth users, profiles, app config, seasons, missions, achievements, nutrition profiles, foods and ingestion tokens.';
