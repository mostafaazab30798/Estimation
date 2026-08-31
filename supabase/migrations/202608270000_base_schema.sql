-- Canonical base schema for local CI / fresh installs (W1.5 partial).
-- Production may already have this from legacy root SQL files; all statements are idempotent.

-- ─── Profiles ────────────────────────────────────────────────────────────────

create table if not exists public.profiles (
  id uuid references auth.users on delete cascade primary key,
  email text,
  username text,
  avatar_url text,
  xp bigint default 0 not null,
  level int default 1 not null,
  games_played int default 0 not null,
  games_won int default 0 not null,
  created_at timestamptz default timezone('utc', now()) not null,
  updated_at timestamptz default timezone('utc', now()) not null
);

alter table public.profiles enable row level security;

drop policy if exists "Public profiles are viewable by everyone." on public.profiles;
create policy "Public profiles are viewable by everyone."
  on public.profiles for select using (true);

drop policy if exists "Users can insert their own profile." on public.profiles;
create policy "Users can insert their own profile."
  on public.profiles for insert with check (auth.uid() = id);

drop policy if exists "Users can update their own profile." on public.profiles;
create policy "Users can update their own profile."
  on public.profiles for update using (auth.uid() = id);

create or replace function public.handle_new_user()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
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
    0, 1, 0, 0
  )
  on conflict (id) do update set
    email = excluded.email,
    username = coalesce(public.profiles.username, excluded.username),
    avatar_url = coalesce(public.profiles.avatar_url, excluded.avatar_url),
    updated_at = timezone('utc', now());
  return new;
end;
$$;

drop trigger if exists on_auth_user_created on auth.users;
create trigger on_auth_user_created
  after insert on auth.users
  for each row execute function public.handle_new_user();

-- ─── Multiplayer lobby ───────────────────────────────────────────────────────

create table if not exists public.game_rooms (
  id uuid primary key default gen_random_uuid(),
  room_code varchar(6) not null unique,
  host_id uuid not null references auth.users(id) on delete cascade,
  status varchar(20) not null default 'waiting',
  max_players integer not null default 4,
  host_ip varchar(45) not null,
  ws_port integer not null,
  game_type text not null default 'kotchina',
  game_state jsonb,
  state_updated_at timestamptz,
  created_at timestamptz not null default now(),
  started_at timestamptz,
  constraint game_rooms_status_check
    check (status in ('waiting', 'playing', 'finished', 'cancelled')),
  constraint game_rooms_max_players_check check (max_players > 0)
);

create index if not exists idx_game_rooms_room_code on public.game_rooms(room_code);
create index if not exists idx_game_rooms_status on public.game_rooms(status);
create index if not exists idx_game_rooms_game_type on public.game_rooms(game_type);

create table if not exists public.room_players (
  id uuid primary key default gen_random_uuid(),
  room_id uuid not null references public.game_rooms(id) on delete cascade,
  player_id uuid not null references auth.users(id) on delete cascade,
  player_name text not null,
  is_host boolean not null default false,
  is_online boolean not null default true,
  last_seen timestamptz not null default now(),
  hand_cards jsonb,
  joined_at timestamptz not null default now(),
  unique(room_id, player_id)
);

create index if not exists idx_room_players_room_id on public.room_players(room_id);

alter table public.game_rooms enable row level security;
alter table public.room_players enable row level security;

drop policy if exists "Anyone can read game rooms" on public.game_rooms;
create policy "Anyone can read game rooms"
  on public.game_rooms for select using (true);

drop policy if exists "Authenticated users can create rooms" on public.game_rooms;
create policy "Authenticated users can create rooms"
  on public.game_rooms for insert to authenticated with check (auth.uid() = host_id);

drop policy if exists "Only host can update their room" on public.game_rooms;
create policy "Only host can update their room"
  on public.game_rooms for update to authenticated using (auth.uid() = host_id);

drop policy if exists "Only host can delete their room" on public.game_rooms;
create policy "Only host can delete their room"
  on public.game_rooms for delete to authenticated using (auth.uid() = host_id);

drop policy if exists "Anyone can read room players" on public.room_players;
create policy "Anyone can read room players"
  on public.room_players for select using (true);

drop policy if exists "Authenticated users can join rooms" on public.room_players;
create policy "Authenticated users can join rooms"
  on public.room_players for insert to authenticated with check (auth.uid() = player_id);

drop policy if exists "Users can update their own player record" on public.room_players;
create policy "Users can update their own player record"
  on public.room_players for update to authenticated using (auth.uid() = player_id);

drop policy if exists "Users can leave rooms" on public.room_players;
create policy "Users can leave rooms"
  on public.room_players for delete to authenticated using (auth.uid() = player_id);

-- ─── Game history ────────────────────────────────────────────────────────────

create table if not exists public.game_history (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users(id) on delete cascade,
  game_data jsonb not null,
  created_at timestamptz not null default now()
);

create index if not exists idx_game_history_user_id_created_at
  on public.game_history(user_id, created_at desc);

alter table public.game_history enable row level security;

drop policy if exists "Users can read game history" on public.game_history;
create policy "Users can read game history"
  on public.game_history for select to authenticated using (true);

drop policy if exists "Users can insert their own game history" on public.game_history;
create policy "Users can insert their own game history"
  on public.game_history for insert to authenticated with check (auth.uid() = user_id);

drop policy if exists "Users can update their own game history" on public.game_history;
create policy "Users can update their own game history"
  on public.game_history for update to authenticated using (auth.uid() = user_id);

drop policy if exists "Users can delete their own game history" on public.game_history;
create policy "Users can delete their own game history"
  on public.game_history for delete to authenticated using (auth.uid() = user_id);

-- Stats RPC hardened in 202608310002 (not defined here — avoids legacy body on CI reset).

-- ─── Realtime (best-effort; local stack may already publish these) ─────────

do $$
begin
  alter publication supabase_realtime add table public.game_rooms;
exception when duplicate_object then null;
end $$;

do $$
begin
  alter publication supabase_realtime add table public.room_players;
exception when duplicate_object then null;
end $$;
