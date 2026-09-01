-- W1.1 — Host may proxy bot-seat actions via payload.playerId (server authority).

create or replace function public.is_proxy_bot_seat(
  p_state jsonb,
  p_player_id text
)
returns boolean
language sql
immutable
set search_path = public
as $$
  select
    p_player_id like 'bot\_%' escape '\'
    or coalesce(p_state -> 'botPlayerIds', '[]'::jsonb) @> to_jsonb(p_player_id)
    or exists (
      select 1
      from jsonb_array_elements(coalesce(p_state -> 'players', '[]'::jsonb)) elem
      where elem ->> 'id' = p_player_id
        and coalesce((elem ->> 'isBot')::boolean, false)
    );
$$;

create or replace function public.resolve_acting_player_id(
  p_actor_uid uuid,
  p_payload jsonb,
  p_state jsonb,
  p_is_host boolean
)
returns text
language plpgsql
immutable
set search_path = public
as $$
declare
  v_proxy text := nullif(trim(p_payload ->> 'playerId'), '');
begin
  if p_is_host
    and v_proxy is not null
    and public.is_proxy_bot_seat(p_state, v_proxy) then
    return v_proxy;
  end if;
  return p_actor_uid::text;
end;
$$;

create or replace function public.estimation_player_seat(
  p_state jsonb,
  p_player_id text
)
returns int
language sql
immutable
set search_path = public
as $$
  select coalesce(
    (
      select (elem ->> 'seatIndex')::int
      from jsonb_array_elements(coalesce(p_state -> 'players', '[]'::jsonb)) elem
      where elem ->> 'id' = p_player_id
      limit 1
    ),
    -1
  );
$$;

create or replace function public.player_index_in_state(
  p_state jsonb,
  p_player_id text
)
returns int
language sql
immutable
set search_path = public
as $$
  select coalesce(
    (
      select ordinality - 1
      from jsonb_array_elements(coalesce(p_state -> 'players', '[]'::jsonb))
        with ordinality
      where value ->> 'id' = p_player_id
      limit 1
    ),
    -1
  );
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
    raise exception 'ACTOR_NOT_IN_GAME';
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
    raise exception 'ACTOR_NOT_IN_GAME';
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
    raise exception 'ACTOR_NOT_IN_GAME';
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

revoke all on function public.is_proxy_bot_seat(jsonb, text) from public;
revoke all on function public.resolve_acting_player_id(uuid, jsonb, jsonb, boolean) from public;
revoke all on function public.estimation_player_seat(jsonb, text) from public;
revoke all on function public.player_index_in_state(jsonb, text) from public;
