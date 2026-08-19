# Task: Add LAN-based Offline Multiplayer Mode

## Context — read this first

This is a Flutter Dart estimation card game (Kotchina + a "99" mode) with a Supabase
backend. Multiplayer currently works ONLY over Supabase Realtime Broadcast channels.
Your job is to add a second, fully offline transport that works over the local network
(same WiFi or a host's hotspot with no internet at all), without touching game logic.

**Do not skip the "Explore first" step.** File contents described below reflect a
snapshot of the repo; confirm current state before editing, since the code may have
changed.

## Why this is a clean task (architecture summary)

The game already separates concerns well:

- `lib/core/game_engine.dart` + `lib/core/models/game_state.dart` — pure game logic,
  no networking imports. `GameState` and `Player` already have `toJson()`/`fromJson()`.
- `lib/networking/messages.dart` — transport-agnostic message envelope:
  ```dart
  class GameMessage {
    final MessageType type; // stateUpdate, playerJoined, error, playerAction, joinRequest, heartbeat
    final Map<String, dynamic> payload;
    String toJsonString() => jsonEncode(toJson());
    factory GameMessage.fromJsonString(String s) => ...
  }
  class ActionType {
    static const submitBid = 'submitBid';
    // ... etc, see file for full list
  }
  ```
- `lib/networking/game_server.dart` (`GameServer`) — HOST-AUTHORITATIVE. Owns the real
  `GameEngine`, mutates `GameState`, calls `_broadcastState()` on every change. The
  networking-specific parts are isolated to a Supabase `RealtimeChannel`
  (`channel()`, `.onBroadcast()`, `.sendBroadcastMessage()`, presence tracking).
- `lib/networking/game_client.dart` (`GameClient`) — connects to the host's Supabase
  channel, listens for `state`/`error` broadcasts, calls `sendAction()` to send player
  actions to the host.
- `lib/modes/ninety_nine/networking/ninety_nine_game_server.dart` /
  `ninety_nine_game_client.dart` — the SAME pattern duplicated for the second game
  mode. Treat as a second instance of the same problem; do NOT special-case it.
- `lib/providers/game_provider.dart` (`GameProvider`) — the single place that decides
  whether to instantiate `GameServer`/`GameClient` (or the ninety-nine equivalents) and
  wires their callbacks to app state (`_state`, `notifyListeners()`).
- `lib/features/lobby/domain/models/game_room.dart` (`GameRoom`) — **already has
  `hostIp` and `wsPort` fields**, currently unused (`GameProvider` passes hardcoded
  placeholders `hostIp: '127.0.0.1', wsPort: 0` when creating a room — see
  `game_provider.dart` around the `createRoom` call). Investigate whether these fields
  were scaffolded for exactly this feature, whether Supabase's room schema
  (RPC `create_room` or equivalent) already stores them usefully, and whether you
  should repurpose them or add new fields/table for local rooms. Don't assume — check
  the actual Supabase schema/RPC before deciding.
- `lib/services/reconnection_manager.dart` — app-lifecycle-driven reconnect flow, tied
  to Supabase session persistence (`session_storage_service.dart`). Local mode needs an
  analogous but simpler reconnect path (see Phase 4).

**Because game logic and message shape are already transport-agnostic, this task is a
transport swap, not a rewrite.** Do not modify `GameEngine`, `GameState`, `Player`,
`Bid`, or any card/model logic. Do not modify game logic inside `GameServer`'s action
handlers — only its I/O plumbing is being replaced in the new local variant.

## Goal

Add a "Play Offline (Local)" path alongside the existing "Play Online" path so a group
of players on the same physical network (shared WiFi, or the host's phone hotspot —
internet connectivity to the WAN is NOT required in either case) can play with:

- No dependency on Supabase reachability once the local session starts.
- Host-authoritative state, identical semantics to the online mode.
- Discovery of nearby games without players typing IP addresses (with a manual
  fallback).
- Reasonable reconnect behavior if a player's WiFi hiccups mid-game.

## Explore first (do this before writing any code)

1. Read `lib/networking/game_server.dart`, `lib/networking/game_client.dart`,
   `lib/networking/messages.dart` in full.
2. Read the ninety-nine equivalents in `lib/modes/ninety_nine/networking/`.
3. Read `lib/providers/game_provider.dart` in full — especially every place `_server`,
   `_client`, `_nnServer`, `_nnClient` are constructed, and the `createRoom`/`joinRoom`
   flows, `_listenToRoom`, and the reconnection-related methods near the bottom of the
   file.
4. Read `lib/features/lobby/data/lobby_repository.dart` and
   `lib/features/lobby/domain/models/game_room.dart` — confirm what `createRoom` sends
   to Supabase and what `hostIp`/`wsPort` currently do (if anything) server-side.
5. Read `lib/services/reconnection_manager.dart` and `session_storage_service.dart`.
6. Read `lib/screens/mode_selection_screen.dart`, `lib/screens/home_screen.dart`,
   `lib/screens/lobby_screen.dart` to find where "create room" / "join room" UI lives,
   since a new entry point needs to be added there.
7. Check `pubspec.yaml` for existing dependencies before adding new ones (avoid
   duplicate/conflicting packages).
8. Confirm target platforms (Android/iOS/both) — this affects the discovery package
   choice (see Phase 2).

## Non-negotiable constraints

- **Zero internet dependency for local mode.** No code path in the local transport may
  call Supabase for anything gameplay-related. It's fine (and expected) for the
  existing online path to keep using Supabase exactly as it does today — the two modes
  coexist, they don't replace each other.
- **Host-authoritative, unchanged engine.** `GameEngine`/`GameState` must not need to
  know which transport is active.
- **Match existing method signatures.** New classes should expose the same shape as
  `GameServer`/`GameClient` (`start(...)`, `stop()`, `connect(...)`, `disconnect(...)`,
  `sendAction(...)`, `onStateUpdate`, `onError`) so `GameProvider` changes are additive
  (branch on a mode flag), not a rewrite of `GameProvider`.
- **Reuse `GameMessage`/`ActionType` as the wire format.** Don't invent a new protocol.
  Local transport sends `GameMessage(...).toJsonString()` as WebSocket text frames and
  parses incoming frames with `GameMessage.fromJsonString(...)`.
- **Don't break the online path.** No changes to `GameServer`/`GameClient`'s Supabase
  behavior unless you're extracting a truly shared interface (see Phase 3, optional).

## Phase 1 — Local transport core

Create `lib/networking/local/`:

- `local_game_server.dart` — `LocalGameServer` class:
  - Constructor: `LocalGameServer({required StateUpdateCallback onStateUpdate})` —
    same shape as `GameServer`.
  - Internally owns a `GameEngine`/`GameState` exactly like `GameServer` does today —
    consider whether to literally reuse `GameServer`'s private game-logic methods via
    composition/inheritance rather than copy-pasting the ~800 lines of action-handling
    logic in `game_server.dart`. Prefer extracting the transport-independent parts of
    `GameServer` into a shared base/mixin over duplicating them. Use your judgment
    after reading the file — the goal is one source of truth for game rules, two
    sources for I/O.
  - Runs a `shelf` + `shelf_web_socket` HTTP/WebSocket server bound to
    `InternetAddress.anyIPv4` on a free or fixed port.
  - On client connect: track the `WebSocketChannel`, listen for `GameMessage` frames
    (`playerAction`, `joinRequest`, `leaveRequest`, `heartbeat` — mirror
    `_handlePlayerAction`/`_handleJoinRequest`/`_handleLeaveRequest` from
    `game_server.dart`).
  - On every state mutation: broadcast `GameMessage(type: MessageType.stateUpdate,
    payload: state.toJson())` to all connected sockets (mirror `_broadcastState`).
  - Expose the bound port and the host's local IP (via `NetworkInfo` or similar) so it
    can be shown/advertised for joining.
  - `stop()` closes all sockets and shuts down the HTTP server cleanly.

- `local_game_client.dart` — `LocalGameClient` class:
  - Constructor: `LocalGameClient({required StateUpdateCallback onStateUpdate,
    required ErrorCallback onError})` — same shape as `GameClient`.
  - `connect(String hostIp, int port, String playerId, String playerName, String
    playerPhoto)` — opens a `WebSocketChannel.connect(Uri.parse('ws://$hostIp:$port'))`,
    sends a `joinRequest` `GameMessage`, listens for `stateUpdate`/`error` messages,
    parses `GameState.fromJson` exactly like `GameClient._handleStateUpdate` does.
  - `sendAction(String action, String playerId, [Map extra])` — sends a
    `playerAction` `GameMessage`.
  - `disconnect(String playerId)` — sends `leaveRequest`, closes the socket.
  - On unexpected socket closure: do NOT immediately surface a fatal error to the UI
    (same reasoning as the comment in `game_client.dart` about not calling `onError`
    on `channelError`) — instead expose a reconnecting state and attempt a bounded
    number of reconnect attempts to the same `hostIp:port` (see Phase 4).

Repeat the equivalent pair for the 99 mode (`lib/modes/ninety_nine/networking/local_ninety_nine_game_server.dart` /
`local_ninety_nine_game_client.dart`) reusing whatever shared base you built above.

## Phase 2 — Discovery

Add `lib/networking/local/local_discovery_service.dart`:

- Host side: after `LocalGameServer.start()` binds successfully, advertise the service
  via mDNS (`nsd` package — supports Android + iOS — or `bonsoir` as an alternative;
  check current pub.dev status/maintenance of both before picking, since this
  information may be stale) under a service type like `_pocketestimation._tcp`, with
  TXT records for room name/host name/game type/current player count.
- Client side: a "Find Games Nearby" screen/dialog that browses for that service type
  and lists discovered hosts (name + player count), tapping one triggers
  `LocalGameClient.connect(discoveredIp, discoveredPort, ...)`.
- **Always include a manual fallback**: a text field for entering `hostIp` (and port,
  or fix the port to a constant like `7890` to simplify this) directly, since mDNS can
  fail on some router/hotspot configurations. Show the host's own IP prominently on
  the hosting screen so this is easy to do by hand if discovery fails.
- Handle the Android local-network / nearby-devices runtime permission prompt (required
  on newer Android versions for mDNS) and the iOS local network usage description in
  `Info.plist` (`NSLocalNetworkUsageDescription`) — add whatever the chosen package's
  docs specify. Verify current requirements against the package's own documentation
  rather than assuming, since OS permission requirements change across versions.

## Phase 3 — Wire into `GameProvider` and UI

1. In `GameProvider`, add a `ConnectionMode { online, local }` (or similar) distinct
   from the existing `ConnectionRole`. Wherever `_server = GameServer(...)` /
   `_client = GameClient(...)` (and the ninety-nine equivalents) are constructed,
   branch on this mode to construct the local variants instead. Keep field types as a
   shared interface/abstract class if that keeps this branching clean — introduce one
   only if it clearly reduces duplication versus a straightforward `if/else`; don't
   over-engineer this.
2. Local mode does not need `_lobbyRepo.createRoom(...)` (Supabase) at all — a locally
   hosted room doesn't need a Supabase row. Skip that call entirely on the local path
   rather than sending placeholder values.
3. Add UI entry points in `mode_selection_screen.dart` / `home_screen.dart`: "Play
   Offline (Local)" alongside the existing online option, leading to a
   host-or-join choice, then either the hosting screen (shows IP/port + "waiting for
   players", reuses as much of `lobby_screen.dart` as sensibly possible) or the
   "Find Games Nearby" screen from Phase 2.
4. Confirm `lobby_screen.dart` can operate against `LocalGameServer`/`LocalGameClient`
   state (player list, ready-up, start button for the host) without Supabase-specific
   assumptions leaking in — check for any direct Supabase calls inside that screen and
   route them through `GameProvider` instead if found.

## Phase 4 — Reconnection (local mode)

Do not reuse `ReconnectionManager` as-is (it's built around Supabase session rows and
`session_storage_service.dart`'s persisted room/session data). Instead:

- In `LocalGameClient`, on socket closure, attempt to reconnect to the last-known
  `hostIp:port` a small number of times with backoff (e.g. 3 attempts, 1–2s apart)
  before surfacing a "connection lost" state to `GameProvider`.
- In `LocalGameServer`, if a connected socket drops, keep that player's seat/hand
  intact for a grace period (don't immediately remove them from `GameState`, unlike
  the Supabase presence-leave behavior in `game_server.dart` which removes players
  during the lobby phase) so a brief WiFi hiccup doesn't eject someone from a game in
  progress. Match whatever grace-period/removal behavior the online path currently has
  during active play (check `game_server.dart` for how mid-game disconnects are
  handled today, if at all) rather than inventing new semantics.
- No persistence is required across an app restart for local mode unless you decide
  it's worth it — flag this as an open question rather than assuming; a full local
  session-restore (host rebinding to the same port, clients re-discovering it) is a
  reasonable v2, not required for v1.

## Phase 5 — Testing checklist

Before considering this done, verify:

- [ ] Host can start a local game with airplane mode + WiFi hotspot on (i.e.
      literally no WAN route) and it works end to end.
- [ ] A second device can discover and join via mDNS on the same hotspot.
- [ ] A second device can join via manual IP entry when mDNS is disabled/blocked.
- [ ] Full game round (bid → play → score) completes correctly for both Kotchina and
      99 modes over local transport, matching existing online-mode behavior.
- [ ] Killing WiFi on a client mid-game and restoring it within the grace period
      does not eject the player or corrupt state.
- [ ] Existing online (Supabase) mode is unaffected — run through its existing flow
      to confirm no regression.
- [ ] `flutter analyze` is clean for all new/changed files.

## Explicitly out of scope for this task

- Bluetooth/BLE or `nearby_connections`-based transport (WebSocket-over-LAN is
  sufficient for this use case; don't add it unless asked).
- Cross-network play (players not on the same LAN/hotspot) — that's what the existing
  Supabase online mode is for.
- Any change to bot logic, scoring rules, or card assets.