-- Fix leaderboard: public_profiles must not inherit owner-only RLS from profiles.
--
-- With security_invoker = true, each caller only sees their own profiles row,
-- so the leaderboard showed a single player. security_invoker = false runs
-- the view as its owner (postgres), exposing only the public columns below.

create or replace view public.public_profiles
with (security_invoker = false) as
select
  p.id,
  p.username,
  p.avatar_url,
  p.xp,
  p.level,
  p.games_played,
  p.games_won,
  p.created_at,
  p.updated_at
from public.profiles p
inner join auth.users u on u.id = p.id
where coalesce(u.is_anonymous, false) = false
  and u.email is not null
  and trim(u.email) <> '';

grant select on public.public_profiles to anon, authenticated;
