create or replace function public.notify_post_activity()
returns trigger
language plpgsql security definer
set search_path = pg_catalog, public
as $$
declare
  v_name text;
  v_body text;
  v_peer uuid;
begin
  if NEW.system_generated then return NEW; end if;
  select display_name into v_name from public.profiles where id = NEW.author_id;
  v_body := case NEW.post_type
    when 'meal' then 'Compartió una comida con el grupo'
    when 'photo' then 'Subió una foto nueva'
    when 'workout' then 'Terminó un entrenamiento'
    when 'route' then 'Compartió una actividad al aire libre'
    when 'achievement' then 'Desbloqueó un logro'
    when 'steps' then 'Compartió su progreso de pasos'
    when 'mission' then 'Completó una misión'
    else coalesce(nullif(left(NEW.caption, 120), ''), 'Publicó una actualización')
  end;
  for v_peer in select id from public.profiles where id <> NEW.author_id loop
    perform public.insert_notification_any(v_peer, 'feed_post', coalesce(v_name, 'Alguien') || ' tiene algo nuevo', v_body,
      jsonb_build_object('post_id', NEW.id, 'actor_id', NEW.author_id, 'post_type', NEW.post_type, 'route', '/today?post=' || NEW.id::text));
  end loop;
  return NEW;
end;
$$;

create or replace function public.notify_comment_activity()
returns trigger
language plpgsql security definer
set search_path = pg_catalog, public
as $$
declare v_owner uuid; v_name text;
begin
  select author_id into v_owner from public.posts where id = NEW.post_id;
  if v_owner is null or v_owner = NEW.author_id then return NEW; end if;
  select display_name into v_name from public.profiles where id = NEW.author_id;
  perform public.insert_notification_any(v_owner, 'comment', coalesce(v_name, 'Alguien') || ' respondió tu publicación', left(NEW.body, 140),
    jsonb_build_object('post_id', NEW.post_id, 'actor_id', NEW.author_id, 'comment_id', NEW.id, 'route', '/today?post=' || NEW.post_id::text));
  return NEW;
end;
$$;

create or replace function public.notify_reaction_activity()
returns trigger
language plpgsql security definer
set search_path = pg_catalog, public
as $$
declare v_owner uuid; v_name text; v_recent boolean;
begin
  select author_id into v_owner from public.posts where id = NEW.post_id;
  if v_owner is null or v_owner = NEW.user_id then return NEW; end if;
  select exists(select 1 from public.notifications where user_id = v_owner and type = 'reaction'
    and payload ->> 'post_id' = NEW.post_id::text and payload ->> 'actor_id' = NEW.user_id::text
    and created_at > now() - interval '24 hours') into v_recent;
  if v_recent then return NEW; end if;
  select display_name into v_name from public.profiles where id = NEW.user_id;
  perform public.insert_notification_any(v_owner, 'reaction', coalesce(v_name, 'Alguien') || ' te motivó', 'Reaccionó a tu publicación con ' || NEW.emoji,
    jsonb_build_object('post_id', NEW.post_id, 'actor_id', NEW.user_id, 'emoji', NEW.emoji, 'route', '/today?post=' || NEW.post_id::text));
  return NEW;
end;
$$;
