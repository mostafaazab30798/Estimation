-- Make the advertised 30-second absence takeover actionable immediately.

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
  v_ban interval := interval '5 minutes';
  v_fresh_absence_cutoff timestamptz;
begin
  select * into v_room
  from public.game_rooms
  where id = p_room_id
  for update;

  if not found or v_room.status not in ('waiting', 'playing') then
    return jsonb_build_object('processed', false, 'bot_takeovers', 0);
  end if;

  v_fresh_absence_cutoff := timezone('utc', now())
    - v_reclaim_window - interval '90 seconds';

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
    select rp.player_id, rp.last_seen
    from public.room_players rp
    where rp.room_id = p_room_id
      and rp.last_seen < timezone('utc', now()) - v_reclaim_window
  loop
    if v_player.last_seen > v_fresh_absence_cutoff then
      update public.profiles
      set online_ban_until = timezone('utc', now()) + v_ban,
          updated_at = timezone('utc', now())
      where id = v_player.player_id;
    end if;

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
    delete from public.game_action_log where room_id = p_room_id;
    update public.game_rooms
    set status = 'cancelled',
        matchmaking_state = 'none',
        bots_to_fill = 0,
        game_state = null,
        state_updated_at = timezone('utc', now())
    where id = p_room_id and status in ('waiting', 'playing');

    return jsonb_build_object(
      'detached', v_detached,
      'bot_takeovers', v_bot_takeovers,
      'terminated', true,
      'active_humans', 0
    );
  end if;

  return jsonb_build_object(
    'detached', v_detached,
    'bot_takeovers', v_bot_takeovers,
    'terminated', false,
    'active_humans', v_active_humans
  );
end;
$$;

drop function if exists public.player_heartbeat(uuid);
create function public.player_heartbeat(p_room_id uuid)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  v_uid uuid := auth.uid();
  v_result jsonb;
begin
  if v_uid is null then
    return jsonb_build_object('processed', false, 'bot_takeovers', 0);
  end if;

  update public.room_players
  set is_online = true,
      last_seen = timezone('utc', now())
  where room_id = p_room_id
    and player_id = v_uid;

  update public.game_rooms
  set game_state = public.unmark_player_bot_in_game_state(
        game_state,
        v_uid::text,
        game_type
      ),
      state_updated_at = timezone('utc', now())
  where id = p_room_id
    and status = 'playing'
    and game_state is not null;

  v_result := public.process_room_absences(p_room_id);
  return coalesce(v_result, jsonb_build_object('bot_takeovers', 0));
end;
$$;

revoke all on function public.player_heartbeat(uuid) from public;
grant execute on function public.player_heartbeat(uuid) to authenticated;

create or replace function public.estimation_validate_turn(
  p_action text,
  p_payload jsonb,
  p_actor_uid uuid,
  p_state jsonb,
  p_is_host boolean
)
returns void
language plpgsql
stable
set search_path = public
as $$
declare
  v_phase text := coalesce(p_state ->> 'phase', 'lobby');
  v_player_id text;
  v_seat int;
  v_turn_seat int;
  v_auction_seat int;
  v_deadline bigint;
  v_now_ms bigint;
begin
  if public.estimation_actor_seat(p_state, p_actor_uid) < 0 then
    if p_action = 'startGame'
      and p_is_host
      and v_phase in ('waiting', 'lobby')
      and jsonb_array_length(coalesce(p_state -> 'players', '[]'::jsonb)) = 0 then
      return;
    else
      raise exception 'ACTOR_NOT_IN_GAME';
    end if;
  end if;

  v_player_id := public.resolve_acting_player_id(
    p_actor_uid, p_payload, p_state, p_is_host
  );
  if v_player_id <> p_actor_uid::text and not p_is_host then
    raise exception 'PROXY_NOT_ALLOWED';
  end if;
  if v_player_id <> p_actor_uid::text
    and not public.is_proxy_bot_seat(p_state, v_player_id) then
    raise exception 'PROXY_NOT_ALLOWED';
  end if;

  v_seat := public.estimation_player_seat(p_state, v_player_id);
  if v_seat < 0 then raise exception 'ACTOR_NOT_IN_GAME'; end if;

  case p_action
    when 'startGame', 'nextRound', 'changeTheme' then
      if not p_is_host then raise exception 'HOST_ONLY'; end if;
    when 'submitBid', 'passBid' then
      if v_phase <> 'auction' then raise exception 'WRONG_PHASE'; end if;
      v_auction_seat := coalesce((p_state ->> 'auctionTurnSeatIndex')::int, -1);
      if v_seat <> v_auction_seat then raise exception 'NOT_YOUR_TURN'; end if;
    when 'submitDashCall' then
      if v_phase <> 'dashCall' then raise exception 'WRONG_PHASE'; end if;
      v_turn_seat := coalesce((p_state ->> 'currentPlayerSeatIndex')::int, -1);
      if v_seat <> v_turn_seat then raise exception 'NOT_YOUR_TURN'; end if;
    when 'submitDeclaration' then
      if v_phase <> 'declarations' then raise exception 'WRONG_PHASE'; end if;
      v_turn_seat := coalesce((p_state ->> 'currentPlayerSeatIndex')::int, -1);
      if v_seat <> v_turn_seat then raise exception 'NOT_YOUR_TURN'; end if;
    when 'playCard' then
      if v_phase <> 'trickTaking' then raise exception 'WRONG_PHASE'; end if;
      v_turn_seat := coalesce((p_state ->> 'currentPlayerSeatIndex')::int, -1);
      if v_seat <> v_turn_seat then raise exception 'NOT_YOUR_TURN'; end if;
    when 'timeoutTurn' then
      if v_phase not in ('dashCall', 'auction', 'declarations', 'trickTaking') then
        raise exception 'WRONG_PHASE';
      end if;
      v_deadline := coalesce((p_state ->> 'turnDeadlineEpochMs')::bigint, 0);
      v_now_ms := floor(extract(epoch from clock_timestamp()) * 1000)::bigint;
      if v_deadline <= 0 or v_now_ms + 250 < v_deadline then
        raise exception 'TURN_NOT_EXPIRED';
      end if;
    when 'confirmNoVoid', 'unready', 'approveRedeal', 'rejectRedeal' then
      if v_phase <> 'voidCheck' then raise exception 'WRONG_PHASE'; end if;
    when 'sendReaction', 'triggerEarthquake', 'requestStateSync', 'processBots' then
      null;
    else
      raise exception 'UNKNOWN_ACTION';
  end case;
end;
$$;
