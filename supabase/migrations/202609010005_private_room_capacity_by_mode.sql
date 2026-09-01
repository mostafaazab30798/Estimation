-- Private room capacity is mode-specific: 99 supports up to 7 players.

create or replace function public.set_private_room_max_players(
  p_room_id uuid,
  p_max_players integer
)
returns void
language plpgsql
security definer
set search_path = public
as $$
declare
  v_room public.game_rooms%rowtype;
  v_min integer;
  v_max integer;
begin
  select * into v_room
  from public.game_rooms
  where id = p_room_id;

  if not found then
    raise exception 'ROOM_NOT_FOUND';
  end if;

  if v_room.host_id <> auth.uid() then
    raise exception 'NOT_HOST';
  end if;

  if v_room.room_kind <> 'private' or v_room.status <> 'waiting' then
    return;
  end if;

  case
    when v_room.game_type in ('ninety_nine', '99') then
      v_min := 2;
      v_max := 7;
    when v_room.game_type = 'basra' then
      v_min := 2;
      v_max := 4;
    else
      -- Estimation private rooms are always four-seat.
      v_min := 4;
      v_max := 4;
  end case;

  if p_max_players < v_min or p_max_players > v_max then
    raise exception 'ROOM_INVALID_CAPACITY';
  end if;

  update public.game_rooms
  set max_players = p_max_players
  where id = p_room_id;
end;
$$;
