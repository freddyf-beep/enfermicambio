-- The media reference stores bucket/path while storage.objects stores only
-- the path. Recreate the read policy with the full reference comparison.
drop policy if exists meal_media_storage_select_owner_or_published on storage.objects;

create policy meal_media_storage_select_owner_or_published
on storage.objects for select to authenticated
using (
  bucket_id = 'meal-media'
  and public.is_allowlisted_user()
  and (
    (storage.foldername(name))[1] = (select auth.uid())::text
    or exists (
      select 1
      from public.post_media pm
      join public.posts p on p.id = pm.post_id
      where pm.url = storage.objects.bucket_id || '/' || storage.objects.name
        and p.author_id is not null
    )
  )
);
