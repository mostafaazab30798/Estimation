-- Return a room snapshot with only the authenticated member's real hand.
-- The persisted room state remains sanitized; this is an owner-specific view.
create or replace function public.get_my_game_state(p_room_id uuid)
returns jsonb
language plpgsql
stable
security definer
set search_path = public
as $$
declare
  v_state jsonb;
  v_hand jsonb;
  v_seq bigint;
  v_status text;
  v_players jsonb;
begin
  if auth.uid() is null then
    raise exception 'NOT_AUTHENTICATED';
  end if;

  if not public.is_room_member(p_room_id) then
    raise exception 'NOT_ROOM_MEMBER';
  end if;

  select game_state, action_seq, status::text
  into v_state, v_seq, v_status
  from public.game_rooms
  where id = p_room_id;

  if v_state is null then
    return null;
  end if;

  select coalesce(hand_cards, '[]'::jsonb)
  into v_hand
  from public.player_private_hands
  where room_id = p_room_id
    and player_id = auth.uid();

  v_hand := coalesce(v_hand, '[]'::jsonb);

  select coalesce(
    jsonb_agg(
      case
        when player ->> 'id' = auth.uid()::text
          then jsonb_set(player, '{hand}', v_hand, true)
        else player
      end
      order by ordinal
    ),
    '[]'::jsonb
  )
  into v_players
  from jsonb_array_elements(coalesce(v_state -> 'players', '[]'::jsonb))
       with ordinality as entries(player, ordinal);

  v_state := jsonb_set(v_state, '{players}', v_players, true);

  return jsonb_build_object(
    'state', v_state,
    'actionSeq', coalesce(v_seq, 0),
    'status', v_status
  );
end;
$$;

revoke all on function public.get_my_game_state(uuid) from public;
grant execute on function public.get_my_game_state(uuid) to authenticated;
