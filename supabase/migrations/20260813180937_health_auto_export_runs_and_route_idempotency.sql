-- Health Auto Export receipts are intentionally private.  The bridge Edge
-- Function writes them with service_role and the client reads only the
-- redacted latest summary through health_auto_export_setup.
create table if not exists public.health_ingestion_runs (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references public.profiles (id) on delete cascade,
  source text not null default 'health_auto_export',
  request_id text,
  received_at timestamptz not null default now(),
  status text not null default 'received',
  stage text,
  metric_samples integer not null default 0,
  manual_samples_skipped integer not null default 0,
  workouts integer not null default 0,
  route_points integer not null default 0,
  imported_dates jsonb not null default '[]'::jsonb,
  warnings jsonb not null default '[]'::jsonb,
  error_message text,
  constraint health_ingestion_runs_status_check check (
    status in ('received', 'success', 'failed')
  ),
  constraint health_ingestion_runs_counts_check check (
    metric_samples >= 0 and manual_samples_skipped >= 0
    and workouts >= 0 and route_points >= 0
  )
);

create index if not exists health_ingestion_runs_user_received_idx
  on public.health_ingestion_runs (user_id, received_at desc);

create index if not exists posts_workout_id_idx
  on public.posts (workout_id)
  where workout_id is not null;

alter table public.health_ingestion_runs enable row level security;
revoke all on table public.health_ingestion_runs from anon, authenticated;
grant select, insert, update on table public.health_ingestion_runs to service_role;
drop policy if exists health_ingestion_runs_no_client_access on public.health_ingestion_runs;
create policy health_ingestion_runs_no_client_access
on public.health_ingestion_runs for all to authenticated
using (false)
with check (false);

-- A repeated HAE payload may update the same workout concurrently.  The
-- unique key makes the point insert safe when both requests contain the same
-- timestamp and coordinates.
create unique index if not exists workout_route_points_dedupe_idx
  on public.workout_route_points (workout_id, "timestamp", latitude, longitude);

-- A workout can be shared as a route only once by its owner.  Other post types
-- remain available for the same workout (for example a text update).
create unique index if not exists posts_route_workout_owner_unique
  on public.posts (author_id, workout_id)
  where post_type = 'route' and workout_id is not null;

create unique index if not exists posts_workout_workout_owner_unique
  on public.posts (author_id, workout_id)
  where post_type = 'workout' and workout_id is not null;

-- Photo retries may replace the same temporary object after a transient
-- network failure; keep the bucket private while allowing only group members
-- to update/delete objects.
drop policy if exists feed_media_storage_update_auth on storage.objects;
create policy feed_media_storage_update_auth
on storage.objects for update to authenticated
using (bucket_id = 'feed-media' and public.is_allowlisted_user())
with check (bucket_id = 'feed-media' and public.is_allowlisted_user());

drop policy if exists feed_media_storage_delete_auth on storage.objects;
create policy feed_media_storage_delete_auth
on storage.objects for delete to authenticated
using (bucket_id = 'feed-media' and public.is_allowlisted_user());

drop policy if exists workout_media_storage_delete_auth on storage.objects;
create policy workout_media_storage_delete_auth
on storage.objects for delete to authenticated
using (bucket_id = 'workout-media' and public.is_allowlisted_user());

drop policy if exists workout_media_storage_update_auth on storage.objects;
create policy workout_media_storage_update_auth
on storage.objects for update to authenticated
using (bucket_id = 'workout-media' and public.is_allowlisted_user())
with check (bucket_id = 'workout-media' and public.is_allowlisted_user());

comment on table public.health_ingestion_runs is
  'Private technical audit of Health Auto Export receipts; never exposes raw health payloads.';

-- Repair known English system captions without touching user-written posts.
update public.posts
set caption = replace(
  replace(
    replace(caption, ' won the morning round', ' gan' || chr(243) || ' la franja de la ma' || chr(241) || 'ana'),
    ' won the afternoon round', ' gan' || chr(243) || ' la franja de la tarde'
  ),
  ' won the night round', ' gan' || chr(243) || ' la franja de la noche'
)
where system_generated = true
  and post_type = 'round_result'
  and caption like '% won the % round%';

update public.posts
set caption = replace(caption, ' takes the lead.', ' tom' || chr(243) || ' la delantera.')
where system_generated = true
  and post_type = 'ranking_change'
  and caption like '% takes the lead.';

update public.posts
set caption = replace(caption, ' overtakes ', ' adelant' || chr(243) || ' a ')
where system_generated = true
  and post_type = 'ranking_change'
  and caption like '% overtakes %';

-- Some legacy rows were written through a mis-decoded client and contain
-- UTF-8 mojibake (for example `ganÃ³`). Repair those bytes with chr() so this
-- migration remains transport-safe even when executed from Windows tooling.
update public.posts
set caption = replace(
  replace(
    replace(
      replace(caption, ' on ', ' el '),
      'gan' || chr(195) || chr(131) || chr(194) || chr(179),
      'gan' || chr(243)
    ),
    'ma' || chr(195) || chr(131) || chr(194) || chr(177) || 'ana',
    'ma' || chr(241) || 'ana'
  ),
  'tom' || chr(195) || chr(131) || chr(194) || chr(179),
  'tom' || chr(243)
)
where system_generated = true
  and post_type in ('round_result', 'ranking_change');

update public.posts
set caption = replace(caption, ' on ', ' el ')
where system_generated = true
  and post_type = 'round_result';

update public.posts
set caption = replace(
  caption,
  'adelant' || chr(195) || chr(131) || chr(194) || chr(179),
  'adelant' || chr(243)
)
where system_generated = true
  and post_type = 'ranking_change';

update public.posts
set caption = replace(
  replace(
    replace(caption, convert_from(decode('c383c2b3', 'hex'), 'UTF8'), chr(243)),
    convert_from(decode('c383c2b1', 'hex'), 'UTF8'), chr(241)
  ),
  convert_from(decode('c383c2b4', 'hex'), 'UTF8'), chr(244)
)
where system_generated = true
  and post_type in ('round_result', 'ranking_change');

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
  select da.user_id into v_winner_id
  from public.daily_activity da
  where da.activity_date = p_date and da.manual_entry_detected = false
  order by da.daily_steps desc, da.user_id
  limit 1;
  if v_winner_id is null then return 'no_activity'; end if;

  select display_name into v_winner_name
  from public.profiles where id = v_winner_id;
  select p.author_id, p.created_at into v_prev_leader_id, v_last_post
  from public.posts p
  where p.post_type = 'ranking_change'
  order by p.created_at desc limit 1;
  select (config_value #>> '{}')::interval into v_cooldown
  from public.app_config where config_key = 'leader_event_cooldown';
  if v_cooldown is null then v_cooldown := interval '5 minutes'; end if;

  if v_prev_leader_id is null then
    insert into public.posts (author_id, post_type, caption, system_generated)
    values (v_winner_id, 'ranking_change', v_winner_name || ' tom' || chr(243) || ' la delantera.', true);
    return 'published_first';
  end if;
  if v_prev_leader_id = v_winner_id then return 'no_change'; end if;
  if v_last_post is not null and now() - v_last_post < v_cooldown then return 'cooldown'; end if;

  select display_name into v_prev_leader_name
  from public.profiles where id = v_prev_leader_id;
  v_caption := v_winner_name || ' adelant' || chr(243) || ' a ' || v_prev_leader_name || '.';
  insert into public.posts (author_id, post_type, caption, system_generated)
  values (v_winner_id, 'ranking_change', v_caption, true);
  return 'published';
end;
$$;

revoke all on function public.maybe_publish_leader_change(date) from public;
revoke all on function public.maybe_publish_leader_change(date) from anon;
revoke all on function public.maybe_publish_leader_change(date) from authenticated;
grant execute on function public.maybe_publish_leader_change(date) to service_role;
