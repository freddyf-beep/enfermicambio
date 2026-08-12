-- season_results stores the final rank as final_rank. The original
-- achievement evaluator referenced the old name position.

do $$
declare
  v_definition text;
begin
  select pg_get_functiondef(
    'public.evaluate_achievements(uuid,date)'::regprocedure
  ) into v_definition;
  v_definition := replace(v_definition, 'sr.position', 'sr.final_rank');
  execute v_definition;
end;
$$;
