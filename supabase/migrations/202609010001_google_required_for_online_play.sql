-- Online create / join / matchmaking requires a registered (Google) account.
-- Anonymous and signed-out callers are rejected. Service-role / SQL jobs
-- with no JWT user are left unchanged so tests and backend jobs keep working.

create or replace function public.require_google_user()
returns void
language plpgsql
stable
security definer
set search_path = public, auth
as $$
declare
  v_uid uuid := auth.uid();
begin
  if v_uid is null then
    raise exception 'GOOGLE_LOGIN_REQUIRED';
  end if;
  if exists (
    select 1
    from auth.users
    where id = v_uid
      and coalesce(is_anonymous, false)
  ) then
    raise exception 'GOOGLE_LOGIN_REQUIRED';
  end if;
end;
$$;

revoke all on function public.require_google_user() from public;
grant execute on function public.require_google_user() to authenticated;

create or replace function public.enforce_google_online_play()
returns trigger
language plpgsql
security definer
set search_path = public, auth
as $$
begin
  -- No JWT: service role, migrations, and pgTAP fixtures.
  if auth.uid() is null then
    return new;
  end if;
  perform public.require_google_user();
  return new;
end;
$$;

drop trigger if exists trg_game_rooms_require_google on public.game_rooms;
create trigger trg_game_rooms_require_google
before insert on public.game_rooms
for each row execute function public.enforce_google_online_play();

drop trigger if exists trg_room_players_require_google on public.room_players;
create trigger trg_room_players_require_google
before insert on public.room_players
for each row execute function public.enforce_google_online_play();

-- Reject anonymous callers before reuse/join short-circuits that skip INSERT.
CREATE OR REPLACE FUNCTION public.enter_matchmaking(
  p_player_name TEXT,
  p_game_type TEXT,
  p_total_rounds INTEGER
) RETURNS JSONB
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, extensions AS $$
DECLARE
  v_user_id UUID := auth.uid();
  v_room public.game_rooms%ROWTYPE;
  v_count INTEGER;
  v_code TEXT;
BEGIN
  PERFORM public.require_google_user();
  IF v_user_id IS NULL THEN RAISE EXCEPTION 'MATCHMAKING_NOT_AUTHENTICATED'; END IF;
  p_player_name := left(trim(p_player_name), 40);
  IF p_player_name = '' OR p_game_type <> 'kotchina' OR p_total_rounds <= 0 THEN
    RAISE EXCEPTION 'MATCHMAKING_ROOM_INVALID';
  END IF;

  PERFORM pg_advisory_xact_lock(hashtext('matchmaking:' || p_game_type || ':' || p_total_rounds));

  SELECT gr.* INTO v_room
  FROM public.game_rooms gr JOIN public.room_players rp ON rp.room_id = gr.id
  WHERE rp.player_id = v_user_id AND gr.room_kind = 'matchmaking'
    AND gr.status = 'waiting' AND gr.game_type = p_game_type
    AND gr.total_rounds = p_total_rounds
  ORDER BY gr.created_at DESC LIMIT 1 FOR UPDATE OF gr;
  IF FOUND THEN
    SELECT public.matchmaking_active_human_count(v_room.id) INTO v_count;
    RETURN jsonb_build_object('room_id', v_room.id, 'room_code', v_room.room_code,
      'host_id', v_room.host_id, 'is_host', v_room.host_id = v_user_id,
      'player_count', v_count, 'matchmaking_state', v_room.matchmaking_state,
      'bots_to_fill', v_room.bots_to_fill, 'bot_offer_version', v_room.bot_offer_version);
  END IF;

  DELETE FROM public.room_players rp USING public.game_rooms gr
  WHERE rp.room_id = gr.id AND rp.player_id = v_user_id
    AND gr.room_kind = 'matchmaking' AND gr.status = 'waiting';

  SELECT gr.* INTO v_room FROM public.game_rooms gr
  WHERE gr.room_kind = 'matchmaking' AND gr.game_type = p_game_type
    AND gr.total_rounds = p_total_rounds AND gr.status = 'waiting'
    AND gr.matchmaking_state IN ('waiting', 'voting')
    AND public.matchmaking_active_human_count(gr.id) < 4
  ORDER BY gr.created_at LIMIT 1 FOR UPDATE SKIP LOCKED;

  IF NOT FOUND THEN
    LOOP
      v_code := upper(substr(encode(extensions.gen_random_bytes(6), 'hex'), 1, 6));
      BEGIN
        INSERT INTO public.game_rooms
          (room_code, host_id, status, max_players, host_ip, ws_port, game_type,
           room_kind, matchmaking_state, total_rounds, bot_offer_after,
           matchmaking_updated_at)
        VALUES (v_code, v_user_id, 'waiting', 4, '127.0.0.1', 0, p_game_type,
          'matchmaking', 'waiting', p_total_rounds, NOW() + INTERVAL '8 seconds', NOW())
        RETURNING * INTO v_room;
        EXIT;
      EXCEPTION WHEN unique_violation THEN NULL;
      END;
    END LOOP;
    INSERT INTO public.room_players(room_id, player_id, player_name, is_host)
      VALUES (v_room.id, v_user_id, p_player_name, TRUE);
  ELSE
    INSERT INTO public.room_players(room_id, player_id, player_name, is_host)
      VALUES (v_room.id, v_user_id, p_player_name, FALSE)
      ON CONFLICT (room_id, player_id) DO UPDATE SET player_name = EXCLUDED.player_name,
        is_online = TRUE, last_seen = NOW();
    DELETE FROM public.matchmaking_bot_votes WHERE room_id = v_room.id;
    UPDATE public.game_rooms SET matchmaking_state = 'waiting', bots_to_fill = 0,
      bot_yes_votes = 0, bot_offer_version = bot_offer_version + 1,
      bot_offer_after = NOW() + INTERVAL '8 seconds', matchmaking_updated_at = NOW()
    WHERE id = v_room.id RETURNING * INTO v_room;
  END IF;

  SELECT public.matchmaking_active_human_count(v_room.id) INTO v_count;
  IF v_count = 4 THEN
    DELETE FROM public.matchmaking_bot_votes WHERE room_id = v_room.id;
    UPDATE public.game_rooms SET matchmaking_state = 'starting', bots_to_fill = 0,
      bot_yes_votes = 0, bot_offer_version = bot_offer_version + 1,
      matchmaking_starting_at = NOW(), matchmaking_updated_at = NOW()
    WHERE id = v_room.id RETURNING * INTO v_room;
  END IF;
  RETURN jsonb_build_object('room_id', v_room.id, 'room_code', v_room.room_code,
    'host_id', v_room.host_id, 'is_host', v_room.host_id = v_user_id,
    'player_count', v_count, 'matchmaking_state', v_room.matchmaking_state,
    'bots_to_fill', v_room.bots_to_fill, 'bot_offer_version', v_room.bot_offer_version);
END $$;

CREATE OR REPLACE FUNCTION public.join_game_room(p_room_code VARCHAR(6), p_player_name TEXT)
RETURNS JSONB LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS $$
DECLARE v_room public.game_rooms%ROWTYPE; v_count INTEGER; v_user UUID := auth.uid();
BEGIN
  PERFORM public.require_google_user();
  IF v_user IS NULL THEN RAISE EXCEPTION 'NOT_AUTHENTICATED'; END IF;
  SELECT * INTO v_room FROM public.game_rooms WHERE room_code=upper(trim(p_room_code)) ORDER BY created_at DESC LIMIT 1;
  IF NOT FOUND THEN RAISE EXCEPTION 'ROOM_NOT_FOUND'; END IF;
  IF v_room.room_kind <> 'private' THEN RAISE EXCEPTION 'ROOM_NOT_FOUND'; END IF;
  PERFORM pg_advisory_xact_lock(hashtext(v_room.id::TEXT));
  SELECT * INTO v_room FROM public.game_rooms WHERE id=v_room.id;
  IF EXISTS (SELECT 1 FROM public.room_players WHERE room_id=v_room.id AND player_id=v_user)
    THEN RETURN jsonb_build_object('room_id',v_room.id); END IF;
  IF v_room.status <> 'waiting' THEN RAISE EXCEPTION 'ROOM_NOT_WAITING'; END IF;
  SELECT count(*)::INTEGER INTO v_count FROM public.room_players WHERE room_id=v_room.id;
  IF v_count >= v_room.max_players THEN RAISE EXCEPTION 'ROOM_FULL'; END IF;
  INSERT INTO public.room_players(room_id,player_id,player_name,is_host) VALUES(v_room.id,v_user,trim(p_player_name),FALSE);
  RETURN jsonb_build_object('room_id',v_room.id);
END $$;
