-- The PWA bridges for Apple Shortcuts and Android Health Connect must not
-- rotate each other's credentials. Expose only a redacted, owner-scoped
-- status summary; raw hashes and ingestion receipts stay service-role only.

create or replace function public.rotate_platform_health_ingest_token(p_source text)
returns jsonb
language plpgsql
security definer
set search_path = pg_catalog, public, extensions
as $$
declare
  v_source text := lower(trim(coalesce(p_source, '')));
  v_token text;
  v_prefix text;
begin
  if auth.uid() is null or not public.is_allowlisted_user() then
    raise exception 'Not authorized' using errcode = '42501';
  end if;
  if v_source not in ('ios_shortcut', 'android_health_connect') then
    raise exception 'Unsupported health bridge' using errcode = '22023';
  end if;

  v_token := encode(gen_random_bytes(32), 'hex');
  v_prefix := left(v_token, 12);
  insert into public.health_ingestion_tokens (
    user_id, token_hash, token_prefix, source, active, last_used_at, revoked_at
  ) values (
    auth.uid(), encode(digest(v_token, 'sha256'), 'hex'), v_prefix,
    v_source, true, null, null
  )
  on conflict (user_id, source) do update
    set token_hash = excluded.token_hash,
        token_prefix = excluded.token_prefix,
        active = true,
        last_used_at = null,
        revoked_at = null,
        created_at = now();

  return jsonb_build_object('token', v_token, 'token_prefix', v_prefix, 'source', v_source);
end;
$$;

revoke all on function public.rotate_platform_health_ingest_token(text) from public, anon;
grant execute on function public.rotate_platform_health_ingest_token(text) to authenticated;

create or replace function public.get_platform_health_ingest_status(p_source text)
returns jsonb
language plpgsql
security definer
stable
set search_path = pg_catalog, public
as $$
declare
  v_source text := lower(trim(coalesce(p_source, '')));
  v_token record;
  v_run record;
  v_activity record;
begin
  if auth.uid() is null or not public.is_allowlisted_user() then
    raise exception 'Not authorized' using errcode = '42501';
  end if;
  if v_source not in ('ios_shortcut', 'android_health_connect') then
    raise exception 'Unsupported health bridge' using errcode = '22023';
  end if;

  select token_prefix, active, last_used_at
  into v_token
  from public.health_ingestion_tokens
  where user_id = auth.uid() and source = v_source;

  select status, received_at, stage, metric_samples, workouts,
         imported_dates, warnings, error_message
  into v_run
  from public.health_ingestion_runs
  where user_id = auth.uid() and source = v_source
  order by received_at desc
  limit 1;

  select activity_date, daily_steps, active_calories, synced_at
  into v_activity
  from public.daily_activity
  where user_id = auth.uid()
    and source_metadata ->> 'bridge' = v_source
  order by activity_date desc
  limit 1;

  return jsonb_build_object(
    'configured', coalesce(v_token.active, false),
    'token_prefix', v_token.token_prefix,
    'last_received_at', v_token.last_used_at,
    'latest_activity_date', v_activity.activity_date,
    'latest_daily_steps', v_activity.daily_steps,
    'latest_active_calories', v_activity.active_calories,
    'latest_synced_at', v_activity.synced_at,
    'last_run_status', v_run.status,
    'last_run_received_at', v_run.received_at,
    'last_run_stage', v_run.stage,
    'last_run_metric_samples', coalesce(v_run.metric_samples, 0),
    'last_run_workouts', coalesce(v_run.workouts, 0),
    'last_run_imported_dates', coalesce(v_run.imported_dates, '[]'::jsonb),
    'last_run_warnings', coalesce(v_run.warnings, '[]'::jsonb),
    'last_run_error', v_run.error_message
  );
end;
$$;

revoke all on function public.get_platform_health_ingest_status(text) from public, anon;
grant execute on function public.get_platform_health_ingest_status(text) to authenticated;

comment on function public.rotate_platform_health_ingest_token(text) is
  'Rotates an owner credential for Apple Shortcuts or Android Health Connect without invalidating the other platform.';
comment on function public.get_platform_health_ingest_status(text) is
  'Returns the signed-in owner a redacted latest receipt for one generic health bridge.';
