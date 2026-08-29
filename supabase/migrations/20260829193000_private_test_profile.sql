-- Allow one-off device validation without expanding the competition group.
-- Test profiles are service-role provisioned and hidden from all shared reads.

alter table public.profiles
  add column if not exists is_test_account boolean not null default false;

create index if not exists profiles_test_account_idx
  on public.profiles (is_test_account);

create or replace function public.enforce_four_profile_cap()
returns trigger
language plpgsql
security definer
set search_path = pg_catalog, public
as $$
begin
  if tg_op = 'INSERT' and not coalesce(new.is_test_account, false) then
    perform pg_advisory_xact_lock(
      hashtextextended('public.profiles.four_user_cap', 0)
    );

    if (select count(*) from public.profiles where not is_test_account) >= 4 then
      raise exception 'The application allowlist is limited to exactly four profiles'
        using errcode = 'check_violation';
    end if;
  end if;

  return new;
end;
$$;

create or replace function public.is_allowlisted_user()
returns boolean
language sql
stable
security definer
set search_path = pg_catalog, public
as $$
  select auth.uid() is not null
    and (
      select count(*) <= 4
      from public.profiles
      where not is_test_account
    )
    and exists (
      select 1
      from public.profiles
      where id = auth.uid()
    );
$$;

create or replace function public.is_test_profile(p_user_id uuid)
returns boolean
language sql
stable
security definer
set search_path = pg_catalog, public
set row_security = off
as $$
  select coalesce((
    select is_test_account
    from public.profiles
    where id = p_user_id
  ), false);
$$;

revoke all on function public.is_test_profile(uuid) from public, anon;
grant execute on function public.is_test_profile(uuid) to authenticated, service_role;

drop policy if exists profiles_select_for_allowlisted_users on public.profiles;
create policy profiles_select_for_allowlisted_users
on public.profiles
for select to authenticated
using (
  public.is_allowlisted_user()
  and (not is_test_account or id = (select auth.uid()))
);

drop policy if exists daily_activity_select_for_allowlisted_users on public.daily_activity;
create policy daily_activity_select_for_allowlisted_users
on public.daily_activity
for select to authenticated
using (
  public.is_allowlisted_user()
  and (not public.is_test_profile(user_id) or user_id = (select auth.uid()))
);

drop policy if exists workouts_select_for_allowlisted on public.workouts;
create policy workouts_select_for_allowlisted
on public.workouts
for select to authenticated
using (
  public.is_allowlisted_user()
  and (not public.is_test_profile(user_id) or user_id = (select auth.uid()))
);

drop policy if exists posts_select_for_allowlisted on public.posts;
create policy posts_select_for_allowlisted
on public.posts
for select to authenticated
using (
  public.is_allowlisted_user()
  and (not public.is_test_profile(author_id) or author_id = (select auth.uid()))
);

drop policy if exists post_media_select_for_allowlisted on public.post_media;
create policy post_media_select_for_allowlisted
on public.post_media
for select to authenticated
using (
  public.is_allowlisted_user()
  and exists (
    select 1
    from public.posts p
    where p.id = post_media.post_id
      and (not public.is_test_profile(p.author_id) or p.author_id = (select auth.uid()))
  )
);

drop policy if exists comments_select_for_allowlisted on public.comments;
create policy comments_select_for_allowlisted
on public.comments
for select to authenticated
using (
  public.is_allowlisted_user()
  and (not public.is_test_profile(author_id) or author_id = (select auth.uid()))
);

drop policy if exists reactions_select_for_allowlisted on public.reactions;
create policy reactions_select_for_allowlisted
on public.reactions
for select to authenticated
using (
  public.is_allowlisted_user()
  and (not public.is_test_profile(user_id) or user_id = (select auth.uid()))
);

drop policy if exists user_achievements_select_for_allowlisted on public.user_achievements;
create policy user_achievements_select_for_allowlisted
on public.user_achievements
for select to authenticated
using (
  public.is_allowlisted_user()
  and (not public.is_test_profile(user_id) or user_id = (select auth.uid()))
);

drop policy if exists streaks_select_for_allowlisted on public.streaks;
create policy streaks_select_for_allowlisted
on public.streaks
for select to authenticated
using (
  public.is_allowlisted_user()
  and (not public.is_test_profile(user_id) or user_id = (select auth.uid()))
);

drop policy if exists mission_progress_select_for_allowlisted on public.mission_progress;
create policy mission_progress_select_for_allowlisted
on public.mission_progress
for select to authenticated
using (
  public.is_allowlisted_user()
  and (not public.is_test_profile(user_id) or user_id = (select auth.uid()))
);

drop policy if exists season_points_select_for_allowlisted on public.season_points;
create policy season_points_select_for_allowlisted
on public.season_points
for select to authenticated
using (
  public.is_allowlisted_user()
  and (not public.is_test_profile(user_id) or user_id = (select auth.uid()))
);

drop policy if exists season_results_select_for_allowlisted on public.season_results;
create policy season_results_select_for_allowlisted
on public.season_results
for select to authenticated
using (
  public.is_allowlisted_user()
  and (not public.is_test_profile(user_id) or user_id = (select auth.uid()))
);

drop policy if exists battle_pass_claims_read_allowlisted on public.battle_pass_claims;
create policy battle_pass_claims_read_allowlisted
on public.battle_pass_claims
for select to authenticated
using (
  public.is_allowlisted_user()
  and (not public.is_test_profile(user_id) or user_id = (select auth.uid()))
);

comment on column public.profiles.is_test_account is
  'Service-role-only temporary profile marker; hidden from shared app reads.';
