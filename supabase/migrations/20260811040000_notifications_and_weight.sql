-- Notifications center (Phase 4.9) + private weight log (Phase 4.9 extra).
--
-- Server-authoritative notifications: the `notifications` table is the source
-- of truth; Realtime is only the delivery channel. Inserts happen through
-- security definer functions (triggers for social activity, Edge Functions /
-- RPCs for system events and personal milestones). Clients read and mark read
-- only their own rows. Weight is private: owner-only RLS, never in ranking or
-- feed. Applied migrations are forward-only.

-- 1. notifications ------------------------------------------------------------

create table public.notifications (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references public.profiles (id) on delete cascade,
  type text not null,
  title text not null,
  body text not null,
  payload jsonb not null default '{}'::jsonb,
  is_read boolean not null default false,
  created_at timestamptz not null default now(),
  constraint notifications_type_check check (
    type in (
      'overtake', 'leader_change', 'round_result', 'round_ending_soon',
      'achievement', 'workout', 'feed_post', 'comment', 'reaction',
      'mission', 'season', 'steps_milestone', 'personal_record',
      'daily_goal', 'weight_entry_goal', 'weight_change'
    )
  )
);

create index notifications_user_created_idx
  on public.notifications (user_id, created_at desc);

create index notifications_unread_idx
  on public.notifications (user_id) where is_read = false;

alter table public.notifications enable row level security;

create policy notifications_select_own
on public.notifications for select to authenticated
using (public.is_allowlisted_user() and user_id = auth.uid());

create policy notifications_update_own
on public.notifications for update to authenticated
using (public.is_allowlisted_user() and user_id = auth.uid())
with check (public.is_allowlisted_user() and user_id = auth.uid());

-- No insert/delete policies: writes only via security definer functions
-- (insert_notification / insert_notification_any) or the service role.

-- 2. weight_entries -----------------------------------------------------------

create table public.weight_entries (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references public.profiles (id) on delete cascade,
  entry_date date not null,
  weight_kg numeric(5,2) not null check (weight_kg between 20 and 400),
  source text not null default 'manual' check (source in ('manual', 'import')),
  created_at timestamptz not null default now(),
  unique (user_id, entry_date)
);

create index weight_entries_user_date_idx
  on public.weight_entries (user_id, entry_date desc);

alter table public.weight_entries enable row level security;

create policy weight_entries_select_own
on public.weight_entries for select to authenticated
using (public.is_allowlisted_user() and user_id = auth.uid());

create policy weight_entries_insert_own
on public.weight_entries for insert to authenticated
with check (public.is_allowlisted_user() and user_id = auth.uid());

create policy weight_entries_update_own
on public.weight_entries for update to authenticated
using (public.is_allowlisted_user() and user_id = auth.uid())
with check (public.is_allowlisted_user() and user_id = auth.uid());

create policy weight_entries_delete_own
on public.weight_entries for delete to authenticated
using (public.is_allowlisted_user() and user_id = auth.uid());

-- 3. weight goal on profiles --------------------------------------------------

alter table public.profiles
  add column weight_goal_kg numeric(5,2)
  check (weight_goal_kg is null or (weight_goal_kg between 20 and 400));

-- 4. rank_positions (overtake support) ----------------------------------------

create table public.rank_positions (
  competition_date date not null,
  user_id uuid not null references public.profiles (id) on delete cascade,
  position int not null check (position between 1 and 4),
  updated_at timestamptz not null default now(),
  primary key (competition_date, user_id)
);

alter table public.rank_positions enable row level security;
-- No policies: only security definer functions and the service role touch it.

-- 5. category helper ----------------------------------------------------------

create or replace function public.notification_category(p_type text)
returns text
language sql
immutable
as $$
  select case p_type
    when 'overtake' then 'overtakes'
    when 'leader_change' then 'overtakes'
    when 'round_result' then 'rounds'
    when 'round_ending_soon' then 'rounds'
    when 'achievement' then 'achievements'
    when 'workout' then 'workouts'
    when 'feed_post' then 'feed'
    when 'comment' then 'social'
    when 'reaction' then 'social'
    when 'mission' then 'missions'
    when 'season' then 'season'
    when 'steps_milestone' then 'personal'
    when 'personal_record' then 'personal'
    when 'daily_goal' then 'personal'
    when 'weight_entry_goal' then 'weight'
    when 'weight_change' then 'weight'
    else 'other'
  end;
$$;

-- 6. insert_notification_any / insert_notification ---------------------------

-- Low-level insert honoring per-category preferences. No ownership check:
-- callable only by security definer triggers and the service role.
create or replace function public.insert_notification_any(
  p_user_id uuid,
  p_type text,
  p_title text,
  p_body text,
  p_payload jsonb default '{}'::jsonb
)
returns void
language plpgsql
security definer
set search_path = pg_catalog, public
as $$
declare
  v_category text;
begin
  v_category := public.notification_category(p_type);
  if exists (
    select 1
    from public.profiles pr
    where pr.id = p_user_id
      and pr.notification_preferences ->> v_category = 'false'
  ) then
    return;
  end if;
  insert into public.notifications (user_id, type, title, body, payload)
  values (p_user_id, p_type, p_title, p_body, p_payload);
end;
$$;

revoke all on function public.insert_notification_any(uuid, text, text, text, jsonb)
  from public, anon;
grant execute on function public.insert_notification_any(uuid, text, text, text, jsonb)
  to service_role;

-- Public entry point. Authenticated callers may only notify themselves
-- (used by the weight goal RPC and by Edge Functions via the service role,
-- where auth.uid() is null).
create or replace function public.insert_notification(
  p_user_id uuid,
  p_type text,
  p_title text,
  p_body text,
  p_payload jsonb default '{}'::jsonb
)
returns void
language plpgsql
security definer
set search_path = pg_catalog, public
as $$
begin
  if auth.uid() is not null and auth.uid() <> p_user_id then
    raise exception 'not allowed to create notifications for another user';
  end if;
  perform public.insert_notification_any(
    p_user_id, p_type, p_title, p_body, p_payload
  );
end;
$$;

revoke all on function public.insert_notification(uuid, text, text, text, jsonb)
  from public, anon;
grant execute on function public.insert_notification(uuid, text, text, text, jsonb)
  to authenticated, service_role;

-- 7. social triggers ----------------------------------------------------------

-- New manual post -> feed_post notification to the other three users.
create or replace function public.notify_post_activity()
returns trigger
language plpgsql
security definer
set search_path = pg_catalog, public
as $$
declare
  v_author_name text;
  v_emoji text;
  v_title text;
  v_body text;
  v_peer uuid;
begin
  if NEW.system_generated then
    return NEW;
  end if;

  select display_name into v_author_name
  from public.profiles
  where id = NEW.author_id;

  v_emoji := case NEW.post_type
    when 'meal' then '🍔'
    when 'photo' then '📷'
    when 'workout' then '🏃'
    when 'route' then '🗺️'
    when 'achievement' then '🏆'
    when 'steps' then '👟'
    when 'mission' then '🎯'
    else '📝'
  end;

  v_body := v_emoji || ' ' || case NEW.post_type
    when 'meal' then 'Publicó una comida.'
    when 'photo' then 'Publicó una foto.'
    when 'workout' then 'Compartió un entrenamiento.'
    when 'route' then 'Compartió una ruta.'
    when 'achievement' then 'Desbloqueó un logro.'
    when 'steps' then 'Compartió sus pasos.'
    when 'mission' then 'Compartió una misión.'
    else 'Publicó un mensaje nuevo.'
  end;

  for v_peer in
    select pr.id from public.profiles pr where pr.id <> NEW.author_id
  loop
    perform public.insert_notification_any(
      v_peer,
      'feed_post',
      coalesce(v_author_name, 'Alguien') || ' publicó',
      v_body,
      jsonb_build_object(
        'post_id', NEW.id,
        'actor_id', NEW.author_id,
        'post_type', NEW.post_type
      )
    );
  end loop;

  return NEW;
end;
$$;

create trigger notify_post_activity_trigger
after insert on public.posts
for each row execute function public.notify_post_activity();

-- New comment -> comment notification to the post author (not to the author
-- of the comment).
create or replace function public.notify_comment_activity()
returns trigger
language plpgsql
security definer
set search_path = pg_catalog, public
as $$
declare
  v_post_author uuid;
  v_commenter_name text;
begin
  select author_id into v_post_author
  from public.posts
  where id = NEW.post_id;

  if v_post_author is null or v_post_author = NEW.author_id then
    return NEW;
  end if;

  select display_name into v_commenter_name
  from public.profiles
  where id = NEW.author_id;

  perform public.insert_notification_any(
    v_post_author,
    'comment',
    coalesce(v_commenter_name, 'Alguien') || ' comentó',
    '💬 Comentó tu publicación.',
    jsonb_build_object(
      'post_id', NEW.post_id,
      'actor_id', NEW.author_id,
      'comment_id', NEW.id
    )
  );

  return NEW;
end;
$$;

create trigger notify_comment_activity_trigger
after insert on public.comments
for each row execute function public.notify_comment_activity();

-- New reaction -> reaction notification to the post author, at most once per
-- (post, actor) within 24 hours so reaction toggles do not spam.
create or replace function public.notify_reaction_activity()
returns trigger
language plpgsql
security definer
set search_path = pg_catalog, public
as $$
declare
  v_post_author uuid;
  v_actor_name text;
  v_recent boolean;
begin
  select author_id into v_post_author
  from public.posts
  where id = NEW.post_id;

  if v_post_author is null or v_post_author = NEW.user_id then
    return NEW;
  end if;

  select exists (
    select 1
    from public.notifications n
    where n.user_id = v_post_author
      and n.type = 'reaction'
      and n.payload ->> 'post_id' = NEW.post_id::text
      and n.payload ->> 'actor_id' = NEW.user_id::text
      and n.created_at > now() - interval '24 hours'
  ) into v_recent;

  if v_recent then
    return NEW;
  end if;

  select display_name into v_actor_name
  from public.profiles
  where id = NEW.user_id;

  perform public.insert_notification_any(
    v_post_author,
    'reaction',
    coalesce(v_actor_name, 'Alguien') || ' reaccionó',
    NEW.emoji || ' Reaccionó a tu publicación.',
    jsonb_build_object(
      'post_id', NEW.post_id,
      'actor_id', NEW.user_id,
      'emoji', NEW.emoji
    )
  );

  return NEW;
end;
$$;

create trigger notify_reaction_activity_trigger
after insert on public.reactions
for each row execute function public.notify_reaction_activity();

-- 8. weight goal notifications -----------------------------------------------

-- Personal weight notifications (goal reached + weekly change). Callable by
-- the owner only; deduplicated by payload keys.
create or replace function public.notify_weight_goal(p_user_id uuid)
returns text
language plpgsql
security definer
set search_path = pg_catalog, public
as $$
declare
  v_goal numeric(5,2);
  v_latest numeric(5,2);
  v_latest_date date;
  v_prev numeric(5,2);
  v_prev_date date;
  v_delta numeric(6,2);
  v_week text;
  v_result text := 'no_op';
begin
  if auth.uid() is null or auth.uid() <> p_user_id then
    raise exception 'not allowed to query another user''s weight';
  end if;

  select weight_goal_kg into v_goal
  from public.profiles where id = p_user_id;

  if v_goal is null then
    return 'no_goal';
  end if;

  select weight_kg, entry_date into v_latest, v_latest_date
  from public.weight_entries
  where user_id = p_user_id
  order by entry_date desc
  limit 1;

  if v_latest is null then
    return 'no_entry';
  end if;

  if v_latest <= v_goal then
    if not exists (
      select 1 from public.notifications n
      where n.user_id = p_user_id
        and n.type = 'weight_entry_goal'
        and n.payload ->> 'key' = 'goal:' || v_goal::text
    ) then
      perform public.insert_notification_any(
        p_user_id,
        'weight_entry_goal',
        '¡Meta de peso lograda!',
        '⚖️ Alcanzaste tu meta de ' || v_goal::text || ' kg.',
        jsonb_build_object('key', 'goal:' || v_goal::text, 'weight_kg', v_latest)
      );
      v_result := 'goal_emitted';
    end if;
  end if;

  v_week := to_char(v_latest_date, 'IYYY-IW');
  if not exists (
    select 1 from public.notifications n
    where n.user_id = p_user_id
      and n.type = 'weight_change'
      and n.payload ->> 'key' = 'week:' || v_week
  ) then
    select weight_kg, entry_date into v_prev, v_prev_date
    from public.weight_entries
    where user_id = p_user_id
      and entry_date < v_latest_date
    order by entry_date desc
    limit 1;

    if v_prev is not null and (v_latest_date - v_prev_date) >= 6 then
      v_delta := v_latest - v_prev;
      if abs(v_delta) >= 0.5 then
        if v_delta < 0 then
          perform public.insert_notification_any(
            p_user_id,
            'weight_change',
            'Semana en movimiento',
            '⚖️ Bajaste ' || abs(v_delta)::text || ' kg esta semana.',
            jsonb_build_object('key', 'week:' || v_week, 'delta_kg', v_delta)
          );
        else
          perform public.insert_notification_any(
            p_user_id,
            'weight_change',
            'Semana en movimiento',
            '⚖️ Subiste ' || v_delta::text || ' kg esta semana. ¡Tú puedes!',
            jsonb_build_object('key', 'week:' || v_week, 'delta_kg', v_delta)
          );
        end if;
        v_result := 'change_emitted';
      end if;
    end if;
  end if;

  return v_result;
end;
$$;

revoke all on function public.notify_weight_goal(uuid) from public, anon;
grant execute on function public.notify_weight_goal(uuid) to authenticated;

-- 9. round ending reminder ----------------------------------------------------

-- 30 minutes before a round closes, the scheduled jobs call this with the
-- round name; deduplicated per (round, date) via the payload key.
create or replace function public.notify_round_ending(
  p_round text,
  p_date date,
  p_minutes_left int default 30
)
returns void
language plpgsql
security definer
set search_path = pg_catalog, public
as $$
declare
  v_round_label text;
  v_key text;
  v_user uuid;
begin
  v_round_label := case p_round
    when 'morning' then 'la mañana'
    when 'afternoon' then 'la tarde'
    else 'la noche'
  end;
  v_key := 'round_ending:' || p_round || ':' || p_date::text;

  for v_user in select id from public.profiles
  loop
    if not exists (
      select 1 from public.notifications n
      where n.user_id = v_user
        and n.type = 'round_ending_soon'
        and n.payload ->> 'key' = v_key
    ) then
      perform public.insert_notification_any(
        v_user,
        'round_ending_soon',
        '¡La ronda está por cerrar!',
        '🌙 Quedan ' || p_minutes_left::text || ' min de la ronda de ' ||
          v_round_label || '. ¡Dale con todo!',
        jsonb_build_object('key', v_key, 'round', p_round, 'minutes_left', p_minutes_left)
      );
    end if;
  end loop;
end;
$$;

revoke all on function public.notify_round_ending(text, date, int)
  from public, anon, authenticated;
grant execute on function public.notify_round_ending(text, date, int)
  to service_role;

-- Schedule the reminders at 11:30, 17:30 and 23:30 competition time,
-- reusing the pg_cron + pg_net pattern of close_round.
do $$
declare
  v_url text := 'https://bweynxdzovnbcjwgddar.supabase.co/functions/v1/close_round';
begin
  -- pg_cron can call the RPC directly (job runs as the creating role).
  perform cron.schedule(
    'notify-round-morning',
    '30 11 * * *',
    format(
      'select public.notify_round_ending(%L, (now() at time zone ''America/Santiago'')::date, 30)',
      'morning'
    )
  );
  perform cron.schedule(
    'notify-round-afternoon',
    '30 17 * * *',
    format(
      'select public.notify_round_ending(%L, (now() at time zone ''America/Santiago'')::date, 30)',
      'afternoon'
    )
  );
  perform cron.schedule(
    'notify-round-night',
    '30 23 * * *',
    format(
      'select public.notify_round_ending(%L, (now() at time zone ''America/Santiago'')::date, 30)',
      'night'
    )
  );
end;
$$;

-- 10. Realtime delivery --------------------------------------------------------

alter publication supabase_realtime add table public.notifications;

-- 11. smoke test script (manual) ----------------------------------------------

-- See supabase/scripts/notifications_smoke_test.sql for trigger and RPC
-- checks. The DB itself ships without them because the four-profile cap
-- makes temporary users unavailable inside migrations.
