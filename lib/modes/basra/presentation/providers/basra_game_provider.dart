// lib/modes/basra/presentation/providers/basra_game_provider.dart

import 'dart:async';
import 'package:flutter/foundation.dart';

import 'package:estimation/core/models/card.dart';
import 'package:estimation/core/models/game_reaction.dart';
import 'package:estimation/modes/basra/domain/models/basra_game_state.dart';
import 'package:estimation/modes/basra/networking/basra_game_client.dart';
import 'package:estimation/networking/messages.dart';
import 'package:estimation/services/audio_service.dart';

export 'package:estimation/modes/basra/domain/models/basra_game_state.dart';

class BasraGameProvider extends ChangeNotifier {
  final Map<String, GameReaction> _activeReactions = {};
  Map<String, GameReaction> get activeReactions =>
      Map.unmodifiable(_activeReactions);
  final Map<String, Timer> _reactionTimers = {};

  BasraGameState? _state;
  BasraGameClient? _client;
  void Function(String action, [Map<String, dynamic>? data])? onSendAction;
  String? _myPlayerId;

  bool get isOnline => _client != null;
  BasraGameState? get state => _state;

  void setClient(BasraGameClient? client) {
    _client = client;
  }

  void setPlayerId(String id) {
    _myPlayerId = id;
    notifyListeners();
  }

  String? get myPlayerId => _myPlayerId;

  void syncState(BasraGameState state) {
    _state = state;
    notifyListeners();
  }

  List<BasraPlayer> get players => _state?.players ?? const [];
  BasraPhase get phase => _state?.phase ?? BasraPhase.waiting;
  String get cardTheme => _state?.cardTheme ?? 'theme_1';
  int get currentPlayerIndex => _state?.currentPlayerIndex ?? 0;
  int get currentRoundNumber => _state?.currentRoundNumber ?? 1;
  int get dealerPlayerIndex => _state?.dealerPlayerIndex ?? 0;
  int get carriedMajorityPoints => _state?.carriedMajorityPoints ?? 0;
  int get deckCount => _state?.remainingDeckCount ?? 0;
  List<PlayingCard> get tableCards => _state?.tableCards ?? const [];
  BasraTurnResult? get lastTurnResult => _state?.lastTurnResult;
  String? get lastCapturePlayerId => _state?.lastCapturePlayerId;
  bool get lastRoundAwardedFinalTable =>
      _state?.lastRoundAwardedFinalTable ?? false;
  List<BasraPlayerScore> get lastRoundScores =>
      _state?.lastRoundScores ?? const [];
  String? get matchWinnerId => _state?.matchWinnerId;
  bool get lastRoundWasTwentySixTie =>
      _state?.lastRoundWasTwentySixTie ?? false;

  BasraPlayer? get currentPlayer => _state?.currentPlayer;

  BasraPlayer? get localPlayer {
    if (_state == null) return null;
    if (_myPlayerId != null) {
      return _state!.players.where((p) => p.id == _myPlayerId).firstOrNull;
    }
    return _state!.players.where((p) => !p.isBot).firstOrNull ??
        _state!.players.firstOrNull;
  }

  BasraPlayer? get matchWinner {
    final id = matchWinnerId;
    if (id == null || _state == null) return null;
    return _state!.playerByIdOrNull(id);
  }

  bool get isLocalPlayerTurn =>
      currentPlayer != null && currentPlayer!.id == _myPlayerId;

  /// Seats rotated so the local player is always index 0 for table layout.
  List<BasraPlayer> get seatedPlayers {
    final list = players;
    final localId = localPlayer?.id;
    if (localId == null || list.isEmpty) return list;
    final idx = list.indexWhere((p) => p.id == localId);
    if (idx <= 0) return list;
    return [...list.sublist(idx), ...list.sublist(0, idx)];
  }

  int seatedIndexOf(String playerId) {
    return seatedPlayers.indexWhere((p) => p.id == playerId);
  }

  @override
  void dispose() {
    for (final t in _reactionTimers.values) {
      t.cancel();
    }
    _reactionTimers.clear();
    _activeReactions.clear();
    super.dispose();
  }

  void handleIncomingReaction(Map<String, dynamic> data) {
    try {
      final reaction = GameReaction.fromJson(data);
      _activeReactions[reaction.playerId] = reaction;
      _reactionTimers[reaction.playerId]?.cancel();
      _reactionTimers[reaction.playerId] =
          Timer(const Duration(milliseconds: 3200), () {
        _activeReactions.remove(reaction.playerId);
        notifyListeners();
      });
      notifyListeners();
    } catch (e) {
      debugPrint('[BasraGameProvider] Error handling incoming reaction: $e');
    }
  }

  void sendReaction(String emoji, [String? text]) {
    final reaction = GameReaction(
      id: DateTime.now().microsecondsSinceEpoch.toString(),
      playerId: _myPlayerId ?? '',
      playerName: localPlayer?.name,
      emoji: emoji,
      text: text,
      timestamp: DateTime.now().millisecondsSinceEpoch,
    );
    handleIncomingReaction(reaction.toJson());
    _dispatch(ActionType.sendReaction, {
      'reactionId': reaction.id,
      'emoji': emoji,
      'text': text,
      'timestamp': reaction.timestamp,
    });
  }

  void playCard(String playerId, PlayingCard card) {
    AudioService.instance.playCard();
    _dispatch(ActionType.playCardBasra, {'card': card.toJson()});
  }

  void advanceToNextRound() {
    _dispatch(ActionType.nextRound);
  }

  void _dispatch(String action, [Map<String, dynamic>? data]) {
    if (onSendAction != null) {
      onSendAction!(action, data);
    } else if (_client != null) {
      _client!.sendAction(action, data);
    }
  }

  void reset() {
    for (final t in _reactionTimers.values) {
      t.cancel();
    }
    _reactionTimers.clear();
    _activeReactions.clear();
    _state = null;
    _client = null;
    _myPlayerId = null;
    notifyListeners();
  }
}
