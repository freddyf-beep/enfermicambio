-- Keep the fail-closed behaviour explicit for the two client roles. The
-- Edge Function uses service_role, which bypasses this policy.

create policy health_ingestion_tokens_no_client_access
on public.health_ingestion_tokens
for all
to anon, authenticated
using (false)
with check (false);
