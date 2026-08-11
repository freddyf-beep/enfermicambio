-- Enable Realtime for the tables the app streams. The database remains
-- authoritative; Realtime is only a delivery mechanism. Forward-only.

alter publication supabase_realtime add table public.posts;
alter publication supabase_realtime add table public.comments;
alter publication supabase_realtime add table public.reactions;
alter publication supabase_realtime add table public.daily_activity;
alter publication supabase_realtime add table public.season_points;
