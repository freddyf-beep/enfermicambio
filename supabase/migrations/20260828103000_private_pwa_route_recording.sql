-- Precise GPS points recorded by the PWA are private unless the owner
-- explicitly chooses to share them in a later product flow.

alter table public.workouts
  add column if not exists route_visibility text not null default 'private'
  check (route_visibility in ('private', 'group'));

drop policy if exists workout_route_points_select_for_allowlisted
  on public.workout_route_points;

create policy workout_route_points_select_owner_or_shared
on public.workout_route_points for select to authenticated
using (
  public.is_allowlisted_user()
  and exists (
    select 1
    from public.workouts w
    where w.id = workout_route_points.workout_id
      and (w.user_id = (select auth.uid()) or w.route_visibility = 'group')
  )
);

grant select, insert on table public.workout_route_points to authenticated;

comment on column public.workouts.route_visibility is
  'Controls access to precise route points. PWA GPS recordings default to private.';
