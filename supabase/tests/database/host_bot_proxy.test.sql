begin;
select plan(11);

select tests.create_supabase_user('bot_host', 'bot_host@test.local');

select tests.authenticate_as('bot_host');

select throws_ok(
  $$
    select public.estimation_validate_turn(
      'playCard',
      jsonb_build_object('playerId', 'bot_0'),
      tests.get_supabase_uid('bot_host'),
      jsonb_build_object(
        'phase', 'trickTaking',
        'currentPlayerSeatIndex', 1,
        'currentTrick', '[]'::jsonb,
        'players', jsonb_build_array(
          jsonb_build_object(
            'id', tests.get_supabase_uid('bot_host')::text,
            'seatIndex', 0
          ),
          jsonb_build_object(
            'id', 'bot_0',
            'seatIndex', 1,
            'isBot', true
          )
        )
      ),
      true
    );
  $$,
  'NOT_YOUR_TURN',
  'host cannot play on bot turn — payload.playerId is ignored for clients'
);

select tests.authenticate_as_service_role();

select lives_ok(
  $$
    select public.estimation_validate_turn(
      'confirmNoVoid',
      jsonb_build_object('playerId', 'bot_0'),
      tests.get_supabase_uid('bot_host'),
      jsonb_build_object(
        'phase', 'voidCheck',
        'voidDeclaringPlayerId', null,
        'voidCheckPassed', '[]'::jsonb,
        'voidRedealRejections', '[]'::jsonb,
        'botPlayerIds', '[]'::jsonb,
        'players', jsonb_build_array(
          jsonb_build_object(
            'id', tests.get_supabase_uid('bot_host')::text,
            'seatIndex', 0
          ),
          jsonb_build_object(
            'id', 'bot_0',
            'seatIndex', 1,
            'isBot', true
          )
        )
      ),
      true
    );
  $$,
  'service_role may validate bot-seat proxy for server bot runner'
);

select lives_ok(
  $$
    select public.estimation_validate_turn(
      'playCard',
      jsonb_build_object(
        'playerId', 'bot_0',
        'card', jsonb_build_object('suit', 'spade', 'rank', 'two')
      ),
      tests.get_supabase_uid('bot_host'),
      jsonb_build_object(
        'phase', 'trickTaking',
        'currentPlayerSeatIndex', 1,
        'currentTrick', '[]'::jsonb,
        'players', jsonb_build_array(
          jsonb_build_object(
            'id', tests.get_supabase_uid('bot_host')::text,
            'seatIndex', 0
          ),
          jsonb_build_object(
            'id', 'bot_0',
            'seatIndex', 1,
            'isBot', true
          )
        )
      ),
      true
    );
  $$,
  'service_role may proxy bot trick-taking turns'
);

select is(
  public.unmark_player_bot_in_game_state(
    jsonb_build_object(
      'botPlayerIds', jsonb_build_array(tests.get_supabase_uid('bot_host')::text, 'bot_0'),
      'players', jsonb_build_array(
        jsonb_build_object(
          'id', tests.get_supabase_uid('bot_host')::text,
          'seatIndex', 0,
          'isBot', false
        ),
        jsonb_build_object('id', 'bot_0', 'seatIndex', 1, 'isBot', true)
      )
    ),
    tests.get_supabase_uid('bot_host')::text,
    'kotchina'
  ) -> 'botPlayerIds',
  jsonb_build_array('bot_0'),
  'heartbeat/action reclaims a human UUID without removing permanent bots'
);

select is(
  public.sanitize_game_state_json(
    jsonb_build_object(
      'botPlayerIds', jsonb_build_array(tests.get_supabase_uid('bot_host')::text),
      'players', jsonb_build_array(
        jsonb_build_object(
          'id', tests.get_supabase_uid('bot_host')::text,
          'isBot', false,
          'hand', jsonb_build_array(jsonb_build_object('suit', 'heart', 'rank', 'ace'))
        )
      )
    )
  ) #> '{players,0,hand,0}',
  jsonb_build_object('suit', 'spade', 'rank', 'two'),
  'temporary human takeover never exposes the real private hand'
);

select throws_ok(
  format(
    $sql$
      select public.estimation_validate_turn(
        'timeoutTurn', '{}'::jsonb, %L::uuid,
        jsonb_build_object(
          'phase', 'auction',
          'turnDeadlineEpochMs', floor(extract(epoch from clock_timestamp()) * 1000)::bigint + 60000,
          'players', jsonb_build_array(jsonb_build_object('id', %L, 'seatIndex', 0))
        ),
        true
      )
    $sql$,
    tests.get_supabase_uid('bot_host'),
    tests.get_supabase_uid('bot_host')::text
  ),
  'TURN_NOT_EXPIRED',
  'timeout cannot be submitted before the authoritative deadline'
);

select lives_ok(
  format(
    $sql$
      select public.estimation_validate_turn(
        'timeoutTurn', '{}'::jsonb, %L::uuid,
        jsonb_build_object(
          'phase', 'auction',
          'turnDeadlineEpochMs', floor(extract(epoch from clock_timestamp()) * 1000)::bigint - 1,
          'players', jsonb_build_array(jsonb_build_object('id', %L, 'seatIndex', 0))
        ),
        true
      )
    $sql$,
    tests.get_supabase_uid('bot_host'),
    tests.get_supabase_uid('bot_host')::text
  ),
  'expired authoritative turn may advance exactly once'
);

select lives_ok(
  format(
    $sql$
      select public.estimation_validate_turn(
        'processBots', '{}'::jsonb, %L::uuid,
        jsonb_build_object(
          'phase', 'trickTaking',
          'players', jsonb_build_array(jsonb_build_object('id', %L, 'seatIndex', 0))
        ),
        false
      )
    $sql$,
    tests.get_supabase_uid('bot_host'),
    tests.get_supabase_uid('bot_host')::text
  ),
  'room member may wake newly assigned server bots'
);

select tests.authenticate_as_service_role();

insert into public.game_rooms (
  id, room_code, host_id, status, max_players, host_ip, ws_port, game_type, game_state
) values (
  'dddddddd-dddd-dddd-dddd-000000000004'::uuid,
  'BOT030',
  tests.get_supabase_uid('bot_host'),
  'playing',
  4,
  '127.0.0.1',
  7890,
  'kotchina',
  jsonb_build_object(
    'phase', 'trickTaking',
    'botPlayerIds', '[]'::jsonb,
    'players', jsonb_build_array(
      jsonb_build_object(
        'id', tests.get_supabase_uid('bot_host')::text,
        'seatIndex', 0,
        'hand', '[]'::jsonb
      )
    )
  )
);

insert into public.room_players (
  room_id, player_id, player_name, is_host, is_online, last_seen
) values (
  'dddddddd-dddd-dddd-dddd-000000000004'::uuid,
  tests.get_supabase_uid('bot_host'),
  'Bot Host',
  true,
  false,
  timezone('utc', now()) - interval '31 seconds'
);

select is(
  (public.process_room_absences('dddddddd-dddd-dddd-dddd-000000000004'::uuid)
    ->> 'bot_takeovers')::int,
  1,
  'human seat becomes bot-controlled after 30 seconds'
);

select is(
  (select game_state -> 'botPlayerIds' ->> 0
   from public.game_rooms
   where id = 'dddddddd-dddd-dddd-dddd-000000000004'::uuid),
  tests.get_supabase_uid('bot_host')::text,
  'takeover persists the absent human seat in botPlayerIds'
);

select is(
  (public.process_room_absences('dddddddd-dddd-dddd-dddd-000000000004'::uuid)
    ->> 'bot_takeovers')::int,
  0,
  'takeover is emitted only once so bot progression is not duplicated'
);

select * from finish();
rollback;
