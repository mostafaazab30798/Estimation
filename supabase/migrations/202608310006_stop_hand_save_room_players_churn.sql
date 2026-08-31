-- Hands live in player_private_hands. Updating room_players.hand_cards on every
-- save_player_hand call was firing Realtime for the whole roster, which made
-- matchmaking clients log "Population changed: 2/4" on every card play.

create or replace function public.save_player_hand(
  p_room_id uuid,
  p_player_id uuid,
  p_hand_cards jsonb
)
returns void
language plpgsql
security definer
set search_path = public
as $$
begin
  if not exists (
    select 1
    from public.game_rooms
    where id = p_room_id
      and host_id = auth.uid()
  ) then
    raise exception 'NOT_HOST';
  end if;

  if jsonb_typeof(p_hand_cards) <> 'array' then
    raise exception 'INVALID_HAND';
  end if;

  if jsonb_array_length(p_hand_cards) > 52 then
    raise exception 'HAND_TOO_LARGE';
  end if;

  insert into public.player_private_hands (room_id, player_id, hand_cards, updated_at)
  values (p_room_id, p_player_id, p_hand_cards, timezone('utc', now()))
  on conflict (room_id, player_id) do update
    set hand_cards = excluded.hand_cards,
        updated_at = excluded.updated_at;
end;
$$;

revoke all on function public.save_player_hand(uuid, uuid, jsonb) from public;
grant execute on function public.save_player_hand(uuid, uuid, jsonb) to authenticated;
