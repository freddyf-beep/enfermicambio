-- The existing workouts update trigger writes updated_at, but the original
-- table definition omitted that column. Add it so repeated imports can update
-- the same workout safely.

alter table public.workouts
  add column if not exists updated_at timestamptz not null default now();
