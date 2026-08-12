-- The notification bell and the OS delivery coordinator subscribe to inserts
-- on this table. Without publication membership they only update after a
-- manual reload. Keep the migration safe when a dashboard/manual change has
-- already enabled it.
do $$
begin
  alter publication supabase_realtime add table public.notifications;
exception when duplicate_object then
  null;
end;
$$;
