-- Leaderboard: registered (Google) users only — exclude anonymous auth accounts.
--
-- Anonymous users were inserted into profiles by handle_new_user; the view
-- now joins auth.users and filters is_anonymous. The trigger skips anonymous
-- sign-ups going forward.

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

-- Stop creating profile rows for anonymous / email-less auth users.
create or replace function public.handle_new_user()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  if coalesce(new.is_anonymous, false) then
    return new;
  end if;

  if new.email is null or trim(new.email) = '' then
    return new;
  end if;

  insert into public.profiles (id, email, username, avatar_url, xp, level, games_played, games_won)
  values (
    new.id,
    new.email,
    coalesce(
      new.raw_user_meta_data->>'full_name',
      new.raw_user_meta_data->>'name',
      split_part(new.email, '@', 1)
    ),
    coalesce(
      new.raw_user_meta_data->>'avatar_url',
      new.raw_user_meta_data->>'picture',
      'preset:king'
    ),
    0,
    1,
    0,
    0
  )
  on conflict (id) do update set
    email = excluded.email,
    username = coalesce(public.profiles.username, excluded.username),
    avatar_url = coalesce(public.profiles.avatar_url, excluded.avatar_url),
    updated_at = timezone('utc', now());

  return new;
end;
$$;

-- Optional: remove legacy anonymous rows from leaderboard source table.
delete from public.profiles p
using auth.users u
where p.id = u.id
  and (
    coalesce(u.is_anonymous, false)
    or u.email is null
    or trim(u.email) = ''
  );
