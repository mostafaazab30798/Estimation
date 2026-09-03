-- Drop ghost players from abandoned matchmaking queues before join/reuse.

create or replace function public.prune_stale_matchmaking_players(p_room_id uuid)
returns void
language plpgsql
security definer
set search_path = public
as $$
declare
  v_room public.game_rooms%rowtype;
  v_remaining integer;
begin
  select * into v_room
  from public.game_rooms
  where id = p_room_id;

  if not found
    or v_room.room_kind <> 'matchmaking'
    or v_room.status <> 'waiting' then
    return;
  end if;

  delete from public.room_players rp
  where rp.room_id = p_room_id
    and rp.is_online = false
    and rp.last_seen < timezone('utc', now()) - interval '45 seconds';

  select count(*)::integer into v_remaining
  from public.room_players
  where room_id = p_room_id;

  if v_remaining = 0 then
    update public.game_rooms
    set
      status = 'cancelled',
      matchmaking_state = 'none',
      bots_to_fill = 0,
      bot_yes_votes = 0,
      matchmaking_updated_at = timezone('utc', now())
    where id = p_room_id;
  end if;
end;
$$;

create or replace function public.prune_stale_matchmaking_queues(
  p_game_type text,
  p_total_rounds integer
)
returns void
language plpgsql
security definer
set search_path = public
as $$
begin
  delete from public.room_players rp
  using public.game_rooms gr
  where rp.room_id = gr.id
    and gr.room_kind = 'matchmaking'
    and gr.status = 'waiting'
    and gr.game_type = p_game_type
    and gr.total_rounds = p_total_rounds
    and rp.is_online = false
    and rp.last_seen < timezone('utc', now()) - interval '45 seconds';

  update public.game_rooms gr
  set
    status = 'cancelled',
    matchmaking_state = 'none',
    bots_to_fill = 0,
    bot_yes_votes = 0,
    matchmaking_updated_at = timezone('utc', now())
  where gr.room_kind = 'matchmaking'
    and gr.status = 'waiting'
    and gr.game_type = p_game_type
    and gr.total_rounds = p_total_rounds
    and (
      not exists (
        select 1
        from public.room_players rp
        where rp.room_id = gr.id
      )
      or public.matchmaking_active_human_count(gr.id) = 0
    );
end;
$$;

create or replace function public.enter_matchmaking(
  p_player_name text,
  p_game_type text,
  p_total_rounds integer
)
returns jsonb
language plpgsql
security definer
set search_path = public, extensions
as $$
declare
  v_user_id uuid := auth.uid();
  v_room public.game_rooms%rowtype;
  v_count integer;
  v_code text;
begin
  perform public.require_google_user();
  if v_user_id is null then
    raise exception 'MATCHMAKING_NOT_AUTHENTICATED';
  end if;

  p_player_name := left(trim(p_player_name), 40);
  if p_player_name = '' or p_game_type <> 'kotchina' or p_total_rounds <= 0 then
    raise exception 'MATCHMAKING_ROOM_INVALID';
  end if;

  perform pg_advisory_xact_lock(hashtext('matchmaking:' || p_game_type || ':' || p_total_rounds));
  perform public.prune_stale_matchmaking_queues(p_game_type, p_total_rounds);

  select gr.* into v_room
  from public.game_rooms gr
  join public.room_players rp on rp.room_id = gr.id
  where rp.player_id = v_user_id
    and gr.room_kind = 'matchmaking'
    and gr.status = 'waiting'
    and gr.game_type = p_game_type
    and gr.total_rounds = p_total_rounds
  order by gr.created_at desc
  limit 1
  for update of gr;

  if found then
    perform public.prune_stale_matchmaking_players(v_room.id);
    select * into v_room from public.game_rooms where id = v_room.id;

    if v_room.status = 'waiting' then
      update public.room_players
      set
        player_name = p_player_name,
        is_online = true,
        last_seen = timezone('utc', now())
      where room_id = v_room.id
        and player_id = v_user_id;

      if public.matchmaking_active_human_count(v_room.id) <= 1 then
        delete from public.matchmaking_bot_votes where room_id = v_room.id;
        update public.game_rooms
        set
          matchmaking_state = 'waiting',
          bots_to_fill = 0,
          bot_yes_votes = 0,
          bot_offer_version = bot_offer_version + 1,
          bot_offer_after = timezone('utc', now()) + interval '8 seconds',
          matchmaking_starting_at = null,
          matchmaking_updated_at = timezone('utc', now())
        where id = v_room.id
        returning * into v_room;
      end if;

      select public.matchmaking_active_human_count(v_room.id) into v_count;
      return jsonb_build_object(
        'room_id', v_room.id,
        'room_code', v_room.room_code,
        'host_id', v_room.host_id,
        'is_host', v_room.host_id = v_user_id,
        'player_count', v_count,
        'matchmaking_state', v_room.matchmaking_state,
        'bots_to_fill', v_room.bots_to_fill,
        'bot_offer_version', v_room.bot_offer_version
      );
    end if;
  end if;

  delete from public.room_players rp
  using public.game_rooms gr
  where rp.room_id = gr.id
    and rp.player_id = v_user_id
    and gr.room_kind = 'matchmaking'
    and gr.status = 'waiting';

  select gr.* into v_room
  from public.game_rooms gr
  where gr.room_kind = 'matchmaking'
    and gr.game_type = p_game_type
    and gr.total_rounds = p_total_rounds
    and gr.status = 'waiting'
    and gr.matchmaking_state in ('waiting', 'voting')
    and public.matchmaking_active_human_count(gr.id) < 4
    and public.matchmaking_active_human_count(gr.id) > 0
  order by gr.matchmaking_updated_at desc, gr.created_at desc
  limit 1
  for update skip locked;

  if not found then
    loop
      v_code := upper(substr(encode(extensions.gen_random_bytes(6), 'hex'), 1, 6));
      begin
        insert into public.game_rooms (
          room_code, host_id, status, max_players, host_ip, ws_port, game_type,
          room_kind, matchmaking_state, total_rounds, bot_offer_after,
          matchmaking_updated_at
        )
        values (
          v_code, v_user_id, 'waiting', 4, '127.0.0.1', 0, p_game_type,
          'matchmaking', 'waiting', p_total_rounds,
          timezone('utc', now()) + interval '8 seconds',
          timezone('utc', now())
        )
        returning * into v_room;
        exit;
      exception when unique_violation then
        null;
      end;
    end loop;

    insert into public.room_players (room_id, player_id, player_name, is_host)
    values (v_room.id, v_user_id, p_player_name, true);
  else
    perform public.prune_stale_matchmaking_players(v_room.id);
    select * into v_room from public.game_rooms where id = v_room.id;
    if v_room.status <> 'waiting' then
      raise exception 'MATCHMAKING_ROOM_INVALID';
    end if;

    insert into public.room_players (room_id, player_id, player_name, is_host)
    values (v_room.id, v_user_id, p_player_name, false)
    on conflict (room_id, player_id) do update
      set
        player_name = excluded.player_name,
        is_online = true,
        last_seen = timezone('utc', now());

    delete from public.matchmaking_bot_votes where room_id = v_room.id;
    update public.game_rooms
    set
      matchmaking_state = 'waiting',
      bots_to_fill = 0,
      bot_yes_votes = 0,
      bot_offer_version = bot_offer_version + 1,
      bot_offer_after = timezone('utc', now()) + interval '8 seconds',
      matchmaking_updated_at = timezone('utc', now())
    where id = v_room.id
    returning * into v_room;
  end if;

  select public.matchmaking_active_human_count(v_room.id) into v_count;
  if v_count = 4 then
    delete from public.matchmaking_bot_votes where room_id = v_room.id;
    update public.game_rooms
    set
      matchmaking_state = 'starting',
      bots_to_fill = 0,
      bot_yes_votes = 0,
      bot_offer_version = bot_offer_version + 1,
      matchmaking_starting_at = timezone('utc', now()),
      matchmaking_updated_at = timezone('utc', now())
    where id = v_room.id
    returning * into v_room;
  end if;

  return jsonb_build_object(
    'room_id', v_room.id,
    'room_code', v_room.room_code,
    'host_id', v_room.host_id,
    'is_host', v_room.host_id = v_user_id,
    'player_count', v_count,
    'matchmaking_state', v_room.matchmaking_state,
    'bots_to_fill', v_room.bots_to_fill,
    'bot_offer_version', v_room.bot_offer_version
  );
end;
$$;

create or replace function public.leave_matchmaking(p_room_id uuid)
returns void
language plpgsql
security definer
set search_path = public
as $$
declare
  v_room public.game_rooms%rowtype;
  v_new_host uuid;
  v_count integer;
begin
  select * into v_room
  from public.game_rooms
  where id = p_room_id
  for update;

  if not found or v_room.room_kind <> 'matchmaking' then
    return;
  end if;

  if not exists (
    select 1
    from public.room_players
    where room_id = p_room_id
      and player_id = auth.uid()
  ) then
    return;
  end if;

  delete from public.matchmaking_bot_votes
  where room_id = p_room_id
    and player_id = auth.uid();

  delete from public.room_players
  where room_id = p_room_id
    and player_id = auth.uid();

  perform public.prune_stale_matchmaking_players(p_room_id);

  select count(*)::integer into v_count
  from public.room_players
  where room_id = p_room_id;

  if v_count = 0 then
    update public.game_rooms
    set
      status = 'cancelled',
      matchmaking_state = 'none',
      bots_to_fill = 0,
      bot_yes_votes = 0,
      matchmaking_updated_at = timezone('utc', now())
    where id = p_room_id;
    return;
  end if;

  select * into v_room from public.game_rooms where id = p_room_id;

  if v_room.host_id = auth.uid() then
    select player_id into v_new_host
    from public.room_players
    where room_id = p_room_id
    order by joined_at
    limit 1;

    update public.room_players
    set is_host = (player_id = v_new_host)
    where room_id = p_room_id;
  else
    v_new_host := v_room.host_id;
  end if;

  delete from public.matchmaking_bot_votes where room_id = p_room_id;
  update public.game_rooms
  set
    host_id = v_new_host,
    matchmaking_state = 'waiting',
    bots_to_fill = 0,
    bot_yes_votes = 0,
    bot_offer_version = bot_offer_version + 1,
    bot_offer_after = timezone('utc', now()) + interval '8 seconds',
    matchmaking_starting_at = null,
    matchmaking_updated_at = timezone('utc', now())
  where id = p_room_id
    and status = 'waiting';
end;
$$;

revoke all on function public.prune_stale_matchmaking_players(uuid) from public;
grant execute on function public.prune_stale_matchmaking_players(uuid) to service_role;

revoke all on function public.prune_stale_matchmaking_queues(text, integer) from public;
grant execute on function public.prune_stale_matchmaking_queues(text, integer) to service_role;
