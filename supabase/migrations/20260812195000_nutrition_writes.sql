-- Allow each allowlisted user to create and maintain the private catalogue
-- entries they add from the barcode/custom-food flow.
create policy foods_insert_own
on public.foods for insert to authenticated
with check (
  public.is_allowlisted_user()
  and created_by = auth.uid()
);

create policy foods_update_own
on public.foods for update to authenticated
using (
  public.is_allowlisted_user()
  and created_by = auth.uid()
)
with check (
  public.is_allowlisted_user()
  and created_by = auth.uid()
);

grant insert, update on table public.foods to authenticated;
