# Multiplayer Room & Lobby System — Flutter + Supabase Implementation Specification

## 1. Agent Role

You are a Senior Flutter Architect and Supabase Backend Engineer.

Your task is to implement a production-ready multiplayer Room and Lobby system inside the existing Flutter game project.

The system must allow a player to:

1. Create a game room.
2. Become the room host.
3. Receive a unique room code.
4. Share the room code with another player.
5. Allow another player to join using the code.
6. Display all joined players in real time.
7. Allow only the host to start the game.
8. Automatically navigate all room players to the game screen when the host starts the game.

You MUST inspect the existing Flutter project before making any changes.

DO NOT blindly generate a new project.

DO NOT replace the existing architecture.

DO NOT rewrite unrelated features.

DO NOT introduce unnecessary packages.

---

# 2. Mandatory Initial Project Analysis

Before writing code, inspect the entire relevant project structure.

Analyze:

* `pubspec.yaml`
* Flutter SDK compatibility
* Existing folder architecture
* Existing state management solution
* Existing routing solution
* Existing Supabase initialization
* Existing authentication implementation
* Existing user/player model
* Existing repositories
* Existing services
* Existing providers, blocs, cubits, or controllers
* Existing game screen
* Existing navigation flow
* Existing error handling pattern
* Existing loading state pattern

Determine whether the project currently uses:

* Riverpod
* Provider
* BLoC
* Cubit
* GetX
* StatefulWidget state

Use the EXISTING state management solution.

Determine whether routing uses:

* go_router
* Navigator
* AutoRoute
* another routing solution

Use the EXISTING routing solution.

### Critical Rule

Never create a second architecture beside the existing architecture.

For example:

If Riverpod already exists, use Riverpod.

If BLoC already exists, use BLoC.

If repositories already exist, follow the repository pattern.

If Freezed models are already used, use Freezed.

If models use manual `fromJson` and `toJson`, follow that pattern.

The implementation must look like it was originally developed as part of the project.

---

# 3. Required User Flow

The required flow is:

```text
Main Game Menu
      |
      +-----------------------+
      |                       |
      v                       v
  HOST GAME               JOIN GAME
      |                       |
      v                       v
Create Room             Enter Room Code
      |                       |
      v                       v
Generate Code           Validate Room
      |                       |
      v                       v
Add Host                Add Player
      |                       |
      +-----------+-----------+
                  |
                  v
              LOBBY ROOM
                  |
                  v
         Realtime Player List
                  |
                  v
          Host Presses Start
                  |
                  v
       Room Status = playing
                  |
                  v
      All Players Open Game
```

The complete flow must work without requiring manual refresh.

---

# 4. Supabase Database Design

Create a SQL migration for the multiplayer room system.

Do NOT manually modify existing unrelated database tables.

Create the following tables.

## 4.1 `game_rooms`

```sql
create table if not exists public.game_rooms (
    id uuid primary key default gen_random_uuid(),

    room_code varchar(6) not null unique,

    host_id uuid not null references auth.users(id) on delete cascade,

    status varchar(20) not null default 'waiting',

    max_players integer not null default 2,

    created_at timestamptz not null default now(),

    started_at timestamptz,

    constraint game_rooms_status_check
        check (status in ('waiting', 'playing', 'finished', 'cancelled')),

    constraint game_rooms_max_players_check
        check (max_players > 0)
);
```

Create an index:

```sql
create index if not exists idx_game_rooms_room_code
on public.game_rooms(room_code);
```

Create an index:

```sql
create index if not exists idx_game_rooms_status
on public.game_rooms(status);
```

---

## 4.2 `room_players`

```sql
create table if not exists public.room_players (
    id uuid primary key default gen_random_uuid(),

    room_id uuid not null
        references public.game_rooms(id)
        on delete cascade,

    player_id uuid not null
        references auth.users(id)
        on delete cascade,

    player_name text not null,

    is_host boolean not null default false,

    joined_at timestamptz not null default now(),

    unique(room_id, player_id)
);
```

Create an index:

```sql
create index if not exists idx_room_players_room_id
on public.room_players(room_id);
```

---

# 5. Row Level Security

Enable RLS.

```sql
alter table public.game_rooms enable row level security;
alter table public.room_players enable row level security;
```

Implement secure RLS policies.

Authenticated users must be able to find a waiting room using a room code.

Authenticated users must be able to create rooms.

Room players must be able to read their room.

Players must be able to join a valid waiting room.

Only the host must be allowed to change the room status to `playing`.

A normal player MUST NOT be able to start the game.

A player MUST NOT be able to modify another player's room player record.

Do not use insecure policies such as:

```sql
using (true)
```

for UPDATE or DELETE operations.

Do not disable RLS as a shortcut.

Security must be implemented correctly.

---

# 6. Realtime Configuration

The lobby requires Supabase Realtime.

Ensure the following tables are available to Realtime:

```text
game_rooms
room_players
```

If required, provide the SQL migration or Supabase configuration instructions needed to add the tables to the Realtime publication.

The application must listen to:

```text
room_players
```

for:

* player joined
* player left
* player changes

The application must listen to:

```text
game_rooms
```

for:

* room status changes
* game start event
* room cancellation

Do not implement polling.

Do not repeatedly call the database using timers.

Use Supabase Realtime correctly.

---

# 7. Room Code Generation

Room codes must contain exactly 6 characters.

Allowed characters:

```text
ABCDEFGHJKLMNPQRSTUVWXYZ23456789
```

Do not use:

```text
I
O
0
1
```

This prevents visual confusion.

Example room codes:

```text
K7P4XQ
B9TR5M
Q2WK8A
```

Implement a secure room code generator using:

```dart
Random.secure()
```

Example concept:

```dart
String generateRoomCode() {
  const chars = 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789';
  final random = Random.secure();

  return List.generate(
    6,
    (_) => chars[random.nextInt(chars.length)],
  ).join();
}
```

However, generating a code locally is NOT enough.

The implementation must handle room code collisions.

Required behavior:

1. Generate room code.
2. Attempt room creation.
3. If the unique room code constraint fails:

   * generate another code
   * retry
4. Use a reasonable maximum retry count.
5. Throw a controlled application exception if all attempts fail.

Never assume generated codes are always unique.

---

# 8. Atomic Room Creation

Creating a room and adding the host must be atomic.

DO NOT implement:

```text
Insert room
Wait
Insert host
```

as two unsafe independent client operations.

This could create an empty room if the second request fails.

Create a Supabase PostgreSQL RPC function such as:

```text
create_game_room
```

The database function must:

1. Validate `auth.uid()`.
2. Receive the generated room code.
3. Create the room.
4. Add the authenticated user as the host.
5. Set `is_host = true`.
6. Return the created room.
7. Execute inside one database transaction.

If any operation fails, the entire operation must fail.

The client must call the RPC through the existing Supabase client.

---

# 9. Atomic Join Room Operation

Joining a room must also be implemented safely.

Create a PostgreSQL RPC function:

```text
join_game_room
```

The function must receive:

```text
room code
player name
```

The function must:

1. Validate `auth.uid()`.
2. Normalize the room code to uppercase.
3. Find the room.
4. Verify the room exists.
5. Verify room status is `waiting`.
6. Verify the player is not already in the room.
7. Count current room players.
8. Verify the room is not full.
9. Insert the player.
10. Return the room.

The operation must protect against concurrent join requests.

Two players joining the last available slot simultaneously MUST NOT cause the room to exceed `max_players`.

Use appropriate PostgreSQL row locking or another correct transactional concurrency solution.

Do not rely only on a Flutter-side player count check.

The database is the source of truth.

---

# 10. Required Domain Models

Create or adapt models matching the project's existing model conventions.

Required conceptual models:

## GameRoom

Required fields:

```text
id
roomCode
hostId
status
maxPlayers
createdAt
startedAt
```

Suggested enum:

```dart
enum GameRoomStatus {
  waiting,
  playing,
  finished,
  cancelled,
}
```

Do not scatter raw status strings throughout the application.

Centralize status parsing.

Unknown database values must be handled safely.

---

## RoomPlayer

Required fields:

```text
id
roomId
playerId
playerName
isHost
joinedAt
```

Models must correctly map Supabase snake_case fields.

Example:

```text
room_code -> roomCode
host_id -> hostId
max_players -> maxPlayers
player_id -> playerId
player_name -> playerName
is_host -> isHost
joined_at -> joinedAt
```

Follow the existing serialization pattern.

---

# 11. Repository Requirements

Create or extend the appropriate repository.

Conceptual interface:

```dart
abstract interface class LobbyRepository {
  Future<GameRoom> createRoom({
    required String playerName,
  });

  Future<GameRoom> joinRoom({
    required String roomCode,
    required String playerName,
  });

  Future<GameRoom?> getRoom(String roomId);

  Stream<GameRoom> watchRoom(String roomId);

  Stream<List<RoomPlayer>> watchRoomPlayers(String roomId);

  Future<void> startGame(String roomId);

  Future<void> leaveRoom(String roomId);
}
```

Adapt naming to the existing project architecture.

Do not create unnecessary abstraction layers if the project does not use them.

Repository responsibilities:

* Supabase communication
* RPC calls
* Realtime streams
* Database mapping
* Supabase exception translation

UI widgets MUST NOT directly contain complex Supabase queries.

Avoid code such as this inside a screen:

```dart
Supabase.instance.client
    .from(...)
    .select(...);
```

Database logic belongs in the data/repository layer according to the project's architecture.

---

# 12. Create Room Behavior

When the user presses:

```text
HOST GAME
```

The application must:

1. Validate authentication.
2. Obtain the current player's name from the existing player/user system.
3. Generate a room code.
4. Call the atomic room creation RPC.
5. Handle room code collision retry.
6. Receive the created room.
7. Navigate to the lobby.
8. Start realtime room subscriptions.

Expected result:

```text
Room Code: K7P4XQ

Players:

👑 Mostafa
Waiting for player...
```

The room creator is always the host.

Do not allow client input to arbitrarily set another user as host.

The database function must derive the host from:

```sql
auth.uid()
```

---

# 13. Join Room Behavior

Create a Join Game UI.

Required UI:

```text
JOIN GAME

[ _ _ _ _ _ _ ]

[ JOIN ROOM ]
```

The input must:

* accept 6 characters
* convert input to uppercase
* remove surrounding spaces
* prevent unsupported characters where appropriate
* support keyboard submission

When the user submits:

1. Validate authentication.
2. Normalize the code.
3. Validate code length.
4. Call `join_game_room`.
5. Handle controlled database errors.
6. Navigate to the lobby when successful.
7. Subscribe to room realtime events.

Required user-friendly errors:

```text
Room not found.
This game has already started.
The room is full.
You are already in this room.
Invalid room code.
Unable to join the room. Please try again.
```

Use the application's existing localization solution if localization already exists.

Do not hardcode English text if the project already uses ARB or another localization system.

---

# 14. Lobby Screen

Create a polished multiplayer lobby screen matching the existing game visual design.

Do not introduce an unrelated visual design system.

The lobby must display:

* Room code
* Copy room code action
* Share room code action if a sharing package already exists
* Player list
* Host indicator
* Current player indicator if appropriate
* Waiting state
* Player count
* Maximum player count
* Start Game button for host
* Leave Room action

Example layout:

```text
┌──────────────────────────────────┐
│          GAME LOBBY              │
│                                  │
│           ROOM CODE              │
│                                  │
│            K7P4XQ                │
│                                  │
│       [ COPY ]    [ SHARE ]      │
│                                  │
│          PLAYERS 1 / 2           │
│                                  │
│       👑 Mostafa     HOST        │
│       🎮 Waiting for player...   │
│                                  │
│          [ START GAME ]          │
│                                  │
│            LEAVE ROOM            │
└──────────────────────────────────┘
```

The UI must update automatically when players join or leave.

Use the existing theme.

Use existing:

* colors
* typography
* spacing system
* buttons
* cards
* animations

Do not hardcode random colors.

---

# 15. Host Permissions

The Start Game button must only be visible or enabled for the host.

Client-side logic:

```text
currentUserId == room.hostId
```

However, client-side validation is NOT security.

The backend must independently verify the host.

The database operation responsible for starting the game must verify:

```sql
auth.uid() = game_rooms.host_id
```

A malicious player calling Supabase directly must still be unable to start the game.

---

# 16. Start Game Operation

Create a secure RPC function:

```text
start_game_room
```

The function must:

1. Validate authentication.
2. Find the room.
3. Lock the room row.
4. Verify the current authenticated user is the host.
5. Verify room status is `waiting`.
6. Verify the required minimum number of players.
7. Change status to `playing`.
8. Set `started_at = now()`.
9. Return the updated room.

The operation must be idempotent or safely reject repeated start requests.

The Flutter client must NOT directly update:

```text
status = playing
```

Use the secure RPC.

---

# 17. Automatic Game Navigation

Every player in the lobby must subscribe to room changes.

When:

```text
room.status == GameRoomStatus.playing
```

the application must navigate to the existing game screen.

All connected players must react to the same database state change.

Conceptual behavior:

```dart
if (room.status == GameRoomStatus.playing) {
  navigateToGame(room.id);
}
```

Prevent duplicate navigation.

Realtime events may emit multiple times.

Implement a navigation guard.

Example conceptual state:

```dart
bool hasNavigatedToGame = false;
```

Or use the existing state management architecture to ensure the transition only occurs once.

Do not call navigation repeatedly from uncontrolled widget rebuilds.

---

# 18. Leaving a Room

Implement:

```text
leaveRoom
```

Required behavior for a normal player:

1. Remove the player's `room_players` record.
2. Other lobby players receive the realtime update.
3. Navigate the leaving player back to the previous game menu.

Host behavior requires special handling.

If the host leaves while the room is waiting:

Recommended initial implementation:

```text
Cancel the room.
```

The system must:

1. Change room status to `cancelled`.
2. Other players receive the realtime room update.
3. Other players leave the lobby automatically.
4. Display an appropriate message.

Do not silently leave other players inside an abandoned room.

Implement this operation atomically using an RPC if necessary.

---

# 19. Realtime Lifecycle Management

Realtime subscriptions must be managed correctly.

The implementation must:

* create subscriptions when entering the lobby
* avoid duplicate subscriptions
* cancel subscriptions when leaving the lobby
* cancel subscriptions when the controller/provider/bloc is disposed
* handle temporary realtime errors
* avoid memory leaks

Do not keep global uncontrolled subscriptions.

Do not create a new realtime subscription on every widget rebuild.

Realtime logic belongs in the appropriate repository/controller/provider layer.

---

# 20. App Lifecycle and Reconnection

Handle basic application lifecycle scenarios.

If the application temporarily loses connection:

* do not immediately remove the player
* display the existing offline/network state if the project has one
* allow Supabase realtime to reconnect

When the lobby screen is restored:

1. Fetch the latest room state.
2. Fetch or subscribe to the latest player state.
3. Re-establish realtime subscriptions safely.

If the room is already:

```text
playing
```

navigate to the game.

If the room is:

```text
cancelled
```

return to the menu.

If the room no longer exists:

return to the menu with a controlled message.

---

# 21. Race Conditions

The implementation must explicitly protect against race conditions.

Handle:

### Duplicate Room Code

Use the database unique constraint and retry logic.

### Simultaneous Join

Use database transaction and row locking.

### Two Start Requests

Lock the room and validate the current status.

### Player Double Tap Join

Disable the button while loading and protect at database level.

### Host Double Tap Start

Disable the button while loading and protect at database level.

### Duplicate Realtime Events

Use stable state updates and navigation guards.

### Player Joins During Start

The database must define a consistent transaction boundary.

A player must not successfully join a room after its status becomes `playing`.

---

# 22. Loading and Error States

Every async action must have a proper state.

Required conceptual states:

```text
idle
loading
success
error
```

Required operations:

```text
createRoom
joinRoom
startGame
leaveRoom
```

Prevent duplicate submissions.

Buttons must show loading indicators according to the existing UI design.

Never swallow exceptions.

Do not use:

```dart
catch (_) {}
```

Do not only use:

```dart
print(error);
```

Translate technical exceptions into controlled application failures.

Log technical information using the project's existing logging solution.

---

# 23. File Structure

First inspect the existing structure.

If the project uses feature-first architecture, prefer a structure similar to:

```text
lib/
└── features/
    └── lobby/
        ├── data/
        │   ├── repositories/
        │   │   └── lobby_repository_impl.dart
        │   │
        │   └── datasources/
        │       └── lobby_remote_data_source.dart
        │
        ├── domain/
        │   ├── models/
        │   │   ├── game_room.dart
        │   │   └── room_player.dart
        │   │
        │   └── repositories/
        │       └── lobby_repository.dart
        │
        └── presentation/
            ├── controllers/
            │   └── lobby_controller.dart
            │
            ├── screens/
            │   ├── join_room_screen.dart
            │   └── lobby_screen.dart
            │
            └── widgets/
                ├── room_code_card.dart
                ├── lobby_player_tile.dart
                └── lobby_players_list.dart
```

This is only a conceptual structure.

DO NOT force this structure if the existing project follows another architecture.

Adapt to the project.

---

# 24. SQL Migration

Create ONE complete SQL migration containing:

* `game_rooms`
* `room_players`
* constraints
* indexes
* RLS enablement
* RLS policies
* Realtime configuration if applicable
* `create_game_room`
* `join_game_room`
* `start_game_room`
* host leave/cancel room operation
* required grants

The migration must be safe and readable.

Add SQL comments explaining security-critical operations.

Do not use the Supabase `service_role` key inside Flutter.

Never expose admin secrets to the Flutter client.

---

# 25. Existing Game Integration

The project already contains game logic or a game screen.

Inspect it before implementing navigation.

Do not create a fake replacement game unless no game screen exists.

Pass the required room identifier to the game feature.

Conceptual route:

```text
/game/:roomId
```

The game feature must be able to identify:

```text
roomId
currentPlayerId
hostId
```

Do not duplicate authentication state.

Use the existing authenticated user source.

---

# 26. Important Multiplayer Architecture Boundary

Supabase is being used for:

```text
Authentication
Room creation
Room code
Lobby
Player membership
Realtime lobby updates
Game start synchronization
```

Do NOT automatically use database row updates for high-frequency gameplay synchronization.

If the existing game requires:

* continuous movement
* physics synchronization
* shooting
* racing positions
* frame-level synchronization
* high-frequency player coordinates

STOP before implementing gameplay networking.

Analyze the game requirements first.

Explain whether the game requires:

```text
WebSocket authoritative server
```

or whether Supabase Realtime is sufficient.

Do not implement high-frequency gameplay state using repeated database UPDATE queries.

The current task is primarily the Room and Lobby system.

---

# 27. Testing Requirements

After implementation, verify the following scenarios.

## Test 1 — Create Room

Player A presses Host Game.

Expected:

```text
Room created.
Player A is host.
Unique room code displayed.
Lobby opens.
```

## Test 2 — Join Room

Player B enters Player A's room code.

Expected:

```text
Player B joins.
Player A sees Player B without refresh.
Player B sees Player A.
```

## Test 3 — Invalid Code

Player B enters:

```text
XXXXXX
```

Expected:

```text
Controlled Room Not Found error.
```

No crash.

## Test 4 — Room Full

Join a full room.

Expected:

```text
Room Full error.
```

## Test 5 — Start Game

Host presses Start Game.

Expected:

```text
Room becomes playing.
Host navigates to game.
All joined players navigate to game.
```

## Test 6 — Non-Host Start Attack

Attempt to call the start RPC as a normal player.

Expected:

```text
Database rejects the operation.
```

## Test 7 — Host Leaves

Host leaves a waiting room.

Expected:

```text
Room cancelled.
Other players receive realtime update.
Other players return to menu.
```

## Test 8 — Simultaneous Join

Multiple users attempt to join the final room slot.

Expected:

```text
Only the allowed number of players joins.
Room never exceeds max_players.
```

## Test 9 — Duplicate Join

Same user submits Join twice.

Expected:

```text
No duplicate room_players records.
```

## Test 10 — Realtime Reconnection

Temporarily disconnect and reconnect.

Expected:

```text
Lobby restores the latest state.
No duplicate subscriptions.
```

---

# 28. Code Quality Rules

Follow these rules strictly.

* Use null safety correctly.
* Do not use unnecessary `dynamic`.
* Do not use `Map<String, dynamic>` throughout the presentation layer.
* Parse database data into typed models.
* Reuse existing project components.
* Reuse existing theme.
* Reuse existing state management.
* Reuse existing authentication.
* Keep widgets focused.
* Keep Supabase queries outside UI widgets where architecture allows.
* Dispose realtime subscriptions.
* Handle Supabase exceptions.
* Protect against duplicate navigation.
* Protect against duplicate button actions.
* Use database transactions for critical operations.
* Use backend authorization for host-only operations.
* Never trust client-provided user IDs for security decisions.
* Use `auth.uid()` inside PostgreSQL functions.
* Never expose the Supabase service role key.
* Do not disable RLS.
* Do not modify unrelated code.

---

# 29. Agent Execution Process

Follow this exact process.

## Phase 1 — Analyze

Inspect the project.

Report:

```text
State management:
Routing:
Supabase setup:
Authentication source:
Player model:
Game screen:
Architecture pattern:
Files requiring modification:
New files required:
```

Do not make assumptions.

## Phase 2 — Plan

Create a concise implementation plan.

List:

```text
Database changes
Model changes
Repository changes
State management changes
UI changes
Routing changes
Realtime implementation
```

## Phase 3 — Implement Database

Create the complete SQL migration.

Review:

* transactions
* concurrency
* RLS
* RPC security
* grants

## Phase 4 — Implement Flutter Data Layer

Implement:

```text
Models
Supabase operations
Repository
Realtime streams
Exception mapping
```

## Phase 5 — Implement State Management

Implement lobby state according to the project's existing architecture.

Handle:

```text
create
join
watch room
watch players
start
leave
dispose
```

## Phase 6 — Implement UI

Implement:

```text
Join Room UI
Lobby UI
Host controls
Player list
Loading states
Error states
```

Match the existing design.

## Phase 7 — Integrate Routing

Connect:

```text
Host Game
Join Game
Lobby
Existing Game Screen
```

## Phase 8 — Review

Before declaring completion, inspect all modified files.

Check for:

```text
compile errors
missing imports
incorrect generated file references
invalid Riverpod/BLoC usage
incorrect route names
Supabase API misuse
unmanaged realtime subscriptions
race conditions
RLS vulnerabilities
duplicate navigation
```

## Phase 9 — Validation

Run the available project commands.

At minimum, when supported by the environment:

```bash
flutter pub get
flutter analyze
```

If the project uses code generation:

```bash
dart run build_runner build --delete-conflicting-outputs
```

Then run:

```bash
flutter analyze
```

Fix ALL errors introduced by this implementation.

Do not claim success if analyzer errors caused by the new implementation remain.

---

# 30. Final Agent Instructions

Do not provide only tutorial code.

Implement the feature directly in the existing project.

Do not create placeholders when real existing project components can be used.

Do not invent class names without checking the project.

Do not invent route names.

Do not invent user model properties.

Do not assume the authentication implementation.

Do not replace the project's architecture.

Do not leave TODO comments for core functionality.

Do not weaken database security to make the implementation easier.

Do not mark the task complete before reviewing the implementation.

The final result must provide a complete multiplayer Room and Lobby flow:

```text
HOST GAME
    ↓
CREATE ROOM
    ↓
GENERATE UNIQUE CODE
    ↓
LOBBY
    ↓
SHARE CODE
    ↓
SECOND PLAYER JOINS
    ↓
REALTIME PLAYER UPDATE
    ↓
HOST STARTS GAME
    ↓
ALL PLAYERS NAVIGATE TO GAME
```

The implementation must be production-oriented, secure, race-condition aware, and fully integrated with the existing Flutter project.
