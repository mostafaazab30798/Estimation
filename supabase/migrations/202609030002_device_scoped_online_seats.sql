-- Distinguish installations signed in with the same Google account. One
-- installation owns the live seat; after it goes offline, either installation
-- may atomically claim the recoverable seat.

alter table public.room_players
  add column if not exists active_device_id text;

create index if not exists idx_room_players_active_device
  on public.room_players(player_id, active_device_id);

create or replace function public.enter_matchmaking(
  p_player_name text,
  p_game_type text,
  p_total_rounds integer,
  p_device_id text
)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  v_uid uuid := auth.uid();
  v_existing record;
  v_result jsonb;
  v_room_id uuid;
begin
  perform public.require_google_user();
  if v_uid is null then
    raise exception 'MATCHMAKING_NOT_AUTHENTICATED';
  end if;
  if nullif(trim(p_device_id), '') is null then
    raise exception 'DEVICE_ID_REQUIRED';
  end if;

  -- Serialize queue/recovery decisions for this Google account.
  perform pg_advisory_xact_lock(hashtext('online-device:' || v_uid::text));

  for v_existing in
    select gr.id
    from public.room_players rp
    join public.game_rooms gr on gr.id = rp.room_id
    where rp.player_id = v_uid and gr.status in ('waiting', 'playing')
  loop
    perform public.process_room_absences(v_existing.id);
  end loop;

  select gr.id, gr.status, rp.is_online, rp.last_seen, rp.active_device_id
  into v_existing
  from public.room_players rp
  join public.game_rooms gr on gr.id = rp.room_id
  where rp.player_id = v_uid and gr.status in ('waiting', 'playing')
  order by rp.joined_at desc
  limit 1
  for update of rp;

  if found then
    if v_existing.active_device_id is distinct from p_device_id
      and v_existing.active_device_id is not null
      and v_existing.is_online
      and v_existing.last_seen >= timezone('utc', now()) - interval '20 seconds' then
      raise exception 'ACTIVE_ON_ANOTHER_DEVICE';
    end if;

    if v_existing.status = 'playing'
      or v_existing.active_device_id is distinct from p_device_id then
      raise exception 'ONGOING_GAME_REQUIRES_RETURN';
    end if;
  end if;

  v_result := public.enter_matchmaking(
    p_player_name,
    p_game_type,
    p_total_rounds
  );
  v_room_id := (v_result ->> 'room_id')::uuid;

  update public.room_players
  set active_device_id = p_device_id,
      is_online = true,
      last_seen = timezone('utc', now())
  where room_id = v_room_id and player_id = v_uid;

  return v_result;
end;
$$;

create or replace function public.claim_room_device(
  p_room_id uuid,
  p_device_id text
)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  v_uid uuid := auth.uid();
  v_player public.room_players%rowtype;
  v_room public.game_rooms%rowtype;
  v_next_state jsonb;
begin
  if v_uid is null or nullif(trim(p_device_id), '') is null then
    return jsonb_build_object('claimed', false, 'reason', 'UNAUTHENTICATED');
  end if;

  perform pg_advisory_xact_lock(hashtext('online-device:' || v_uid::text));
  perform public.process_room_absences(p_room_id);

  select * into v_room from public.game_rooms where id = p_room_id;
  select * into v_player
  from public.room_players
  where room_id = p_room_id and player_id = v_uid
  for update;

  if not found or v_room.status not in ('waiting', 'playing') then
    return jsonb_build_object('claimed', false, 'reason', 'ROOM_UNAVAILABLE');
  end if;

  if v_player.active_device_id is distinct from p_device_id
    and v_player.active_device_id is not null
    and v_player.is_online
    and v_player.last_seen >= timezone('utc', now()) - interval '20 seconds' then
    return jsonb_build_object(
      'claimed', false,
      'reason', 'ACTIVE_ON_ANOTHER_DEVICE'
    );
  end if;

  update public.room_players
  set active_device_id = p_device_id,
      is_online = true,
      last_seen = timezone('utc', now())
  where room_id = p_room_id and player_id = v_uid;

  if v_room.status = 'playing' and v_room.game_state is not null then
    v_next_state := public.unmark_player_bot_in_game_state(
      v_room.game_state, v_uid::text, v_room.game_type
    );
    if v_next_state is distinct from v_room.game_state then
      update public.game_rooms
      set game_state = v_next_state,
          state_updated_at = timezone('utc', now())
      where id = p_room_id;
    end if;
  end if;

  return jsonb_build_object('claimed', true);
end;
$$;

create or replace function public.player_heartbeat(
  p_room_id uuid,
  p_device_id text
)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  v_uid uuid := auth.uid();
  v_result jsonb;
  v_player public.room_players%rowtype;
  v_next_state jsonb;
  v_room public.game_rooms%rowtype;
begin
  if v_uid is null or nullif(trim(p_device_id), '') is null then
    return jsonb_build_object('processed', false, 'device_conflict', false);
  end if;

  v_result := public.process_room_absences(p_room_id);
  if coalesce((v_result ->> 'terminated')::boolean, false) then
    return v_result || jsonb_build_object('device_conflict', false);
  end if;

  select * into v_player
  from public.room_players
  where room_id = p_room_id and player_id = v_uid
  for update;

  if not found then
    return v_result || jsonb_build_object(
      'device_conflict', false,
      'membership_missing', true
    );
  end if;

  if v_player.active_device_id is distinct from p_device_id
    and v_player.active_device_id is not null
    and v_player.is_online
    and v_player.last_seen >= timezone('utc', now()) - interval '20 seconds' then
    return v_result || jsonb_build_object('device_conflict', true);
  end if;

  update public.room_players
  set active_device_id = p_device_id,
      is_online = true,
      last_seen = timezone('utc', now())
  where room_id = p_room_id and player_id = v_uid;

  select * into v_room from public.game_rooms where id = p_room_id;
  if v_room.status = 'playing' and v_room.game_state is not null then
    v_next_state := public.unmark_player_bot_in_game_state(
      v_room.game_state, v_uid::text, v_room.game_type
    );
    if v_next_state is distinct from v_room.game_state then
      update public.game_rooms
      set game_state = v_next_state,
          state_updated_at = timezone('utc', now())
      where id = p_room_id;
    end if;
  end if;

  return v_result || jsonb_build_object('device_conflict', false);
end;
$$;

create or replace function public.player_go_offline(
  p_room_id uuid,
  p_device_id text
)
returns void
language plpgsql
security definer
set search_path = public
as $$
begin
  update public.room_players
  set is_online = false,
      last_seen = timezone('utc', now())
  where room_id = p_room_id
    and player_id = auth.uid()
    and active_device_id = p_device_id;
end;
$$;

create or replace function public.get_online_play_status(p_device_id text)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  v_uid uuid := auth.uid();
  v_membership record;
  v_ban timestamptz;
  v_room_id uuid;
  v_room_status text;
  v_last_seen timestamptz;
  v_is_online boolean;
  v_active_device_id text;
  v_reclaim_window interval := interval '5 minutes';
  v_grace_ends timestamptz;
  v_can_join boolean := true;
  v_has_membership boolean := false;
  v_active_elsewhere boolean := false;
  v_recovery_available boolean := false;
begin
  if v_uid is null then
    return jsonb_build_object('can_join_new_online', false);
  end if;

  update public.profiles
  set online_ban_until = null,
      updated_at = timezone('utc', now())
  where id = v_uid
    and online_ban_until is not null
    and online_ban_until <= timezone('utc', now());

  for v_membership in
    select gr.id
    from public.room_players rp
    join public.game_rooms gr on gr.id = rp.room_id
    where rp.player_id = v_uid and gr.status in ('waiting', 'playing')
  loop
    perform public.process_room_absences(v_membership.id);
  end loop;

  select online_ban_until into v_ban
  from public.profiles where id = v_uid;

  select gr.id, gr.status, rp.last_seen, rp.is_online, rp.active_device_id
  into v_room_id, v_room_status, v_last_seen, v_is_online, v_active_device_id
  from public.room_players rp
  join public.game_rooms gr on gr.id = rp.room_id
  where rp.player_id = v_uid and gr.status in ('waiting', 'playing')
  order by rp.joined_at desc
  limit 1;

  if found then
    v_has_membership := true;
    v_can_join := false;
    v_active_elsewhere := v_is_online
      and v_active_device_id is not null
      and v_active_device_id is distinct from p_device_id
      and v_last_seen >= timezone('utc', now()) - interval '20 seconds';
    v_recovery_available := not v_active_elsewhere;
    if not v_is_online
      or v_last_seen < timezone('utc', now()) - interval '20 seconds' then
      v_grace_ends := v_last_seen + v_reclaim_window;
    end if;
  end if;

  if v_ban is not null and v_ban > timezone('utc', now()) then
    v_can_join := false;
  end if;

  return jsonb_build_object(
    'can_join_new_online', v_can_join,
    'has_active_membership', v_has_membership,
    'active_on_another_device', v_active_elsewhere,
    'recovery_available', v_recovery_available,
    'online_ban_until', v_ban,
    'grace_ends_at', case
      when v_has_membership and not v_active_elsewhere then v_grace_ends
      else null
    end,
    'room_id', case when v_has_membership then v_room_id else null end,
    'room_status', case when v_has_membership then v_room_status else null end
  );
end;
$$;

revoke all on function public.enter_matchmaking(text, text, integer, text) from public;
grant execute on function public.enter_matchmaking(text, text, integer, text) to authenticated;
revoke all on function public.claim_room_device(uuid, text) from public;
grant execute on function public.claim_room_device(uuid, text) to authenticated;
revoke all on function public.player_heartbeat(uuid, text) from public;
grant execute on function public.player_heartbeat(uuid, text) to authenticated;
revoke all on function public.player_go_offline(uuid, text) from public;
grant execute on function public.player_go_offline(uuid, text) to authenticated;
revoke all on function public.get_online_play_status(text) from public;
grant execute on function public.get_online_play_status(text) to authenticated;
