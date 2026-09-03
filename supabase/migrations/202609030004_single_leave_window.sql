-- The five-minute reconnect grace is the complete online-play restriction.
-- Detaching the seat after that grace must not start a second five-minute ban.

create or replace function public.process_room_absences(p_room_id uuid)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  v_room public.game_rooms%rowtype;
  v_player record;
  v_next_state jsonb;
  v_detached int := 0;
  v_bot_takeovers int := 0;
  v_active_humans int := 0;
  v_reclaim_window interval := interval '5 minutes';
  v_bot_delay interval := interval '30 seconds';
  v_max_match_age interval := interval '6 hours';
begin
  select * into v_room
  from public.game_rooms
  where id = p_room_id
  for update;

  if not found or v_room.status not in ('waiting', 'playing') then
    return jsonb_build_object('processed', false, 'bot_takeovers', 0);
  end if;

  if v_room.status = 'playing'
    and coalesce(v_room.started_at, v_room.created_at)
      < timezone('utc', now()) - v_max_match_age then
    select count(*)::int into v_detached
    from public.room_players
    where room_id = p_room_id;

    update public.game_rooms
    set status = 'cancelled',
        matchmaking_state = 'none',
        bots_to_fill = 0,
        bot_yes_votes = 0,
        state_updated_at = timezone('utc', now())
    where id = p_room_id;

    return jsonb_build_object(
      'detached', v_detached,
      'bot_takeovers', 0,
      'terminated', true,
      'expired', true,
      'active_humans', 0
    );
  end if;

  if v_room.status = 'playing' and v_room.game_state is not null then
    for v_player in
      select rp.player_id
      from public.room_players rp
      where rp.room_id = p_room_id
        and rp.last_seen <= timezone('utc', now()) - v_bot_delay
    loop
      v_next_state := public.mark_player_bot_in_game_state(
        v_room.game_state,
        v_player.player_id::text,
        v_room.game_type
      );

      if v_next_state is distinct from v_room.game_state then
        update public.game_rooms
        set game_state = v_next_state,
            state_updated_at = timezone('utc', now())
        where id = p_room_id;
        v_room.game_state := v_next_state;
        v_bot_takeovers := v_bot_takeovers + 1;
      end if;
    end loop;
  end if;

  for v_player in
    select rp.player_id
    from public.room_players rp
    where rp.room_id = p_room_id
      and rp.last_seen < timezone('utc', now()) - v_reclaim_window
  loop
    -- The player already waited the full reclaim window. Remove the stale seat
    -- without creating a new restriction starting at cleanup time.
    delete from public.room_players
    where room_id = p_room_id
      and player_id = v_player.player_id;
    v_detached := v_detached + 1;
  end loop;

  select count(*)::int into v_active_humans
  from public.room_players rp
  where rp.room_id = p_room_id
    and rp.last_seen >= timezone('utc', now()) - v_reclaim_window;

  if v_active_humans = 0 then
    update public.game_rooms
    set status = 'cancelled',
        matchmaking_state = 'none',
        bots_to_fill = 0,
        bot_yes_votes = 0,
        state_updated_at = timezone('utc', now())
    where id = p_room_id and status in ('waiting', 'playing');

    return jsonb_build_object(
      'detached', v_detached,
      'bot_takeovers', v_bot_takeovers,
      'terminated', true,
      'expired', false,
      'active_humans', 0
    );
  end if;

  return jsonb_build_object(
    'detached', v_detached,
    'bot_takeovers', v_bot_takeovers,
    'terminated', false,
    'expired', false,
    'active_humans', v_active_humans
  );
end;
$$;

revoke all on function public.process_room_absences(uuid) from public;
grant execute on function public.process_room_absences(uuid) to authenticated;
