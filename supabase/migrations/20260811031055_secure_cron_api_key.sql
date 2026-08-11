-- Move the Edge Function API key out of the migration into app_config so no
-- key material is committed to the repository. Recreates the close_round cron
-- jobs to read the key from app_config. Forward-only; the earlier migration is
-- left untouched but superseded by this one.

insert into public.app_config (config_key, config_value, description)
values (
  'edge_publishable_key',
  '"sb_publishable_JS-Th9Up9BBHjI51WD4Reg_V57pz8BO"'::jsonb,
  'Publishable key used by scheduled jobs to invoke public Edge Functions.'
)
on conflict (config_key) do nothing;

do $$
declare
  v_url text := 'https://bweynxdzovnbcjwgddar.supabase.co/functions/v1/close_round';
  v_key text;
  v_headers jsonb;
begin
  select config_value #>> '{}' into v_key
  from public.app_config where config_key = 'edge_publishable_key';

  if v_key is null then
    raise exception 'edge_publishable_key missing from app_config';
  end if;

  v_headers := jsonb_build_object('apikey', v_key);

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
