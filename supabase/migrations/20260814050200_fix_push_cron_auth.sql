-- The first push migration created the retry job before its private header was
-- included. Replace it with an authenticated call that reads the key from the
-- locked database row at execution time.

do $schedule$
begin
  perform cron.unschedule('enfermicambio-push-dispatch');
  perform cron.schedule(
    'enfermicambio-push-dispatch',
    '* * * * *',
    $command$
      select net.http_post(
        url := 'https://bweynxdzovnbcjwgddar.supabase.co/functions/v1/send_push',
        body := '{"mode":"drain"}'::jsonb,
        headers := jsonb_build_object(
          'Content-Type', 'application/json',
          'X-EnfermiCambio-Dispatch-Key',
          (select dispatch_key from public.push_dispatch_secrets where id = true)
        ),
        timeout_milliseconds := 5000
      );
    $command$
  );
end;
$schedule$;
