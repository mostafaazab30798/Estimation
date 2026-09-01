-- Restore membership / rate-limit / payload guards dropped in 202609010004.

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

revoke all on function public.apply_game_action(
  uuid, uuid, text, jsonb, uuid, bigint, jsonb, jsonb
) from public;
grant execute on function public.apply_game_action(
  uuid, uuid, text, jsonb, uuid, bigint, jsonb, jsonb
) to service_role;
