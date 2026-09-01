begin;
select plan(2);

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

select * from finish();
rollback;
