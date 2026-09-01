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
  Timer? _tickTimer;

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

  void startPolling() {
    _tickTimer?.cancel();
    unawaited(refresh());
    _tickTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      unawaited(refresh(silent: true));
    });
  }

  void stopPolling() {
    _tickTimer?.cancel();
    _tickTimer = null;
  }

  Future<OnlinePlayStatus> refresh({bool silent = false}) async {
    var next = await _lobbyRepo.getOnlinePlayStatus();
    next = await _reconcileSessionWithServer(next);
    next = await _recoverStaleBlock(next);

    if (!next.hasActiveMembership && !next.canReturnToOngoingGame) {
      await _sessionStorage.clearSession();
    }

    final changed = _status.canJoinNewOnline != next.canJoinNewOnline ||
        _status.blockedUntil != next.blockedUntil ||
        _status.hasActiveMembership != next.hasActiveMembership;

    _status = next;

    if (changed || !silent) {
      notifyListeners();
    } else if (!canJoinNewOnline) {
      notifyListeners();
    }

    if (canJoinNewOnline) {
      stopPolling();
    } else if (_tickTimer == null) {
      startPolling();
    }

    return _status;
  }

  Future<OnlinePlayStatus> _reconcileSessionWithServer(
    OnlinePlayStatus next,
  ) async {
    final session = await _sessionStorage.getActiveRoomSession();
    if (session == null) return next;

    try {
      final room = await _lobbyRepo.getRoom(session.roomId);
      if (room.status == GameRoomStatus.cancelled ||
          room.status == GameRoomStatus.finished) {
        await _lobbyRepo.processRoomAbsences(session.roomId);
        await _sessionStorage.clearSession();
        return _lobbyRepo.getOnlinePlayStatus();
      }
    } catch (error) {
      debugPrint('[OnlinePlayGate] Room lookup failed: $error');
      await _sessionStorage.clearSession();
      return _lobbyRepo.getOnlinePlayStatus();
    }

    var stillMember =
        await _lobbyRepo.isPlayerInRoom(session.roomId, session.playerId);
    if (!stillMember) {
      await _sessionStorage.clearSession();
      return _lobbyRepo.getOnlinePlayStatus();
    }

    await _lobbyRepo.processRoomAbsences(session.roomId);
    stillMember =
        await _lobbyRepo.isPlayerInRoom(session.roomId, session.playerId);
    if (!stillMember) {
      await _sessionStorage.clearSession();
      return _lobbyRepo.getOnlinePlayStatus();
    }

    return _lobbyRepo.getOnlinePlayStatus();
  }

  Future<OnlinePlayStatus> _recoverStaleBlock(OnlinePlayStatus next) async {
    if (!next.isStaleBlock) return next;

    final session = await _sessionStorage.getActiveRoomSession();
    if (session != null) {
      await _lobbyRepo.processRoomAbsences(session.roomId);
    }
    await _sessionStorage.clearSession();

    final refreshed = await _lobbyRepo.getOnlinePlayStatus();
    if (refreshed.isStaleBlock || !refreshed.canJoinNewOnline) {
      await _sessionStorage.clearSession();
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
