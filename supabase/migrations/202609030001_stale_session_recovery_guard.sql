-- Prevent a cached client session from reviving an abandoned game.
-- An Estimation match is never recoverable overnight, regardless of a late
-- heartbeat from an old client build.

create or replace function public.process_room_absences(p_room_id uuid)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  v_room public.game_rooms%rowtype;
  v_player record;
  v_next_state jsonb;
  v_detached int := 0;
  v_bot_takeovers int := 0;
  v_active_humans int := 0;
  v_reclaim_window interval := interval '5 minutes';
  v_bot_delay interval := interval '30 seconds';
  v_max_match_age interval := interval '6 hours';
  v_ban interval := interval '5 minutes';
  v_fresh_absence_cutoff timestamptz;
begin
  select * into v_room
  from public.game_rooms
  where id = p_room_id
  for update;

  if not found or v_room.status not in ('waiting', 'playing') then
    return jsonb_build_object('processed', false, 'bot_takeovers', 0);
  end if;

  -- Absolute safety boundary: activity timestamps may be refreshed by a stale
  -- client, but the immutable match start/creation time cannot be revived.
  if v_room.status = 'playing'
    and coalesce(v_room.started_at, v_room.created_at)
      < timezone('utc', now()) - v_max_match_age then
    select count(*)::int into v_detached
    from public.room_players
    where room_id = p_room_id;

    -- Preserve the final snapshot, action history and membership rows for
    -- diagnostics. A cancelled room is excluded from the online-play gate, so
    -- cancelling alone safely releases every account that belonged to it.
    update public.game_rooms
    set status = 'cancelled',
        matchmaking_state = 'none',
        bots_to_fill = 0,
        bot_yes_votes = 0,
        state_updated_at = timezone('utc', now())
    where id = p_room_id;

    return jsonb_build_object(
      'detached', v_detached,
      'bot_takeovers', 0,
      'terminated', true,
      'expired', true,
      'active_humans', 0
    );
  end if;

  v_fresh_absence_cutoff := timezone('utc', now())
    - v_reclaim_window - interval '90 seconds';

  if v_room.status = 'playing' and v_room.game_state is not null then
    for v_player in
      select rp.player_id
      from public.room_players rp
      where rp.room_id = p_room_id
        and rp.last_seen <= timezone('utc', now()) - v_bot_delay
    loop
      v_next_state := public.mark_player_bot_in_game_state(
        v_room.game_state,
        v_player.player_id::text,
        v_room.game_type
      );

      if v_next_state is distinct from v_room.game_state then
        update public.game_rooms
        set game_state = v_next_state,
            state_updated_at = timezone('utc', now())
        where id = p_room_id;
        v_room.game_state := v_next_state;
        v_bot_takeovers := v_bot_takeovers + 1;
      end if;
    end loop;
  end if;

  for v_player in
    select rp.player_id, rp.last_seen
    from public.room_players rp
    where rp.room_id = p_room_id
      and rp.last_seen < timezone('utc', now()) - v_reclaim_window
  loop
    if v_player.last_seen > v_fresh_absence_cutoff then
      update public.profiles
      set online_ban_until = timezone('utc', now()) + v_ban,
          updated_at = timezone('utc', now())
      where id = v_player.player_id;
    end if;

    delete from public.room_players
    where room_id = p_room_id
      and player_id = v_player.player_id;
    v_detached := v_detached + 1;
  end loop;

  select count(*)::int into v_active_humans
  from public.room_players rp
  where rp.room_id = p_room_id
    and rp.last_seen >= timezone('utc', now()) - v_reclaim_window;

  if v_active_humans = 0 then
    update public.game_rooms
    set status = 'cancelled',
        matchmaking_state = 'none',
        bots_to_fill = 0,
        bot_yes_votes = 0,
        state_updated_at = timezone('utc', now())
    where id = p_room_id and status in ('waiting', 'playing');

    return jsonb_build_object(
      'detached', v_detached,
      'bot_takeovers', v_bot_takeovers,
      'terminated', true,
      'expired', false,
      'active_humans', 0
    );
  end if;

  return jsonb_build_object(
    'detached', v_detached,
    'bot_takeovers', v_bot_takeovers,
    'terminated', false,
    'expired', false,
    'active_humans', v_active_humans
  );
end;
$$;

drop function if exists public.player_heartbeat(uuid);
create function public.player_heartbeat(p_room_id uuid)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  v_uid uuid := auth.uid();
  v_result jsonb;
begin
  if v_uid is null then
    return jsonb_build_object('processed', false, 'bot_takeovers', 0);
  end if;

  -- Cleanup first. This prevents heartbeat from refreshing a seat whose
  -- reclaim window (or entire match lifetime) has already expired.
  v_result := public.process_room_absences(p_room_id);
  if coalesce((v_result ->> 'terminated')::boolean, false) then
    return v_result;
  end if;

  update public.room_players
  set is_online = true,
      last_seen = timezone('utc', now())
  where room_id = p_room_id
    and player_id = v_uid;

  update public.game_rooms gr
  set game_state = public.unmark_player_bot_in_game_state(
        gr.game_state,
        v_uid::text,
        gr.game_type
      ),
      state_updated_at = timezone('utc', now())
  where gr.id = p_room_id
    and gr.status = 'playing'
    and gr.game_state is not null
    and exists (
      select 1 from public.room_players rp
      where rp.room_id = gr.id and rp.player_id = v_uid
    )
    and public.unmark_player_bot_in_game_state(
          gr.game_state, v_uid::text, gr.game_type
        ) is distinct from gr.game_state;

  return coalesce(v_result, jsonb_build_object('bot_takeovers', 0));
end;
$$;

create or replace function public.get_online_play_status()
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
  v_reclaim_window interval := interval '5 minutes';
  v_grace_ends timestamptz;
  v_can_join boolean := true;
  v_has_membership boolean := false;
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

  -- Clean every active membership, not merely the newest one. This also
  -- repairs accounts left in multiple rooms by interrupted older builds.
  for v_membership in
    select gr.id
    from public.room_players rp
    join public.game_rooms gr on gr.id = rp.room_id
    where rp.player_id = v_uid
      and gr.status in ('waiting', 'playing')
  loop
    perform public.process_room_absences(v_membership.id);
  end loop;

  select online_ban_until into v_ban
  from public.profiles
  where id = v_uid;

  select gr.id, gr.status, rp.last_seen
  into v_room_id, v_room_status, v_last_seen
  from public.room_players rp
  join public.game_rooms gr on gr.id = rp.room_id
  where rp.player_id = v_uid
    and gr.status in ('waiting', 'playing')
  order by rp.joined_at desc
  limit 1;

  if found then
    v_has_membership := true;
    v_grace_ends := v_last_seen + v_reclaim_window;
    v_can_join := false;
  end if;

  if v_ban is not null and v_ban > timezone('utc', now()) then
    v_can_join := false;
  end if;

  return jsonb_build_object(
    'can_join_new_online', v_can_join,
    'has_active_membership', v_has_membership,
    'online_ban_until', v_ban,
    'grace_ends_at', case when v_has_membership then v_grace_ends else null end,
    'room_id', case when v_has_membership then v_room_id else null end,
    'room_status', case when v_has_membership then v_room_status else null end
  );
end;
$$;

revoke all on function public.process_room_absences(uuid) from public;
grant execute on function public.process_room_absences(uuid) to authenticated;
revoke all on function public.player_heartbeat(uuid) from public;
grant execute on function public.player_heartbeat(uuid) to authenticated;
revoke all on function public.get_online_play_status() from public;
grant execute on function public.get_online_play_status() to authenticated;
