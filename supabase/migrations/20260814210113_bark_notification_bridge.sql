-- Bark bridge for iPhone builds that cannot receive native APNs.
-- Bark itself is the native iOS app; the device key is a private capability.
-- ntfy remains available during migration and is skipped for a user once Bark
-- is enabled for that user, preventing duplicate alerts.

create table if not exists public.bark_devices (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null unique references auth.users(id) on delete cascade,
  device_key text not null unique
    check (device_key ~ '^[A-Za-z0-9_-]{8,128}$'),
  server_url text not null default 'https://api.day.app'
    check (server_url = 'https://api.day.app'),
  enabled boolean not null default true,
  last_seen_at timestamptz not null default now(),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create index if not exists bark_devices_enabled_idx
  on public.bark_devices (enabled, last_seen_at desc);

alter table public.bark_devices enable row level security;
revoke all on public.bark_devices from public, anon, authenticated;
grant select, insert, update, delete on public.bark_devices to authenticated;
grant all on public.bark_devices to service_role;

drop policy if exists bark_devices_select_own on public.bark_devices;
create policy bark_devices_select_own
on public.bark_devices for select to authenticated
using (
  (select public.is_allowlisted_user())
  and user_id = (select auth.uid())
);

drop policy if exists bark_devices_insert_own on public.bark_devices;
create policy bark_devices_insert_own
on public.bark_devices for insert to authenticated
with check (
  (select public.is_allowlisted_user())
  and user_id = (select auth.uid())
);

drop policy if exists bark_devices_update_own on public.bark_devices;
create policy bark_devices_update_own
on public.bark_devices for update to authenticated
using (
  (select public.is_allowlisted_user())
  and user_id = (select auth.uid())
)
with check (
  (select public.is_allowlisted_user())
  and user_id = (select auth.uid())
);

drop policy if exists bark_devices_delete_own on public.bark_devices;
create policy bark_devices_delete_own
on public.bark_devices for delete to authenticated
using (
  (select public.is_allowlisted_user())
  and user_id = (select auth.uid())
);

create or replace function public.register_bark_device(p_device_key text)
returns table(device_key text, server_url text, enabled boolean)
language plpgsql
security invoker
set search_path = pg_catalog, public
as $$
declare
  v_user_id uuid := auth.uid();
  v_device_key text := btrim(coalesce(p_device_key, ''));
begin
  if v_user_id is null or not public.is_allowlisted_user() then
    raise exception 'Usuario no autorizado' using errcode = '42501';
  end if;

  if v_device_key !~ '^[A-Za-z0-9_-]{8,128}$' then
    raise exception 'Clave Bark inválida' using errcode = '22023';
  end if;

  insert into public.bark_devices (
    user_id,
    device_key,
    server_url,
    enabled,
    last_seen_at,
    updated_at
  )
  values (
    v_user_id,
    v_device_key,
    'https://api.day.app',
    true,
    now(),
    now()
  )
  on conflict (user_id) do update
    set device_key = excluded.device_key,
        server_url = excluded.server_url,
        enabled = true,
        last_seen_at = now(),
        updated_at = now();

  return query
    select d.device_key, d.server_url, d.enabled
    from public.bark_devices d
    where d.user_id = v_user_id;
end;
$$;

create or replace function public.get_bark_device()
returns table(device_key text, server_url text, enabled boolean)
language sql
security invoker
set search_path = pg_catalog, public
as $$
  select d.device_key, d.server_url, d.enabled
  from public.bark_devices d
  where d.user_id = (select auth.uid())
    and public.is_allowlisted_user();
$$;

create or replace function public.disable_bark_device()
returns void
language plpgsql
security invoker
set search_path = pg_catalog, public
as $$
begin
  if auth.uid() is null or not public.is_allowlisted_user() then
    raise exception 'Usuario no autorizado' using errcode = '42501';
  end if;

  update public.bark_devices
  set enabled = false,
      updated_at = now()
  where user_id = auth.uid();
end;
$$;

-- Internal dispatcher lookup. It is intentionally callable only by the
-- service role; no device key is exposed to the client or anonymous users.
create or replace function public.list_bark_devices_for_dispatch(p_user_id uuid)
returns table(device_key text, server_url text)
language sql
security invoker
set search_path = pg_catalog, public
as $$
  select d.device_key, d.server_url
  from public.bark_devices d
  where d.user_id = p_user_id
    and d.enabled = true;
$$;

revoke all on function public.register_bark_device(text)
  from public, anon;
grant execute on function public.register_bark_device(text)
  to authenticated;

revoke all on function public.get_bark_device()
  from public, anon;
grant execute on function public.get_bark_device()
  to authenticated;

revoke all on function public.disable_bark_device()
  from public, anon;
grant execute on function public.disable_bark_device()
  to authenticated;

revoke all on function public.list_bark_devices_for_dispatch(uuid)
  from public, anon, authenticated;
grant execute on function public.list_bark_devices_for_dispatch(uuid)
  to service_role;
