-- W1.10 — Anonymous / unrelated-authenticated callers must fail confidentiality checks.

begin;

select plan(9);

select tests.create_supabase_user('ei_alice', 'ei-alice@test.local');
select tests.create_supabase_user('ei_anon', 'ei-anon@test.local');
select tests.create_supabase_user('ei_outsider', 'ei-outsider@test.local');

update auth.users
set is_anonymous = true, email = null
where id = tests.get_supabase_uid('ei_anon');

select tests.authenticate_as_service_role();

insert into public.game_rooms (
  id, room_code, host_id, status, max_players, host_ip, ws_port, game_type
) values (
  'cccccccc-cccc-cccc-cccc-000000000003'::uuid,
  'ENVISO',
  tests.get_supabase_uid('ei_alice'),
  'playing',
  4,
  '127.0.0.1',
  7890,
  'kotchina'
)
on conflict (id) do nothing;

insert into public.room_players (room_id, player_id, player_name, is_host)
values (
  'cccccccc-cccc-cccc-cccc-000000000003'::uuid,
  tests.get_supabase_uid('ei_alice'),
  'Alice',
  true
)
on conflict (room_id, player_id) do nothing;

insert into public.player_private_hands (room_id, player_id, hand_cards)
values (
  'cccccccc-cccc-cccc-cccc-000000000003'::uuid,
  tests.get_supabase_uid('ei_alice'),
  '[{"suit":"spade","rank":"ace"}]'::jsonb
)
on conflict (room_id, player_id) do update set hand_cards = excluded.hand_cards;

-- Anonymous JWT
select tests.authenticate_as('ei_anon');

select is_empty(
  $$ select 1 from public.game_rooms where room_code = 'ENVISO' $$,
  'anonymous cannot read game_rooms'
);

select is_empty(
  $$ select 1 from public.player_private_hands
     where room_id = 'cccccccc-cccc-cccc-cccc-000000000003'::uuid $$,
  'anonymous cannot read private hands'
);

select throws_ok(
  $$ select public.get_room_public_state('cccccccc-cccc-cccc-cccc-000000000003'::uuid) $$,
  'NOT_ROOM_MEMBER',
  'anonymous cannot call get_room_public_state for member room'
);

select throws_ok(
  $$ select public.get_my_hand_cards('cccccccc-cccc-cccc-cccc-000000000003'::uuid) $$,
  'NOT_ROOM_MEMBER',
  'anonymous member cannot read hands for room they are not in'
);

select throws_ok(
  $$ select public.enter_matchmaking('Anon', 'kotchina', 13) $$,
  'GOOGLE_LOGIN_REQUIRED',
  'anonymous cannot enter matchmaking'
);

select ok(
  not has_function_privilege(
    'public.increment_player_stats(uuid, bigint, boolean)',
    'EXECUTE'
  ),
  'anonymous cannot execute increment_player_stats'
);

-- Unrelated authenticated user (not a room member)
select tests.authenticate_as('ei_outsider');

select is_empty(
  $$ select 1 from public.game_rooms where room_code = 'ENVISO' $$,
  'unrelated authenticated user cannot read game_rooms'
);

select is_empty(
  $$ select 1 from public.player_private_hands
     where room_id = 'cccccccc-cccc-cccc-cccc-000000000003'::uuid $$,
  'unrelated authenticated user cannot read private hands'
);

select throws_ok(
  $$ select public.get_room_public_state('cccccccc-cccc-cccc-cccc-000000000003'::uuid) $$,
  'NOT_ROOM_MEMBER',
  'unrelated authenticated user cannot call get_room_public_state'
);

select * from finish();
rollback;
