-- ntfy bridge for iPhone/Android builds that cannot receive native APNs/FCM.
-- Each allowlisted user receives one random topic. The topic is treated as a
-- private capability: it is never exposed through a public table policy.

create table if not exists public.ntfy_devices (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null unique references auth.users(id) on delete cascade,
  topic text not null unique
    check (topic ~ '^[A-Za-z0-9_-]{24,64}$'),
  server_url text not null default 'https://ntfy.sh'
    check (server_url = 'https://ntfy.sh'),
  enabled boolean not null default true,
  last_seen_at timestamptz not null default now(),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create index if not exists ntfy_devices_enabled_idx
  on public.ntfy_devices (enabled, last_seen_at desc);

alter table public.ntfy_devices enable row level security;
revoke all on public.ntfy_devices from public, anon, authenticated;
grant select, insert, update on public.ntfy_devices to authenticated;
grant all on public.ntfy_devices to service_role;

drop policy if exists ntfy_devices_select_own on public.ntfy_devices;
create policy ntfy_devices_select_own
on public.ntfy_devices for select to authenticated
using (
  (select public.is_allowlisted_user())
  and user_id = (select auth.uid())
);

drop policy if exists ntfy_devices_insert_own on public.ntfy_devices;
create policy ntfy_devices_insert_own
on public.ntfy_devices for insert to authenticated
with check (
  (select public.is_allowlisted_user())
  and user_id = (select auth.uid())
);

drop policy if exists ntfy_devices_update_own on public.ntfy_devices;
create policy ntfy_devices_update_own
on public.ntfy_devices for update to authenticated
using (
  (select public.is_allowlisted_user())
  and user_id = (select auth.uid())
)
with check (
  (select public.is_allowlisted_user())
  and user_id = (select auth.uid())
);

create or replace function public.get_or_create_ntfy_subscription()
returns table(topic text, server_url text)
language plpgsql
security invoker
set search_path = pg_catalog, public
as $$
declare
  v_user_id uuid := auth.uid();
begin
  if v_user_id is null or not public.is_allowlisted_user() then
    raise exception 'Usuario no autorizado' using errcode = '42501';
  end if;

  insert into public.ntfy_devices (user_id, topic, server_url, enabled, last_seen_at, updated_at)
  values (
    v_user_id,
    -- gen_random_bytes() belongs to pgcrypto and is not enabled on every
    -- project. gen_random_uuid() is available in Supabase by default and
    -- provides enough entropy for this private capability topic.
    'enfermicambio_' || replace(gen_random_uuid()::text, '-', ''),
    'https://ntfy.sh',
    true,
    now(),
    now()
  )
  on conflict (user_id) do update
    set enabled = true,
        last_seen_at = now(),
        updated_at = now();

  return query
    select d.topic, d.server_url
    from public.ntfy_devices d
    where d.user_id = v_user_id
      and d.enabled = true;
end;
$$;

revoke all on function public.get_or_create_ntfy_subscription()
  from public, anon;
grant execute on function public.get_or_create_ntfy_subscription()
  to authenticated;
