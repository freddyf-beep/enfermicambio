-- app_config stores scalar values as JSONB. Casting a JSONB string directly
-- to text keeps its quotes ("America/Santiago"), which PostgreSQL rejects as
-- a time zone. Recreate the two evaluators with the JSON scalar extracted.

do $$
declare
  v_definition text;
begin
  select pg_get_functiondef('public.evaluate_missions(date)'::regprocedure)
    into v_definition;
  v_definition := replace(
    v_definition,
    'select config_value into v_tz from public.app_config',
    'select config_value #>> ''{}'' into v_tz from public.app_config'
  );
  execute v_definition;

  select pg_get_functiondef(
    'public.evaluate_achievements(uuid,date)'::regprocedure
  ) into v_definition;
  v_definition := replace(
    v_definition,
    'select config_value into v_tz from public.app_config',
    'select config_value #>> ''{}'' into v_tz from public.app_config'
  );
  execute v_definition;
end;
$$;
