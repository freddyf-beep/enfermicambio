-- Keep one system feed item per user's daily activity.  The activity row is
-- still the source of truth; this post is only the group-facing projection.
alter table public.posts
  add column if not exists source_key text;

create unique index if not exists posts_source_key_unique
  on public.posts (source_key);

create or replace function public.upsert_daily_activity_feed_post(
  p_user_id uuid,
  p_date date
)
returns uuid
language plpgsql
security definer
set search_path = pg_catalog, public
as $$
declare
  v_steps integer;
  v_distance numeric;
  v_manual boolean;
  v_name text;
  v_source_key text;
  v_caption text;
  v_post_id uuid;
begin
  select da.daily_steps, da.distance_meters, da.manual_entry_detected
    into v_steps, v_distance, v_manual
  from public.daily_activity da
  where da.user_id = p_user_id
    and da.activity_date = p_date;

  if not found or coalesce(v_manual, false) then
    return null;
  end if;

  select coalesce(p.display_name, 'Amigo')
    into v_name
  from public.profiles p
  where p.id = p_user_id;

  v_source_key := 'daily_activity:' || p_user_id::text || ':' || p_date::text;
  if coalesce(v_distance, 0) > 0 then
    v_caption := v_name || ' actualizó sus pasos: ' ||
      coalesce(v_steps, 0)::text || ' pasos · ' ||
      round(v_distance)::text || ' m.';
  else
    v_caption := v_name || ' actualizó sus pasos: ' ||
      coalesce(v_steps, 0)::text || ' pasos.';
  end if;

  insert into public.posts (
    author_id,
    post_type,
    caption,
    system_generated,
    source_key
  ) values (
    p_user_id,
    'steps',
    v_caption,
    true,
    v_source_key
  )
  on conflict (source_key) do update
    set author_id = excluded.author_id,
        post_type = excluded.post_type,
        caption = excluded.caption,
        system_generated = true,
        created_at = now()
  returning id into v_post_id;

  return v_post_id;
end;
$$;

revoke all on function public.upsert_daily_activity_feed_post(uuid, date)
  from public, anon, authenticated;
grant execute on function public.upsert_daily_activity_feed_post(uuid, date)
  to service_role;

create or replace function public.sync_daily_activity_feed_post()
returns trigger
language plpgsql
security definer
set search_path = pg_catalog, public
as $$
begin
  perform public.upsert_daily_activity_feed_post(new.user_id, new.activity_date);
  return new;
end;
$$;

revoke all on function public.sync_daily_activity_feed_post()
  from public, anon, authenticated;
grant execute on function public.sync_daily_activity_feed_post() to service_role;

drop trigger if exists daily_activity_feed_projection on public.daily_activity;
create trigger daily_activity_feed_projection
after insert or update on public.daily_activity
for each row execute function public.sync_daily_activity_feed_post();

-- Repair existing automatic activity rows, including Android rows that were
-- received before the feed projection existed.
do $$
declare
  v_row record;
begin
  for v_row in
    select user_id, activity_date
    from public.daily_activity
    where manual_entry_detected = false
  loop
    perform public.upsert_daily_activity_feed_post(
      v_row.user_id,
      v_row.activity_date
    );
  end loop;
end;
$$;

-- Private Web Push subscriptions used by the iPhone Home Screen bridge.
create table if not exists public.web_push_devices (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users(id) on delete cascade,
  endpoint text not null,
  p256dh text not null,
  auth text not null,
  user_agent text,
  enabled boolean not null default true,
  last_seen_at timestamptz not null default now(),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique (user_id, endpoint)
);

create index if not exists web_push_devices_user_enabled_idx
  on public.web_push_devices (user_id, enabled);

alter table public.web_push_devices enable row level security;
revoke all on public.web_push_devices from anon;
grant select, insert, update, delete on public.web_push_devices to authenticated;
grant all on public.web_push_devices to service_role;

drop policy if exists web_push_devices_select_own on public.web_push_devices;
create policy web_push_devices_select_own
on public.web_push_devices for select to authenticated
using (public.is_allowlisted_user() and user_id = auth.uid());

drop policy if exists web_push_devices_insert_own on public.web_push_devices;
create policy web_push_devices_insert_own
on public.web_push_devices for insert to authenticated
with check (public.is_allowlisted_user() and user_id = auth.uid());

drop policy if exists web_push_devices_update_own on public.web_push_devices;
create policy web_push_devices_update_own
on public.web_push_devices for update to authenticated
using (public.is_allowlisted_user() and user_id = auth.uid())
with check (public.is_allowlisted_user() and user_id = auth.uid());

drop policy if exists web_push_devices_delete_own on public.web_push_devices;
create policy web_push_devices_delete_own
on public.web_push_devices for delete to authenticated
using (public.is_allowlisted_user() and user_id = auth.uid());

create or replace function public.register_web_push_device(
  p_endpoint text,
  p_p256dh text,
  p_auth text,
  p_user_agent text default null
)
returns uuid
language plpgsql
security definer
set search_path = pg_catalog, public
as $$
declare
  v_user_id uuid := auth.uid();
  v_id uuid;
begin
  if v_user_id is null or not public.is_allowlisted_user() then
    raise exception 'Usuario no autorizado' using errcode = '42501';
  end if;
  if length(coalesce(p_endpoint, '')) < 32
     or left(p_endpoint, 8) <> 'https://'
     or length(coalesce(p_p256dh, '')) < 16
     or length(coalesce(p_auth, '')) < 8 then
    raise exception 'Suscripción Web Push inválida' using errcode = '22023';
  end if;

  insert into public.web_push_devices (
    user_id, endpoint, p256dh, auth, user_agent,
    enabled, last_seen_at, updated_at
  ) values (
    v_user_id, p_endpoint, p_p256dh, p_auth, left(p_user_agent, 500),
    true, now(), now()
  )
  on conflict (user_id, endpoint) do update
    set p256dh = excluded.p256dh,
        auth = excluded.auth,
        user_agent = excluded.user_agent,
        enabled = true,
        last_seen_at = now(),
        updated_at = now()
  returning id into v_id;

  return v_id;
end;
$$;

revoke all on function public.register_web_push_device(text, text, text, text)
  from public, anon;
grant execute on function public.register_web_push_device(text, text, text, text)
  to authenticated;

create or replace function public.unregister_web_push_device(p_endpoint text)
returns boolean
language plpgsql
security definer
set search_path = pg_catalog, public
as $$
begin
  delete from public.web_push_devices
  where user_id = auth.uid()
    and endpoint = p_endpoint;
  return found;
end;
$$;

revoke all on function public.unregister_web_push_device(text)
  from public, anon;
grant execute on function public.unregister_web_push_device(text)
  to authenticated;

-- Avatar replacement needs UPDATE/DELETE in addition to the original INSERT
-- policy. Objects remain private and are exposed only through signed URLs.
drop policy if exists avatars_storage_update_own on storage.objects;
create policy avatars_storage_update_own
on storage.objects for update to authenticated
using (
  bucket_id = 'avatars'
  and public.is_allowlisted_user()
  and (storage.foldername(name))[1] = auth.uid()::text
)
with check (
  bucket_id = 'avatars'
  and public.is_allowlisted_user()
  and (storage.foldername(name))[1] = auth.uid()::text
);

drop policy if exists avatars_storage_delete_own on storage.objects;
create policy avatars_storage_delete_own
on storage.objects for delete to authenticated
using (
  bucket_id = 'avatars'
  and public.is_allowlisted_user()
  and (storage.foldername(name))[1] = auth.uid()::text
);
