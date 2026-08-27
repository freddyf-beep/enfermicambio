-- Enfermicambio 2.0 PWA: cloud training state and token-based health imports.

create table public.training_states (
  user_id uuid primary key references public.profiles(id) on delete cascade,
  state jsonb not null default '{}'::jsonb,
  version bigint not null default 1,
  updated_at timestamptz not null default now(),
  constraint training_states_object check (jsonb_typeof(state) = 'object')
);

alter table public.training_states enable row level security;
create policy training_states_select_own on public.training_states
  for select to authenticated using (public.is_allowlisted_user() and user_id = auth.uid());
create policy training_states_insert_own on public.training_states
  for insert to authenticated with check (public.is_allowlisted_user() and user_id = auth.uid());
create policy training_states_update_own on public.training_states
  for update to authenticated using (public.is_allowlisted_user() and user_id = auth.uid())
  with check (public.is_allowlisted_user() and user_id = auth.uid());

create trigger training_states_set_updated_at before update on public.training_states
for each row execute function public.set_updated_at();

create table public.health_ingest_tokens (
  user_id uuid primary key references public.profiles(id) on delete cascade,
  token_hash text not null unique,
  created_at timestamptz not null default now(),
  last_used_at timestamptz
);

alter table public.health_ingest_tokens enable row level security;
-- Token hashes are backend-only. Users rotate them through the RPC below.

create or replace function public.rotate_health_ingest_token()
returns text
language plpgsql
security definer
set search_path = pg_catalog, public, extensions
as $$
declare
  v_token text;
begin
  if auth.uid() is null or not public.is_allowlisted_user() then
    raise exception 'Not authorized' using errcode = 'insufficient_privilege';
  end if;
  v_token := encode(gen_random_bytes(32), 'hex');
  insert into public.health_ingest_tokens(user_id, token_hash, created_at, last_used_at)
  values (auth.uid(), encode(digest(v_token, 'sha256'), 'hex'), now(), null)
  on conflict (user_id) do update
    set token_hash = excluded.token_hash, created_at = now(), last_used_at = null;
  return v_token;
end;
$$;

revoke all on function public.rotate_health_ingest_token() from public, anon;
grant execute on function public.rotate_health_ingest_token() to authenticated;

comment on table public.training_states is
  'Synced openGym-compatible training state for the web-first client.';
comment on table public.health_ingest_tokens is
  'Hashed bearer tokens used only by the ingest_health Edge Function.';
