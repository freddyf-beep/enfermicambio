-- Enfermicambio PWA: synchronized training state and a generic health webhook.
-- The existing Health Auto Export tables/functions remain the canonical iOS bridge.

create table if not exists public.training_states (
  user_id uuid primary key references public.profiles(id) on delete cascade,
  state jsonb not null default '{}'::jsonb,
  version bigint not null default 1,
  updated_at timestamptz not null default now(),
  constraint training_states_object check (jsonb_typeof(state) = 'object')
);

alter table public.training_states enable row level security;
revoke all on table public.training_states from anon;
grant select, insert, update on table public.training_states to authenticated;

drop policy if exists training_states_select_own on public.training_states;
create policy training_states_select_own on public.training_states
  for select to authenticated
  using (public.is_allowlisted_user() and user_id = auth.uid());

drop policy if exists training_states_insert_own on public.training_states;
create policy training_states_insert_own on public.training_states
  for insert to authenticated
  with check (public.is_allowlisted_user() and user_id = auth.uid());

drop policy if exists training_states_update_own on public.training_states;
create policy training_states_update_own on public.training_states
  for update to authenticated
  using (public.is_allowlisted_user() and user_id = auth.uid())
  with check (public.is_allowlisted_user() and user_id = auth.uid());

create or replace function public.bump_training_state_version()
returns trigger
language plpgsql
set search_path = pg_catalog, public
as $$
begin
  new.version := old.version + 1;
  new.updated_at := now();
  return new;
end;
$$;

drop trigger if exists training_states_bump_version on public.training_states;
create trigger training_states_bump_version
before update on public.training_states
for each row execute function public.bump_training_state_version();

create or replace function public.rotate_generic_health_ingest_token()
returns jsonb
language plpgsql
security definer
set search_path = pg_catalog, public, extensions
as $$
declare
  v_token text;
  v_prefix text;
begin
  if auth.uid() is null or not public.is_allowlisted_user() then
    raise exception 'Not authorized' using errcode = 'insufficient_privilege';
  end if;

  v_token := encode(gen_random_bytes(32), 'hex');
  v_prefix := left(v_token, 12);
  insert into public.health_ingestion_tokens (
    user_id, token_hash, token_prefix, source, active, last_used_at, revoked_at
  ) values (
    auth.uid(), encode(digest(v_token, 'sha256'), 'hex'), v_prefix,
    'generic_health_export', true, null, null
  )
  on conflict (user_id, source) do update
    set token_hash = excluded.token_hash,
        token_prefix = excluded.token_prefix,
        active = true,
        last_used_at = null,
        revoked_at = null,
        created_at = now();

  return jsonb_build_object('token', v_token, 'token_prefix', v_prefix);
end;
$$;

revoke all on function public.rotate_generic_health_ingest_token() from public, anon;
grant execute on function public.rotate_generic_health_ingest_token() to authenticated;

comment on table public.training_states is
  'Per-user openGym-compatible state synchronized by the Enfermicambio PWA.';
comment on function public.rotate_generic_health_ingest_token() is
  'Rotates the private bearer token used by generic Android health exporters.';
