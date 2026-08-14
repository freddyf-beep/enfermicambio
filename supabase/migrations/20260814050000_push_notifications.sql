-- Real device notifications for the four-user private competition.
--
-- The notifications table remains the source of truth. New rows are placed in
-- a private outbox and dispatched by the send_push Edge Function. The
-- database trigger uses pg_net so server-generated events can notify devices
-- even when the author has the app closed.

create table if not exists public.push_devices (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references public.profiles(id) on delete cascade,
  token text not null check (length(token) between 20 and 4096),
  platform text not null check (platform in ('android', 'ios')),
  provider text not null check (provider in ('fcm', 'apns')),
  app_id text not null default 'com.enfermicambio.enfermicambio',
  enabled boolean not null default true,
  last_seen_at timestamptz not null default now(),
  created_at timestamptz not null default now(),
  unique (token)
);

create index if not exists push_devices_user_idx
  on public.push_devices(user_id, enabled, last_seen_at desc);

alter table public.push_devices enable row level security;

drop policy if exists push_devices_select_own on public.push_devices;
create policy push_devices_select_own
on public.push_devices for select to authenticated
using (public.is_allowlisted_user() and user_id = auth.uid());

drop policy if exists push_devices_delete_own on public.push_devices;
create policy push_devices_delete_own
on public.push_devices for delete to authenticated
using (public.is_allowlisted_user() and user_id = auth.uid());

revoke all on public.push_devices from anon, authenticated;
grant select, delete on public.push_devices to authenticated;
grant all on public.push_devices to service_role;

create or replace function public.register_push_device(
  p_token text,
  p_platform text,
  p_provider text,
  p_app_id text default 'com.enfermicambio.enfermicambio'
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
    raise exception 'not allowed';
  end if;
  if p_token is null or length(trim(p_token)) < 20 then
    raise exception 'invalid push token';
  end if;
  if p_platform not in ('android', 'ios') then
    raise exception 'invalid push platform';
  end if;
  if p_provider not in ('fcm', 'apns') then
    raise exception 'invalid push provider';
  end if;

  insert into public.push_devices (
    user_id, token, platform, provider, app_id, enabled, last_seen_at
  )
  values (
    v_user_id, trim(p_token), p_platform, p_provider,
    coalesce(nullif(trim(p_app_id), ''), 'com.enfermicambio.enfermicambio'),
    true, now()
  )
  on conflict (token) do update set
    user_id = excluded.user_id,
    platform = excluded.platform,
    provider = excluded.provider,
    app_id = excluded.app_id,
    enabled = true,
    last_seen_at = now()
  returning id into v_id;

  return v_id;
end;
$$;

revoke all on function public.register_push_device(text, text, text, text)
  from public, anon;
grant execute on function public.register_push_device(text, text, text, text)
  to authenticated, service_role;

create or replace function public.unregister_push_device(p_token text)
returns void
language plpgsql
security definer
set search_path = pg_catalog, public
as $$
begin
  delete from public.push_devices
  where user_id = auth.uid() and token = trim(p_token);
end;
$$;

revoke all on function public.unregister_push_device(text) from public, anon;
grant execute on function public.unregister_push_device(text)
  to authenticated, service_role;

create table if not exists public.push_outbox (
  id uuid primary key default gen_random_uuid(),
  notification_id uuid not null references public.notifications(id) on delete cascade,
  user_id uuid not null references public.profiles(id) on delete cascade,
  status text not null default 'pending'
    check (status in ('pending', 'processing', 'sent', 'failed')),
  attempts integer not null default 0 check (attempts >= 0),
  next_attempt_at timestamptz not null default now(),
  last_error text,
  created_at timestamptz not null default now(),
  sent_at timestamptz,
  unique (notification_id)
);

create index if not exists push_outbox_pending_idx
  on public.push_outbox(status, next_attempt_at, created_at);

alter table public.push_outbox enable row level security;
revoke all on public.push_outbox from anon, authenticated;
grant all on public.push_outbox to service_role;

-- This private row is read only by the SECURITY DEFINER trigger and the
-- service-role Edge Function. No client role receives any privilege.
create table if not exists public.push_dispatch_secrets (
  id boolean primary key default true check (id),
  dispatch_key text not null,
  created_at timestamptz not null default now()
);

alter table public.push_dispatch_secrets enable row level security;
revoke all on public.push_dispatch_secrets from public, anon, authenticated;
grant all on public.push_dispatch_secrets to service_role;

insert into public.push_dispatch_secrets (id, dispatch_key)
values (true, encode(gen_random_bytes(32), 'hex'))
on conflict (id) do nothing;

create or replace function public.enqueue_push_outbox()
returns trigger
language plpgsql
security definer
set search_path = pg_catalog, public
as $$
declare
  v_dispatch_key text;
begin
  insert into public.push_outbox (notification_id, user_id)
  values (new.id, new.user_id)
  on conflict (notification_id) do nothing;

  select dispatch_key into v_dispatch_key
  from public.push_dispatch_secrets
  where id = true;

  if v_dispatch_key is not null then
    perform net.http_post(
      url := 'https://bweynxdzovnbcjwgddar.supabase.co/functions/v1/send_push',
      body := jsonb_build_object('notification_id', new.id),
      headers := jsonb_build_object(
        'Content-Type', 'application/json',
        'X-EnfermiCambio-Dispatch-Key', v_dispatch_key
      ),
      timeout_milliseconds := 5000
    );
  end if;
  return new;
end;
$$;

drop trigger if exists notification_push_outbox_trigger on public.notifications;
create trigger notification_push_outbox_trigger
after insert on public.notifications
for each row execute function public.enqueue_push_outbox();

-- Retry pending rows every minute. The trigger usually delivers immediately;
-- this job covers transient function/network failures without duplicating a
-- successfully sent notification.
do $schedule$
begin
  if not exists (
    select 1 from cron.job where jobname = 'enfermicambio-push-dispatch'
  ) then
    perform cron.schedule(
      'enfermicambio-push-dispatch',
      '* * * * *',
      $command$
        select net.http_post(
          url := 'https://bweynxdzovnbcjwgddar.supabase.co/functions/v1/send_push',
          body := '{"mode":"drain"}'::jsonb,
          headers := '{"Content-Type":"application/json"}'::jsonb,
          timeout_milliseconds := 5000
        );
      $command$
    );
  end if;
end;
$schedule$;
