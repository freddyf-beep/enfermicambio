-- Health Connect re-reads a workout on every foreground sync. Replacing its
-- route first removes the previous points, then inserts the latest route.
-- Keep both operations owner-scoped; this is never a group-wide delete.

grant delete on table public.workout_route_points to authenticated;

drop policy if exists workout_route_points_delete_with_own_workout
  on public.workout_route_points;

create policy workout_route_points_delete_with_own_workout
on public.workout_route_points
for delete
to authenticated
using (
  is_allowlisted_user()
  and exists (
    select 1
    from public.workouts w
    where w.id = workout_route_points.workout_id
      and w.user_id = (select auth.uid())
  )
);
