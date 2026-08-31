-- RLS security matrix (Phase 1 W1.6)
-- Runs against a DB built from supabase/migrations via `supabase db reset`.
-- Requires local Supabase (pgTAP + tests schema).

begin;

select plan(17);

-- ─── Fixtures ───────────────────────────────────────────────────────────────

select tests.create_supabase_user('rls-alice@test.local', 'test-pass-123');
select tests.create_supabase_user('rls-bob@test.local', 'test-pass-123');
select tests.create_supabase_user('rls-carol@test.local', 'test-pass-123');
select tests.create_supabase_user('rls-anon@test.local', 'test-pass-123');

create temp table _rls_users as
select id, email
from auth.users
where email in (
  'rls-alice@test.local',
  'rls-bob@test.local',
  'rls-carol@test.local',
  'rls-anon@test.local'
);

-- Mark one account as anonymous (legacy); should be excluded from leaderboard view.
update auth.users
set is_anonymous = true, email = null
where email = 'rls-anon@test.local';

select tests.authenticate_as_service_role();

insert into public.profiles (id, email, username, avatar_url, xp, level, games_played, games_won)
select u.id, u.email, split_part(u.email, '@', 1), 'preset:king', 100, 2, 5, 1
from auth.users u
where u.email in ('rls-alice@test.local', 'rls-bob@test.local', 'rls-carol@test.local')
on conflict (id) do update set email = excluded.email;

insert into public.game_rooms (id, room_code, host_id, status, max_players, host_ip, ws_port, game_type)
select
  'aaaaaaaa-bbbb-cccc-dddd-000000000001'::uuid,
  'RLSTST',
  (select id from auth.users where email = 'rls-alice@test.local'),
  'waiting',
  4,
  '127.0.0.1',
  7890,
  'kotchina'
where not exists (
  select 1 from public.game_rooms where room_code = 'RLSTST'
);

insert into public.room_players (room_id, player_id, player_name, is_host)
values
  (
    'aaaaaaaa-bbbb-cccc-dddd-000000000001'::uuid,
    (select id from auth.users where email = 'rls-alice@test.local'),
    'Alice',
    true
  ),
  (
    'aaaaaaaa-bbbb-cccc-dddd-000000000001'::uuid,
    (select id from auth.users where email = 'rls-bob@test.local'),
    'Bob',
    false
  )
on conflict (room_id, player_id) do nothing;

insert into public.player_private_hands (room_id, player_id, hand_cards)
values
  (
    'aaaaaaaa-bbbb-cccc-dddd-000000000001'::uuid,
    (select id from auth.users where email = 'rls-alice@test.local'),
    '[{"suit":"spade","rank":"ace"}]'::jsonb
  ),
  (
    'aaaaaaaa-bbbb-cccc-dddd-000000000001'::uuid,
    (select id from auth.users where email = 'rls-bob@test.local'),
    '[{"suit":"heart","rank":"king"}]'::jsonb
  )
on conflict (room_id, player_id) do update set hand_cards = excluded.hand_cards;

insert into public.game_history (user_id, game_data)
select u.id, '{"mode":"test"}'::jsonb
from auth.users u
where u.email in ('rls-alice@test.local', 'rls-bob@test.local');

-- ─── Outsider (Carol) ────────────────────────────────────────────────────────

select tests.authenticate_as(
  (select id from auth.users where email = 'rls-carol@test.local')
);

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

select tests.authenticate_as(
  (select id from auth.users where email = 'rls-bob@test.local')
);

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
       (select id from auth.users where email = 'rls-alice@test.local'),
       '[]'::jsonb
     ) $$,
  'NOT_HOST',
  'non-host cannot save opponent hand'
);

select throws_ok(
  $$ select public.increment_player_stats(
       (select id from auth.users where email = 'rls-bob@test.local'),
       50,
       true
     ) $$,
  'SERVICE_ROLE_ONLY',
  'authenticated user cannot increment stats'
);

-- ─── Profile privacy (Alice) ─────────────────────────────────────────────────

select tests.authenticate_as(
  (select id from auth.users where email = 'rls-alice@test.local')
);

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
    where id = (select id from auth.users where email = 'rls-anon@test.local')
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
  (select (public.get_room_private_hands_for_host(
    'aaaaaaaa-bbbb-cccc-dddd-000000000001'::uuid
  )->>(select id::text from auth.users where email = 'rls-bob@test.local'))) is not null),
  'host recovery includes member hand'
);

select * from finish();
rollback;
