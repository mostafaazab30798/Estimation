-- Anonymous auth users cannot create or join online rooms.

begin;

select plan(2);

select tests.create_supabase_user('go_alice', 'go-alice@test.local');
select tests.create_supabase_user('go_anon', 'go-anon@test.local');

update auth.users
set is_anonymous = true, email = null
where id = tests.get_supabase_uid('go_anon');

select tests.authenticate_as('go_anon');

select throws_ok(
  $$ select public.enter_matchmaking('Anon', 'kotchina', 13) $$,
  'GOOGLE_LOGIN_REQUIRED',
  'anonymous user cannot enter online matchmaking'
);

select tests.authenticate_as_service_role();

select lives_ok(
  $$
    insert into public.game_rooms (
      room_code, host_id, status, max_players, host_ip, ws_port, game_type
    ) values (
      'GOALCE',
      tests.get_supabase_uid('go_alice'),
      'waiting',
      4,
      '127.0.0.1',
      7891,
      'kotchina'
    )
  $$,
  'service role can still insert rooms for tests'
);

select * from finish();
rollback;
