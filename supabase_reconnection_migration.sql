-- ═══════════════════════════════════════════════════════════════════════════════
-- Reconnection & State Recovery — Database Migration
-- Run in the Supabase SQL Editor AFTER the base supabase_migration.sql
-- Safe to run multiple times (all statements are idempotent).
-- ═══════════════════════════════════════════════════════════════════════════════

-- ─── 1. New columns on room_players ──────────────────────────────────────────
--   is_online  : toggled by heartbeat / go-offline RPCs
--   last_seen  : timestamp of last heartbeat; used to enforce the 60-s grace window
--   hand_cards : JSONB snapshot of the player's private hand (written by the host
--                after each deal so a reconnecting player can recover their cards)
ALTER TABLE public.room_players
  ADD COLUMN IF NOT EXISTS is_online   BOOLEAN     NOT NULL DEFAULT TRUE,
  ADD COLUMN IF NOT EXISTS last_seen   TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  ADD COLUMN IF NOT EXISTS hand_cards  JSONB;

-- ─── 2. New columns on game_rooms ─────────────────────────────────────────────
--   game_state       : full GameState JSON snapshot written by the host on
--                      every phase transition (voidCheck→auction→declarations…)
--   state_updated_at : timestamp of last snapshot; lets clients verify freshness
ALTER TABLE public.game_rooms
  ADD COLUMN IF NOT EXISTS game_state        JSONB,
  ADD COLUMN IF NOT EXISTS state_updated_at  TIMESTAMPTZ;

-- ─── 3. Supporting indexes ────────────────────────────────────────────────────
CREATE INDEX IF NOT EXISTS idx_room_players_is_online
  ON public.room_players (room_id, is_online);

CREATE INDEX IF NOT EXISTS idx_room_players_last_seen
  ON public.room_players (room_id, last_seen DESC);

-- ─── 4. RPC: player_heartbeat ─────────────────────────────────────────────────
-- Called by every connected player every 15 seconds while the app is in the
-- foreground. Marks the player as online and refreshes last_seen.
CREATE OR REPLACE FUNCTION public.player_heartbeat(p_room_id UUID)
RETURNS VOID
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
BEGIN
  UPDATE public.room_players
  SET    is_online = TRUE,
         last_seen = NOW()
  WHERE  room_id   = p_room_id
    AND  player_id = auth.uid();
END;
$$;

-- ─── 5. RPC: player_go_offline ────────────────────────────────────────────────
-- Called when AppLifecycleState transitions to paused / detached.
-- Marks the player offline so others can detect the disconnection.
CREATE OR REPLACE FUNCTION public.player_go_offline(p_room_id UUID)
RETURNS VOID
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
BEGIN
  UPDATE public.room_players
  SET    is_online = FALSE,
         last_seen = NOW()
  WHERE  room_id   = p_room_id
    AND  player_id = auth.uid();
END;
$$;

-- ─── 6. RPC: save_game_state ──────────────────────────────────────────────────
-- Called by the current host on every game PHASE TRANSITION (not every broadcast).
-- Persists a full GameState snapshot so any reconnecting player (including a
-- newly promoted host) can re-hydrate the game without data loss.
CREATE OR REPLACE FUNCTION public.save_game_state(
  p_room_id UUID,
  p_state   JSONB
)
RETURNS VOID
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
BEGIN
  UPDATE public.game_rooms
  SET    game_state       = p_state,
         state_updated_at = NOW()
  WHERE  id      = p_room_id
    AND  host_id = auth.uid();
END;
$$;

-- ─── 7. RPC: promote_new_host ─────────────────────────────────────────────────
-- Atomically promotes the most senior online player to host when the current
-- host has been offline for longer than the grace window (60 s).
-- Returns the new host's player_id UUID, or NULL if:
--   • the current host is still online / within grace window, OR
--   • no eligible replacement is available.
--
-- Any connected client may call this RPC; the advisory lock and the host-online
-- check inside make it safe for concurrent callers.
CREATE OR REPLACE FUNCTION public.promote_new_host(p_room_id UUID)
RETURNS UUID
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  v_room             public.game_rooms%ROWTYPE;
  v_new_host_id      UUID;
  v_grace_seconds    CONSTANT INT := 60;
BEGIN
  -- Serialise concurrent promotion attempts for the same room
  PERFORM pg_advisory_xact_lock(hashtext(p_room_id::TEXT || '_promote'));

  -- Re-fetch room state after acquiring lock
  SELECT * INTO v_room FROM public.game_rooms WHERE id = p_room_id;
  IF NOT FOUND THEN RETURN NULL; END IF;

  -- Room must be in an active state
  IF v_room.status NOT IN ('waiting', 'playing') THEN RETURN NULL; END IF;

  -- Is the current host still alive within the grace window?
  IF EXISTS (
    SELECT 1 FROM public.room_players
    WHERE  room_id   = p_room_id
      AND  player_id = v_room.host_id
      AND  is_online = TRUE
      AND  last_seen > NOW() - (v_grace_seconds || ' seconds')::INTERVAL
  ) THEN
    RETURN NULL;  -- Current host is fine; no promotion needed
  END IF;

  -- Pick the oldest online player (by joined_at) who is not the current host
  SELECT player_id INTO v_new_host_id
  FROM   public.room_players
  WHERE  room_id   = p_room_id
    AND  player_id != v_room.host_id
    AND  is_online  = TRUE
    AND  last_seen  > NOW() - (v_grace_seconds || ' seconds')::INTERVAL
  ORDER BY joined_at ASC
  LIMIT 1;

  IF v_new_host_id IS NULL THEN RETURN NULL; END IF;

  -- Promote: update game_rooms.host_id
  UPDATE public.game_rooms
  SET    host_id = v_new_host_id
  WHERE  id = p_room_id;

  -- Demote old host flag, promote new host flag
  UPDATE public.room_players
  SET    is_host = FALSE
  WHERE  room_id = p_room_id AND is_host = TRUE;

  UPDATE public.room_players
  SET    is_host = TRUE
  WHERE  room_id   = p_room_id
    AND  player_id = v_new_host_id;

  RETURN v_new_host_id;
END;
$$;

-- ─── 8. RPC: save_player_hand ─────────────────────────────────────────────────
-- Called by the host after dealing cards to persist each player's private hand.
-- A reconnecting player fetches their own row to recover their hand without
-- needing the full broadcast.
CREATE OR REPLACE FUNCTION public.save_player_hand(
  p_room_id    UUID,
  p_player_id  UUID,
  p_hand_cards JSONB
)
RETURNS VOID
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
BEGIN
  -- Only the current room host may write hand cards on behalf of players
  IF NOT EXISTS (
    SELECT 1 FROM public.game_rooms
    WHERE id = p_room_id AND host_id = auth.uid()
  ) THEN
    RAISE EXCEPTION 'NOT_HOST';
  END IF;

  UPDATE public.room_players
  SET    hand_cards = p_hand_cards
  WHERE  room_id   = p_room_id
    AND  player_id = p_player_id;
END;
$$;

-- ─── 9. RLS: allow host to write game_state ───────────────────────────────────
-- The base migration already has an update policy for game_rooms but scoped to
-- the host. We add a named policy specifically for the new columns; if you
-- already have a "Only host can update their room" policy this is a no-op
-- because host_id check is identical.
DROP POLICY IF EXISTS "Only host can save game state" ON public.game_rooms;
CREATE POLICY "Only host can save game state"
  ON public.game_rooms
  FOR UPDATE
  TO authenticated
  USING     (auth.uid() = host_id)
  WITH CHECK (auth.uid() = host_id);

-- ─── 10. Grant EXECUTE to authenticated role ─────────────────────────────────
GRANT EXECUTE ON FUNCTION public.player_heartbeat(UUID)             TO authenticated;
GRANT EXECUTE ON FUNCTION public.player_go_offline(UUID)            TO authenticated;
GRANT EXECUTE ON FUNCTION public.save_game_state(UUID, JSONB)       TO authenticated;
GRANT EXECUTE ON FUNCTION public.promote_new_host(UUID)             TO authenticated;
GRANT EXECUTE ON FUNCTION public.save_player_hand(UUID, UUID, JSONB) TO authenticated;

-- ─── Done ─────────────────────────────────────────────────────────────────────
-- Verify with:
--   SELECT column_name, data_type
--   FROM   information_schema.columns
--   WHERE  table_name IN ('room_players','game_rooms')
--     AND  column_name IN ('is_online','last_seen','hand_cards','game_state','state_updated_at');
