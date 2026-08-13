-- Nutrition profiles, durable meal snapshots and private media access.
--
-- Food entries are personal health data. A post is the explicit opt-in that
-- makes a meal/photo visible to the private four-person group.

create table public.nutrition_profiles (
  user_id uuid primary key references public.profiles (id) on delete cascade,
  birth_date date,
  height_cm numeric(5, 1),
  sex_for_formula text,
  activity_level text not null default 'moderate',
  goal text not null default 'maintain',
  deficit_percent numeric(4, 1) not null default 15,
  manual_calorie_target integer,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  constraint nutrition_profiles_birth_date_check check (
    birth_date is null or birth_date <= current_date - interval '18 years'
  ),
  constraint nutrition_profiles_height_check check (
    height_cm is null or height_cm between 100 and 250
  ),
  constraint nutrition_profiles_sex_check check (
    sex_for_formula is null or sex_for_formula in ('female', 'male')
  ),
  constraint nutrition_profiles_activity_check check (
    activity_level in ('sedentary', 'light', 'moderate', 'active', 'very_active')
  ),
  constraint nutrition_profiles_goal_check check (
    goal in ('maintain', 'lose', 'gain')
  ),
  constraint nutrition_profiles_deficit_check check (
    deficit_percent between 5 and 30
  ),
  constraint nutrition_profiles_manual_target_check check (
    manual_calorie_target is null or manual_calorie_target between 800 and 10000
  )
);

create trigger nutrition_profiles_set_updated_at
before update on public.nutrition_profiles
for each row
execute function public.set_updated_at();

alter table public.nutrition_profiles enable row level security;

create policy nutrition_profiles_select_own
on public.nutrition_profiles for select to authenticated
using (public.is_allowlisted_user() and user_id = auth.uid());

create policy nutrition_profiles_insert_own
on public.nutrition_profiles for insert to authenticated
with check (public.is_allowlisted_user() and user_id = auth.uid());

create policy nutrition_profiles_update_own
on public.nutrition_profiles for update to authenticated
using (public.is_allowlisted_user() and user_id = auth.uid())
with check (public.is_allowlisted_user() and user_id = auth.uid());

create policy nutrition_profiles_delete_own
on public.nutrition_profiles for delete to authenticated
using (public.is_allowlisted_user() and user_id = auth.uid());

grant select, insert, update, delete on table public.nutrition_profiles to authenticated;
revoke all on table public.nutrition_profiles from anon;

-- Keep the name available if the product is later removed from the group
-- catalogue. Existing entries are backfilled from the related food.
alter table public.food_entries
  add column if not exists food_name_snapshot text;

update public.food_entries fe
set food_name_snapshot = coalesce(f.name, 'Alimento')
from public.foods f
where fe.food_id = f.id
  and (fe.food_name_snapshot is null or btrim(fe.food_name_snapshot) = '');

update public.food_entries
set food_name_snapshot = 'Alimento'
where food_name_snapshot is null or btrim(food_name_snapshot) = '';

alter table public.food_entries
  alter column food_name_snapshot set not null;

alter table public.food_entries
  add constraint food_entries_food_name_snapshot_not_blank
  check (char_length(btrim(food_name_snapshot)) > 0);

-- Entries are private. A deliberately created post remains readable by the
-- group and is the only vehicle for sharing a meal.
drop policy if exists food_entries_select_for_allowlisted on public.food_entries;

create policy food_entries_select_own
on public.food_entries for select to authenticated
using (public.is_allowlisted_user() and user_id = auth.uid());

-- Private bucket: the owner can read their draft image; fellow group members
-- can obtain a signed URL only once an explicit post references that object.
drop policy if exists meal_media_storage_select_auth on storage.objects;

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

create policy meal_media_storage_update_own
on storage.objects for update to authenticated
using (
  bucket_id = 'meal-media'
  and public.is_allowlisted_user()
  and (storage.foldername(name))[1] = (select auth.uid())::text
)
with check (
  bucket_id = 'meal-media'
  and public.is_allowlisted_user()
  and (storage.foldername(name))[1] = (select auth.uid())::text
);
