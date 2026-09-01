-- Allow the first startGame commit when game_state is still empty in the DB.
-- Edge reducer hydrates players from room_players; SQL validation must not
-- require a seat in the persisted snapshot before the first action lands.

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
  v_seat int := public.estimation_actor_seat(p_state, p_actor_uid);
  v_turn_seat int;
  v_auction_seat int;
begin
  if v_seat < 0 then
    if p_action = 'startGame'
      and p_is_host
      and v_phase in ('waiting', 'lobby')
      and jsonb_array_length(coalesce(p_state -> 'players', '[]'::jsonb)) = 0 then
      null;
    else
      raise exception 'ACTOR_NOT_IN_GAME';
    end if;
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

    when 'approveRedeal', 'rejectRedeal', 'confirmNoVoid', 'unready' then
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
  v_actor_idx int := public.mode_actor_index(p_state, p_actor_uid);
  v_host text := coalesce(p_state ->> 'hostId', '');
begin
  if v_actor_idx < 0 then
    if p_action = 'startGame'
      and p_is_host
      and v_phase in ('waiting', 'lobby')
      and jsonb_array_length(coalesce(p_state -> 'players', '[]'::jsonb)) = 0 then
      null;
    else
      raise exception 'ACTOR_NOT_IN_GAME';
    end if;
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
  v_actor_idx int := public.mode_actor_index(p_state, p_actor_uid);
  v_host text := coalesce(p_state ->> 'hostId', '');
begin
  if v_actor_idx < 0 then
    if p_action = 'startGame'
      and p_is_host
      and v_phase in ('waiting', 'lobby')
      and jsonb_array_length(coalesce(p_state -> 'players', '[]'::jsonb)) = 0 then
      null;
    else
      raise exception 'ACTOR_NOT_IN_GAME';
    end if;
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

-- Treat json null snapshots like empty objects when building authority state.
create or replace function public.get_authority_room_state(p_room_id uuid)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  v_room public.game_rooms%rowtype;
  v_state jsonb;
  v_players jsonb;
  v_player jsonb;
  v_hand jsonb;
  v_idx int;
  v_player_id_text text;
  v_player_id uuid;
  v_result jsonb;
begin
  if auth.role() <> 'service_role' then
    raise exception 'SERVICE_ROLE_ONLY';
  end if;

  select * into v_room
  from public.game_rooms
  where id = p_room_id;

  if not found then
    raise exception 'ROOM_NOT_FOUND';
  end if;

  v_state := coalesce(v_room.game_state, '{}'::jsonb);
  if v_state is null or v_state = 'null'::jsonb or jsonb_typeof(v_state) <> 'object' then
    v_state := '{}'::jsonb;
  end if;
  v_players := coalesce(v_state -> 'players', '[]'::jsonb);

  if jsonb_array_length(v_players) = 0
    or coalesce(v_state ->> 'phase', 'waiting') in ('waiting', 'lobby') then
    select coalesce(
      jsonb_agg(
        jsonb_build_object(
          'id', rp.player_id::text,
          'name', rp.player_name,
          'hand', '[]'::jsonb,
          'isBot', false,
          'avatarId', 'avatar_1',
          'capturedCards', '[]'::jsonb,
          'roundScore', 0,
          'basraCount', 0,
          'takenTricks', '[]'::jsonb,
          'actual', 0,
          'hasPassed', false,
          'isDashCall', false,
          'isRisk', false,
          'totalScore', 0
        )
        order by rp.joined_at
      ),
      '[]'::jsonb
    )
    into v_players
    from public.room_players rp
    where rp.room_id = p_room_id;

    v_state := jsonb_set(v_state, '{players}', v_players);
    v_state := jsonb_set(v_state, '{hostId}', to_jsonb(v_room.host_id::text));
    if not (v_state ? 'phase') then
      v_state := jsonb_set(v_state, '{phase}', '"waiting"'::jsonb);
    end if;
    if v_room.game_type in ('ninety_nine', '99') and not (v_state ? 'playerLosses') then
      v_state := jsonb_set(v_state, '{playerLosses}', '{}'::jsonb);
    end if;
  end if;

  for v_idx in 0 .. jsonb_array_length(v_players) - 1 loop
    v_player := v_players -> v_idx;
    v_player_id_text := v_player ->> 'id';
    v_hand := coalesce(v_player -> 'hand', '[]'::jsonb);

    if v_player_id_text ~ '^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$' then
      begin
        v_player_id := v_player_id_text::uuid;
        select coalesce(pph.hand_cards, v_hand)
        into v_hand
        from public.player_private_hands pph
        where pph.room_id = p_room_id
          and pph.player_id = v_player_id;
      exception when others then
        null;
      end;
    end if;

    v_player := jsonb_set(v_player, '{hand}', v_hand);
    v_players := jsonb_set(v_players, array[v_idx::text], v_player);
  end loop;

  v_state := jsonb_set(v_state, '{players}', v_players);

  if v_room.game_type = 'basra' then
    select gras.deck
    into v_hand
    from public.game_room_authority_secrets gras
    where gras.room_id = p_room_id;

    if v_hand is not null then
      v_state := jsonb_set(v_state, '{deck}', v_hand);
    end if;
  end if;

  v_result := jsonb_build_object(
    'roomId', v_room.id,
    'gameType', v_room.game_type,
    'hostId', v_room.host_id,
    'status', v_room.status,
    'actionSeq', v_room.action_seq,
    'maxPlayers', v_room.max_players,
    'state', v_state
  );

  return v_result;
end;
$$;
