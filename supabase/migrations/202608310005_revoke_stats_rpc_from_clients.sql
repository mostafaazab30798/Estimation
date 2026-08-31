-- Ensure clients cannot call increment_player_stats directly (W1.3 / W1.6).
-- Safe on production if 202608310002 already applied; idempotent.

revoke execute on function public.increment_player_stats(uuid, bigint, boolean) from authenticated;
revoke execute on function public.increment_player_stats(uuid, bigint, boolean) from anon;
