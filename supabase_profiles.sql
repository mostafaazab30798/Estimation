-- ==============================================================================
-- Supabase Profiles & Google Auth Schema Migration
-- ==============================================================================

-- 1. Create the public.profiles table
create table if not exists public.profiles (
  id uuid references auth.users on delete cascade primary key,
  email text,
  username text,
  avatar_url text,
  xp bigint default 0 not null,
  level int default 1 not null,
  games_played int default 0 not null,
  games_won int default 0 not null,
  created_at timestamp with time zone default timezone('utc'::text, now()) not null,
  updated_at timestamp with time zone default timezone('utc'::text, now()) not null
);

-- 2. Enable Row Level Security (RLS)
alter table public.profiles enable row level security;

-- 3. RLS Policies
-- Allow anyone to view profiles (for leaderboard, match history, and multiplayer discovery)
drop policy if exists "Public profiles are viewable by everyone." on public.profiles;
create policy "Public profiles are viewable by everyone." 
  on public.profiles for select 
  using (true);

-- Allow authenticated users to insert their own profile
drop policy if exists "Users can insert their own profile." on public.profiles;
create policy "Users can insert their own profile." 
  on public.profiles for insert 
  with check (auth.uid() = id);

-- Allow authenticated users to update their own profile
drop policy if exists "Users can update their own profile." on public.profiles;
create policy "Users can update their own profile." 
  on public.profiles for update 
  using (auth.uid() = id);

-- 4. Function & Trigger to automatically create a profile on signup
create or replace function public.handle_new_user()
returns trigger as $$
begin
  insert into public.profiles (id, email, username, avatar_url, xp, level, games_played, games_won)
  values (
    new.id,
    new.email,
    coalesce(
      new.raw_user_meta_data->>'full_name',
      new.raw_user_meta_data->>'name',
      split_part(coalesce(new.email, 'Player'), '@', 1)
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
    updated_at = timezone('utc'::text, now());
  return new;
end;
$$ language plpgsql security definer;

drop trigger if exists on_auth_user_created on auth.users;
create trigger on_auth_user_created
  after insert on auth.users
  for each row execute function public.handle_new_user();

-- 5. Helper function for atomic stats increment
create or replace function public.increment_player_stats(
  player_id uuid,
  xp_gain bigint default 0,
  won boolean default false
)
returns void as $$
declare
  current_xp bigint;
  calculated_level int;
begin
  update public.profiles
  set
    xp = xp + xp_gain,
    games_played = games_played + 1,
    games_won = case when won then games_won + 1 else games_won end,
    -- Level formula: 1 + floor(sqrt(new_xp / 100))
    level = 1 + floor(sqrt((xp + xp_gain) / 100.0))::int,
    updated_at = timezone('utc'::text, now())
  where id = player_id and (auth.uid() = player_id or auth.role() = 'service_role');
end;
$$ language plpgsql security definer;
