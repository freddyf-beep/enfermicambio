-- Concurrency-safe claims for the push dispatcher.

create or replace function public.claim_push_outbox(
  p_notification_id uuid default null,
  p_limit integer default 25
)
returns table (id uuid, notification_id uuid, user_id uuid)
language plpgsql
security definer
set search_path = pg_catalog, public
as $$
begin
  return query
  with candidates as (
    select o.id
    from public.push_outbox o
    where o.next_attempt_at <= now()
      and (
        o.status = 'pending'
        or (o.status = 'processing' and o.created_at < now() - interval '5 minutes')
      )
      and (p_notification_id is null or o.notification_id = p_notification_id)
    order by o.created_at
    for update skip locked
    limit greatest(1, least(coalesce(p_limit, 25), 100))
  ), claimed as (
    update public.push_outbox o
    set status = 'processing',
        attempts = o.attempts + 1
    from candidates c
    where o.id = c.id
    returning o.id, o.notification_id, o.user_id
  )
  select c.id, c.notification_id, c.user_id from claimed c;
end;
$$;

revoke all on function public.claim_push_outbox(uuid, integer)
  from public, anon, authenticated;
grant execute on function public.claim_push_outbox(uuid, integer)
  to service_role;

create or replace function public.finish_push_outbox(
  p_id uuid,
  p_success boolean,
  p_error text default null
)
returns void
language plpgsql
security definer
set search_path = pg_catalog, public
as $$
begin
  update public.push_outbox
  set status = case
        when p_success then 'sent'
        when attempts >= 5 then 'failed'
        else 'pending'
      end,
      last_error = case when p_success then null else left(p_error, 2000) end,
      next_attempt_at = case
        when p_success then now()
        else now() + make_interval(mins => least(greatest(attempts, 1) * 2, 30))
      end,
      sent_at = case when p_success then now() else null end
  where id = p_id;
end;
$$;

revoke all on function public.finish_push_outbox(uuid, boolean, text)
  from public, anon, authenticated;
grant execute on function public.finish_push_outbox(uuid, boolean, text)
  to service_role;
