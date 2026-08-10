-- Phase 3 ledger: service-role-only point awards and derived standings.
-- Applied migrations are forward-only.

-- Single entry point for awarding season points. Only callable by the
-- service role / trusted backend; the authenticated role has no execute
-- grant. Idempotency is enforced by the unique ledger entry constraint on
-- (season_id, user_id, reason, reference_type, reference_id).
create or replace function public.award_points(
  p_season_id uuid,
  p_user_id uuid,
  p_points integer,
  p_reason text,
  p_reference_type text default null,
  p_reference_id uuid default null
)
returns uuid
language plpgsql
security definer
set search_path = pg_catalog, public
as $$
declare
  v_ledger_id uuid;
  v_season_open boolean;
begin
  if p_points < 0 then
    raise exception 'Points cannot be negative'
      using errcode = 'check_violation';
  end if;

  select exists (
    select 1
    from public.seasons s
    where s.id = p_season_id
      and s.status = 'active'
      and s.starts_at <= now()
      and s.ends_at > now()
  ) into v_season_open;

  if not v_season_open then
    raise exception 'Season is not accepting points'
      using errcode = 'check_violation';
  end if;

  insert into public.season_points (
    season_id, user_id, points, reason, reference_type, reference_id
  )
  values (
    p_season_id, p_user_id, p_points, p_reason, p_reference_type, p_reference_id
  )
  returning id into v_ledger_id;

  return v_ledger_id;
end;
$$;

comment on function public.award_points(uuid, uuid, integer, text, text, uuid) is
  'Append-only season point ledger write. Service-role only; rejects points for closed seasons.';

-- The authenticated role must never call this function directly.
revoke all on function public.award_points(uuid, uuid, integer, text, text, uuid) from public;
revoke all on function public.award_points(uuid, uuid, integer, text, text, uuid) from anon;
revoke all on function public.award_points(uuid, uuid, integer, text, text, uuid) from authenticated;
grant execute on function public.award_points(uuid, uuid, integer, text, text, uuid) to service_role;

-- Standings view over the ledger, with proper ranking. Clients may only
-- read it; writes flow exclusively through award_points.
drop view if exists public.season_standings;
create view public.season_standings
with (security_invoker = true)
as
select
  sp.season_id,
  sp.user_id,
  p.display_name,
  coalesce(sum(sp.points), 0) as total_points,
  rank() over (
    partition by sp.season_id
    order by coalesce(sum(sp.points), 0) desc
  ) as position
from public.season_points sp
join public.profiles p on p.id = sp.user_id
group by sp.season_id, sp.user_id, p.display_name;

grant select on table public.season_standings to authenticated;
revoke all on table public.season_standings from anon;
