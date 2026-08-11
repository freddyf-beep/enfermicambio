-- Schedule close_round at 12:00, 18:00, 00:00 in the competition timezone.
-- Each job posts to the close_round Edge Function, which awards points
-- idempotently. Applied migrations are forward-only.

create extension if not exists pg_cron with schema extensions;
create extension if not exists pg_net with schema extensions;

-- The publishable key is public by design; it only lets callers reach
-- functions that explicitly accept the publishable mode.
do $$
declare
  v_url text := 'https://bweynxdzovnbcjwgddar.supabase.co/functions/v1/close_round';
  v_headers jsonb := '{"apikey": "sb_publishable_JS-Th9Up9BBHjI51WD4Reg_V57pz8BO"}'::jsonb;
begin
  if exists (select 1 from cron.job where jobname = 'close-round-morning') then
    perform cron.unschedule('close-round-morning');
  end if;
  if exists (select 1 from cron.job where jobname = 'close-round-afternoon') then
    perform cron.unschedule('close-round-afternoon');
  end if;
  if exists (select 1 from cron.job where jobname = 'close-round-night') then
    perform cron.unschedule('close-round-night');
  end if;

  perform cron.schedule(
    'close-round-morning',
    '0 12 * * *',
    format(
      'select net.http_post(''%s'', ''{"round":"morning","date":"%s"}''::jsonb, ''{}''::jsonb, ''%s''::jsonb)',
      v_url,
      to_char(now() at time zone 'America/Santiago', 'YYYY-MM-DD'),
      v_headers::text
    )
  );

  perform cron.schedule(
    'close-round-afternoon',
    '0 18 * * *',
    format(
      'select net.http_post(''%s'', ''{"round":"afternoon","date":"%s"}''::jsonb, ''{}''::jsonb, ''%s''::jsonb)',
      v_url,
      to_char(now() at time zone 'America/Santiago', 'YYYY-MM-DD'),
      v_headers::text
    )
  );

  perform cron.schedule(
    'close-round-night',
    '0 0 * * *',
    format(
      'select net.http_post(''%s'', ''{"round":"night","date":"%s"}''::jsonb, ''{}''::jsonb, ''%s''::jsonb)',
      v_url,
      to_char(now() at time zone 'America/Santiago', 'YYYY-MM-DD'),
      v_headers::text
    )
  );
end;
$$;
