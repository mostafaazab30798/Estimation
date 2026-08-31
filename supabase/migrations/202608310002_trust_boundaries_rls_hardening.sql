-- Phase 1 W1.4 / W1.2 / W1.3 — Trust boundary foundations
-- Member-scoped reads, owner-only private hands, hardened definer RPCs,
-- server-side sanitization of persisted game snapshots.

-- ─── Helpers ─────────────────────────────────────────────────────────────────

create or replace function public.is_room_member(p_room_id uuid)
returns boolean
language sql
stable
security definer
set search_path = public
as $$
  select exists (
    select 1
    from public.room_players rp
    where rp.room_id = p_room_id
      and rp.player_id = auth.uid()
  );
$$;

revoke all on function public.is_room_member(uuid) from public;
grant execute on function public.is_room_member(uuid) to authenticated;

-- Strip real card faces from a GameState JSON snapshot before persistence/broadcast storage.
create or replace function public.sanitize_game_state_json(p_state jsonb)
returns jsonb
language plpgsql
immutable
set search_path = public
as $$
declare
  result jsonb := coalesce(p_state, '{}'::jsonb);
  players jsonb;
  sanitized_players jsonb := '[]'::jsonb;
  player jsonb;
  hand jsonb;
  masked_hand jsonb;
  idx int;
  hand_len int;
begin
  players := result -> 'players';
  if players is null or jsonb_typeof(players) <> 'array' then
    -- Basra may store deck at top level — never persist the full deck.
    if result ? 'deck' then
      result := result - 'deck';
      if not (result ? 'deckCount') then
        result := jsonb_set(
          result,
          '{deckCount}',
          to_jsonb(coalesce(jsonb_array_length(p_state -> 'deck'), 0))
        );
      end if;
    end if;
    return result;
  end if;

  for idx in 0 .. jsonb_array_length(players) - 1 loop
    player := players -> idx;
    hand := player -> 'hand';
    if hand is not null and jsonb_typeof(hand) = 'array' then
      hand_len := jsonb_array_length(hand);
      select coalesce(
        jsonb_agg(jsonb_build_object('suit', 'spade', 'rank', 'two')),
        '[]'::jsonb
      )
      into masked_hand
      from generate_series(1, hand_len);
      player := jsonb_set(player, '{hand}', masked_hand);
    end if;
    sanitized_players := sanitized_players || jsonb_build_array(player);
  end loop;

  result := jsonb_set(result, '{players}', sanitized_players);
  if result ? 'deck' then
    result := result - 'deck';
    if not (result ? 'deckCount') then
      result := jsonb_set(
        result,
        '{deckCount}',
        to_jsonb(coalesce(jsonb_array_length(p_state -> 'deck'), 0))
      );
    end if;
  end if;
  return result;
end;
$$;

revoke all on function public.sanitize_game_state_json(jsonb) from public;
grant execute on function public.sanitize_game_state_json(jsonb) to authenticated;

-- ─── Owner-only private hands (separate from room_players) ───────────────────

create table if not exists public.player_private_hands (
  room_id uuid not null references public.game_rooms (id) on delete cascade,
  player_id uuid not null references auth.users (id) on delete cascade,
  hand_cards jsonb not null default '[]'::jsonb,
  updated_at timestamptz not null default timezone('utc', now()),
  primary key (room_id, player_id)
);

alter table public.player_private_hands enable row level security;

drop policy if exists "Owners read own private hand" on public.player_private_hands;
create policy "Owners read own private hand"
  on public.player_private_hands
  for select
  to authenticated
  using (auth.uid() = player_id);

drop policy if exists "Owners delete own private hand" on public.player_private_hands;
create policy "Owners delete own private hand"
  on public.player_private_hands
  for delete
  to authenticated
  using (auth.uid() = player_id);

-- Writes only through SECURITY DEFINER RPCs (host saves opponent hands).

-- Migrate any existing hand_cards rows off room_players.
insert into public.player_private_hands (room_id, player_id, hand_cards, updated_at)
select rp.room_id, rp.player_id, coalesce(rp.hand_cards, '[]'::jsonb), now()
from public.room_players rp
where rp.hand_cards is not null
on conflict (room_id, player_id) do update
  set hand_cards = excluded.hand_cards,
      updated_at = excluded.updated_at;

-- Public room roster view (no hand_cards column).
create or replace view public.room_players_public
with (security_invoker = true) as
select
  id,
  room_id,
  player_id,
  player_name,
  is_host,
  joined_at,
  is_online,
  last_seen
from public.room_players;

grant select on public.room_players_public to authenticated;

-- ─── game_rooms RLS ──────────────────────────────────────────────────────────

drop policy if exists "Anyone can read game rooms" on public.game_rooms;
drop policy if exists "Room members can read game rooms" on public.game_rooms;
create policy "Room members can read game rooms"
  on public.game_rooms
  for select
  to authenticated
  using (public.is_room_member(id));

-- ─── room_players RLS ────────────────────────────────────────────────────────

drop policy if exists "Anyone can read room players" on public.room_players;
drop policy if exists "Anyone can view room_players" on public.room_players;
drop policy if exists "Players can view room players" on public.room_players;
drop policy if exists "Room members can read room players" on public.room_players;

create policy "Room members can read room players"
  on public.room_players
  for select
  to authenticated
  using (public.is_room_member(room_id));

-- Block direct hand_cards reads even for members (owner-only table holds secrets).
revoke select (hand_cards) on public.room_players from authenticated;
revoke select (hand_cards) on public.room_players from anon;

-- ─── game_history RLS ────────────────────────────────────────────────────────

drop policy if exists "Users can read game history" on public.game_history;
create policy "Users can read own game history"
  on public.game_history
  for select
  to authenticated
  using (auth.uid() = user_id);

-- ─── Profile competitive fields: server-only writes ───────────────────────

create or replace function public.prevent_competitive_profile_self_update()
returns trigger
language plpgsql
set search_path = public
as $$
begin
  if auth.uid() = new.id then
    if new.xp is distinct from old.xp
      or new.level is distinct from old.level
      or new.games_played is distinct from old.games_played
      or new.games_won is distinct from old.games_won then
      raise exception 'COMPETITIVE_FIELDS_READ_ONLY';
    end if;
  end if;
  return new;
end;
$$;

drop trigger if exists profiles_prevent_competitive_self_update on public.profiles;
create trigger profiles_prevent_competitive_self_update
  before update on public.profiles
  for each row execute function public.prevent_competitive_profile_self_update();

-- ─── Harden increment_player_stats (W1.3 partial) ────────────────────────────

create or replace function public.increment_player_stats(
  player_id uuid,
  xp_gain bigint default 0,
  won boolean default false
)
returns void
language plpgsql
security definer
set search_path = public
as $$
begin
  if auth.role() <> 'service_role' then
    raise exception 'SERVICE_ROLE_ONLY';
  end if;

  if xp_gain < 0 or xp_gain > 10000 then
    raise exception 'XP_GAIN_OUT_OF_BOUNDS';
  end if;

  update public.profiles
  set
    xp = xp + xp_gain,
    games_played = games_played + 1,
    games_won = case when won then games_won + 1 else games_won end,
    level = 1 + floor(sqrt((xp + xp_gain) / 100.0))::int,
    updated_at = timezone('utc', now())
  where id = player_id;
end;
$$;

revoke all on function public.increment_player_stats(uuid, bigint, boolean) from public;
revoke execute on function public.increment_player_stats(uuid, bigint, boolean) from authenticated;
revoke execute on function public.increment_player_stats(uuid, bigint, boolean) from anon;
grant execute on function public.increment_player_stats(uuid, bigint, boolean) to service_role;

-- ─── Harden hand + snapshot RPCs ───────────────────────────────────────────

create or replace function public.get_my_hand_cards(p_room_id uuid)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  v_cards jsonb;
begin
  if auth.uid() is null then
    raise exception 'NOT_AUTHENTICATED';
  end if;

  if not public.is_room_member(p_room_id) then
    raise exception 'NOT_ROOM_MEMBER';
  end if;

  select hand_cards
  into v_cards
  from public.player_private_hands
  where room_id = p_room_id
    and player_id = auth.uid();

  return coalesce(v_cards, '[]'::jsonb);
end;
$$;

revoke all on function public.get_my_hand_cards(uuid) from public;
grant execute on function public.get_my_hand_cards(uuid) to authenticated;

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

  -- Legacy column: keep masked length only for debugging/migration, not real cards.
  update public.room_players
  set hand_cards = (
    select coalesce(
      jsonb_agg(jsonb_build_object('suit', 'spade', 'rank', 'two')),
      '[]'::jsonb
    )
    from generate_series(1, jsonb_array_length(p_hand_cards))
  )
  where room_id = p_room_id
    and player_id = p_player_id;
end;
$$;

revoke all on function public.save_player_hand(uuid, uuid, jsonb) from public;
grant execute on function public.save_player_hand(uuid, uuid, jsonb) to authenticated;

create or replace function public.save_game_state(
  p_room_id uuid,
  p_state jsonb
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

  update public.game_rooms
  set
    game_state = public.sanitize_game_state_json(p_state),
    state_updated_at = timezone('utc', now())
  where id = p_room_id;
end;
$$;

revoke all on function public.save_game_state(uuid, jsonb) from public;
grant execute on function public.save_game_state(uuid, jsonb) to authenticated;

-- Host promotion / reconnection: host may load all private hands to resume authority.
create or replace function public.get_room_private_hands_for_host(p_room_id uuid)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  result jsonb;
begin
  if not exists (
    select 1
    from public.game_rooms
    where id = p_room_id
      and host_id = auth.uid()
  ) then
    raise exception 'NOT_HOST';
  end if;

  select coalesce(
    jsonb_object_agg(player_id::text, hand_cards),
    '{}'::jsonb
  )
  into result
  from public.player_private_hands
  where room_id = p_room_id;

  return result;
end;
$$;

revoke all on function public.get_room_private_hands_for_host(uuid) from public;
grant execute on function public.get_room_private_hands_for_host(uuid) to authenticated;

-- Pin search_path on existing definer RPCs used by the app.
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
end;
$$;

create or replace function public.player_go_offline(p_room_id uuid)
returns void
language plpgsql
security definer
set search_path = public
as $$
begin
  update public.room_players
  set is_online = false, last_seen = timezone('utc', now())
  where room_id = p_room_id
    and player_id = auth.uid();
end;
$$;

revoke all on function public.player_heartbeat(uuid) from public;
grant execute on function public.player_heartbeat(uuid) to authenticated;

revoke all on function public.player_go_offline(uuid) from public;
grant execute on function public.player_go_offline(uuid) to authenticated;
