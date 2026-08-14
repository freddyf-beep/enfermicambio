-- Keep generated captions in UTF-8 even when a Windows shell has a legacy
-- console code page. chr() avoids storing mojibake in the shared feed.
create or replace function public.upsert_daily_activity_feed_post(
  p_user_id uuid,
  p_date date
)
returns uuid
language plpgsql
security definer
set search_path = pg_catalog, public
as $$
declare
  v_steps integer;
  v_distance numeric;
  v_manual boolean;
  v_name text;
  v_source_key text;
  v_caption text;
  v_post_id uuid;
begin
  select da.daily_steps, da.distance_meters, da.manual_entry_detected
    into v_steps, v_distance, v_manual
  from public.daily_activity da
  where da.user_id = p_user_id
    and da.activity_date = p_date;

  if not found or coalesce(v_manual, false) then
    return null;
  end if;

  select coalesce(p.display_name, 'Amigo')
    into v_name
  from public.profiles p
  where p.id = p_user_id;

  v_source_key := 'daily_activity:' || p_user_id::text || ':' || p_date::text;
  if coalesce(v_distance, 0) > 0 then
    v_caption := v_name || ' actualiz' || chr(243) || ' sus pasos: ' ||
      coalesce(v_steps, 0)::text || ' pasos ' || chr(183) || ' ' ||
      round(v_distance)::text || ' m.';
  else
    v_caption := v_name || ' actualiz' || chr(243) || ' sus pasos: ' ||
      coalesce(v_steps, 0)::text || ' pasos.';
  end if;

  insert into public.posts (
    author_id, post_type, caption, system_generated, source_key
  ) values (
    p_user_id, 'steps', v_caption, true, v_source_key
  )
  on conflict (source_key) do update
    set author_id = excluded.author_id,
        post_type = excluded.post_type,
        caption = excluded.caption,
        system_generated = true,
        created_at = now()
  returning id into v_post_id;

  return v_post_id;
end;
$$;

revoke all on function public.upsert_daily_activity_feed_post(uuid, date)
  from public, anon, authenticated;
grant execute on function public.upsert_daily_activity_feed_post(uuid, date)
  to service_role;

update public.posts p
set caption = case
  when coalesce(da.distance_meters, 0) > 0 then
    coalesce(pr.display_name, 'Amigo') || ' actualiz' || chr(243) ||
    ' sus pasos: ' || coalesce(da.daily_steps, 0)::text || ' pasos ' ||
    chr(183) || ' ' || round(da.distance_meters)::text || ' m.'
  else
    coalesce(pr.display_name, 'Amigo') || ' actualiz' || chr(243) ||
    ' sus pasos: ' || coalesce(da.daily_steps, 0)::text || ' pasos.'
end
from public.daily_activity da
join public.profiles pr on pr.id = da.user_id
where p.source_key = 'daily_activity:' || da.user_id::text || ':' || da.activity_date::text
  and da.manual_entry_detected = false;
