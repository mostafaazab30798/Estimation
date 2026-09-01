-- W1.3 — Server-derived match XP when authority commits matchEnd / finished.

create table if not exists public.match_xp_awards (
  room_id uuid not null references public.game_rooms(id) on delete cascade,
  player_id uuid not null references public.profiles(id) on delete cascade,
  xp_gain bigint not null check (xp_gain >= 0 and xp_gain <= 10000),
  won boolean not null default false,
  rank_index int not null default 0 check (rank_index >= 0 and rank_index <= 3),
  placement_xp int not null default 0,
  win_bonus int not null default 0,
  accuracy_bonus int not null default 0,
  awarded_at timestamptz not null default timezone('utc', now()),
  primary key (room_id, player_id)
);

create index if not exists idx_match_xp_awards_player
  on public.match_xp_awards(player_id, awarded_at desc);

alter table public.match_xp_awards enable row level security;

drop policy if exists "Users read own match xp awards" on public.match_xp_awards;
create policy "Users read own match xp awards"
  on public.match_xp_awards
  for select
  to authenticated
  using (auth.uid() = player_id);

-- ─── XP calculation (mirrors client placement tiers; bonuses omitted server-side) ─

create or replace function public._estimation_placement_xp(p_rank_index int)
returns int
language sql
immutable
as $$
  select case p_rank_index
    when 0 then 100
    when 1 then 65
    when 2 then 35
    else 15
  end;
$$;

create or replace function public.award_authority_match_xp(
  p_room_id uuid,
  p_game_type text,
  p_state jsonb
)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  v_player jsonb;
  v_player_id uuid;
  v_bot_ids jsonb;
  v_rank int := 0;
  v_won boolean;
  v_placement int;
  v_win_bonus int;
  v_accuracy int;
  v_total int;
  v_awarded int := 0;
  v_players jsonb;
begin
  if auth.role() <> 'service_role' then
    raise exception 'SERVICE_ROLE_ONLY';
  end if;

  if exists (select 1 from public.match_xp_awards where room_id = p_room_id limit 1) then
    return jsonb_build_object('awarded', 0, 'idempotent', true);
  end if;

  v_players := coalesce(p_state -> 'players', '[]'::jsonb);
  if jsonb_typeof(v_players) <> 'array' or jsonb_array_length(v_players) = 0 then
    return jsonb_build_object('awarded', 0, 'reason', 'NO_PLAYERS');
  end if;

  v_bot_ids := coalesce(p_state -> 'botPlayerIds', '[]'::jsonb);

  for v_player in
    select value
    from jsonb_array_elements(v_players) as t(value)
    order by (value ->> 'totalScore')::int desc nulls last,
             (value ->> 'seatIndex')::int asc nulls last
  loop
    begin
      v_player_id := (v_player ->> 'id')::uuid;
    exception
      when others then
        continue;
    end;

    if coalesce((v_player ->> 'isBot')::boolean, false)
       or v_bot_ids @> to_jsonb(v_player ->> 'id') then
      v_rank := v_rank + 1;
      continue;
    end if;

    if not exists (select 1 from public.profiles where id = v_player_id) then
      v_rank := v_rank + 1;
      continue;
    end if;

    v_won := v_rank = 0;
    v_placement := 0;
    v_win_bonus := 0;
    v_accuracy := 0;

    if p_game_type in ('kotchina', 'estimation') then
      v_placement := public._estimation_placement_xp(v_rank);
      v_win_bonus := case when v_won then 50 else 0 end;
      if coalesce((v_player ->> 'declared')::int, -1) = coalesce((v_player ->> 'actual')::int, -2)
         and v_player ? 'declared' then
        v_accuracy := 20;
      end if;
      if coalesce((v_player ->> 'isDashCall')::boolean, false)
         and coalesce((v_player ->> 'actual')::int, -1) = 0 then
        v_accuracy := v_accuracy + 30;
      end if;
      if coalesce((v_player ->> 'totalScore')::int, 0) >= 50 then
        v_accuracy := v_accuracy + 25;
      elsif coalesce((v_player ->> 'totalScore')::int, 0) >= 30 then
        v_accuracy := v_accuracy + 15;
      end if;
    elsif p_game_type in ('ninety_nine', '99') then
      v_placement := case when v_won then 80 else 30 end;
      v_win_bonus := case when v_won then 40 else 0 end;
      v_accuracy := greatest(coalesce((p_state ->> 'roundNumber')::int, 1), 1) * 5;
    elsif p_game_type = 'basra' then
      v_placement := case when v_won then 90 else 35 end;
      v_win_bonus := case when v_won then 45 else 0 end;
      v_accuracy := greatest(coalesce((p_state ->> 'roundNumber')::int, 1), 1) * 4;
    else
      v_placement := case when v_won then 50 else 20 end;
      v_win_bonus := case when v_won then 25 else 0 end;
    end if;

    v_total := v_placement + v_win_bonus + v_accuracy;

    insert into public.match_xp_awards (
      room_id, player_id, xp_gain, won, rank_index,
      placement_xp, win_bonus, accuracy_bonus
    )
    values (
      p_room_id, v_player_id, v_total, v_won, v_rank,
      v_placement, v_win_bonus, v_accuracy
    );

    perform public.increment_player_stats(v_player_id, v_total, v_won);

    v_awarded := v_awarded + 1;
    v_rank := v_rank + 1;
  end loop;

  return jsonb_build_object('awarded', v_awarded, 'idempotent', false);
end;
$$;

revoke all on function public.award_authority_match_xp(uuid, text, jsonb) from public;
grant execute on function public.award_authority_match_xp(uuid, text, jsonb) to service_role;

create or replace function public.get_my_match_xp_award(p_room_id uuid)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  v_row public.match_xp_awards%rowtype;
begin
  if auth.uid() is null then
    raise exception 'NOT_AUTHENTICATED';
  end if;

  select *
  into v_row
  from public.match_xp_awards
  where room_id = p_room_id
    and player_id = auth.uid();

  if not found then
    return null;
  end if;

  return jsonb_build_object(
    'xp_gain', v_row.xp_gain,
    'won', v_row.won,
    'rank_index', v_row.rank_index,
    'placement_xp', v_row.placement_xp,
    'win_bonus', v_row.win_bonus,
    'accuracy_bonus', v_row.accuracy_bonus,
    'awarded_at', v_row.awarded_at
  );
end;
$$;

revoke all on function public.get_my_match_xp_award(uuid) from public;
grant execute on function public.get_my_match_xp_award(uuid) to authenticated;

-- Hook awards into authority commits.

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
