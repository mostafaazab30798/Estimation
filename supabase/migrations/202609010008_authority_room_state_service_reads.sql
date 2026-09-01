-- get_authority_room_state must read room_players as service_role without RLS
-- filtering, and must hydrate roster when game_state is still SQL NULL.

create or replace function public.get_authority_room_state(p_room_id uuid)
returns jsonb
language plpgsql
security definer
set search_path = public
set row_security = off
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
  v_needs_roster boolean := false;
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

  if v_room.game_state is null
    or v_room.game_state = 'null'::jsonb then
    v_state := '{}'::jsonb;
    v_players := '[]'::jsonb;
    v_needs_roster := true;
  else
    v_state := v_room.game_state;
    if jsonb_typeof(v_state) <> 'object' then
      v_state := '{}'::jsonb;
    end if;

    v_players := v_state -> 'players';
    if v_players is null
      or jsonb_typeof(v_players) <> 'array'
      or coalesce(jsonb_array_length(v_players), 0) = 0 then
      v_needs_roster := true;
    elsif coalesce(v_state ->> 'phase', 'waiting') in ('waiting', 'lobby') then
      v_needs_roster := true;
    elsif exists (
      select 1
      from jsonb_array_elements(v_players) elem
      where not (elem ? 'seatIndex')
    ) then
      v_needs_roster := true;
    end if;
  end if;

  if v_needs_roster then
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

  v_players := coalesce(v_players, '[]'::jsonb);

  for v_idx in 0 .. coalesce(jsonb_array_length(v_players), 0) - 1 loop
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

revoke all on function public.get_authority_room_state(uuid) from public;
grant execute on function public.get_authority_room_state(uuid) to service_role;
