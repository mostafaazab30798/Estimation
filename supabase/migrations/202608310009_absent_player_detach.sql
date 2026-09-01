-- Absent-player detach: 5-minute grace, 5-minute online ban, bot fill, abandon cleanup.

alter table public.profiles
  add column if not exists online_ban_until timestamptz;

comment on column public.profiles.online_ban_until is
  'Blocks entering new online matchmaking until this timestamp after abandoning a live game.';

-- ─── Mark a human seat as bot-controlled inside persisted game_state ─────────

create or replace function public.mark_player_bot_in_game_state(
  p_state jsonb,
  p_player_id text,
  p_game_type text
)
returns jsonb
language plpgsql
immutable
as $$
declare
  v_players jsonb;
  v_idx int;
  v_player jsonb;
begin
  if p_state is null or p_player_id is null or p_player_id = '' then
    return p_state;
  end if;

  v_players := coalesce(p_state->'players', '[]'::jsonb);
  if jsonb_typeof(v_players) <> 'array' then
    return p_state;
  end if;

  for v_idx in 0..jsonb_array_length(v_players) - 1 loop
    v_player := v_players->v_idx;
    if v_player->>'id' = p_player_id then
      if p_game_type in ('ninety_nine', 'basra') then
        v_players := jsonb_set(v_players, array[v_idx::text, 'isBot'], 'true'::jsonb);
      else
        -- Estimation / kotchina: host tracks bot IDs in a sidecar list.
        return p_state || jsonb_build_object(
          'botPlayerIds',
          case
            when coalesce(p_state->'botPlayerIds', '[]'::jsonb) @> to_jsonb(p_player_id)
              then coalesce(p_state->'botPlayerIds', '[]'::jsonb)
            else coalesce(p_state->'botPlayerIds', '[]'::jsonb) || to_jsonb(p_player_id)
          end
        );
      end if;
      exit;
    end if;
  end loop;

  return jsonb_set(p_state, '{players}', v_players);
end;
$$;

-- Detach absent humans and terminate rooms with no active humans ──────────

create or replace function public.process_room_absences(p_room_id uuid)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  v_room public.game_rooms%rowtype;
  v_player record;
  v_detached int := 0;
  v_active_humans int := 0;
  v_reclaim_window interval := interval '5 minutes';
  v_bot_delay interval := interval '30 seconds';
  v_ban interval := interval '5 minutes';
begin
  select * into v_room from public.game_rooms where id = p_room_id;
  if not found or v_room.status not in ('waiting', 'playing') then
    return jsonb_build_object('processed', false);
  end if;

  if v_room.status = 'playing' and v_room.game_state is not null then
    for v_player in
      select rp.player_id
      from public.room_players rp
      where rp.room_id = p_room_id
        and rp.last_seen < timezone('utc', now()) - v_bot_delay
    loop
      update public.game_rooms
      set game_state = public.mark_player_bot_in_game_state(
            game_state,
            v_player.player_id::text,
            v_room.game_type
          ),
          state_updated_at = timezone('utc', now())
      where id = p_room_id;
      select * into v_room from public.game_rooms where id = p_room_id;
    end loop;
  end if;

  for v_player in
    select rp.player_id, rp.last_seen
    from public.room_players rp
    where rp.room_id = p_room_id
      and rp.last_seen < timezone('utc', now()) - v_reclaim_window
  loop
    update public.profiles
    set online_ban_until = timezone('utc', now()) + v_ban,
        updated_at = timezone('utc', now())
    where id = v_player.player_id;

    delete from public.room_players
    where room_id = p_room_id
      and player_id = v_player.player_id;

    v_detached := v_detached + 1;
  end loop;

  select count(*)::int
  into v_active_humans
  from public.room_players rp
  where rp.room_id = p_room_id
    and rp.last_seen >= timezone('utc', now()) - v_reclaim_window;

  if v_active_humans = 0 then
    delete from public.game_action_log where room_id = p_room_id;

    update public.game_rooms
    set status = 'cancelled',
        matchmaking_state = 'none',
        bots_to_fill = 0,
        game_state = null,
        state_updated_at = timezone('utc', now())
    where id = p_room_id
      and status in ('waiting', 'playing');

    return jsonb_build_object(
      'detached', v_detached,
      'terminated', true,
      'active_humans', 0
    );
  end if;

  return jsonb_build_object(
    'detached', v_detached,
    'terminated', false,
    'active_humans', v_active_humans
  );
end;
$$;

revoke all on function public.process_room_absences(uuid) from public;
grant execute on function public.process_room_absences(uuid) to authenticated;

-- ─── Online-play gate status for the current user ────────────────────────────

create or replace function public.get_online_play_status()
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  v_uid uuid := auth.uid();
  v_ban timestamptz;
  v_room_id uuid;
  v_room_status text;
  v_last_seen timestamptz;
  v_reclaim_window interval := interval '5 minutes';
  v_grace_ends timestamptz;
  v_can_join boolean := true;
  v_has_membership boolean := false;
  v_result jsonb;
begin
  if v_uid is null then
    return jsonb_build_object('can_join_new_online', false);
  end if;

  select online_ban_until
  into v_ban
  from public.profiles
  where id = v_uid;

  if v_ban is not null and v_ban <= timezone('utc', now()) then
    v_ban := null;
  end if;

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
    perform public.process_room_absences(v_room_id);

    select gr.id, gr.status, rp.last_seen
    into v_room_id, v_room_status, v_last_seen
    from public.room_players rp
    join public.game_rooms gr on gr.id = rp.room_id
    where rp.player_id = v_uid
      and gr.status in ('waiting', 'playing')
    order by rp.joined_at desc
    limit 1;

    if found then
      v_grace_ends := v_last_seen + v_reclaim_window;
      if v_grace_ends > timezone('utc', now()) then
        v_can_join := false;
      else
        perform public.process_room_absences(v_room_id);
        v_has_membership := false;
        v_grace_ends := null;
      end if;
    else
      v_has_membership := false;
    end if;
  end if;

  if v_ban is not null and v_ban > timezone('utc', now()) then
    v_can_join := false;
  end if;

  v_result := jsonb_build_object(
    'can_join_new_online', v_can_join,
    'has_active_membership', v_has_membership,
    'online_ban_until', v_ban,
    'grace_ends_at', case when v_has_membership then v_grace_ends else null end,
    'room_id', case when v_has_membership then v_room_id else null end,
    'room_status', case when v_has_membership then v_room_status else null end
  );

  return v_result;
end;
$$;

revoke all on function public.get_online_play_status() from public;
grant execute on function public.get_online_play_status() to authenticated;

-- ─── Heartbeat also sweeps absences for the room ─────────────────────────────

create or replace function public.player_heartbeat(p_room_id uuid)
returns void
language plpgsql
security definer
set search_path = public
as $$
begin
  update public.room_players
  set is_online = true, last_seen = timezone('utc', now())
  where room_id = p_room_id
    and player_id = auth.uid();

  perform public.process_room_absences(p_room_id);
end;
$$;

revoke all on function public.player_heartbeat(uuid) from public;
grant execute on function public.player_heartbeat(uuid) to authenticated;
