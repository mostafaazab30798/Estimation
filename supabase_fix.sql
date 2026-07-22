-- ============================================================
-- Fix: join_game_room & create_game_room robustness patch
-- Run this in Supabase SQL Editor (Dashboard -> SQL Editor)
-- ============================================================

-- 1. Improved create_game_room
--    Cleans up stale rooms by same host before creating a new one
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
        raise exception 'NOT_AUTHENTICATED';
    end if;

    -- Clean up any previous waiting/cancelled rooms owned by this host
    delete from public.game_rooms
    where host_id = v_user_id
      and status in ('waiting', 'cancelled');

    -- Normalize room code
    p_room_code := upper(trim(p_room_code));

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

-- 2. Improved join_game_room
--    Distinct error codes for each failure mode
create or replace function public.join_game_room(
    p_room_code varchar(6),
    p_player_name text
) returns jsonb as $$
declare
    v_room         public.game_rooms%rowtype;
    v_player_count integer;
    v_user_id      uuid := auth.uid();
begin
    if v_user_id is null then
        raise exception 'NOT_AUTHENTICATED';
    end if;

    -- Normalize input
    p_room_code := upper(trim(p_room_code));

    -- Look up the room by code (pick newest if duplicates exist)
    select * into v_room
    from public.game_rooms
    where room_code = p_room_code
    order by created_at desc
    limit 1;

    if not found then
        raise exception 'ROOM_NOT_FOUND';
    end if;

    -- Idempotent: if already joined, return success (allow reconnects)
    if exists (
        select 1 from public.room_players
        where room_id = v_room.id and player_id = v_user_id
    ) then
        return jsonb_build_object('room_id', v_room.id);
    end if;

    -- Check if room is still joinable for NEW players
    if v_room.status = 'playing' then
        raise exception 'ROOM_ALREADY_STARTED';
    end if;

    if v_room.status in ('finished', 'cancelled') then
        raise exception 'ROOM_NOT_AVAILABLE';
    end if;

    -- Advisory lock to prevent join race conditions
    perform pg_advisory_xact_lock(hashtext(v_room.id::text));

    -- Re-fetch after lock
    select * into v_room
    from public.game_rooms
    where id = v_room.id;

    if v_room.status != 'waiting' then
        raise exception 'ROOM_NOT_WAITING';
    end if;

    -- Check capacity
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

-- 3. Grant execute permissions
grant execute on function public.create_game_room(varchar, text, varchar, integer) to authenticated;
grant execute on function public.join_game_room(varchar, text) to authenticated;
