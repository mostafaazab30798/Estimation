// lib/modes/ninety_nine/presentation/providers/ninety_nine_game_provider.dart

import 'dart:async';
import 'package:flutter/foundation.dart';

import 'package:estimation/core/models/card.dart';

import 'package:estimation/modes/ninety_nine/domain/models/ninety_nine_game_state.dart';
export 'package:estimation/modes/ninety_nine/domain/models/ninety_nine_game_state.dart';
import 'package:estimation/modes/ninety_nine/networking/ninety_nine_game_client.dart';
import 'package:estimation/networking/messages.dart';

class NinetyNineGameProvider extends ChangeNotifier {
  static const int maxLosses = 5;
  Timer? _botTimer;

  int _groundTotal = 0;
  int _direction = 1; // 1 = clockwise, -1 = counter-clockwise
  int _currentPlayerIndex = 0;
  int _currentRoundNumber = 1;
  List<NinetyNinePlayer> _players = [];
  Map<String, int> _playerLosses = {};
  NinetyNinePhase _phase = NinetyNinePhase.waiting;
  String _cardTheme = 'theme_1';
  NinetyNinePlayer? _roundLoser;
  NinetyNinePlayer? _matchLoser;
  NinetyNinePlayer? _matchWinner;
  PlayingCard? _lastPlayedCard;
  String? _lastPlayedPlayerName;
  List<NinetyNineMove> _moveHistory = [];
  NinetyNineGameClient? _client;
  String? _myPlayerId;
  bool get isOnline => _client != null;

  void setClient(NinetyNineGameClient? client) {
    _client = client;
  }

  void setPlayerId(String id) {
    _myPlayerId = id;
    notifyListeners();
  }

  void syncState(NinetyNineGameState state) {
    _groundTotal = state.groundTotal;
    _direction = state.direction;
    _currentPlayerIndex = state.currentPlayerIndex;
    _currentRoundNumber = state.currentRoundNumber;
    _players = state.players;
    _playerLosses = state.playerLosses;
    _phase = state.phase;
    _cardTheme = state.cardTheme;
    _roundLoser = state.roundLoserId != null ? state.players.firstWhere((p) => p.id == state.roundLoserId) : null;
    _matchLoser = state.matchLoserId != null ? state.players.firstWhere((p) => p.id == state.matchLoserId) : null;
    _matchWinner = state.matchWinnerId != null ? state.players.firstWhere((p) => p.id == state.matchWinnerId) : null;
    _lastPlayedCard = state.lastPlayedCard;
    _lastPlayedPlayerName = state.lastPlayedPlayerName;
    _moveHistory = List.from(state.moveHistory);
    notifyListeners();
  }

  // ── Getters ──────────────────────────────────────────────────────────
  int get groundTotal => _groundTotal;
  int get direction => _direction;
  int get currentPlayerIndex => _currentPlayerIndex;
  int get currentRoundNumber => _currentRoundNumber;
  List<NinetyNinePlayer> get players => List.unmodifiable(_players);
  Map<String, int> get playerLosses => Map.unmodifiable(_playerLosses);
  NinetyNinePhase get phase => _phase;
  String get cardTheme => _cardTheme;
  NinetyNinePlayer? get roundLoser => _roundLoser;
  NinetyNinePlayer? get matchLoser => _matchLoser;
  NinetyNinePlayer? get matchWinner => _matchWinner;
  PlayingCard? get lastPlayedCard => _lastPlayedCard;
  String? get lastPlayedPlayerName => _lastPlayedPlayerName;
  List<NinetyNineMove> get moveHistory => List.unmodifiable(_moveHistory);

  NinetyNinePlayer? get currentPlayer =>
      _players.isNotEmpty && _currentPlayerIndex < _players.length
          ? _players[_currentPlayerIndex]
          : null;

  NinetyNinePlayer? get localPlayer {
    if (_myPlayerId != null) {
      return _players.where((p) => p.id == _myPlayerId).firstOrNull;
    }
    return _players.where((p) => !p.isBot).firstOrNull ?? _players.firstOrNull;
  }

  bool get isLocalPlayerTurn =>
      currentPlayer != null && currentPlayer!.id == _myPlayerId;

  int getPlayerLosses(String playerId) => _playerLosses[playerId] ?? 0;

  @override
  void dispose() {
    _botTimer?.cancel();
    super.dispose();
  }

  // ── Client Actions ───────────────────────────────────────────

  void playCard(String playerId, PlayingCard card) {
    _client?.sendAction(ActionType.playCardNinetyNine, {'card': card.toJson()});
  }

  void advanceToNextRound() {
    _client?.sendAction(ActionType.nextRound);
  }
}
