-- Restore service_role bot-seat proxy in turn validation (regressed in 202609010003).
-- Also persist real bot hands so the server bot runner can plan trick-taking moves.

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
begin
  players := result -> 'players';
  if players is null or jsonb_typeof(players) <> 'array' then
    if result ? 'deck' then
      result := result - 'deck';
      if not (result ? 'deckCount') then
        result := jsonb_set(
          result,
          '{deckCount}',
          to_jsonb(coalesce(jsonb_array_length(p_state -> 'deck'), 0))
        );
      end if;
    end if;
    return result;
  end if;

  for idx in 0 .. jsonb_array_length(players) - 1 loop
    player := players -> idx;
    v_player_id := player ->> 'id';
    hand := player -> 'hand';

    if hand is not null
      and jsonb_typeof(hand) = 'array'
      and not public.is_proxy_bot_seat(result, v_player_id) then
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
    if not (result ? 'deckCount') then
      result := jsonb_set(
        result,
        '{deckCount}',
        to_jsonb(coalesce(jsonb_array_length(p_state -> 'deck'), 0))
      );
    end if;
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
immutable
set search_path = public
as $$
declare
  v_phase text := coalesce(p_state ->> 'phase', 'lobby');
  v_player_id text;
  v_seat int;
  v_turn_seat int;
  v_auction_seat int;
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
  if v_seat < 0 then
    raise exception 'ACTOR_NOT_IN_GAME';
  end if;

  case p_action
    when 'startGame', 'nextRound', 'changeTheme' then
      if not p_is_host then
        raise exception 'HOST_ONLY';
      end if;

    when 'submitBid', 'passBid' then
      if v_phase <> 'auction' then
        raise exception 'WRONG_PHASE';
      end if;
      v_auction_seat := coalesce((p_state ->> 'auctionTurnSeatIndex')::int, -1);
      if v_seat <> v_auction_seat then
        raise exception 'NOT_YOUR_TURN';
      end if;

    when 'submitDashCall' then
      if v_phase <> 'dashCall' then
        raise exception 'WRONG_PHASE';
      end if;
      v_turn_seat := coalesce((p_state ->> 'currentPlayerSeatIndex')::int, -1);
      if v_seat <> v_turn_seat then
        raise exception 'NOT_YOUR_TURN';
      end if;

    when 'submitDeclaration' then
      if v_phase <> 'declarations' then
        raise exception 'WRONG_PHASE';
      end if;
      v_turn_seat := coalesce((p_state ->> 'currentPlayerSeatIndex')::int, -1);
      if v_seat <> v_turn_seat then
        raise exception 'NOT_YOUR_TURN';
      end if;

    when 'playCard' then
      if v_phase <> 'trickTaking' then
        raise exception 'WRONG_PHASE';
      end if;
      v_turn_seat := coalesce((p_state ->> 'currentPlayerSeatIndex')::int, -1);
      if v_seat <> v_turn_seat then
        raise exception 'NOT_YOUR_TURN';
      end if;

    when 'confirmNoVoid', 'unready', 'approveRedeal', 'rejectRedeal' then
      if v_phase <> 'voidCheck' then
        raise exception 'WRONG_PHASE';
      end if;

    when 'sendReaction', 'triggerEarthquake', 'requestStateSync' then
      null;

    else
      raise exception 'UNKNOWN_ACTION';
  end case;
end;
$$;

create or replace function public.ninety_nine_validate_turn(
  p_action text,
  p_payload jsonb,
  p_actor_uid uuid,
  p_state jsonb,
  p_is_host boolean
)
returns void
language plpgsql
immutable
set search_path = public
as $$
declare
  v_phase text := coalesce(p_state ->> 'phase', 'waiting');
  v_turn_idx int := coalesce((p_state ->> 'currentPlayerIndex')::int, -1);
  v_player_id text;
  v_actor_idx int;
  v_host text := coalesce(p_state ->> 'hostId', '');
begin
  if public.mode_actor_index(p_state, p_actor_uid) < 0 then
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

  v_actor_idx := public.player_index_in_state(p_state, v_player_id);
  if v_actor_idx < 0 then
    raise exception 'ACTOR_NOT_IN_GAME';
  end if;

  case p_action
    when 'startGame', 'nextRound', 'changeTheme' then
      if not p_is_host and v_host <> '' and v_host <> p_actor_uid::text then
        raise exception 'HOST_ONLY';
      end if;

    when 'playCardNinetyNine' then
      if v_phase <> 'playing' then
        raise exception 'WRONG_PHASE';
      end if;
      if v_actor_idx <> v_turn_idx then
        raise exception 'NOT_YOUR_TURN';
      end if;

    when 'sendReaction', 'triggerEarthquake', 'requestStateSync' then
      null;

    else
      raise exception 'UNKNOWN_ACTION';
  end case;
end;
$$;

create or replace function public.basra_validate_turn(
  p_action text,
  p_payload jsonb,
  p_actor_uid uuid,
  p_state jsonb,
  p_is_host boolean
)
returns void
language plpgsql
immutable
set search_path = public
as $$
declare
  v_phase text := coalesce(p_state ->> 'phase', 'waiting');
  v_turn_idx int := coalesce((p_state ->> 'currentPlayerIndex')::int, -1);
  v_player_id text;
  v_actor_idx int;
  v_host text := coalesce(p_state ->> 'hostId', '');
begin
  if public.mode_actor_index(p_state, p_actor_uid) < 0 then
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

  v_actor_idx := public.player_index_in_state(p_state, v_player_id);
  if v_actor_idx < 0 then
    raise exception 'ACTOR_NOT_IN_GAME';
  end if;

  case p_action
    when 'startGame', 'nextRound', 'changeTheme' then
      if not p_is_host and v_host <> '' and v_host <> p_actor_uid::text then
        raise exception 'HOST_ONLY';
      end if;

    when 'playCardBasra' then
      if v_phase <> 'playing' then
        raise exception 'WRONG_PHASE';
      end if;
      if v_actor_idx <> v_turn_idx then
        raise exception 'NOT_YOUR_TURN';
      end if;

    when 'sendReaction', 'triggerEarthquake', 'requestStateSync' then
      null;

    else
      raise exception 'UNKNOWN_ACTION';
  end case;
end;
$$;
