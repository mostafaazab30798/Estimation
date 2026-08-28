-- Online matchmaking for four-seat Estimation games.
-- Run after the base, game_type, and reconnection migrations.

ALTER TABLE public.game_rooms
  ADD COLUMN IF NOT EXISTS room_kind TEXT NOT NULL DEFAULT 'private',
  ADD COLUMN IF NOT EXISTS matchmaking_state TEXT NOT NULL DEFAULT 'none',
  ADD COLUMN IF NOT EXISTS total_rounds INTEGER,
  ADD COLUMN IF NOT EXISTS bots_to_fill INTEGER NOT NULL DEFAULT 0,
  ADD COLUMN IF NOT EXISTS bot_offer_version INTEGER NOT NULL DEFAULT 0,
  ADD COLUMN IF NOT EXISTS bot_yes_votes INTEGER NOT NULL DEFAULT 0,
  ADD COLUMN IF NOT EXISTS bot_offer_after TIMESTAMPTZ,
  ADD COLUMN IF NOT EXISTS matchmaking_updated_at TIMESTAMPTZ,
  ADD COLUMN IF NOT EXISTS matchmaking_starting_at TIMESTAMPTZ;

DO $$ BEGIN
  ALTER TABLE public.game_rooms ADD CONSTRAINT game_rooms_room_kind_check
    CHECK (room_kind IN ('private', 'matchmaking'));
EXCEPTION WHEN duplicate_object THEN NULL; END $$;
DO $$ BEGIN
  ALTER TABLE public.game_rooms ADD CONSTRAINT game_rooms_matchmaking_state_check
    CHECK (matchmaking_state IN ('none', 'waiting', 'voting', 'starting'));
EXCEPTION WHEN duplicate_object THEN NULL; END $$;
DO $$ BEGIN
  ALTER TABLE public.game_rooms ADD CONSTRAINT game_rooms_matchmaking_bots_check
    CHECK (room_kind <> 'matchmaking' OR bots_to_fill BETWEEN 0 AND 2);
EXCEPTION WHEN duplicate_object THEN NULL; END $$;

CREATE INDEX IF NOT EXISTS idx_game_rooms_matchmaking_lookup
  ON public.game_rooms
    (game_type, total_rounds, room_kind, status, matchmaking_state, created_at);
CREATE INDEX IF NOT EXISTS idx_room_players_room_id
  ON public.room_players(room_id);

CREATE TABLE IF NOT EXISTS public.matchmaking_bot_votes (
  room_id UUID NOT NULL REFERENCES public.game_rooms(id) ON DELETE CASCADE,
  player_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  offer_version INTEGER NOT NULL,
  accepted BOOLEAN NOT NULL,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  PRIMARY KEY (room_id, player_id, offer_version)
);

ALTER TABLE public.matchmaking_bot_votes ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS "Room members can read matchmaking votes" ON public.matchmaking_bot_votes;
CREATE POLICY "Room members can read matchmaking votes"
  ON public.matchmaking_bot_votes FOR SELECT TO authenticated
  USING (EXISTS (
    SELECT 1 FROM public.room_players rp
    WHERE rp.room_id = matchmaking_bot_votes.room_id
      AND rp.player_id = auth.uid()
  ));

CREATE OR REPLACE FUNCTION public.matchmaking_active_human_count(p_room_id UUID)
RETURNS INTEGER LANGUAGE sql STABLE SECURITY DEFINER SET search_path = public AS $$
  SELECT count(*)::INTEGER FROM public.room_players
  WHERE room_id = p_room_id
    AND (is_online = TRUE OR last_seen > NOW() - INTERVAL '45 seconds')
$$;

CREATE OR REPLACE FUNCTION public.enter_matchmaking(
  p_player_name TEXT,
  p_game_type TEXT,
  p_total_rounds INTEGER
) RETURNS JSONB
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS $$
DECLARE
  v_user_id UUID := auth.uid();
  v_room public.game_rooms%ROWTYPE;
  v_count INTEGER;
  v_code TEXT;
BEGIN
  IF v_user_id IS NULL THEN RAISE EXCEPTION 'MATCHMAKING_NOT_AUTHENTICATED'; END IF;
  p_player_name := left(trim(p_player_name), 40);
  IF p_player_name = '' OR p_game_type <> 'kotchina' OR p_total_rounds <= 0 THEN
    RAISE EXCEPTION 'MATCHMAKING_ROOM_INVALID';
  END IF;

  PERFORM pg_advisory_xact_lock(hashtext('matchmaking:' || p_game_type || ':' || p_total_rounds));

  -- Reuse a valid existing membership, otherwise remove stale waiting membership.
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

CREATE OR REPLACE FUNCTION public.open_bot_fill_offer(p_room_id UUID)
RETURNS JSONB LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS $$
DECLARE v_room public.game_rooms%ROWTYPE; v_count INTEGER;
BEGIN
  SELECT * INTO v_room FROM public.game_rooms WHERE id = p_room_id FOR UPDATE;
  IF NOT FOUND OR v_room.room_kind <> 'matchmaking' THEN RETURN NULL; END IF;
  IF v_room.host_id <> auth.uid() THEN RAISE EXCEPTION 'NOT_HOST'; END IF;
  IF v_room.status <> 'waiting' OR v_room.matchmaking_state <> 'waiting' THEN RETURN NULL; END IF;
  IF v_room.bot_offer_after IS NOT NULL AND v_room.bot_offer_after > NOW() THEN RETURN NULL; END IF;
  SELECT public.matchmaking_active_human_count(p_room_id) INTO v_count;
  IF v_count NOT IN (2, 3) THEN RETURN NULL; END IF;
  DELETE FROM public.matchmaking_bot_votes WHERE room_id = p_room_id;
  UPDATE public.game_rooms SET matchmaking_state = 'voting', bots_to_fill = 0,
    bot_yes_votes = 0, bot_offer_version = bot_offer_version + 1,
    matchmaking_updated_at = NOW() WHERE id = p_room_id
    RETURNING * INTO v_room;
  RETURN jsonb_build_object('offer_version', v_room.bot_offer_version, 'human_count', v_count);
END $$;

CREATE OR REPLACE FUNCTION public.cast_bot_fill_vote(
  p_room_id UUID, p_offer_version INTEGER, p_accepted BOOLEAN
) RETURNS JSONB LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS $$
DECLARE v_room public.game_rooms%ROWTYPE; v_count INTEGER; v_yes INTEGER;
BEGIN
  SELECT * INTO v_room FROM public.game_rooms WHERE id = p_room_id FOR UPDATE;
  IF NOT FOUND OR v_room.room_kind <> 'matchmaking' THEN RAISE EXCEPTION 'MATCHMAKING_ROOM_INVALID'; END IF;
  IF v_room.status <> 'waiting' OR v_room.matchmaking_state <> 'voting'
     OR v_room.bot_offer_version <> p_offer_version THEN RAISE EXCEPTION 'MATCHMAKING_STALE_OFFER'; END IF;
  IF NOT EXISTS (SELECT 1 FROM public.room_players WHERE room_id = p_room_id AND player_id = auth.uid())
    THEN RAISE EXCEPTION 'MATCHMAKING_ROOM_INVALID'; END IF;
  SELECT public.matchmaking_active_human_count(p_room_id) INTO v_count;
  IF v_count = 4 THEN
    DELETE FROM public.matchmaking_bot_votes WHERE room_id = p_room_id;
    UPDATE public.game_rooms SET matchmaking_state = 'starting', bots_to_fill = 0,
      bot_yes_votes = 0, bot_offer_version = bot_offer_version + 1,
      matchmaking_starting_at = NOW(), matchmaking_updated_at = NOW() WHERE id = p_room_id;
    RETURN jsonb_build_object('result','starting','should_start',TRUE,'waiting_for_votes',FALSE,
      'yes_votes',0,'human_count',4,'bots_to_fill',0);
  ELSIF v_count NOT IN (2,3) THEN
    DELETE FROM public.matchmaking_bot_votes WHERE room_id = p_room_id;
    UPDATE public.game_rooms SET matchmaking_state = 'waiting', bots_to_fill = 0,
      bot_yes_votes = 0, bot_offer_version = bot_offer_version + 1,
      bot_offer_after = NOW() + INTERVAL '8 seconds', matchmaking_updated_at = NOW() WHERE id = p_room_id;
    RAISE EXCEPTION 'MATCHMAKING_STALE_OFFER';
  END IF;

  INSERT INTO public.matchmaking_bot_votes(room_id, player_id, offer_version, accepted)
    VALUES (p_room_id, auth.uid(), p_offer_version, p_accepted)
  ON CONFLICT (room_id, player_id, offer_version) DO UPDATE
    SET accepted = EXCLUDED.accepted, updated_at = NOW();
  IF NOT p_accepted THEN
    DELETE FROM public.matchmaking_bot_votes WHERE room_id = p_room_id;
    UPDATE public.game_rooms SET matchmaking_state = 'waiting', bots_to_fill = 0,
      bot_yes_votes = 0, bot_offer_version = bot_offer_version + 1,
      bot_offer_after = NOW() + INTERVAL '25 seconds', matchmaking_updated_at = NOW() WHERE id = p_room_id;
    RETURN jsonb_build_object('result','declined','should_start',FALSE,'waiting_for_votes',FALSE,
      'yes_votes',0,'human_count',v_count,'bots_to_fill',0);
  END IF;
  SELECT count(*)::INTEGER INTO v_yes FROM public.matchmaking_bot_votes
    WHERE room_id = p_room_id AND offer_version = p_offer_version AND accepted;
  UPDATE public.game_rooms SET bot_yes_votes = v_yes, matchmaking_updated_at = NOW() WHERE id = p_room_id;
  IF v_yes = v_count THEN
    -- Revalidate under the same room lock immediately before approval.
    SELECT public.matchmaking_active_human_count(p_room_id) INTO v_count;
    IF v_count = 4 THEN v_count := 4;
    ELSIF v_count NOT IN (2,3) THEN RAISE EXCEPTION 'MATCHMAKING_STALE_OFFER'; END IF;
    UPDATE public.game_rooms SET matchmaking_state = 'starting', bots_to_fill = 4 - v_count,
      matchmaking_starting_at = NOW(), matchmaking_updated_at = NOW() WHERE id = p_room_id;
    RETURN jsonb_build_object('result','starting','should_start',TRUE,'waiting_for_votes',FALSE,
      'yes_votes',v_yes,'human_count',v_count,'bots_to_fill',4-v_count);
  END IF;
  RETURN jsonb_build_object('result','waiting','should_start',FALSE,'waiting_for_votes',TRUE,
    'yes_votes',v_yes,'human_count',v_count,'bots_to_fill',0);
END $$;

CREATE OR REPLACE FUNCTION public.leave_matchmaking(p_room_id UUID)
RETURNS VOID LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS $$
DECLARE v_room public.game_rooms%ROWTYPE; v_new_host UUID; v_count INTEGER;
BEGIN
  SELECT * INTO v_room FROM public.game_rooms WHERE id = p_room_id FOR UPDATE;
  IF NOT FOUND OR v_room.room_kind <> 'matchmaking' THEN RETURN; END IF;
  IF NOT EXISTS (SELECT 1 FROM public.room_players WHERE room_id=p_room_id AND player_id=auth.uid()) THEN RETURN; END IF;
  DELETE FROM public.matchmaking_bot_votes WHERE room_id=p_room_id AND player_id=auth.uid();
  DELETE FROM public.room_players WHERE room_id=p_room_id AND player_id=auth.uid();
  SELECT count(*)::INTEGER INTO v_count FROM public.room_players WHERE room_id=p_room_id;
  IF v_count = 0 THEN
    UPDATE public.game_rooms SET status='cancelled', matchmaking_state='none', bots_to_fill=0,
      bot_yes_votes=0, matchmaking_updated_at=NOW() WHERE id=p_room_id;
    RETURN;
  END IF;
  IF v_room.host_id = auth.uid() THEN
    SELECT player_id INTO v_new_host FROM public.room_players WHERE room_id=p_room_id ORDER BY joined_at LIMIT 1;
    UPDATE public.room_players SET is_host=(player_id=v_new_host) WHERE room_id=p_room_id;
  ELSE v_new_host := v_room.host_id; END IF;
  DELETE FROM public.matchmaking_bot_votes WHERE room_id=p_room_id;
  UPDATE public.game_rooms SET host_id=v_new_host, matchmaking_state='waiting', bots_to_fill=0,
    bot_yes_votes=0, bot_offer_version=bot_offer_version+1,
    bot_offer_after=NOW()+INTERVAL '8 seconds', matchmaking_starting_at=NULL,
    matchmaking_updated_at=NOW() WHERE id=p_room_id AND status='waiting';
END $$;

-- This is the only RPC that may commit an approved public match to playing.
CREATE OR REPLACE FUNCTION public.start_matchmaking_room(p_room_id UUID)
RETURNS VOID LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS $$
DECLARE v_room public.game_rooms%ROWTYPE; v_count INTEGER;
BEGIN
  SELECT * INTO v_room FROM public.game_rooms WHERE id=p_room_id FOR UPDATE;
  IF NOT FOUND OR v_room.room_kind <> 'matchmaking' THEN RAISE EXCEPTION 'MATCHMAKING_ROOM_INVALID'; END IF;
  IF v_room.host_id <> auth.uid() THEN RAISE EXCEPTION 'NOT_HOST'; END IF;
  IF v_room.status = 'playing' THEN RETURN; END IF;
  IF v_room.status <> 'waiting' OR v_room.matchmaking_state <> 'starting' THEN RAISE EXCEPTION 'MATCHMAKING_ALREADY_STARTING'; END IF;
  SELECT public.matchmaking_active_human_count(p_room_id) INTO v_count;
  IF v_count NOT IN (2,3,4) OR v_count + v_room.bots_to_fill <> 4
     OR (v_count=4 AND v_room.bots_to_fill<>0) THEN RAISE EXCEPTION 'MATCHMAKING_ROOM_INVALID'; END IF;
  UPDATE public.game_rooms SET status='playing', started_at=NOW(), matchmaking_updated_at=NOW() WHERE id=p_room_id;
END $$;

-- Preserve the private-room start behavior while rejecting unapproved public starts.
CREATE OR REPLACE FUNCTION public.start_game_room(p_room_id UUID)
RETURNS VOID LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS $$
DECLARE v_room public.game_rooms%ROWTYPE; v_count INTEGER;
BEGIN
  SELECT * INTO v_room FROM public.game_rooms WHERE id=p_room_id FOR UPDATE;
  IF NOT FOUND THEN RAISE EXCEPTION 'ROOM_NOT_FOUND'; END IF;
  IF v_room.host_id <> auth.uid() THEN RAISE EXCEPTION 'NOT_HOST'; END IF;
  IF v_room.status <> 'waiting' THEN RETURN; END IF;
  IF v_room.room_kind = 'matchmaking' THEN
    IF v_room.matchmaking_state <> 'starting' THEN RAISE EXCEPTION 'MATCHMAKING_ROOM_INVALID'; END IF;
    SELECT public.matchmaking_active_human_count(p_room_id) INTO v_count;
    IF v_count NOT IN (2,3,4) OR v_count + v_room.bots_to_fill <> 4
       OR (v_count=4 AND v_room.bots_to_fill<>0) THEN RAISE EXCEPTION 'MATCHMAKING_ROOM_INVALID'; END IF;
  END IF;
  UPDATE public.game_rooms SET status='playing', started_at=NOW() WHERE id=p_room_id;
END $$;

CREATE OR REPLACE FUNCTION public.set_private_room_max_players(p_room_id UUID, p_max_players INTEGER)
RETURNS VOID LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS $$
BEGIN
  IF p_max_players < 1 OR p_max_players > 4 THEN RAISE EXCEPTION 'ROOM_INVALID_CAPACITY'; END IF;
  UPDATE public.game_rooms SET max_players=p_max_players
  WHERE id=p_room_id AND host_id=auth.uid() AND room_kind='private' AND status='waiting';
END $$;

CREATE OR REPLACE FUNCTION public.cancel_private_room(p_room_id UUID)
RETURNS VOID LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS $$
BEGIN
  UPDATE public.game_rooms SET status='cancelled'
  WHERE id=p_room_id AND host_id=auth.uid() AND room_kind='private' AND status='waiting';
END $$;

-- Prevent hidden matchmaking codes from entering through the private join RPC.
CREATE OR REPLACE FUNCTION public.join_game_room(p_room_code VARCHAR(6), p_player_name TEXT)
RETURNS JSONB LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS $$
DECLARE v_room public.game_rooms%ROWTYPE; v_count INTEGER; v_user UUID := auth.uid();
BEGIN
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

GRANT EXECUTE ON FUNCTION public.enter_matchmaking(TEXT,TEXT,INTEGER) TO authenticated;
GRANT EXECUTE ON FUNCTION public.open_bot_fill_offer(UUID) TO authenticated;
GRANT EXECUTE ON FUNCTION public.cast_bot_fill_vote(UUID,INTEGER,BOOLEAN) TO authenticated;
GRANT EXECUTE ON FUNCTION public.leave_matchmaking(UUID) TO authenticated;
GRANT EXECUTE ON FUNCTION public.start_matchmaking_room(UUID) TO authenticated;
GRANT EXECUTE ON FUNCTION public.matchmaking_active_human_count(UUID) TO authenticated;
GRANT EXECUTE ON FUNCTION public.start_game_room(UUID) TO authenticated;
GRANT EXECUTE ON FUNCTION public.set_private_room_max_players(UUID,INTEGER) TO authenticated;
GRANT EXECUTE ON FUNCTION public.cancel_private_room(UUID) TO authenticated;

-- Room mutations are performed only by the narrow SECURITY DEFINER functions above.
REVOKE UPDATE ON public.game_rooms FROM anon, authenticated;
