-- Health Auto Export bridge: tokenized ingestion for a private iPhone setup.
-- The raw token is never stored. The Edge Function receives it over HTTPS and
-- compares its SHA-256 hash with this table using the service role only.

create table public.health_ingestion_tokens (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references public.profiles (id) on delete cascade,
  token_hash text not null unique,
  token_prefix text not null,
  source text not null default 'health_auto_export',
  active boolean not null default true,
  last_used_at timestamptz,
  created_at timestamptz not null default now(),
  revoked_at timestamptz,
  constraint health_ingestion_tokens_user_source_unique unique (user_id, source),
  constraint health_ingestion_tokens_hash_check check (char_length(token_hash) = 64),
  constraint health_ingestion_tokens_prefix_check check (
    char_length(token_prefix) between 4 and 24
  ),
  constraint health_ingestion_tokens_state_check check (
    (active and revoked_at is null) or (not active)
  )
);

comment on table public.health_ingestion_tokens is
  'Hashed private ingestion tokens for Health Auto Export. Raw tokens must never be stored.';

create index health_ingestion_tokens_active_hash_idx
  on public.health_ingestion_tokens (token_hash)
  where active;

alter table public.health_ingestion_tokens enable row level security;

-- The table is intentionally invisible to the mobile clients. Only the
-- server-side Edge Function needs to read or rotate these credentials.
revoke all on table public.health_ingestion_tokens from anon, authenticated;
grant select, insert, update, delete on table public.health_ingestion_tokens to service_role;

-- The competition already runs in the user's configured Chilean timezone.
-- Keeping this explicit makes the bridge and the existing ranking functions
-- agree on the same calendar day and round boundaries.
update public.app_config
set config_value = '"America/Santiago"'::jsonb,
    updated_at = now()
where config_key = 'competition_timezone';
