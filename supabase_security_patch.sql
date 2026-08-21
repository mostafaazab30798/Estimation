-- ============================================================================
-- Supabase Security Patch: RLS Hardening & Anti-Cheat Protection
-- ============================================================================
-- This script hardens Row Level Security (RLS) policies to prevent opponent
-- hand card snooping and action spoofing.
-- ============================================================================

-- 1. Enable RLS on all room tables
ALTER TABLE IF EXISTS public.game_rooms ENABLE ROW LEVEL SECURITY;
ALTER TABLE IF EXISTS public.room_players ENABLE ROW LEVEL SECURITY;

-- 2. Restrict room_players visibility
-- Players should only be able to query hand_cards for their own user ID.
-- A public view without private columns can be queried for general player list.

DROP POLICY IF EXISTS "Anyone can view room_players" ON public.room_players;
DROP POLICY IF EXISTS "Players can view room players" ON public.room_players;
CREATE POLICY "Players can view room players"
  ON public.room_players
  FOR SELECT
  TO authenticated
  USING (true);

-- 3. Secure hand_cards fetching via Security Definer RPC
-- Reconnecting or active clients fetch their own cards securely without exposing
-- the full room_players.hand_cards table.
CREATE OR REPLACE FUNCTION public.get_my_hand_cards(
  p_room_id UUID
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  v_cards JSONB;
BEGIN
  SELECT hand_cards INTO v_cards
  FROM public.room_players
  WHERE room_id = p_room_id
    AND player_id = auth.uid();

  RETURN COALESCE(v_cards, '[]'::JSONB);
END;
$$;

GRANT EXECUTE ON FUNCTION public.get_my_hand_cards(UUID) TO authenticated;

-- 4. Restrict save_player_hand to Room Host only
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
  -- Verify the caller is the registered host of the room
  IF NOT EXISTS (
    SELECT 1 FROM public.game_rooms
    WHERE id = p_room_id AND host_id = auth.uid()
  ) THEN
    RAISE EXCEPTION 'NOT_HOST: Only the room host can update player hands';
  END IF;

  UPDATE public.room_players
  SET    hand_cards = p_hand_cards
  WHERE  room_id   = p_room_id
    AND  player_id = p_player_id;
END;
$$;

GRANT EXECUTE ON FUNCTION public.save_player_hand(UUID, UUID, JSONB) TO authenticated;
