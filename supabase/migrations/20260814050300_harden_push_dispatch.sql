-- Keep the webhook trigger callable only by Postgres internals and make the
-- private queue's deny-by-default posture explicit to the linter.

drop policy if exists push_outbox_no_client_access on public.push_outbox;
create policy push_outbox_no_client_access
on public.push_outbox for all to anon, authenticated
using (false)
with check (false);

drop policy if exists push_dispatch_secrets_no_client_access
  on public.push_dispatch_secrets;
create policy push_dispatch_secrets_no_client_access
on public.push_dispatch_secrets for all to anon, authenticated
using (false)
with check (false);

revoke all on function public.enqueue_push_outbox() from public, anon, authenticated;
grant execute on function public.enqueue_push_outbox() to service_role;
