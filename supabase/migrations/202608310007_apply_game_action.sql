-- Phase 1 W1.1 — Trusted game action authority
-- Idempotent action log, monotonic sequence, apply_game_action commit RPC.

-- ─── Room sequence counter ───────────────────────────────────────────────────

alter table public.game_rooms
  add column if not exists action_seq bigint not null default 0;

comment on column public.game_rooms.action_seq is
  'Monotonic counter incremented on each accepted server-authoritative action.';

-- ─── Action log (idempotency + audit) ────────────────────────────────────────

create table if not exists public.game_action_log (
  room_id uuid not null references public.game_rooms (id) on delete cascade,
  action_id uuid not null,
  player_id uuid not null references auth.users (id) on delete cascade,
  action text not null,
  payload jsonb not null default '{}'::jsonb,
  seq bigint not null,
  result jsonb not null,
  created_at timestamptz not null default timezone('utc', now()),
  primary key (room_id, action_id)
);

create index if not exists idx_game_action_log_room_seq
  on public.game_action_log (room_id, seq desc);

create index if not exists idx_game_action_log_player_recent
  on public.game_action_log (room_id, player_id, created_at desc);

alter table public.game_action_log enable row level security;

drop policy if exists "Room members read action log" on public.game_action_log;
create policy "Room members read action log"
  on public.game_action_log
  for select
  to authenticated
  using (public.is_room_member(room_id));

-- Writes only through apply_game_action (SECURITY DEFINER).

-- ─── Rate limit helper ───────────────────────────────────────────────────────

create or replace function public.check_action_rate_limit(
  p_room_id uuid,
  p_player_id uuid,
  p_window_seconds int default 10,
  p_max_actions int default 40
)
returns void
language plpgsql
security definer
set search_path = public
as $$
declare
  v_count int;
begin
  select count(*)::int
  into v_count
  from public.game_action_log gal
  where gal.room_id = p_room_id
    and gal.player_id = p_player_id
    and gal.created_at > timezone('utc', now()) - make_interval(secs => p_window_seconds);

  if v_count >= p_max_actions then
    raise exception 'RATE_LIMIT_EXCEEDED';
  end if;
end;
$$;

revoke all on function public.check_action_rate_limit(uuid, uuid, int, int) from public;

-- ─── Turn legality (Estimation — defense in depth) ───────────────────────────

create or replace function public.estimation_actor_seat(
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
      select (elem ->> 'seatIndex')::int
      from jsonb_array_elements(coalesce(p_state -> 'players', '[]'::jsonb)) elem
      where elem ->> 'id' = p_actor_uid::text
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
  v_seat int := public.estimation_actor_seat(p_state, p_actor_uid);
  v_turn_seat int;
  v_auction_seat int;
begin
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
      null; -- non-state-changing or broadcast-only; allowed for any member

    else
      raise exception 'UNKNOWN_ACTION';
  end case;
end;
$$;

revoke all on function public.estimation_validate_turn(text, jsonb, uuid, jsonb, boolean) from public;

-- ─── Load full authority state (service role — reducer input) ────────────────

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

  for v_idx in 0 .. jsonb_array_length(v_players) - 1 loop
    v_player := v_players -> v_idx;
    v_player_id := (v_player ->> 'id')::uuid;

    select coalesce(pph.hand_cards, '[]'::jsonb)
    into v_hand
    from public.player_private_hands pph
    where pph.room_id = p_room_id
      and pph.player_id = v_player_id;

    if v_hand is null then
      v_hand := coalesce(v_player -> 'hand', '[]'::jsonb);
    end if;

    v_player := jsonb_set(v_player, '{hand}', v_hand);
    v_players := jsonb_set(v_players, array[v_idx::text], v_player);
  end loop;

  v_state := jsonb_set(v_state, '{players}', v_players);

  v_result := jsonb_build_object(
    'roomId', v_room.id,
    'gameType', v_room.game_type,
    'hostId', v_room.host_id,
    'status', v_room.status,
    'actionSeq', v_room.action_seq,
    'state', v_state
  );

  return v_result;
end;
$$;

revoke all on function public.get_authority_room_state(uuid) from public;
grant execute on function public.get_authority_room_state(uuid) to service_role;

-- ─── Commit accepted action (service role — called from Edge Function) ─────────

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

  -- Idempotency: return cached result for duplicate action_id.
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

  -- Turn / host validation (Estimation first; other modes stubbed in reducer).
  if v_room.game_type in ('kotchina', 'estimation') then
    perform public.estimation_validate_turn(
      p_action, p_payload, p_actor_uid, v_current_state, v_is_host
    );
  end if;

  if p_next_public_state is null then
    raise exception 'NEXT_STATE_REQUIRED';
  end if;

  v_new_seq := v_room.action_seq + 1;

  update public.game_rooms
  set
    game_state = public.sanitize_game_state_json(p_next_public_state),
    state_updated_at = timezone('utc', now()),
    action_seq = v_new_seq,
    status = case
      when (p_next_public_state ->> 'phase') = 'matchEnd' then 'finished'
      when (p_next_public_state ->> 'phase') in ('dealing', 'voidCheck', 'dashCall', 'auction', 'declarations', 'trickTaking', 'scoring')
        then 'playing'
      else status
    end
  where id = p_room_id;

  -- Persist private hand updates from reducer.
  for v_hand_key, v_hand_val in
    select key, value
    from jsonb_each(coalesce(p_hand_updates, '{}'::jsonb))
  loop
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

-- Membership check for a specific uid (service role path).
create or replace function public.is_room_member_for_uid(
  p_room_id uuid,
  p_user_id uuid
)
returns boolean
language sql
stable
security definer
set search_path = public
as $$
  select exists (
    select 1
    from public.room_players rp
    where rp.room_id = p_room_id
      and rp.player_id = p_user_id
  );
$$;

revoke all on function public.is_room_member_for_uid(uuid, uuid) from public;
grant execute on function public.is_room_member_for_uid(uuid, uuid) to service_role;
