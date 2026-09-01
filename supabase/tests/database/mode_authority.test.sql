-- 99 / Basra apply_game_action turn validation (Phase 1 W1.1)

begin;

select plan(4);

select tests.create_supabase_user('nn_alice', 'nn-alice@test.local');
select tests.create_supabase_user('nn_bob', 'nn-bob@test.local');

select tests.authenticate_as_service_role();

insert into public.game_rooms (
  id, room_code, host_id, status, max_players, host_ip, ws_port, game_type, action_seq, game_state
)
values (
  'cccccccc-cccc-cccc-cccc-000000000099'::uuid,
  'NN0099',
  tests.get_supabase_uid('nn_alice'),
  'playing',
  2,
  '127.0.0.1',
  7892,
  'ninety_nine',
  0,
  jsonb_build_object(
    'phase', 'playing',
    'hostId', tests.get_supabase_uid('nn_alice')::text,
    'currentPlayerIndex', 0,
    'players', jsonb_build_array(
      jsonb_build_object(
        'id', tests.get_supabase_uid('nn_alice')::text,
        'name', 'Alice', 'hand', '[]'::jsonb, 'isBot', false
      ),
      jsonb_build_object(
        'id', tests.get_supabase_uid('nn_bob')::text,
        'name', 'Bob', 'hand', '[]'::jsonb, 'isBot', false
      )
    ),
    'playerLosses', '{}'::jsonb,
    'moveHistory', '[]'::jsonb
  )
)
on conflict (id) do update set action_seq = 0, game_state = excluded.game_state;

insert into public.room_players (room_id, player_id, player_name, is_host)
values
  ('cccccccc-cccc-cccc-cccc-000000000099'::uuid, tests.get_supabase_uid('nn_alice'), 'Alice', true),
  ('cccccccc-cccc-cccc-cccc-000000000099'::uuid, tests.get_supabase_uid('nn_bob'), 'Bob', false)
on conflict (room_id, player_id) do nothing;

-- Bob cannot play when Alice's turn (index 0)
select throws_ok(
  $$ select public.apply_game_action(
       'cccccccc-cccc-cccc-cccc-000000000099'::uuid,
       tests.get_supabase_uid('nn_bob'),
       'playCardNinetyNine',
       '{"card":{"suit":"spade","rank":"ace"}}'::jsonb,
       'dddddddd-dddd-dddd-dddd-000000000001'::uuid,
       0,
       '{"phase":"playing","currentPlayerIndex":1,"players":[]}'::jsonb,
       '{}'::jsonb
     ) $$,
  'NOT_YOUR_TURN',
  '99: wrong turn rejected'
);

-- Alice can apply on her turn
select is(
  (
    select (public.apply_game_action(
      'cccccccc-cccc-cccc-cccc-000000000099'::uuid,
      tests.get_supabase_uid('nn_alice'),
      'playCardNinetyNine',
      '{"card":{"suit":"spade","rank":"ace"}}'::jsonb,
      'dddddddd-dddd-dddd-dddd-000000000002'::uuid,
      0,
      jsonb_build_object(
        'phase', 'playing',
        'hostId', tests.get_supabase_uid('nn_alice')::text,
        'currentPlayerIndex', 1,
        'players', '[]'::jsonb,
        'playerLosses', '{}'::jsonb,
        'moveHistory', '[]'::jsonb
      ),
      '{}'::jsonb
    ) ->> 'seq')::bigint
  ),
  1::bigint,
  '99: successful apply increments seq'
);

-- Basra fixture
insert into public.game_rooms (
  id, room_code, host_id, status, max_players, host_ip, ws_port, game_type, action_seq, game_state
)
values (
  'dddddddd-dddd-dddd-dddd-0000000000ba'::uuid,
  'BSR001',
  tests.get_supabase_uid('nn_alice'),
  'playing',
  2,
  '127.0.0.1',
  7893,
  'basra',
  0,
  jsonb_build_object(
    'phase', 'playing',
    'hostId', tests.get_supabase_uid('nn_alice')::text,
    'currentPlayerIndex', 0,
    'tableCards', '[]'::jsonb,
    'players', jsonb_build_array(
      jsonb_build_object(
        'id', tests.get_supabase_uid('nn_alice')::text,
        'name', 'Alice', 'hand', '[]'::jsonb, 'isBot', false,
        'capturedCards', '[]'::jsonb, 'totalScore', 0, 'roundScore', 0, 'basraCount', 0
      ),
      jsonb_build_object(
        'id', tests.get_supabase_uid('nn_bob')::text,
        'name', 'Bob', 'hand', '[]'::jsonb, 'isBot', false,
        'capturedCards', '[]'::jsonb, 'totalScore', 0, 'roundScore', 0, 'basraCount', 0
      )
    ),
    'lastRoundScores', '[]'::jsonb
  )
)
on conflict (id) do update set action_seq = 0, game_state = excluded.game_state;

insert into public.room_players (room_id, player_id, player_name, is_host)
values
  ('dddddddd-dddd-dddd-dddd-0000000000ba'::uuid, tests.get_supabase_uid('nn_alice'), 'Alice', true),
  ('dddddddd-dddd-dddd-dddd-0000000000ba'::uuid, tests.get_supabase_uid('nn_bob'), 'Bob', false)
on conflict (room_id, player_id) do nothing;

select throws_ok(
  $$ select public.apply_game_action(
       'dddddddd-dddd-dddd-dddd-0000000000ba'::uuid,
       tests.get_supabase_uid('nn_bob'),
       'playCardBasra',
       '{"card":{"suit":"club","rank":"ace"}}'::jsonb,
       'eeeeeeee-eeee-eeee-eeee-000000000001'::uuid,
       0,
       '{"phase":"playing","currentPlayerIndex":1,"players":[]}'::jsonb,
       '{}'::jsonb
     ) $$,
  'NOT_YOUR_TURN',
  'Basra: wrong turn rejected'
);

select is(
  public.get_authority_room_state('cccccccc-cccc-cccc-cccc-000000000099'::uuid) ->> 'maxPlayers',
  '2',
  'authority state includes maxPlayers'
);

select * from finish();
rollback;
