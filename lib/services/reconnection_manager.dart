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
  idle,         // No in-progress recovery; nominal operation.
  reconnecting, // Attempting to recover a session.
  reconnected,  // Recovery succeeded; UI may navigate accordingly.
  failed,       // Recovery failed; user must retry or go home.
}

// ── Manager ───────────────────────────────────────────────────────────────────

class ReconnectionManager extends ChangeNotifier
    with WidgetsBindingObserver {
  final GameProvider _gameProvider;
  final LobbyRepository _lobbyRepo = LobbyRepository();

  SessionStorageService get _sessionService => _gameProvider.sessionService;

  ReconnectionState _state = ReconnectionState.idle;
  Timer? _heartbeatTimer;

  static const _heartbeatInterval  = Duration(seconds: 15);

  ReconnectionManager(this._gameProvider);

  // ── Public getters ────────────────────────────────────────────────────────

  ReconnectionState get reconnectionState => _state;

  bool get isReconnecting => _state == ReconnectionState.reconnecting;
  bool get hasFailed      => _state == ReconnectionState.failed;

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
    final roomId = _gameProvider.currentRoom?.id;
    if (roomId == null) return;
    try {
      await _lobbyRepo.pingHeartbeat(roomId);
    } catch (e) {
      debugPrint('[Reconnection] Heartbeat failed: $e');
    }
  }

  // ── WidgetsBindingObserver ────────────────────────────────────────────────

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    switch (state) {
      case AppLifecycleState.paused:
      case AppLifecycleState.detached:
        _onAppPaused();
      case AppLifecycleState.resumed:
        _onAppResumed();
      case AppLifecycleState.inactive:
      case AppLifecycleState.hidden:
        break; // No action needed for transient states
    }
  }

  Future<void> _onAppPaused() async {
    _stopHeartbeat();
    final roomId = _gameProvider.currentRoom?.id;
    if (roomId == null) return;
    try {
      await _lobbyRepo.markOffline(roomId);
      debugPrint('[Reconnection] Marked offline — room $roomId');
    } catch (e) {
      debugPrint('[Reconnection] markOffline failed: $e');
    }
  }

  Future<void> _onAppResumed() async {
    _startHeartbeat();

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
    if (_gameProvider.status == ConnectionStatus.connected) {
      return ReconnectionState.idle;
    }
    return _attemptRecovery();
  }

  // ── Recovery flow ─────────────────────────────────────────────────────────

  Future<ReconnectionState> _attemptRecovery() async {
    final session = await _sessionService.getActiveRoomSession();
    if (session == null) return ReconnectionState.idle;

    _setState(ReconnectionState.reconnecting);
    debugPrint('[Reconnection] Attempting recovery for room ${session.roomId}…');

    try {
      // ── 1. Verify room is still active ──────────────────────────────────
      final room = await _lobbyRepo.getRoom(session.roomId);

      if (room.status == GameRoomStatus.cancelled ||
          room.status == GameRoomStatus.finished) {
        debugPrint('[Reconnection] Room is dead (${room.status.name}); clearing session');
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
          _setState(ReconnectionState.failed);
          return ReconnectionState.failed;
        }
      } else {
        // ── 3. Reconnect as client ─────────────────────────────────────────
        _gameProvider.restoreIdentity(
          playerId:   session.playerId,
          playerName: session.playerName,
        );

        final success =
            await _gameProvider.rehydrateGameState(session.roomId);
        if (!success) {
          _setState(ReconnectionState.failed);
          return ReconnectionState.failed;
        }
      }

      _setState(ReconnectionState.reconnected);
      debugPrint('[Reconnection] Recovery succeeded');
      return ReconnectionState.reconnected;
    } catch (e) {
      debugPrint('[Reconnection] Recovery threw: $e');
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
    await _sessionService.clearSession();
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
