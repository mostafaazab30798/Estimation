begin;
select plan(5);

select tests.create_supabase_user('xp_host', 'xp_host@test.local');
select tests.create_supabase_user('xp_p2', 'xp_p2@test.local');

select tests.authenticate_as_service_role();

insert into public.game_rooms (id, room_code, host_id, game_type, status, max_players, action_seq, host_ip, ws_port)
values (
  'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa',
  'XPTEST',
  tests.get_supabase_uid('xp_host'),
  'kotchina',
  'playing',
  4,
  0,
  '127.0.0.1',
  7891
);

update public.profiles
set xp = 0, games_played = 0, games_won = 0, level = 1
where id in (tests.get_supabase_uid('xp_host'), tests.get_supabase_uid('xp_p2'));

select is(
  (
    select public.award_authority_match_xp(
      'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa',
      'kotchina',
      jsonb_build_object(
        'phase', 'matchEnd',
        'players', jsonb_build_array(
          jsonb_build_object(
            'id', tests.get_supabase_uid('xp_host')::text,
            'name', 'Host',
            'seatIndex', 0,
            'totalScore', 55,
            'declared', 2,
            'actual', 2
          ),
          jsonb_build_object(
            'id', tests.get_supabase_uid('xp_p2')::text,
            'name', 'P2',
            'seatIndex', 1,
            'totalScore', 20,
            'declared', 1,
            'actual', 1
          )
        ),
        'botPlayerIds', '[]'::jsonb
      )
    ) ->> 'awarded'
  )::int,
  2,
  'service role awards xp to both humans'
);

select is(
  (
    select public.award_authority_match_xp(
      'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa',
      'kotchina',
      '{}'::jsonb
    ) ->> 'idempotent'
  ),
  'true',
  'second award call is idempotent'
);

select is(
  (select xp from public.profiles where id = tests.get_supabase_uid('xp_host')),
  195::bigint,
  'winner gets placement 100 + win 50 + accuracy 20 + high score 25'
);

select is(
  (select games_won from public.profiles where id = tests.get_supabase_uid('xp_host')),
  1,
  'winner games_won increments'
);

select tests.authenticate_as('xp_host');

select is(
  (public.get_my_match_xp_award('aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa') ->> 'xp_gain')::int,
  195,
  'winner reads own award via rpc'
);

select * from finish();
rollback;
