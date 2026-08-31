-- RLS security matrix (Phase 1 W1.6)
-- Requires: supabase/seed.sql (test helpers) applied via `supabase db reset`.

begin;

select plan(17);

-- ─── Fixtures ───────────────────────────────────────────────────────────────

select tests.create_supabase_user('alice', 'rls-alice@test.local');
select tests.create_supabase_user('bob', 'rls-bob@test.local');
select tests.create_supabase_user('carol', 'rls-carol@test.local');
select tests.create_supabase_user('anon', 'rls-anon@test.local');

-- Legacy anonymous account; excluded from public_profiles leaderboard view.
update auth.users
set is_anonymous = true, email = null
where id = tests.get_supabase_uid('anon');

select tests.authenticate_as_service_role();

insert into public.profiles (id, email, username, avatar_url, xp, level, games_played, games_won)
values
  (tests.get_supabase_uid('alice'), 'rls-alice@test.local', 'alice', 'preset:king', 100, 2, 5, 1),
  (tests.get_supabase_uid('bob'), 'rls-bob@test.local', 'bob', 'preset:king', 80, 2, 4, 0),
  (tests.get_supabase_uid('carol'), 'rls-carol@test.local', 'carol', 'preset:king', 60, 1, 2, 0)
on conflict (id) do update set email = excluded.email;

insert into public.game_rooms (id, room_code, host_id, status, max_players, host_ip, ws_port, game_type)
values (
  'aaaaaaaa-bbbb-cccc-dddd-000000000001'::uuid,
  'RLSTST',
  tests.get_supabase_uid('alice'),
  'waiting',
  4,
  '127.0.0.1',
  7890,
  'kotchina'
)
on conflict (id) do nothing;

insert into public.room_players (room_id, player_id, player_name, is_host)
values
  ('aaaaaaaa-bbbb-cccc-dddd-000000000001'::uuid, tests.get_supabase_uid('alice'), 'Alice', true),
  ('aaaaaaaa-bbbb-cccc-dddd-000000000001'::uuid, tests.get_supabase_uid('bob'), 'Bob', false)
on conflict (room_id, player_id) do nothing;

insert into public.player_private_hands (room_id, player_id, hand_cards)
values
  (
    'aaaaaaaa-bbbb-cccc-dddd-000000000001'::uuid,
    tests.get_supabase_uid('alice'),
    '[{"suit":"spade","rank":"ace"}]'::jsonb
  ),
  (
    'aaaaaaaa-bbbb-cccc-dddd-000000000001'::uuid,
    tests.get_supabase_uid('bob'),
    '[{"suit":"heart","rank":"king"}]'::jsonb
  )
on conflict (room_id, player_id) do update set hand_cards = excluded.hand_cards;

insert into public.game_history (user_id, game_data)
values
  (tests.get_supabase_uid('alice'), '{"mode":"test"}'::jsonb),
  (tests.get_supabase_uid('bob'), '{"mode":"test"}'::jsonb);

-- ─── Outsider (Carol) ────────────────────────────────────────────────────────

select tests.authenticate_as('carol');

select is_empty(
  $$ select 1 from public.game_rooms where room_code = 'RLSTST' $$,
  'outsider cannot read game_rooms'
);

select is_empty(
  $$ select 1 from public.room_players
     where room_id = 'aaaaaaaa-bbbb-cccc-dddd-000000000001'::uuid $$,
  'outsider cannot read room_players'
);

select is_empty(
  $$ select 1 from public.player_private_hands
     where room_id = 'aaaaaaaa-bbbb-cccc-dddd-000000000001'::uuid $$,
  'outsider cannot read any private hands'
);

select is(
  (select count(*)::integer from public.game_history),
  0,
  'outsider cannot read game_history'
);

-- ─── Room member (Bob) ───────────────────────────────────────────────────────

select tests.authenticate_as('bob');

select isnt_empty(
  $$ select 1 from public.game_rooms where room_code = 'RLSTST' $$,
  'room member can read game_rooms'
);

select isnt_empty(
  $$ select 1 from public.room_players
     where room_id = 'aaaaaaaa-bbbb-cccc-dddd-000000000001'::uuid $$,
  'room member can read room_players roster'
);

select is(
  (select count(*)::integer from public.player_private_hands
   where room_id = 'aaaaaaaa-bbbb-cccc-dddd-000000000001'::uuid),
  1,
  'member sees only own private hand row'
);

select is(
  public.get_my_hand_cards('aaaaaaaa-bbbb-cccc-dddd-000000000001'::uuid)::jsonb,
  '[{"suit": "heart", "rank": "king"}]'::jsonb,
  'get_my_hand_cards returns own hand only'
);

select throws_ok(
  $$ select public.save_player_hand(
       'aaaaaaaa-bbbb-cccc-dddd-000000000001'::uuid,
       tests.get_supabase_uid('alice'),
       '[]'::jsonb
     ) $$,
  'NOT_HOST',
  'non-host cannot save opponent hand'
);

select throws_ok(
  $$ select public.increment_player_stats(tests.get_supabase_uid('bob'), 50, true) $$,
  'SERVICE_ROLE_ONLY',
  'authenticated user cannot increment stats'
);

-- ─── Profile privacy (Alice) ─────────────────────────────────────────────────

select tests.authenticate_as('alice');

select is(
  (select count(*)::integer from public.profiles),
  1,
  'profiles table is owner-only'
);

select ok(
  (select count(*) >= 3 from public.public_profiles),
  'public_profiles lists registered users for leaderboard'
);

select ok(
  not exists (
    select 1 from public.public_profiles
    where id = tests.get_supabase_uid('anon')
  ),
  'anonymous auth user excluded from public_profiles'
);

select throws_ok(
  $$ update public.profiles
     set xp = xp + 9999
     where id = auth.uid() $$,
  'COMPETITIVE_FIELDS_READ_ONLY',
  'user cannot self-update competitive fields'
);

select is(
  (select count(*)::integer from public.game_history),
  1,
  'game_history is owner-only'
);

-- ─── Host (Alice) ────────────────────────────────────────────────────────────

select isnt_empty(
  $$ select public.get_room_private_hands_for_host(
       'aaaaaaaa-bbbb-cccc-dddd-000000000001'::uuid
     )::text $$,
  'host can load all private hands for promotion'
);

select ok(
  (
    select public.get_room_private_hands_for_host(
      'aaaaaaaa-bbbb-cccc-dddd-000000000001'::uuid
    )->>(tests.get_supabase_uid('bob')::text)
  ) is not null,
  'host recovery includes member hand'
);

select * from finish();
rollback;
