-- Online Estimation lifecycle repair:
-- 1. reclaim active humans from temporary bot takeover;
-- 2. execute expired turns through server authority;
-- 3. cancel abandoned playing rooms and normalize matchmaking state.

create or replace function public.unmark_player_bot_in_game_state(
  p_state jsonb,
  p_player_id text,
  p_game_type text
)
returns jsonb
language plpgsql
immutable
set search_path = public
as $$
declare
  v_state jsonb := coalesce(p_state, '{}'::jsonb);
  v_players jsonb := coalesce(p_state -> 'players', '[]'::jsonb);
  v_player jsonb;
  v_index int;
  v_bot_ids jsonb;
begin
  if p_state is null or p_player_id is null or p_player_id = '' then
    return p_state;
  end if;

  if jsonb_typeof(v_players) = 'array' and jsonb_array_length(v_players) > 0 then
    for v_index in 0 .. jsonb_array_length(v_players) - 1 loop
      v_player := v_players -> v_index;
      if v_player ->> 'id' = p_player_id and p_player_id not like 'bot\_%' escape '\' then
        v_players := jsonb_set(v_players, array[v_index::text, 'isBot'], 'false'::jsonb, true);
        exit;
      end if;
    end loop;
    v_state := jsonb_set(v_state, '{players}', v_players, true);
  end if;

  select coalesce(jsonb_agg(value), '[]'::jsonb)
  into v_bot_ids
  from jsonb_array_elements(coalesce(v_state -> 'botPlayerIds', '[]'::jsonb))
  where value #>> '{}' <> p_player_id;

  return jsonb_set(v_state, '{botPlayerIds}', v_bot_ids, true);
end;
$$;

create or replace function public.player_heartbeat(p_room_id uuid)
returns void
language plpgsql
security definer
set search_path = public
as $$
declare
  v_uid uuid := auth.uid();
begin
  if v_uid is null then
    return;
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

  perform public.process_room_absences(p_room_id);
end;
$$;

revoke all on function public.player_heartbeat(uuid) from public;
grant execute on function public.player_heartbeat(uuid) to authenticated;

-- Persist real hands only for permanent bot_* seats. A temporarily automated
-- human UUID still owns a private-hand row and must remain masked publicly.
create or replace function public.sanitize_game_state_json(p_state jsonb)
returns jsonb
language plpgsql
immutable
set search_path = public
as $$
declare
  result jsonb := coalesce(p_state, '{}'::jsonb);
  players jsonb;
  sanitized_players jsonb := '[]'::jsonb;
  player jsonb;
  hand jsonb;
  masked_hand jsonb;
  idx int;
  hand_len int;
  v_player_id text;
  v_permanent_bot boolean;
begin
  players := result -> 'players';
  if players is null or jsonb_typeof(players) <> 'array' then
    if result ? 'deck' then
      result := result - 'deck';
      result := jsonb_set(
        result,
        '{deckCount}',
        to_jsonb(coalesce(jsonb_array_length(p_state -> 'deck'), 0)),
        true
      );
    end if;
    return result;
  end if;

  if jsonb_array_length(players) = 0 then
    return jsonb_set(result, '{players}', '[]'::jsonb, true) - 'deck';
  end if;

  for idx in 0 .. jsonb_array_length(players) - 1 loop
    player := players -> idx;
    v_player_id := coalesce(player ->> 'id', '');
    v_permanent_bot := v_player_id like 'bot\_%' escape '\'
      or coalesce((player ->> 'isBot')::boolean, false);
    hand := player -> 'hand';

    if hand is not null
      and jsonb_typeof(hand) = 'array'
      and not v_permanent_bot then
      hand_len := jsonb_array_length(hand);
      select coalesce(
        jsonb_agg(jsonb_build_object('suit', 'spade', 'rank', 'two')),
        '[]'::jsonb
      )
      into masked_hand
      from generate_series(1, hand_len);
      player := jsonb_set(player, '{hand}', masked_hand);
    end if;

    sanitized_players := sanitized_players || jsonb_build_array(player);
  end loop;

  result := jsonb_set(result, '{players}', sanitized_players);
  if result ? 'deck' then
    result := result - 'deck';
    result := jsonb_set(
      result,
      '{deckCount}',
      to_jsonb(coalesce(jsonb_array_length(p_state -> 'deck'), 0)),
      true
    );
  end if;
  return result;
end;
$$;

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
    when 'sendReaction', 'triggerEarthquake', 'requestStateSync' then
      null;
    else
      raise exception 'UNKNOWN_ACTION';
  end case;
end;
$$;

create or replace function public.cleanup_stale_playing_room(p_room_id uuid)
returns boolean
language plpgsql
security definer
set search_path = public
as $$
declare
  v_changed boolean := false;
begin
  update public.game_rooms gr
  set status = 'cancelled',
      matchmaking_state = 'none',
      bots_to_fill = 0,
      bot_yes_votes = 0,
      state_updated_at = timezone('utc', now())
  where gr.id = p_room_id
    and gr.status = 'playing'
    and coalesce(gr.state_updated_at, gr.started_at, gr.created_at)
      < timezone('utc', now()) - interval '5 minutes'
    and not exists (
      select 1
      from public.room_players rp
      where rp.room_id = gr.id
        and rp.last_seen >= timezone('utc', now()) - interval '5 minutes'
    );
  v_changed := found;
  return v_changed;
end;
$$;

revoke all on function public.cleanup_stale_playing_room(uuid) from public;
grant execute on function public.cleanup_stale_playing_room(uuid) to service_role;

-- Clean only the abandoned staging room supplied with this QA report. Keep its
-- snapshot intact so the failure evidence remains available.
select public.cleanup_stale_playing_room(
  '15f3bd42-95d8-418e-89d8-1334316e8417'::uuid
);
