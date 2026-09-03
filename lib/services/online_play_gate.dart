import 'dart:async';

import 'package:flutter/foundation.dart';

import '../features/lobby/data/lobby_repository.dart';
import '../features/lobby/domain/models/game_room.dart';
import '../features/lobby/domain/models/online_play_status.dart';
import 'session_storage_service.dart';

/// Tracks whether the user may enter online matchmaking and exposes countdowns.
class OnlinePlayGate extends ChangeNotifier {
  OnlinePlayGate({
    LobbyRepository? lobbyRepository,
    SessionStorageService? sessionStorage,
  })  : _lobbyRepo = lobbyRepository ?? LobbyRepository(),
        _sessionStorage = sessionStorage ?? SessionStorageService();

  final LobbyRepository _lobbyRepo;
  final SessionStorageService _sessionStorage;

  OnlinePlayStatus _status = const OnlinePlayStatus(canJoinNewOnline: true);
  Timer? _countdownTimer;
  Timer? _syncTimer;
  bool _refreshInFlight = false;
  int _consecutiveFailures = 0;
  OnlinePlayStatus? _lastGoodStatus;
  bool _suppressedForActiveGame = false;

  OnlinePlayStatus get status => _status;

  bool get canJoinNewOnline => _status.canJoinNewOnline;

  bool get canReturnToOngoingGame => _status.canReturnToOngoingGame;

  bool get isBanOnlyBlock =>
      !_status.canJoinNewOnline &&
      !_status.canReturnToOngoingGame &&
      _status.remainingBlock().inSeconds > 0;

  Duration get remainingBlock => _status.remainingBlock(DateTime.now().toUtc());

  String get remainingLabel {
    final total = remainingBlock.inSeconds;
    if (total <= 0) return '';
    final minutes = total ~/ 60;
    final seconds = total % 60;
    return '${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
  }

  /// Stops background gate polling while the player is in an online room/game.
  void suppressWhileInMatch() {
    _suppressedForActiveGame = true;
    _stopTimers();
  }

  /// Re-enables gate polling after leaving matchmaking/home-only flows.
  void resumeAfterLeavingMatch() {
    _suppressedForActiveGame = false;
  }

  Duration get _syncInterval {
    if (_status.activeOnAnotherDevice) return const Duration(seconds: 5);
    if (_consecutiveFailures <= 0) return const Duration(seconds: 15);
    if (_consecutiveFailures < 3) return const Duration(seconds: 20);
    return const Duration(seconds: 30);
  }

  void startPolling({bool immediate = true}) {
    if (_suppressedForActiveGame) return;
    if (immediate) {
      unawaited(refresh());
    }
    _ensureCountdownTick();
    _scheduleServerSync();
  }

  void _ensureCountdownTick() {
    if (_countdownTimer != null) return;
    _countdownTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (canJoinNewOnline || _suppressedForActiveGame) {
        _countdownTimer?.cancel();
        _countdownTimer = null;
        return;
      }
      notifyListeners();
    });
  }

  void _scheduleServerSync() {
    if (_syncTimer != null) return;
    _syncTimer = Timer(_syncInterval, () {
      _syncTimer = null;
      if (_suppressedForActiveGame || canJoinNewOnline) return;
      unawaited(
        refresh(silent: true).whenComplete(() {
          if (!_suppressedForActiveGame && !canJoinNewOnline) {
            _scheduleServerSync();
          }
        }),
      );
    });
  }

  void stopPolling() {
    _stopTimers();
  }

  void _stopTimers() {
    _countdownTimer?.cancel();
    _countdownTimer = null;
    _syncTimer?.cancel();
    _syncTimer = null;
  }

  Future<OnlinePlayStatus> refresh({bool silent = false}) async {
    if (_suppressedForActiveGame) return _status;
    if (_refreshInFlight) return _status;
    _refreshInFlight = true;
    try {
      final session = await _sessionStorage.getActiveRoomSession();
      final fetched = await _lobbyRepo.getOnlinePlayStatus();

      OnlinePlayStatus next;
      if (fetched != null) {
        _consecutiveFailures = 0;
        _lastGoodStatus = fetched;
        next = fetched;
      } else {
        _consecutiveFailures++;
        next = _statusForNetworkFailure(session);
      }

      next = await _reconcileSessionWithServer(
        next,
        session,
        serverAuthoritative: fetched != null,
      );
      next = await _recoverStaleBlock(next, session);

      if (!next.hasActiveMembership &&
          !next.canReturnToOngoingGame &&
          fetched != null) {
        await _sessionStorage.clearSession();
      }

      final changed = _status.canJoinNewOnline != next.canJoinNewOnline ||
          _status.blockedUntil != next.blockedUntil ||
          _status.hasActiveMembership != next.hasActiveMembership ||
          _status.activeOnAnotherDevice != next.activeOnAnotherDevice ||
          _status.recoveryAvailable != next.recoveryAvailable;

      _status = next;

      if (changed || !silent) {
        notifyListeners();
      }

      if (canJoinNewOnline) {
        stopPolling();
      } else if (_syncTimer == null && !_suppressedForActiveGame) {
        startPolling(immediate: false);
      }

      return _status;
    } finally {
      _refreshInFlight = false;
    }
  }

  OnlinePlayStatus _statusForNetworkFailure(ActiveRoomSession? session) {
    if (_lastGoodStatus != null) return _lastGoodStatus!;
    if (session != null) {
      return OnlinePlayStatus(
        canJoinNewOnline: false,
        hasActiveMembership: true,
        roomId: session.roomId,
        graceEndsAt: _status.graceEndsAt,
      );
    }
    return _status;
  }

  Future<OnlinePlayStatus> _reconcileSessionWithServer(
    OnlinePlayStatus next,
    ActiveRoomSession? session, {
    required bool serverAuthoritative,
  }) async {
    if (session == null) return next;
    if (next.hasActiveMembership && next.roomId != null) return next;

    // A successful server response is authoritative. Never let a stale local
    // reconnect token replace an explicit "may join" result with a phantom
    // five-minute block.
    if (serverAuthoritative && next.canJoinNewOnline) {
      await _sessionStorage.clearSession();
      return next;
    }

    GameRoom? room;
    try {
      await _lobbyRepo.processRoomAbsences(session.roomId);
      room = await _lobbyRepo.getRoom(session.roomId);
      if (room.status == GameRoomStatus.cancelled ||
          room.status == GameRoomStatus.finished) {
        await _lobbyRepo.processRoomAbsences(session.roomId);
        await _sessionStorage.clearSession();
        return await _lobbyRepo.getOnlinePlayStatus() ??
            const OnlinePlayStatus(canJoinNewOnline: true);
      }
    } catch (error) {
      debugPrint('[OnlinePlayGate] Room lookup failed: $error');
      return _localSessionBlock(session, next);
    }

    var stillMember =
        await _lobbyRepo.isPlayerInRoom(session.roomId, session.playerId);
    if (!stillMember) {
      await _sessionStorage.clearSession();
      return await _lobbyRepo.getOnlinePlayStatus() ??
          const OnlinePlayStatus(canJoinNewOnline: true);
    }

    if (room.status == GameRoomStatus.playing) {
      return _localSessionBlock(session, next, roomStatus: room.status.name);
    }

    return next;
  }

  OnlinePlayStatus _localSessionBlock(
    ActiveRoomSession session,
    OnlinePlayStatus next, {
    String? roomStatus,
  }) {
    return OnlinePlayStatus(
      canJoinNewOnline: false,
      hasActiveMembership: true,
      roomId: session.roomId,
      roomStatus: roomStatus ?? next.roomStatus,
      graceEndsAt: next.graceEndsAt ?? _lastGoodStatus?.graceEndsAt,
      onlineBanUntil: next.onlineBanUntil ?? _lastGoodStatus?.onlineBanUntil,
    );
  }

  Future<OnlinePlayStatus> _recoverStaleBlock(
    OnlinePlayStatus next,
    ActiveRoomSession? session,
  ) async {
    if (!next.isStaleBlock) return next;

    if (session != null) {
      await _lobbyRepo.processRoomAbsences(session.roomId);
    }
    await _sessionStorage.clearSession();

    final refreshed = await _lobbyRepo.getOnlinePlayStatus();
    if (refreshed == null ||
        refreshed.isStaleBlock ||
        !refreshed.canJoinNewOnline) {
      return const OnlinePlayStatus(canJoinNewOnline: true);
    }
    return refreshed;
  }

  @override
  void dispose() {
    stopPolling();
    super.dispose();
  }
}
