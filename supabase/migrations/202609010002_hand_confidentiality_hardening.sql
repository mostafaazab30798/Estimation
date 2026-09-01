-- W1.2 — Defense-in-depth: always persist sanitized public snapshots;
-- member RPC for reading room state (never raw opponent hands).

-- Sanitize game_state on any direct row write (not only via save_game_state RPC).
create or replace function public.enforce_sanitized_game_state()
returns trigger
language plpgsql
set search_path = public
as $$
begin
  if new.game_state is not null then
    new.game_state := public.sanitize_game_state_json(new.game_state);
  end if;
  return new;
end;
$$;

drop trigger if exists trg_game_rooms_sanitize_state on public.game_rooms;
create trigger trg_game_rooms_sanitize_state
before insert or update of game_state on public.game_rooms
for each row execute function public.enforce_sanitized_game_state();

-- Member-only public snapshot (hands masked, deck stripped for Basra).
create or replace function public.get_room_public_state(p_room_id uuid)
returns jsonb
language plpgsql
stable
security definer
set search_path = public
as $$
declare
  v_state jsonb;
begin
  if not public.is_room_member(p_room_id) then
    raise exception 'NOT_ROOM_MEMBER';
  end if;

  select game_state into v_state
  from public.game_rooms
  where id = p_room_id;

  if v_state is null then
    return null;
  end if;

  return public.sanitize_game_state_json(v_state);
end;
$$;

revoke all on function public.get_room_public_state(uuid) from public;
grant execute on function public.get_room_public_state(uuid) to authenticated;
