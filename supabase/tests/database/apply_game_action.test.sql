-- apply_game_action authority tests (Phase 1 W1.1)
-- Requires: supabase/seed.sql + migrations through 202608310007.

begin;

select plan(8);

-- ─── Fixtures ───────────────────────────────────────────────────────────────

select tests.create_supabase_user('act_alice', 'act-alice@test.local');
select tests.create_supabase_user('act_bob', 'act-bob@test.local');
select tests.create_supabase_user('act_out', 'act-out@test.local');

select tests.authenticate_as_service_role();

insert into public.game_rooms (
  id, room_code, host_id, status, max_players, host_ip, ws_port, game_type, action_seq
)
values (
  'bbbbbbbb-bbbb-bbbb-bbbb-000000000001'::uuid,
  'ACT001',
  tests.get_supabase_uid('act_alice'),
  'playing',
  4,
  '127.0.0.1',
  7891,
  'kotchina',
  0
)
on conflict (id) do update set action_seq = 0;

update public.game_rooms
set game_state = jsonb_build_object(
  'phase', 'auction',
  'roundNumber', 1,
  'totalRounds', 18,
  'dealerSeatIndex', 0,
  'auctionTurnSeatIndex', 0,
  'currentPlayerSeatIndex', 0,
  'players', jsonb_build_array(
    jsonb_build_object(
      'id', tests.get_supabase_uid('act_alice')::text,
      'name', 'Alice',
      'seatIndex', 0,
      'hand', '[]'::jsonb,
      'actual', 0,
      'hasPassed', false,
      'isDashCall', false,
      'isRisk', false,
      'totalScore', 0,
      'takenTricks', '[]'::jsonb
    ),
    jsonb_build_object(
      'id', tests.get_supabase_uid('act_bob')::text,
      'name', 'Bob',
      'seatIndex', 1,
      'hand', '[]'::jsonb,
      'actual', 0,
      'hasPassed', false,
      'isDashCall', false,
      'isRisk', false,
      'totalScore', 0,
      'takenTricks', '[]'::jsonb
    )
  ),
  'currentTrick', '[]'::jsonb,
  'dashCallPassed', '[]'::jsonb,
  'voidCheckPassed', '[]'::jsonb,
  'voidRedealRejections', '[]'::jsonb,
  'cardTheme', 'theme_1'
)
where id = 'bbbbbbbb-bbbb-bbbb-bbbb-000000000001'::uuid;

insert into public.room_players (room_id, player_id, player_name, is_host)
values
  ('bbbbbbbb-bbbb-bbbb-bbbb-000000000001'::uuid, tests.get_supabase_uid('act_alice'), 'Alice', true),
  ('bbbbbbbb-bbbb-bbbb-bbbb-000000000001'::uuid, tests.get_supabase_uid('act_bob'), 'Bob', false)
on conflict (room_id, player_id) do nothing;

-- ─── Auth binding: outsider rejected ────────────────────────────────────────

select throws_ok(
  $$ select public.apply_game_action(
       'bbbbbbbb-bbbb-bbbb-bbbb-000000000001'::uuid,
       tests.get_supabase_uid('act_out'),
       'passBid',
       '{}'::jsonb,
       'cccccccc-cccc-cccc-cccc-000000000001'::uuid,
       0,
       '{"phase":"auction","players":[]}'::jsonb,
       '{}'::jsonb
     ) $$,
  'NOT_ROOM_MEMBER',
  'outsider cannot apply game action'
);

-- ─── Sequence: mismatch rejected ───────────────────────────────────────────

select throws_ok(
  $$ select public.apply_game_action(
       'bbbbbbbb-bbbb-bbbb-bbbb-000000000001'::uuid,
       tests.get_supabase_uid('act_alice'),
       'passBid',
       '{}'::jsonb,
       'cccccccc-cccc-cccc-cccc-000000000002'::uuid,
       99,
       '{"phase":"auction","roundNumber":1,"totalRounds":18,"dealerSeatIndex":0,"auctionTurnSeatIndex":1,"currentPlayerSeatIndex":0,"players":[],"currentTrick":[],"dashCallPassed":[],"voidCheckPassed":[],"voidRedealRejections":[],"cardTheme":"theme_1"}'::jsonb,
       '{}'::jsonb
     ) $$,
  'SEQ_MISMATCH',
  'wrong expected_seq rejected'
);

-- ─── Turn legality: bob cannot bid when alice turn ───────────────────────────

select throws_ok(
  $$ select public.apply_game_action(
       'bbbbbbbb-bbbb-bbbb-bbbb-000000000001'::uuid,
       tests.get_supabase_uid('act_bob'),
       'passBid',
       '{}'::jsonb,
       'cccccccc-cccc-cccc-cccc-000000000003'::uuid,
       0,
       '{"phase":"auction","roundNumber":1,"totalRounds":18,"dealerSeatIndex":0,"auctionTurnSeatIndex":1,"currentPlayerSeatIndex":0,"players":[],"currentTrick":[],"dashCallPassed":[],"voidCheckPassed":[],"voidRedealRejections":[],"cardTheme":"theme_1"}'::jsonb,
       '{}'::jsonb
     ) $$,
  'NOT_YOUR_TURN',
  'wrong turn rejected server-side'
);

-- ─── Successful apply increments seq ─────────────────────────────────────────

select is(
  (
    select (public.apply_game_action(
      'bbbbbbbb-bbbb-bbbb-bbbb-000000000001'::uuid,
      tests.get_supabase_uid('act_alice'),
      'passBid',
      '{}'::jsonb,
      'cccccccc-cccc-cccc-cccc-000000000004'::uuid,
      0,
      jsonb_build_object(
        'phase', 'auction',
        'roundNumber', 1,
        'totalRounds', 18,
        'dealerSeatIndex', 0,
        'auctionTurnSeatIndex', 1,
        'currentPlayerSeatIndex', 0,
        'players', '[]'::jsonb,
        'currentTrick', '[]'::jsonb,
        'dashCallPassed', '[]'::jsonb,
        'voidCheckPassed', '[]'::jsonb,
        'voidRedealRejections', '[]'::jsonb,
        'cardTheme', 'theme_1'
      ),
      '{}'::jsonb
    ) ->> 'seq')::bigint
  ),
  1::bigint,
  'successful apply returns seq 1'
);

select is(
  (select action_seq from public.game_rooms
   where id = 'bbbbbbbb-bbbb-bbbb-bbbb-000000000001'::uuid),
  1::bigint,
  'room action_seq incremented'
);

-- ─── Idempotency: duplicate action_id returns cached result ──────────────────

select is(
  (
    select (public.apply_game_action(
      'bbbbbbbb-bbbb-bbbb-bbbb-000000000001'::uuid,
      tests.get_supabase_uid('act_alice'),
      'passBid',
      '{}'::jsonb,
      'cccccccc-cccc-cccc-cccc-000000000004'::uuid,
      99,
      '{"phase":"lobby"}'::jsonb,
      '{}'::jsonb
    ) ->> 'seq')::bigint
  ),
  1::bigint,
  'idempotent replay returns cached seq (not 99)'
);

select is(
  (
    select (public.apply_game_action(
      'bbbbbbbb-bbbb-bbbb-bbbb-000000000001'::uuid,
      tests.get_supabase_uid('act_alice'),
      'passBid',
      '{}'::jsonb,
      'cccccccc-cccc-cccc-cccc-000000000004'::uuid,
      99,
      '{"phase":"lobby"}'::jsonb,
      '{}'::jsonb
    ) ->> 'idempotent')::boolean
  ),
  true,
  'idempotent replay flagged'
);

-- ─── Authenticated cannot call apply_game_action directly ────────────────────

select tests.authenticate_as('act_alice');

select throws_ok(
  $$ select public.apply_game_action(
       'bbbbbbbb-bbbb-bbbb-bbbb-000000000001'::uuid,
       tests.get_supabase_uid('act_alice'),
       'passBid',
       '{}'::jsonb,
       'cccccccc-cccc-cccc-cccc-000000000005'::uuid,
       1,
       '{"phase":"auction"}'::jsonb,
       '{}'::jsonb
     ) $$,
  'SERVICE_ROLE_ONLY',
  'clients cannot call apply_game_action directly'
);

select * from finish();
rollback;
