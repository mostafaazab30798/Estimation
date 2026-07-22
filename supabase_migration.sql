-- Supabase Database Migration for Kotshina Multiplayer Lobby

-- 1. Create game_rooms table
create table if not exists public.game_rooms (
    id uuid primary key default gen_random_uuid(),
    room_code varchar(6) not null unique,
    host_id uuid not null references auth.users(id) on delete cascade,
    status varchar(20) not null default 'waiting',
    max_players integer not null default 4,
    host_ip varchar(45) not null,
    ws_port integer not null,
    created_at timestamptz not null default now(),
    started_at timestamptz,

    constraint game_rooms_status_check
        check (status in ('waiting', 'playing', 'finished', 'cancelled')),

    constraint game_rooms_max_players_check
        check (max_players > 0)
);

create index if not exists idx_game_rooms_room_code on public.game_rooms(room_code);
create index if not exists idx_game_rooms_status on public.game_rooms(status);

-- 2. Create room_players table
create table if not exists public.room_players (
    id uuid primary key default gen_random_uuid(),
    room_id uuid not null references public.game_rooms(id) on delete cascade,
    player_id uuid not null references auth.users(id) on delete cascade,
    player_name text not null,
    is_host boolean not null default false,
    joined_at timestamptz not null default now(),

    unique(room_id, player_id)
);

create index if not exists idx_room_players_room_id on public.room_players(room_id);

-- 3. Row Level Security
alter table public.game_rooms enable row level security;
alter table public.room_players enable row level security;

-- Policies for game_rooms
create policy "Anyone can read game rooms" on public.game_rooms
    for select using (true);

create policy "Authenticated users can create rooms" on public.game_rooms
    for insert to authenticated with check (auth.uid() = host_id);

create policy "Only host can update their room" on public.game_rooms
    for update to authenticated using (auth.uid() = host_id);

create policy "Only host can delete their room" on public.game_rooms
    for delete to authenticated using (auth.uid() = host_id);

-- Policies for room_players
create policy "Anyone can read room players" on public.room_players
    for select using (true);

create policy "Authenticated users can join rooms" on public.room_players
    for insert to authenticated with check (auth.uid() = player_id);

create policy "Users can update their own player record" on public.room_players
    for update to authenticated using (auth.uid() = player_id);

create policy "Users can leave rooms" on public.room_players
    for delete to authenticated using (auth.uid() = player_id);

-- 4. Realtime Configuration
begin;
  drop publication if exists supabase_realtime;
  create publication supabase_realtime;
commit;
alter publication supabase_realtime add table game_rooms;
alter publication supabase_realtime add table room_players;

-- 5. RPC Functions
create or replace function public.create_game_room(
    p_room_code varchar(6),
    p_player_name text,
    p_host_ip varchar(45),
    p_ws_port integer
) returns jsonb as $$
declare
    v_room_id uuid;
    v_user_id uuid := auth.uid();
begin
    if v_user_id is null then
        raise exception 'Not authenticated';
    end if;

    insert into public.game_rooms (room_code, host_id, status, host_ip, ws_port)
    values (p_room_code, v_user_id, 'waiting', p_host_ip, p_ws_port)
    returning id into v_room_id;

    insert into public.room_players (room_id, player_id, player_name, is_host)
    values (v_room_id, v_user_id, p_player_name, true);

    return jsonb_build_object('room_id', v_room_id);
exception
    when unique_violation then
        raise exception 'ROOM_CODE_COLLISION';
end;
$$ language plpgsql security definer;

create or replace function public.join_game_room(
    p_room_code varchar(6),
    p_player_name text
) returns jsonb as $$
declare
    v_room public.game_rooms%rowtype;
    v_player_count integer;
    v_user_id uuid := auth.uid();
begin
    if v_user_id is null then
        raise exception 'Not authenticated';
    end if;

    p_room_code := upper(trim(p_room_code));

    -- Initial read without locking to avoid RLS UPDATE policy rejection
    select * into v_room
    from public.game_rooms
    where room_code = p_room_code;

    if not found then
        raise exception 'ROOM_NOT_FOUND';
    end if;

    -- Use advisory lock to prevent race conditions during join
    perform pg_advisory_xact_lock(hashtext(v_room.id::text));

    -- Re-fetch after lock to ensure we have the latest state
    select * into v_room
    from public.game_rooms
    where id = v_room.id;

    if v_room.status != 'waiting' then
        raise exception 'ROOM_NOT_WAITING';
    end if;

    if exists (select 1 from public.room_players where room_id = v_room.id and player_id = v_user_id) then
        return jsonb_build_object('room_id', v_room.id);
    end if;

    select count(*) into v_player_count
    from public.room_players
    where room_id = v_room.id;

    if v_player_count >= v_room.max_players then
        raise exception 'ROOM_FULL';
    end if;

    insert into public.room_players (room_id, player_id, player_name, is_host)
    values (v_room.id, v_user_id, p_player_name, false);

    return jsonb_build_object('room_id', v_room.id);
end;
$$ language plpgsql security definer;

create or replace function public.start_game_room(
    p_room_id uuid
) returns void as $$
declare
    v_room public.game_rooms%rowtype;
    v_user_id uuid := auth.uid();
begin
    if v_user_id is null then
        raise exception 'Not authenticated';
    end if;

    select * into v_room
    from public.game_rooms
    where id = p_room_id
    for update;

    if not found then
        raise exception 'ROOM_NOT_FOUND';
    end if;

    if v_room.host_id != v_user_id then
        raise exception 'NOT_HOST';
    end if;

    if v_room.status != 'waiting' then
        return;
    end if;

    update public.game_rooms
    set status = 'playing', started_at = now()
    where id = p_room_id;
end;
$$ language plpgsql security definer;
