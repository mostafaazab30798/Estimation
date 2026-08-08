// lib/modes/ninety_nine/domain/models/ninety_nine_game_state.dart

import 'package:estimation/core/models/card.dart';

enum NinetyNinePhase {
  waiting,
  playing,
  roundFinished,
  finished,
}

class NinetyNinePlayer {
  final String id;
  final String name;
  final List<PlayingCard> hand;
  final bool isBot;
  final String avatarId;

  NinetyNinePlayer({
    required this.id,
    required this.name,
    required this.hand,
    this.isBot = false,
    this.avatarId = 'avatar_1',
  });

  NinetyNinePlayer copyWith({
    String? id,
    String? name,
    List<PlayingCard>? hand,
    bool? isBot,
    String? avatarId,
  }) {
    return NinetyNinePlayer(
      id: id ?? this.id,
      name: name ?? this.name,
      hand: hand ?? List.from(this.hand),
      isBot: isBot ?? this.isBot,
      avatarId: avatarId ?? this.avatarId,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'hand': hand.map((c) => c.toJson()).toList(),
        'isBot': isBot,
        'avatarId': avatarId,
      };

  factory NinetyNinePlayer.fromJson(Map<String, dynamic> json) => NinetyNinePlayer(
        id: json['id'] as String,
        name: json['name'] as String,
        hand: (json['hand'] as List<dynamic>)
            .map((c) => PlayingCard.fromJson(c as Map<String, dynamic>))
            .toList(),
        isBot: json['isBot'] as bool? ?? false,
        avatarId: json['avatarId'] as String? ?? 'avatar_1',
      );
}

class NinetyNineMove {
  final String playerId;
  final String playerName;
  final PlayingCard card;
  final int newGroundTotal;
  final DateTime timestamp;

  NinetyNineMove({
    required this.playerId,
    required this.playerName,
    required this.card,
    required this.newGroundTotal,
    DateTime? timestamp,
  }) : timestamp = timestamp ?? DateTime.now();

  Map<String, dynamic> toJson() => {
        'playerId': playerId,
        'playerName': playerName,
        'card': card.toJson(),
        'newGroundTotal': newGroundTotal,
        'timestamp': timestamp.toIso8601String(),
      };

  factory NinetyNineMove.fromJson(Map<String, dynamic> json) => NinetyNineMove(
        playerId: json['playerId'] as String,
        playerName: json['playerName'] as String,
        card: PlayingCard.fromJson(json['card'] as Map<String, dynamic>),
        newGroundTotal: json['newGroundTotal'] as int,
        timestamp: DateTime.parse(json['timestamp'] as String),
      );
}

class NinetyNineGameState {
  int groundTotal;
  int direction;
  int currentPlayerIndex;
  int currentRoundNumber;
  List<NinetyNinePlayer> players;
  Map<String, int> playerLosses;
  NinetyNinePhase phase;
  
  String? roundLoserId;
  String? matchLoserId;
  String? matchWinnerId;
  PlayingCard? lastPlayedCard;
  String? lastPlayedPlayerName;
  List<NinetyNineMove> moveHistory;
  
  String hostId;
  String cardTheme;

  NinetyNineGameState({
    this.groundTotal = 0,
    this.direction = 1,
    this.currentPlayerIndex = 0,
    this.currentRoundNumber = 1,
    required this.players,
    required this.playerLosses,
    this.phase = NinetyNinePhase.waiting,
    this.roundLoserId,
    this.matchLoserId,
    this.matchWinnerId,
    this.lastPlayedCard,
    this.lastPlayedPlayerName,
    List<NinetyNineMove>? moveHistory,
    required this.hostId,
    this.cardTheme = 'theme_1',
  }) : moveHistory = moveHistory ?? [];

  NinetyNinePlayer? get currentPlayer =>
      players.isNotEmpty && currentPlayerIndex < players.length
          ? players[currentPlayerIndex]
          : null;

  NinetyNinePlayer playerById(String id) =>
      players.firstWhere((p) => p.id == id);

  Map<String, dynamic> toJson() => {
        'groundTotal': groundTotal,
        'direction': direction,
        'currentPlayerIndex': currentPlayerIndex,
        'cardTheme': cardTheme,
        'currentRoundNumber': currentRoundNumber,
        'players': players.map((p) => p.toJson()).toList(),
        'playerLosses': playerLosses,
        'phase': phase.name,
        'roundLoserId': roundLoserId,
        'matchLoserId': matchLoserId,
        'matchWinnerId': matchWinnerId,
        'lastPlayedCard': lastPlayedCard?.toJson(),
        'lastPlayedPlayerName': lastPlayedPlayerName,
        'moveHistory': moveHistory.map((m) => m.toJson()).toList(),
        'hostId': hostId,
      };

  factory NinetyNineGameState.fromJson(Map<String, dynamic> json) {
    return NinetyNineGameState(
      groundTotal: json['groundTotal'] as int,
      direction: json['direction'] as int,
      currentPlayerIndex: json['currentPlayerIndex'] as int,
      currentRoundNumber: json['currentRoundNumber'] as int,
      players: (json['players'] as List<dynamic>)
          .map((p) => NinetyNinePlayer.fromJson(p as Map<String, dynamic>))
          .toList(),
      playerLosses: Map<String, int>.from(json['playerLosses'] as Map),
      phase: NinetyNinePhase.values.firstWhere(
          (e) => e.name == json['phase'],
          orElse: () => NinetyNinePhase.waiting),
      roundLoserId: json['roundLoserId'] as String?,
      matchLoserId: json['matchLoserId'] as String?,
      matchWinnerId: json['matchWinnerId'] as String?,
      lastPlayedCard: json['lastPlayedCard'] != null
          ? PlayingCard.fromJson(json['lastPlayedCard'] as Map<String, dynamic>)
          : null,
      lastPlayedPlayerName: json['lastPlayedPlayerName'] as String?,
      moveHistory: (json['moveHistory'] as List<dynamic>?)
              ?.map((m) => NinetyNineMove.fromJson(m as Map<String, dynamic>))
              .toList() ??
          [],
      hostId: json['hostId'] as String? ?? '',
      cardTheme: json['cardTheme'] as String? ?? 'theme_1',
    );
  }
}
