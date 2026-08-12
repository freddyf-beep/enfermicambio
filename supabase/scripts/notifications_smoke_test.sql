-- Notifications smoke test (manual, run with psql against the remote DB
-- using the postgres role or the SQL editor in the Supabase dashboard).
--
-- The four-profile cap makes temporary users impossible inside migrations,
-- so these checks live here. It creates temporary auth.users + profiles,
-- verifies triggers/RPCs, then removes everything (cascade cleans up).
--
-- Run inside a transaction; commit only after reviewing the output.
--
-- Usage: paste into Supabase SQL editor, or:
--   psql "$DATABASE_URL" -f supabase/scripts/notifications_smoke_test.sql

begin;

-- Temporarily lift the four-profile cap so test users can be created.
alter table public.profiles disable trigger profiles_enforce_four_user_cap;

create or replace function tmp_make_user(p_email text, p_name text)
returns uuid
language plpgsql
security definer
set search_path = pg_catalog, public
as $$
declare
  v_id uuid := gen_random_uuid();
begin
  insert into auth.users (id, email, encrypted_password, email_confirmed_at)
  values (v_id, p_email, crypt('test123456', gen_salt('bf')), now());
  insert into public.profiles (id, display_name, daily_step_target, daily_calorie_target)
  values (v_id, p_name, 10000, 2200);
  return v_id;
end;
$$;

do $$
declare
  v_a uuid;
  v_b uuid;
  v_c uuid;
  v_post uuid;
  v_n int;
  v_res text;
begin
  select tmp_make_user('notif_a@test.local', 'Alice') into v_a;
  select tmp_make_user('notif_b@test.local', 'Bob') into v_b;
  select tmp_make_user('notif_c@test.local', 'Cara') into v_c;

  -- 1. Manual post -> feed_post for the other two users.
  insert into public.posts (author_id, post_type, caption, system_generated)
  values (v_a, 'text', 'hola', false)
  returning id into v_post;

  select count(*) into v_n from public.notifications
  where type = 'feed_post' and payload ->> 'post_id' = v_post::text;
  assert v_n = 2, 'manual post must notify exactly 2 peers, got ' || v_n;

  -- 2. System post -> no notifications.
  insert into public.posts (author_id, post_type, caption, system_generated)
  values (v_a, 'round_result', 'sys', true);
  select count(*) into v_n from public.notifications where type = 'round_result';
  assert v_n = 0, 'system post must not notify, got ' || v_n;

  -- 3. Comment by Bob on Alice''s post -> one notification to Alice.
  insert into public.comments (post_id, author_id, body)
  values (v_post, v_b, 'nice');
  select count(*) into v_n from public.notifications
  where type = 'comment' and payload ->> 'post_id' = v_post::text;
  assert v_n = 1, 'comment must notify the author once, got ' || v_n;

  -- 4. Reaction by Bob -> one reaction notification to Alice.
  insert into public.reactions (post_id, user_id, emoji) values (v_post, v_b, '❤️');
  insert into public.reactions (post_id, user_id, emoji) values (v_post, v_b, '🔥');
  select count(*) into v_n from public.notifications
  where type = 'reaction' and payload ->> 'post_id' = v_post::text;
  assert v_n = 1, 'reactions dedupe to 1 per (post, actor, 24h), got ' || v_n;

  -- 5. Preferences off: Bob disables 'feed', Cara posts -> no Bob notification.
  update public.profiles
  set notification_preferences = '{"feed": false}'::jsonb
  where id = v_b;
  insert into public.posts (author_id, post_type, caption, system_generated)
  values (v_c, 'photo', 'foto', false)
  returning id into v_post;

  select count(*) into v_n from public.notifications
  where user_id = v_b and type = 'feed_post' and payload ->> 'post_id' = v_post::text;
  assert v_n = 0, 'preference feed=false must suppress, got ' || v_n;

  select count(*) into v_n from public.notifications
  where user_id = v_a and type = 'feed_post' and payload ->> 'post_id' = v_post::text;
  assert v_n = 1, 'peer with feed on must still get it, got ' || v_n;

  -- 6. Weight: set goal, log entry at/below goal, call RPC as Alice (simulated
  -- by running as the owner here; the client path validates auth.uid()).
  update public.profiles set weight_goal_kg = 80 where id = v_a;
  insert into public.weight_entries (user_id, entry_date, weight_kg)
  values (v_a, current_date, 79.5);
  -- Direct call with auth.uid() null bypasses the ownership check (as the
  -- dashboard/SQL editor does); the client path is covered by the RLS policy.
  select public.notify_weight_goal(v_a) into v_res;
  assert v_res in ('goal_emitted', 'change_emitted'), 'expected goal emit, got ' || v_res;

  select count(*) into v_n from public.notifications
  where user_id = v_a and type = 'weight_entry_goal';
  assert v_n = 1, 'weight goal notification missing, got ' || v_n;

  -- 7. Round ending reminder: emits to all profiles, dedupes on retry.
  perform public.notify_round_ending('night', current_date, 30);
  select count(*) into v_n from public.notifications where type = 'round_ending_soon';
  assert v_n = 3, 'round ending must hit all 3 test users, got ' || v_n;

  perform public.notify_round_ending('night', current_date, 30);
  select count(*) into v_n from public.notifications where type = 'round_ending_soon';
  assert v_n = 3, 'round ending must not duplicate, got ' || v_n;

  raise notice 'ALL NOTIFICATION SMOKE TESTS PASSED';
end;
$$;

-- Cleanup: test users, their profiles, notifications, weight rows go away.
delete from auth.users where email like '%@test.local';
alter table public.profiles enable trigger profiles_enforce_four_user_cap;
drop function if exists public.tmp_make_user(text, text);

commit;
