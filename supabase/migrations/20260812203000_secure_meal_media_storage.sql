-- Meal photos are stored under the author's user folder so failed uploads can
-- be cleaned up and one user cannot write into another user's path.
drop policy if exists meal_media_storage_insert_auth on storage.objects;
create policy meal_media_storage_insert_auth
on storage.objects for insert to authenticated
with check (
  bucket_id = 'meal-media'
  and (select public.is_allowlisted_user())
  and (storage.foldername(name))[1] = (select auth.uid())::text
);

drop policy if exists meal_media_storage_delete_own on storage.objects;
create policy meal_media_storage_delete_own
on storage.objects for delete to authenticated
using (
  bucket_id = 'meal-media'
  and (select public.is_allowlisted_user())
  and (storage.foldername(name))[1] = (select auth.uid())::text
);
