-- One authenticated human may belong to only one waiting/playing room.
-- This protects create-room, join-room and matchmaking paths uniformly.

CREATE OR REPLACE FUNCTION public.prevent_multiple_active_room_memberships()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  IF EXISTS (
    SELECT 1
    FROM public.room_players rp
    JOIN public.game_rooms gr ON gr.id = rp.room_id
    WHERE rp.player_id = NEW.player_id
      AND rp.room_id <> NEW.room_id
      AND gr.status IN ('waiting', 'playing')
  ) THEN
    RAISE EXCEPTION 'ONGOING_GAME_REQUIRES_RETURN';
  END IF;
  RETURN NEW;
END
$$;

DROP TRIGGER IF EXISTS trg_prevent_multiple_active_room_memberships
  ON public.room_players;
CREATE TRIGGER trg_prevent_multiple_active_room_memberships
BEFORE INSERT ON public.room_players
FOR EACH ROW EXECUTE FUNCTION public.prevent_multiple_active_room_memberships();
