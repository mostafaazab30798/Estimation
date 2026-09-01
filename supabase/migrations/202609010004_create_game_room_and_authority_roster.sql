-- Restore create_game_room for private Basra / 99 / Estimation lobbies.
-- Harden authority roster hydration (seatIndex, matchmaking total_rounds).

create or replace function public.create_game_room(
  p_room_code varchar(6),
  p_player_name text,
  p_host_ip varchar(45),
  p_ws_port integer,
  p_game_type text default 'kotchina'
)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  v_room_id uuid;
  v_user_id uuid := auth.uid();
  v_game_type text;
begin
  perform public.require_google_user();

  if v_user_id is null then
    raise exception 'NOT_AUTHENTICATED';
  end if;

  p_room_code := upper(trim(p_room_code));
  p_player_name := left(trim(p_player_name), 40);
  v_game_type := lower(trim(coalesce(p_game_type, 'kotchina')));

  if p_room_code = '' or p_player_name = '' then
    raise exception 'ROOM_INVALID';
  end if;

  if v_game_type = '99' then
    v_game_type := 'ninety_nine';
  end if;

  if v_game_type not in ('kotchina', 'basra', 'ninety_nine') then
    raise exception 'ROOM_INVALID_GAME_TYPE';
  end if;

  delete from public.game_rooms
  where host_id = v_user_id
    and room_kind = 'private'
    and status in ('waiting', 'cancelled');

  insert into public.game_rooms (
    room_code,
    host_id,
    status,
    host_ip,
    ws_port,
    game_type,
    room_kind
  )
  values (
    p_room_code,
    v_user_id,
    'waiting',
    p_host_ip,
    p_ws_port,
    v_game_type,
    'private'
  )
  returning id into v_room_id;

  insert into public.room_players (room_id, player_id, player_name, is_host)
  values (v_room_id, v_user_id, p_player_name, true);

  return jsonb_build_object('room_id', v_room_id);
exception
  when unique_violation then
    raise exception 'ROOM_CODE_COLLISION';
end;
$$;

revoke all on function public.create_game_room(varchar, text, varchar, integer, text) from public;
grant execute on function public.create_game_room(varchar, text, varchar, integer, text) to authenticated;

-- Authority loader: seat indices + matchmaking round count for first startGame.
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
          'id', roster.player_id::text,
          'name', roster.player_name,
          'seatIndex', roster.seat_index,
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
        order by roster.seat_index
      ),
      '[]'::jsonb
    )
    into v_players
    from (
      select
        rp.player_id,
        rp.player_name,
        (row_number() over (order by rp.joined_at) - 1)::int as seat_index
      from public.room_players rp
      where rp.room_id = p_room_id
    ) roster;

    v_state := jsonb_set(v_state, '{players}', v_players);
    v_state := jsonb_set(v_state, '{hostId}', to_jsonb(v_room.host_id::text));
    if not (v_state ? 'phase') then
      v_state := jsonb_set(v_state, '{phase}', '"waiting"'::jsonb);
    end if;
    if v_room.total_rounds is not null and v_room.total_rounds > 0 then
      v_state := jsonb_set(v_state, '{totalRounds}', to_jsonb(v_room.total_rounds));
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
    'totalRounds', v_room.total_rounds,
    'state', v_state
  );

  return v_result;
end;
$$;

-- Normalize json null snapshots before turn validation on commit.
create or replace function public.apply_game_action(
  p_room_id uuid,
  p_actor_uid uuid,
  p_action text,
  p_payload jsonb default '{}'::jsonb,
  p_action_id uuid default null,
  p_expected_seq bigint default null,
  p_next_public_state jsonb default null,
  p_hand_updates jsonb default '{}'::jsonb
)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  v_room public.game_rooms%rowtype;
  v_cached jsonb;
  v_current_state jsonb;
  v_is_host boolean;
  v_new_seq bigint;
  v_result jsonb;
  v_hand_key text;
  v_hand_val jsonb;
  v_player_id uuid;
  v_new_status text;
begin
  if auth.role() <> 'service_role' then
    raise exception 'SERVICE_ROLE_ONLY';
  end if;

  select result
  into v_cached
  from public.game_action_log
  where room_id = p_room_id
    and action_id = p_action_id;

  if found then
    return v_cached || jsonb_build_object('idempotent', true);
  end if;

  select *
  into v_room
  from public.game_rooms
  where id = p_room_id
  for update;

  if not found then
    raise exception 'ROOM_NOT_FOUND';
  end if;

  v_is_host := v_room.host_id = p_actor_uid;
  v_current_state := coalesce(v_room.game_state, '{}'::jsonb);
  if v_current_state is null
    or v_current_state = 'null'::jsonb
    or jsonb_typeof(v_current_state) <> 'object' then
    v_current_state := '{}'::jsonb;
  end if;

  if p_expected_seq is not null and p_expected_seq <> v_room.action_seq then
    raise exception 'SEQ_MISMATCH';
  end if;

  if v_room.game_type in ('kotchina', 'estimation') then
    perform public.estimation_validate_turn(
      p_action, p_payload, p_actor_uid, v_current_state, v_is_host
    );
  elsif v_room.game_type in ('ninety_nine', '99') then
    perform public.ninety_nine_validate_turn(
      p_action, p_payload, p_actor_uid, v_current_state, v_is_host
    );
  elsif v_room.game_type = 'basra' then
    perform public.basra_validate_turn(
      p_action, p_payload, p_actor_uid, v_current_state, v_is_host
    );
  end if;

  if p_next_public_state is null then
    raise exception 'NEXT_STATE_REQUIRED';
  end if;

  v_new_seq := v_room.action_seq + 1;

  v_new_status := case
    when (p_next_public_state ->> 'phase') in ('matchEnd', 'finished') then 'finished'
    when (p_next_public_state ->> 'phase') in (
      'dealing', 'voidCheck', 'dashCall', 'auction', 'declarations',
      'trickTaking', 'scoring', 'playing', 'roundFinished'
    ) then 'playing'
    else v_room.status
  end;

  if p_next_public_state ? 'deck'
    and jsonb_typeof(p_next_public_state -> 'deck') = 'array' then
    insert into public.game_room_authority_secrets (room_id, deck, updated_at)
    values (p_room_id, p_next_public_state -> 'deck', timezone('utc', now()))
    on conflict (room_id) do update
      set deck = excluded.deck,
          updated_at = excluded.updated_at;
  end if;

  update public.game_rooms
  set
    game_state = public.sanitize_game_state_json(p_next_public_state),
    state_updated_at = timezone('utc', now()),
    action_seq = v_new_seq,
    status = v_new_status
  where id = p_room_id;

  if v_new_status = 'finished' and v_room.status <> 'finished' then
    perform public.award_authority_match_xp(
      p_room_id,
      v_room.game_type,
      p_next_public_state
    );
  end if;

  for v_hand_key, v_hand_val in
    select key, value
    from jsonb_each(coalesce(p_hand_updates, '{}'::jsonb))
  loop
    if v_hand_key !~ '^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$' then
      continue;
    end if;

    v_player_id := v_hand_key::uuid;

    if jsonb_typeof(v_hand_val) <> 'array' then
      raise exception 'INVALID_HAND_UPDATE';
    end if;

    insert into public.player_private_hands (room_id, player_id, hand_cards, updated_at)
    values (p_room_id, v_player_id, v_hand_val, timezone('utc', now()))
    on conflict (room_id, player_id) do update
      set hand_cards = excluded.hand_cards,
          updated_at = excluded.updated_at;
  end loop;

  v_result := jsonb_build_object(
    'ok', true,
    'seq', v_new_seq,
    'action', p_action,
    'playerId', p_actor_uid,
    'publicState', public.sanitize_game_state_json(p_next_public_state),
    'idempotent', false
  );

  insert into public.game_action_log (
    room_id, action_id, player_id, action, payload, seq, result
  )
  values (
    p_room_id, p_action_id, p_actor_uid, p_action, coalesce(p_payload, '{}'::jsonb),
    v_new_seq, v_result
  );

  return v_result;
end;
$$;
