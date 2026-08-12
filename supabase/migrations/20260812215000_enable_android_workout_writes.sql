-- Android Health Connect reads workouts/routes on the device and persists
-- them through the same owner-scoped policies used by the app.
grant select, insert, update on table public.workouts to authenticated;
grant select, insert on table public.workout_route_points to authenticated;
