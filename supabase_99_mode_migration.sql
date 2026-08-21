-- ═══════════════════════════════════════════════════════════════════════════════
-- Supabase Migration: Add game_type to game_rooms for "99" Mode Support
-- ═══════════════════════════════════════════════════════════════════════════════

-- 1. Add game_type column to game_rooms (defaults to 'kotchina' for legacy rooms)
ALTER TABLE public.game_rooms
  ADD COLUMN IF NOT EXISTS game_type TEXT NOT NULL DEFAULT 'kotchina';

CREATE INDEX IF NOT EXISTS idx_game_rooms_game_type ON public.game_rooms(game_type);

-- 2. Update create_game_room RPC to accept game_type
CREATE OR REPLACE FUNCTION public.create_game_room(
    p_room_code VARCHAR(6),
    p_player_name TEXT,
    p_host_ip VARCHAR(45),
    p_ws_port INTEGER,
    p_game_type TEXT DEFAULT 'kotchina'
) RETURNS JSONB AS $$
DECLARE
    v_room_id UUID;
    v_user_id UUID := auth.uid();
BEGIN
    IF v_user_id IS NULL THEN
        RAISE EXCEPTION 'Not authenticated';
    END IF;

    INSERT INTO public.game_rooms (room_code, host_id, status, host_ip, ws_port, game_type)
    VALUES (p_room_code, v_user_id, 'waiting', p_host_ip, p_ws_port, COALESCE(p_game_type, 'kotchina'))
    RETURNING id INTO v_room_id;

    INSERT INTO public.room_players (room_id, player_id, player_name, is_host)
    VALUES (v_room_id, v_user_id, p_player_name, true);

    RETURN jsonb_build_object('room_id', v_room_id);
EXCEPTION
    WHEN unique_violation THEN
        RAISE EXCEPTION 'ROOM_CODE_COLLISION';
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;
