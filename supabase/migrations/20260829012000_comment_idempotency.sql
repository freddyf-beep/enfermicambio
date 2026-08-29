-- A repeated mobile tap or retried request must create at most one comment.
alter table public.comments
  add column if not exists client_request_id uuid;

create unique index if not exists comments_author_request_unique
  on public.comments (author_id, client_request_id)
  where client_request_id is not null;

create or replace function public.create_comment_once(
  p_post_id uuid,
  p_body text,
  p_request_id uuid
)
returns public.comments
language plpgsql
security definer
set search_path = public, pg_temp
as $$
declare
  v_user_id uuid := auth.uid();
  v_comment public.comments;
begin
  if v_user_id is null then
    raise exception 'Debes iniciar sesión';
  end if;
  if p_request_id is null then
    raise exception 'Falta el identificador de la solicitud';
  end if;

  insert into public.comments (post_id, author_id, body, client_request_id)
  values (p_post_id, v_user_id, btrim(p_body), p_request_id)
  on conflict (author_id, client_request_id) where client_request_id is not null
  do nothing
  returning * into v_comment;

  if v_comment.id is null then
    select * into v_comment
    from public.comments
    where author_id = v_user_id and client_request_id = p_request_id;
  end if;
  return v_comment;
end;
$$;

revoke all on function public.create_comment_once(uuid, text, uuid) from public;
grant execute on function public.create_comment_once(uuid, text, uuid) to authenticated;
