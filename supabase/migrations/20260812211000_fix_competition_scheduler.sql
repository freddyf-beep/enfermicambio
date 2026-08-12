-- The original cron jobs embedded the migration date into their request body
-- and assumed UTC matched the competition clock.  Keep the scheduler in UTC,
-- but decide the round and date at execution time in America/Santiago.  The
-- hourly guards also survive the DST change without another migration.

create extension if not exists pg_cron with schema extensions;
create extension if not exists pg_net with schema extensions;

do $$
declare
  v_url text := 'https://bweynxdzovnbcjwgddar.supabase.co/functions/v1/close_round';
  v_day_url text := 'https://bweynxdzovnbcjwgddar.supabase.co/functions/v1/close_day';
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
  if exists (select 1 from cron.job where jobname = 'notify-round-morning') then
    perform cron.unschedule('notify-round-morning');
  end if;
  if exists (select 1 from cron.job where jobname = 'notify-round-afternoon') then
    perform cron.unschedule('notify-round-afternoon');
  end if;
  if exists (select 1 from cron.job where jobname = 'notify-round-night') then
    perform cron.unschedule('notify-round-night');
  end if;
  if exists (select 1 from cron.job where jobname = 'close-round-window') then
    perform cron.unschedule('close-round-window');
  end if;
  if exists (select 1 from cron.job where jobname = 'close-day-window') then
    perform cron.unschedule('close-day-window');
  end if;
  if exists (select 1 from cron.job where jobname = 'notify-round-window') then
    perform cron.unschedule('notify-round-window');
  end if;

  -- At the competition boundary, close the corresponding round.  Midnight
  -- belongs to the previous calendar date.
  perform cron.schedule(
    'close-round-window',
    '0 * * * *',
    format($command$
      select case extract(hour from (now() at time zone 'America/Santiago'))::integer
        when 12 then net.http_post('%s', jsonb_build_object(
          'round', 'morning',
          'date', (now() at time zone 'America/Santiago')::date
        ), '{}'::jsonb, '%s'::jsonb)
        when 18 then net.http_post('%s', jsonb_build_object(
          'round', 'afternoon',
          'date', (now() at time zone 'America/Santiago')::date
        ), '{}'::jsonb, '%s'::jsonb)
        when 0 then net.http_post('%s', jsonb_build_object(
          'round', 'night',
          'date', ((now() at time zone 'America/Santiago')::date - 1)
        ), '{}'::jsonb, '%s'::jsonb)
        else null
      end
    $command$, v_url, v_headers::text, v_url, v_headers::text, v_url, v_headers::text)
  );

  -- Run the daily close ten minutes after the night round.  This is the
  -- single finalization point for the day; daily_activity itself remains one
  -- upserted row per user/date throughout the day.
  perform cron.schedule(
    'close-day-window',
    '10 * * * *',
    format($command$
      select case extract(hour from (now() at time zone 'America/Santiago'))::integer
        when 0 then net.http_post('%s', jsonb_build_object(
          'date', ((now() at time zone 'America/Santiago')::date - 1)
        ), '{}'::jsonb, '%s'::jsonb)
        else null
      end
    $command$, v_day_url, v_headers::text)
  );

  -- The warning is sent shortly before each boundary in the competition
  -- timezone, regardless of the database server's UTC setting.
  perform cron.schedule(
    'notify-round-window',
    '30 * * * *',
    $command$
      select case extract(hour from (now() at time zone 'America/Santiago'))::integer
        when 11 then public.notify_round_ending(
          'morning', (now() at time zone 'America/Santiago')::date, 30)
        when 17 then public.notify_round_ending(
          'afternoon', (now() at time zone 'America/Santiago')::date, 30)
        when 23 then public.notify_round_ending(
          'night', (now() at time zone 'America/Santiago')::date, 30)
        else null
      end
    $command$
  );
end;
$$;
