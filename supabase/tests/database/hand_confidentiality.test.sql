-- W1.2 — Hand confidentiality: trigger sanitization + member public-state RPC.

begin;

select plan(5);

select tests.create_supabase_user('hc_alice', 'hc-alice@test.local');
select tests.create_supabase_user('hc_bob', 'hc-bob@test.local');
select tests.create_supabase_user('hc_carol', 'hc-carol@test.local');

select tests.authenticate_as_service_role();

insert into public.game_rooms (
  id, room_code, host_id, status, max_players, host_ip, ws_port, game_type
) values (
  'bbbbbbbb-bbbb-bbbb-bbbb-000000000002'::uuid,
  'HCONF1',
  tests.get_supabase_uid('hc_alice'),
  'playing',
  4,
  '127.0.0.1',
  7890,
  'kotchina'
)
on conflict (id) do nothing;

insert into public.room_players (room_id, player_id, player_name, is_host)
values
  ('bbbbbbbb-bbbb-bbbb-bbbb-000000000002'::uuid, tests.get_supabase_uid('hc_alice'), 'Alice', true),
  ('bbbbbbbb-bbbb-bbbb-bbbb-000000000002'::uuid, tests.get_supabase_uid('hc_bob'), 'Bob', false)
on conflict (room_id, player_id) do nothing;

-- Direct write with a real opponent ace — trigger must mask before persist.
update public.game_rooms
set game_state = jsonb_build_object(
  'phase', 'trickTaking',
  'players', jsonb_build_array(
    jsonb_build_object(
      'id', tests.get_supabase_uid('hc_alice')::text,
      'hand', jsonb_build_array(jsonb_build_object('suit', 'spade', 'rank', 'ace'))
    ),
    jsonb_build_object(
      'id', tests.get_supabase_uid('hc_bob')::text,
      'hand', jsonb_build_array(jsonb_build_object('suit', 'heart', 'rank', 'king'))
    )
  )
)
where id = 'bbbbbbbb-bbbb-bbbb-bbbb-000000000002'::uuid;

select tests.authenticate_as('hc_bob');

select is(
  public.get_room_public_state('bbbbbbbb-bbbb-bbbb-bbbb-000000000002'::uuid)
    -> 'players' -> 1 -> 'hand' -> 0 ->> 'rank',
  'two',
  'public state RPC masks opponent hand rank'
);

select is(
  public.get_my_hand_cards('bbbbbbbb-bbbb-bbbb-bbbb-000000000002'::uuid)::jsonb,
  '[]'::jsonb,
  'bob has no private hand row yet'
);

select tests.authenticate_as_service_role();

insert into public.player_private_hands (room_id, player_id, hand_cards)
values (
  'bbbbbbbb-bbbb-bbbb-bbbb-000000000002'::uuid,
  tests.get_supabase_uid('hc_bob'),
  '[{"suit":"heart","rank":"king"}]'::jsonb
)
on conflict (room_id, player_id) do update set hand_cards = excluded.hand_cards;

select tests.authenticate_as('hc_bob');

select is(
  public.get_my_hand_cards('bbbbbbbb-bbbb-bbbb-bbbb-000000000002'::uuid)::jsonb,
  '[{"suit": "heart", "rank": "king"}]'::jsonb,
  'bob reads only own private hand via RPC'
);

select tests.authenticate_as('hc_carol');

select throws_ok(
  $$ select public.get_room_public_state('bbbbbbbb-bbbb-bbbb-bbbb-000000000002'::uuid) $$,
  'NOT_ROOM_MEMBER',
  'non-member cannot read room public state'
);

select * from finish();
rollback;
