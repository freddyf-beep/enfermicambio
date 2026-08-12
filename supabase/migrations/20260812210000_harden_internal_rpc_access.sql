-- Keep internal ranking state and server-side evaluators out of the public
-- Data API. Authenticated clients still retain only the two RPCs they need:
-- today's mission rotation and claiming an earned battle-pass reward.

alter table public.rank_positions enable row level security;

drop policy if exists rank_positions_no_client_access on public.rank_positions;
create policy rank_positions_no_client_access
on public.rank_positions
for all
to anon, authenticated
using (false)
with check (false);

revoke all on table public.rank_positions from anon, authenticated;
grant all on table public.rank_positions to service_role;

revoke all on function public.gen_deterministic_mission_ref(uuid, uuid, date)
  from public, anon, authenticated;
grant execute on function public.gen_deterministic_mission_ref(uuid, uuid, date)
  to service_role;

revoke all on function public.notification_category(text)
  from public, anon, authenticated;
grant execute on function public.notification_category(text)
  to service_role;

revoke all on function public.daily_missions_for_date(date)
  from public, anon;
grant execute on function public.daily_missions_for_date(date)
  to authenticated, service_role;

revoke all on function public.claim_battle_pass_reward(uuid, integer)
  from public, anon;
grant execute on function public.claim_battle_pass_reward(uuid, integer)
  to authenticated, service_role;

revoke all on function public.evaluate_missions(date)
  from public, anon, authenticated;
grant execute on function public.evaluate_missions(date) to service_role;

revoke all on function public.evaluate_achievements(uuid, date)
  from public, anon, authenticated;
grant execute on function public.evaluate_achievements(uuid, date)
  to service_role;

revoke all on function public.is_allowlisted_user() from anon;
grant execute on function public.is_allowlisted_user()
  to authenticated, service_role;
