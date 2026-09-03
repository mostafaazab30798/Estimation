// lib/services/reconnection_manager.dart
//
// Observes app lifecycle events and network state to detect disconnections
// and drive the recovery flow:
//
//   App resumes / cold start
//     └─ getActiveRoomSession()
//          ├─ null          → idle (nothing to recover)
//          └─ session found →
//               ├─ room finished/cancelled → clearSession(), idle
//               └─ room active →
//                    ├─ promoteNewHost() → self? → becomeHost()   [promoted]
//                    └─ otherwise       → rehydrateGameState()   [client]
//
// Heartbeat: every 15 s while the app is foregrounded and in a room.

import 'dart:async';

import 'package:flutter/widgets.dart';

import '../features/lobby/data/lobby_repository.dart';
import '../features/lobby/domain/models/game_room.dart';
import '../providers/game_provider.dart';
import 'session_storage_service.dart';

// ── State enum ────────────────────────────────────────────────────────────────

enum ReconnectionState {
  idle, // No in-progress recovery; nominal operation.
  reconnecting, // Attempting to recover a session.
  reconnected, // Recovery succeeded; UI may navigate accordingly.
  failed, // Recovery failed; user must retry or go home.
}

// ── Manager ───────────────────────────────────────────────────────────────────

class ReconnectionManager extends ChangeNotifier with WidgetsBindingObserver {
  final GameProvider _gameProvider;
  final LobbyRepository _lobbyRepo = LobbyRepository();

  SessionStorageService get _sessionService => _gameProvider.sessionService;

  ReconnectionState _state = ReconnectionState.idle;
  Timer? _heartbeatTimer;
  bool _heartbeatInFlight = false;

  // Check frequently enough that the server's 30-second bot threshold does
  // not drift toward the old 45–60 second observed takeover time.
  static const _heartbeatInterval = Duration(seconds: 5);

  ReconnectionManager(this._gameProvider);

  // ── Public getters ────────────────────────────────────────────────────────

  ReconnectionState get reconnectionState => _state;

  bool get isReconnecting => _state == ReconnectionState.reconnecting;
  bool get hasFailed => _state == ReconnectionState.failed;

  // ── Lifecycle ─────────────────────────────────────────────────────────────

  /// Register the observer and start the heartbeat loop.
  /// Call exactly once, right after construction.
  void start() {
    WidgetsBinding.instance.addObserver(this);
    _startHeartbeat();
    debugPrint('[Reconnection] Manager started');
  }

  /// Unregister and cancel the heartbeat. Called on dispose.
  void stop() {
    WidgetsBinding.instance.removeObserver(this);
    _stopHeartbeat();
    debugPrint('[Reconnection] Manager stopped');
  }

  // ── Heartbeat ─────────────────────────────────────────────────────────────

  void _startHeartbeat() {
    _heartbeatTimer?.cancel();
    _heartbeatTimer = Timer.periodic(_heartbeatInterval, (_) => _ping());
  }

  void _stopHeartbeat() {
    _heartbeatTimer?.cancel();
    _heartbeatTimer = null;
  }

  Future<void> _ping() async {
    if (_heartbeatInFlight) return;
    if (_gameProvider.isTemporarilyAway) {
      return;
    }

    // A normal join/start owns the connection while it is in progress.
    // Recovery racing it can tear down the fresh client and show a false
    // connection-lost dialog over a valid game.
    if (_gameProvider.status == ConnectionStatus.connecting) {
      return;
    }
    final roomId = _gameProvider.currentRoom?.id;
    if (roomId == null ||
        roomId.startsWith('local_') ||
        _gameProvider.isLocal) {
      return;
    }
    _heartbeatInFlight = true;
    try {
      final heartbeat = await _lobbyRepo.pingHeartbeat(roomId);
      if (heartbeat.deviceConflict) {
        await _gameProvider.relinquishSeatToOtherDevice();
        return;
      }
      if (heartbeat.botTakeoverStarted) {
        await _gameProvider.advanceServerBotsAfterTakeover();
      }
    } catch (e) {
      final errorStr = e.toString();
      if (!errorStr.contains('SocketException') &&
          !errorStr.contains('AuthRetryableFetchException')) {
        debugPrint('[Reconnection] Heartbeat failed: $e');
      }
    } finally {
      _heartbeatInFlight = false;
    }
  }

  // ── WidgetsBindingObserver ────────────────────────────────────────────────

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    switch (state) {
      case AppLifecycleState.paused:
        _onAppPaused();
      case AppLifecycleState.detached:
        _onAppPaused();
        if (_gameProvider.isTestMode || _gameProvider.isLocal) {
          _gameProvider.reset();
        }
      case AppLifecycleState.resumed:
        _onAppResumed();
      case AppLifecycleState.inactive:
      case AppLifecycleState.hidden:
        break; // No action needed for transient states
    }
  }

  Future<void> _onAppPaused() async {
    _stopHeartbeat();
    // Bot/local games are in-memory only — keep them alive when the app is
    // briefly backgrounded. Explicit leave + process detach still call reset().
    if (_gameProvider.isTestMode || _gameProvider.isLocal) {
      return;
    }
    final roomId = _gameProvider.currentRoom?.id;
    if (roomId == null ||
        roomId.startsWith('local_') ||
        _gameProvider.isLocal) {
      return;
    }
    try {
      await _lobbyRepo.markOffline(roomId);
      debugPrint('[Reconnection] Marked offline — room $roomId');
    } catch (e) {
      debugPrint('[Reconnection] markOffline failed: $e');
    }
  }

  Future<void> _onAppResumed() async {
    _startHeartbeat();

    // User chose "leave to home" — keep the seat reserved but do not
    // silently rejoin in the background. They tap "return" to resume.
    if (_gameProvider.isTemporarilyAway) {
      return;
    }

    // If we are already live in a room, just refresh the heartbeat.
    if (_gameProvider.status == ConnectionStatus.connected &&
        _gameProvider.currentRoom != null) {
      await _ping();
      return;
    }

    // Otherwise attempt to recover a dangling session.
    await _attemptRecovery();
  }

  // ── Cold-start check (called by HomeScreen) ───────────────────────────────

  /// Check for a stored session on cold start. Returns the resulting state.
  Future<ReconnectionState> checkOnStartup() async {
    // If we are already connected (e.g., the HomeScreen is visited mid-game
    // for some reason) do nothing.
    if (_gameProvider.status == ConnectionStatus.connected ||
        _gameProvider.status == ConnectionStatus.connecting) {
      return ReconnectionState.idle;
    }
    return _attemptRecovery();
  }

  Future<ActiveRoomSession?> getPendingSession() async {
    final session = await _sessionService.getActiveRoomSession();
    if (session == null) return null;
    try {
      // Expire an abandoned server seat before trusting the local reconnect
      // token. Otherwise a cold-start recovery can heartbeat yesterday's room
      // and turn an already stale membership into a fresh five-minute block.
      await _lobbyRepo.processRoomAbsences(session.roomId);
      final room = await _lobbyRepo.getRoom(session.roomId);
      if (room.status == GameRoomStatus.cancelled ||
          room.status == GameRoomStatus.finished) {
        await _sessionService.clearSession();
        return null;
      }
      final stillMember =
          await _lobbyRepo.isPlayerInRoom(session.roomId, session.playerId);
      if (!stillMember) {
        await _sessionService.clearSession();
        return null;
      }
      return session;
    } catch (error) {
      debugPrint('[Reconnection] Pending-session check failed: $error');
      await _sessionService.clearSession();
      return null;
    }
  }

  Future<ReconnectionState> recoverPendingSession() => _attemptRecovery();

  /// Recover a server-advertised seat even when this installation has never
  /// stored the room locally (for example, the player switches phones).
  Future<ReconnectionState> recoverRoomFromGate(String roomId) async {
    try {
      await _lobbyRepo.processRoomAbsences(roomId);
      final room = await _lobbyRepo.getRoom(roomId);
      final player = await _lobbyRepo.fetchCurrentPlayer(roomId);
      if (player == null ||
          room.status == GameRoomStatus.cancelled ||
          room.status == GameRoomStatus.finished) {
        await _sessionService.clearSession();
        return ReconnectionState.failed;
      }
      await _sessionService.saveActiveRoomSession(
        roomId: room.id,
        roomCode: room.roomCode,
        playerId: player.playerId,
        playerName: player.playerName,
        isHost: room.hostId == player.playerId,
      );
      return _attemptRecovery();
    } catch (error) {
      debugPrint('[Reconnection] Could not prepare server recovery: $error');
      return ReconnectionState.failed;
    }
  }

  // ── Recovery flow ─────────────────────────────────────────────────────────

  Future<ReconnectionState> _attemptRecovery() async {
    if (_gameProvider.status == ConnectionStatus.connecting) {
      _setState(ReconnectionState.idle);
      return ReconnectionState.idle;
    }
    if (_gameProvider.status == ConnectionStatus.connected &&
        _gameProvider.currentRoom != null) {
      _setState(ReconnectionState.idle);
      await _ping();
      return ReconnectionState.idle;
    }
    final session = await _sessionService.getActiveRoomSession();
    if (session == null) return ReconnectionState.idle;
    if (_gameProvider.status == ConnectionStatus.connecting ||
        (_gameProvider.status == ConnectionStatus.connected &&
            _gameProvider.currentRoom != null)) {
      _setState(ReconnectionState.idle);
      return ReconnectionState.idle;
    }

    if (session.roomId.startsWith('test_') ||
        session.roomId.startsWith('local_')) {
      debugPrint(
          '[Reconnection] Local or test mode session detected (${session.roomId}); clearing session');
      await _sessionService.clearSession();
      _setState(ReconnectionState.idle);
      return ReconnectionState.idle;
    }

    _setState(ReconnectionState.reconnecting);
    debugPrint(
        '[Reconnection] Attempting recovery for room ${session.roomId}…');

    try {
      // Server cleanup must win the race against resume/heartbeat. A local
      // session is only a reconnect hint; it is not proof that the seat is
      // still recoverable.
      await _lobbyRepo.processRoomAbsences(session.roomId);
      final room = await _lobbyRepo.getRoom(session.roomId);
      final stillMember =
          await _lobbyRepo.isPlayerInRoom(session.roomId, session.playerId);
      if (room.status == GameRoomStatus.cancelled ||
          room.status == GameRoomStatus.finished ||
          !stillMember) {
        debugPrint(
            '[Reconnection] Stored session is no longer recoverable; clearing it');
        await _sessionService.clearSession();
        _setState(ReconnectionState.idle);
        return ReconnectionState.idle;
      }

      // Exactly one installation may own a Google account's active seat.
      // Offline seats are claimable by either phone; the row lock on the RPC
      // makes simultaneous taps deterministic and rejects the loser.
      final claimed = await _lobbyRepo.claimRoomDevice(session.roomId);
      if (!claimed) {
        debugPrint('[Reconnection] Seat is active on another device');
        _setState(ReconnectionState.failed);
        return ReconnectionState.failed;
      }

      if (_gameProvider.canResumeTemporarilyLeftGame) {
        final success = await _gameProvider.resumeTemporarilyLeftGame(session);
        _setState(
            success ? ReconnectionState.reconnected : ReconnectionState.failed);
        return _state;
      }
      // ── 1. Verify room is still active ──────────────────────────────────
      if (_gameProvider.status == ConnectionStatus.connecting ||
          (_gameProvider.status == ConnectionStatus.connected &&
              _gameProvider.currentRoom != null)) {
        _setState(ReconnectionState.idle);
        return ReconnectionState.idle;
      }

      if (room.status == GameRoomStatus.cancelled ||
          room.status == GameRoomStatus.finished) {
        debugPrint(
            '[Reconnection] Room is dead (${room.status.name}); clearing session');
        await _sessionService.clearSession();
        _setState(ReconnectionState.idle);
        return ReconnectionState.idle;
      }

      // ── 2. Try host promotion ────────────────────────────────────────────
      // The RPC is a no-op if the current host is still healthy.
      final newHostId = await _lobbyRepo.promoteNewHost(session.roomId);

      if (newHostId != null && newHostId == session.playerId) {
        // This device has been elected as the new host.
        debugPrint('[Reconnection] Promoted to host!');
        await _sessionService.updateIsHost(isHost: true);

        final success = await _gameProvider.becomeHost(session);
        if (!success) {
          await _sessionService.clearSession();
          _setState(ReconnectionState.failed);
          return ReconnectionState.failed;
        }
      } else {
        // ── 3. Reconnect as client ─────────────────────────────────────────
        _gameProvider.restoreIdentity(
          playerId: session.playerId,
          playerName: session.playerName,
        );

        final success = await _gameProvider.rehydrateGameState(session.roomId);
        if (!success) {
          await _sessionService.clearSession();
          _setState(ReconnectionState.failed);
          return ReconnectionState.failed;
        }
      }

      _setState(ReconnectionState.reconnected);
      debugPrint('[Reconnection] Recovery succeeded');
      return ReconnectionState.reconnected;
    } catch (e) {
      debugPrint('[Reconnection] Recovery threw: $e');
      if (_gameProvider.status == ConnectionStatus.connecting ||
          (_gameProvider.status == ConnectionStatus.connected &&
              _gameProvider.currentRoom != null)) {
        _setState(ReconnectionState.idle);
        return ReconnectionState.idle;
      }
      await _sessionService.clearSession();
      _setState(ReconnectionState.failed);
      return ReconnectionState.failed;
    }
  }

  // ── User-triggered actions ────────────────────────────────────────────────

  /// Retry after a failed recovery attempt.
  Future<void> retry() async {
    _setState(ReconnectionState.idle);
    await _attemptRecovery();
  }

  /// Abandon recovery: clear session and reset to idle.
  /// The caller is responsible for navigating to the home screen.
  Future<void> dismissAndGoHome() async {
    _stopHeartbeat();
    await _gameProvider.reset();
    _setState(ReconnectionState.idle);
  }

  // ── Helpers ───────────────────────────────────────────────────────────────

  void _setState(ReconnectionState newState) {
    if (_state == newState) return;
    _state = newState;
    notifyListeners();
  }

  // The WidgetsBindingObserver mixin provides default no-op implementations
  // for all observer methods. We only override the three we care about:
  //   didChangeAppLifecycleState  (above)
  // Everything else is handled by the mixin automatically.

  @override
  void dispose() {
    stop();
    super.dispose();
  }
}
