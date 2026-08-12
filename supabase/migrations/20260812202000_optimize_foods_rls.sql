-- Keep the food write policies init-plan friendly so the auth helpers are
-- evaluated once per statement instead of once per row.
drop policy if exists foods_insert_own on public.foods;
drop policy if exists foods_update_own on public.foods;

create policy foods_insert_own
on public.foods for insert to authenticated
with check (
  (select public.is_allowlisted_user())
  and created_by = (select auth.uid())
);

create policy foods_update_own
on public.foods for update to authenticated
using (
  (select public.is_allowlisted_user())
  and created_by = (select auth.uid())
)
with check (
  (select public.is_allowlisted_user())
  and created_by = (select auth.uid())
);
