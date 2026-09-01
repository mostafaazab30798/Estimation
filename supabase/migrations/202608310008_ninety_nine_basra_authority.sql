-- Phase 1 W1.1 — 99 / Basra turn validation + authority state fixes

-- ─── Server-only secrets (e.g. Basra deck) — not exposed via game_state ───────

create table if not exists public.game_room_authority_secrets (
  room_id uuid primary key references public.game_rooms (id) on delete cascade,
  deck jsonb,
  updated_at timestamptz not null default timezone('utc', now())
);

alter table public.game_room_authority_secrets enable row level security;
-- No policies: only SECURITY DEFINER RPCs (service role) may read/write.

-- ─── Helper: actor seat by player id in state JSON ─────────────────────────────

create or replace function public.mode_actor_index(
  p_state jsonb,
  p_actor_uid uuid
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
      where value ->> 'id' = p_actor_uid::text
      limit 1
    ),
    -1
  );
$$;

-- ─── 99 turn validation ──────────────────────────────────────────────────────

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

revoke all on function public.ninety_nine_validate_turn(text, jsonb, uuid, jsonb, boolean) from public;

-- ─── Basra turn validation ───────────────────────────────────────────────────

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

revoke all on function public.basra_validate_turn(text, jsonb, uuid, jsonb, boolean) from public;

-- ─── Authority state loader: maxPlayers + bot-safe hand merge ────────────────

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
  v_players := coalesce(v_state -> 'players', '[]'::jsonb);

  -- Waiting lobby: merge live room roster when DB snapshot is empty or stale.
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

-- ─── apply_game_action: route validation by mode; skip bot hand keys ───────────

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
  v_is_host boolean;
  v_current_state jsonb;
  v_new_seq bigint;
  v_result jsonb;
  v_hand_key text;
  v_hand_val jsonb;
  v_player_id uuid;
begin
  if auth.role() <> 'service_role' then
    raise exception 'SERVICE_ROLE_ONLY';
  end if;

  if p_action_id is null then
    raise exception 'ACTION_ID_REQUIRED';
  end if;

  if length(p_action) > 64 then
    raise exception 'ACTION_TOO_LONG';
  end if;

  if octet_length(coalesce(p_payload, '{}'::jsonb)::text) > 8192 then
    raise exception 'PAYLOAD_TOO_LARGE';
  end if;

  if not public.is_room_member_for_uid(p_room_id, p_actor_uid) then
    raise exception 'NOT_ROOM_MEMBER';
  end if;

  perform public.check_action_rate_limit(p_room_id, p_actor_uid);

  select gal.result
  into v_cached
  from public.game_action_log gal
  where gal.room_id = p_room_id
    and gal.action_id = p_action_id;

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

  -- Persist Basra deck server-side before sanitizing public snapshot.
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
    status = case
      when (p_next_public_state ->> 'phase') in ('matchEnd', 'finished') then 'finished'
      when (p_next_public_state ->> 'phase') in (
        'dealing', 'voidCheck', 'dashCall', 'auction', 'declarations',
        'trickTaking', 'scoring', 'playing', 'roundFinished'
      ) then 'playing'
      else status
    end
  where id = p_room_id;

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

revoke all on function public.apply_game_action(
  uuid, uuid, text, jsonb, uuid, bigint, jsonb, jsonb
) from public;
grant execute on function public.apply_game_action(
  uuid, uuid, text, jsonb, uuid, bigint, jsonb, jsonb
) to service_role;
