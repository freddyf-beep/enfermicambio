-- Idempotent activity-sample storage for free HealthKit/Health Connect bridges.
-- Conduit sends incremental HealthKit samples and Life Dashboard can resend
-- Health Connect windows. Keeping only the normalized metrics plus each stable
-- source UUID lets us rebuild daily totals without storing raw health payloads.

create table if not exists public.health_activity_samples (
  user_id uuid not null references public.profiles(id) on delete cascade,
  bridge_source text not null,
  metric text not null,
  external_id text not null,
  activity_date date not null,
  value numeric(16, 4) not null,
  started_at timestamptz,
  ended_at timestamptz,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  primary key (user_id, bridge_source, metric, external_id),
  constraint health_activity_samples_source_check check (
    bridge_source in ('ios_shortcut', 'android_health_connect', 'generic_health_export')
  ),
  constraint health_activity_samples_metric_check check (
    metric in ('daily_steps', 'distance_meters', 'active_calories', 'exercise_minutes')
  ),
  constraint health_activity_samples_value_check check (value >= 0),
  constraint health_activity_samples_external_id_check check (char_length(btrim(external_id)) between 1 and 512)
);

create index if not exists health_activity_samples_user_date_idx
  on public.health_activity_samples (user_id, bridge_source, activity_date, metric);

alter table public.health_activity_samples enable row level security;
revoke all on table public.health_activity_samples from public, anon, authenticated;
grant select, insert, update, delete on table public.health_activity_samples to service_role;

drop policy if exists health_activity_samples_no_client_access on public.health_activity_samples;
create policy health_activity_samples_no_client_access
on public.health_activity_samples for all to authenticated
using (false)
with check (false);

create or replace function public.merge_health_activity_samples(
  p_user_id uuid,
  p_source text,
  p_samples jsonb
)
returns jsonb
language plpgsql
security definer
set search_path = pg_catalog, public
as $$
declare
  v_input_count integer := 0;
  v_written_count integer := 0;
  v_dates date[] := array[]::date[];
  v_totals jsonb := '[]'::jsonb;
begin
  if p_user_id is null
     or p_source not in ('ios_shortcut', 'android_health_connect', 'generic_health_export')
     or jsonb_typeof(p_samples) <> 'array' then
    raise exception 'Invalid health sample batch' using errcode = '22023';
  end if;

  with input_rows as (
    select
      x.metric,
      btrim(x.external_id) as external_id,
      x.activity_date,
      greatest(x.value, 0) as value,
      x.started_at,
      x.ended_at
    from jsonb_to_recordset(p_samples) as x(
      metric text,
      external_id text,
      activity_date date,
      value numeric,
      started_at timestamptz,
      ended_at timestamptz
    )
    where x.metric in ('daily_steps', 'distance_meters', 'active_calories', 'exercise_minutes')
      and x.external_id is not null
      and char_length(btrim(x.external_id)) between 1 and 512
      and x.activity_date is not null
      and x.value is not null
  ),
  upserted as (
    insert into public.health_activity_samples (
      user_id, bridge_source, metric, external_id, activity_date,
      value, started_at, ended_at
    )
    select
      p_user_id, p_source, metric, external_id, activity_date,
      value, started_at, ended_at
    from input_rows
    on conflict (user_id, bridge_source, metric, external_id) do update
      set activity_date = excluded.activity_date,
          value = excluded.value,
          started_at = excluded.started_at,
          ended_at = excluded.ended_at,
          updated_at = now()
      where (health_activity_samples.activity_date,
             health_activity_samples.value,
             health_activity_samples.started_at,
             health_activity_samples.ended_at)
        is distinct from
            (excluded.activity_date,
             excluded.value,
             excluded.started_at,
             excluded.ended_at)
    returning activity_date
  )
  select
    (select count(*) from input_rows),
    (select count(*) from upserted),
    coalesce((select array_agg(distinct activity_date) from input_rows), array[]::date[])
  into v_input_count, v_written_count, v_dates;

  if cardinality(v_dates) > 0 then
    select coalesce(jsonb_agg(to_jsonb(t) order by t.activity_date), '[]'::jsonb)
    into v_totals
    from (
      select
        s.activity_date,
        coalesce(sum(s.value) filter (where s.metric = 'daily_steps'), 0) as daily_steps,
        coalesce(sum(s.value) filter (where s.metric = 'distance_meters'), 0) as distance_meters,
        coalesce(sum(s.value) filter (where s.metric = 'active_calories'), 0) as active_calories,
        coalesce(sum(s.value) filter (where s.metric = 'exercise_minutes'), 0) as exercise_minutes
      from public.health_activity_samples s
      where s.user_id = p_user_id
        and s.bridge_source = p_source
        and s.activity_date = any(v_dates)
      group by s.activity_date
    ) t;
  end if;

  return jsonb_build_object(
    'accepted', v_written_count,
    'deduped', greatest(v_input_count - v_written_count, 0),
    'daily_totals', v_totals
  );
end;
$$;

revoke all on function public.merge_health_activity_samples(uuid, text, jsonb) from public, anon, authenticated;
grant execute on function public.merge_health_activity_samples(uuid, text, jsonb) to service_role;

comment on table public.health_activity_samples is
  'Normalized, UUID-deduplicated activity metrics received from free mobile health bridges; raw payloads are not stored.';
comment on function public.merge_health_activity_samples(uuid, text, jsonb) is
  'Service-role-only idempotent sample merge and daily aggregation for Conduit and Life Dashboard Companion.';
