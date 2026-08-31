-- Canary note (W1.6): if game_rooms SELECT is loosened to USING (true),
-- the test "outsider cannot read game_rooms" in rls_matrix.test.sql MUST fail.
-- Use during policy reviews:
--   1. Temporarily: create policy "CANARY" on game_rooms for select using (true);
--   2. Run: supabase test db
--   3. Expect failure on outsider game_rooms test
--   4. Drop CANARY policy before merge.

begin;
select plan(1);
select pass('RLS canary is documented; run rls_matrix.test.sql in CI');
select * from finish();
rollback;
