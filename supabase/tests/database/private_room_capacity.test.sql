-- Mode-specific private room capacity (99 up to 7 players).

begin;

select plan(2);

select tests.create_supabase_user('cap_host', 'cap-host@test.local');
select tests.authenticate_as('cap_host');

select lives_ok(
  $$ select public.set_private_room_max_players(
      (public.create_game_room('CAP996', 'Host', '127.0.0.1', 0, 'ninety_nine') ->> 'room_id')::uuid,
      6
    ) $$,
  '99 private room accepts 6 max players'
);

select throws_ok(
  $$ select public.set_private_room_max_players(
      (public.create_game_room('CAP995', 'Host', '127.0.0.1', 0, 'ninety_nine') ->> 'room_id')::uuid,
      8
    ) $$,
  'ROOM_INVALID_CAPACITY',
  '99 private room rejects more than 7 players'
);

select * from finish();

rollback;
