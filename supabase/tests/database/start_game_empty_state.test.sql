-- First startGame on an empty persisted snapshot (online lobby → playing).

begin;

select plan(3);

select tests.create_supabase_user('sg_host', 'sg-host@test.local');
select tests.create_supabase_user('sg_join', 'sg-join@test.local');

select tests.authenticate_as_service_role();

insert into public.game_rooms (
  id,
  room_code,
  host_id,
  status,
  max_players,
  host_ip,
  ws_port,
  game_type,
  room_kind,
  action_seq,
  total_rounds
)
values (
  'cccccccc-cccc-cccc-cccc-000000000001'::uuid,
  'SG0001',
  tests.get_supabase_uid('sg_host'),
  'playing',
  4,
  '127.0.0.1',
  0,
  'kotchina',
  'matchmaking',
  0,
  10
)
on conflict (id) do update set
  action_seq = 0,
  game_state = null,
  status = 'playing';

delete from public.room_players
where room_id = 'cccccccc-cccc-cccc-cccc-000000000001'::uuid;

insert into public.room_players (room_id, player_id, player_name, is_host)
values
  (
    'cccccccc-cccc-cccc-cccc-000000000001'::uuid,
    tests.get_supabase_uid('sg_host'),
    'Host',
    true
  ),
  (
    'cccccccc-cccc-cccc-cccc-000000000001'::uuid,
    tests.get_supabase_uid('sg_join'),
    'Guest',
    false
  );

select lives_ok(
  $$ select public.apply_game_action(
      'cccccccc-cccc-cccc-cccc-000000000001'::uuid,
      tests.get_supabase_uid('sg_host'),
      'startGame',
      '{}'::jsonb,
      'cccccccc-cccc-cccc-cccc-00000000a001'::uuid,
      0,
      jsonb_build_object(
        'phase', 'dashCall',
        'roundNumber', 1,
        'totalRounds', 10,
        'hostId', tests.get_supabase_uid('sg_host')::text,
        'players', jsonb_build_array(
          jsonb_build_object(
            'id', tests.get_supabase_uid('sg_host')::text,
            'name', 'Host',
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
            'id', tests.get_supabase_uid('sg_join')::text,
            'name', 'Guest',
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
      ),
      '{}'::jsonb
    ) $$,
  'host may commit first startGame while persisted snapshot is empty'
);

select isnt(
  (
    select public.get_authority_room_state(
      'cccccccc-cccc-cccc-cccc-000000000001'::uuid
    ) -> 'state' -> 'players' -> 0 ->> 'seatIndex'
  ),
  null,
  'authority roster includes seatIndex before first commit'
);

select tests.authenticate_as('sg_host');

select lives_ok(
  $$ select public.create_game_room(
      'SG0002',
      'Host',
      '127.0.0.1',
      0,
      'basra'
    ) $$,
  'create_game_room accepts game_type for private rooms'
);

select * from finish();

rollback;
