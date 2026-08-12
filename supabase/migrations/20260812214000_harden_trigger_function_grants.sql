-- Trigger-only helpers must not be callable through the public Data API.
-- The triggers continue to invoke them as their owner; clients do not need
-- EXECUTE privileges for trigger functions.

revoke all on function public.enforce_four_profile_cap()
  from public, anon, authenticated;
grant execute on function public.enforce_four_profile_cap()
  to service_role;

revoke all on function public.set_updated_at()
  from public, anon, authenticated;
grant execute on function public.set_updated_at()
  to service_role;

revoke all on function public.notify_post_activity()
  from public, anon, authenticated;
grant execute on function public.notify_post_activity()
  to service_role;

revoke all on function public.notify_comment_activity()
  from public, anon, authenticated;
grant execute on function public.notify_comment_activity()
  to service_role;

revoke all on function public.notify_reaction_activity()
  from public, anon, authenticated;
grant execute on function public.notify_reaction_activity()
  to service_role;

revoke all on function public.insert_notification_any(uuid, text, text, text, jsonb)
  from public, anon, authenticated;
grant execute on function public.insert_notification_any(uuid, text, text, text, jsonb)
  to service_role;

revoke all on function public.insert_notification(uuid, text, text, text, jsonb)
  from public, anon, authenticated;
grant execute on function public.insert_notification(uuid, text, text, text, jsonb)
  to service_role;
