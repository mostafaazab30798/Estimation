// lib/modes/basra/domain/models/basra_game_state.dart

import 'package:estimation/core/models/card.dart';
import 'package:estimation/modes/basra/domain/basra_constants.dart';

enum BasraPhase {
  waiting,
  playing,
  roundFinished,
  finished,
}

enum BasraType {
  none,
  normal,
  sevenOfDiamonds,
}

class BasraPlayer {
  final String id;
  final String name;
  final List<PlayingCard> hand;
  final List<PlayingCard> capturedCards;
  final bool isBot;
  final String avatarId;
  int totalScore;
  int roundScore;
  int basraCount;

  BasraPlayer({
    required this.id,
    required this.name,
    List<PlayingCard>? hand,
    List<PlayingCard>? capturedCards,
    this.isBot = false,
    this.avatarId = 'avatar_1',
    this.totalScore = 0,
    this.roundScore = 0,
    this.basraCount = 0,
  })  : hand = hand ?? [],
        capturedCards = capturedCards ?? [];

  BasraPlayer copyWith({
    String? id,
    String? name,
    List<PlayingCard>? hand,
    List<PlayingCard>? capturedCards,
    bool? isBot,
    String? avatarId,
    int? totalScore,
    int? roundScore,
    int? basraCount,
  }) {
    return BasraPlayer(
      id: id ?? this.id,
      name: name ?? this.name,
      hand: hand ?? List.from(this.hand),
      capturedCards: capturedCards ?? List.from(this.capturedCards),
      isBot: isBot ?? this.isBot,
      avatarId: avatarId ?? this.avatarId,
      totalScore: totalScore ?? this.totalScore,
      roundScore: roundScore ?? this.roundScore,
      basraCount: basraCount ?? this.basraCount,
    );
  }

  void resetForRound() {
    hand.clear();
    capturedCards.clear();
    roundScore = 0;
    basraCount = 0;
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'hand': hand.map((c) => c.toJson()).toList(),
        'capturedCards': capturedCards.map((c) => c.toJson()).toList(),
        'isBot': isBot,
        'avatarId': avatarId,
        'totalScore': totalScore,
        'roundScore': roundScore,
        'basraCount': basraCount,
      };

  Map<String, dynamic> toSanitizedJson({bool isSelf = true}) => {
        'id': id,
        'name': name,
        'hand': isSelf
            ? hand.map((c) => c.toJson()).toList()
            : List.generate(
                hand.length,
                (_) => {'suit': 'spade', 'rank': 'two'},
              ),
        'capturedCards': capturedCards.map((c) => c.toJson()).toList(),
        'isBot': isBot,
        'avatarId': avatarId,
        'totalScore': totalScore,
        'roundScore': roundScore,
        'basraCount': basraCount,
      };

  factory BasraPlayer.fromJson(Map<String, dynamic> json) => BasraPlayer(
        id: json['id'] as String,
        name: json['name'] as String,
        hand: (json['hand'] as List<dynamic>?)
                ?.map((c) => PlayingCard.fromJson(c as Map<String, dynamic>))
                .toList() ??
            [],
        capturedCards: (json['capturedCards'] as List<dynamic>?)
                ?.map((c) => PlayingCard.fromJson(c as Map<String, dynamic>))
                .toList() ??
            [],
        isBot: json['isBot'] as bool? ?? false,
        avatarId: json['avatarId'] as String? ?? 'avatar_1',
        totalScore: json['totalScore'] as int? ?? 0,
        roundScore: json['roundScore'] as int? ?? 0,
        basraCount: json['basraCount'] as int? ?? 0,
      );
}

class BasraTurnResult {
  final String playerId;
  final PlayingCard playedCard;
  final List<PlayingCard> capturedCards;
  final List<PlayingCard> tableBefore;
  final List<PlayingCard> tableAfter;
  final bool wasCapture;
  final bool wasBasra;
  final BasraType basraType;
  final String? lastCapturePlayerId;

  const BasraTurnResult({
    required this.playerId,
    required this.playedCard,
    required this.capturedCards,
    required this.tableBefore,
    required this.tableAfter,
    required this.wasCapture,
    required this.wasBasra,
    required this.basraType,
    this.lastCapturePlayerId,
  });

  Map<String, dynamic> toJson() => {
        'playerId': playerId,
        'playedCard': playedCard.toJson(),
        'capturedCards': capturedCards.map((c) => c.toJson()).toList(),
        'tableBefore': tableBefore.map((c) => c.toJson()).toList(),
        'tableAfter': tableAfter.map((c) => c.toJson()).toList(),
        'wasCapture': wasCapture,
        'wasBasra': wasBasra,
        'basraType': basraType.name,
        'lastCapturePlayerId': lastCapturePlayerId,
      };

  factory BasraTurnResult.fromJson(Map<String, dynamic> json) => BasraTurnResult(
        playerId: json['playerId'] as String,
        playedCard: PlayingCard.fromJson(json['playedCard'] as Map<String, dynamic>),
        capturedCards: (json['capturedCards'] as List<dynamic>)
            .map((c) => PlayingCard.fromJson(c as Map<String, dynamic>))
            .toList(),
        tableBefore: (json['tableBefore'] as List<dynamic>)
            .map((c) => PlayingCard.fromJson(c as Map<String, dynamic>))
            .toList(),
        tableAfter: (json['tableAfter'] as List<dynamic>)
            .map((c) => PlayingCard.fromJson(c as Map<String, dynamic>))
            .toList(),
        wasCapture: json['wasCapture'] as bool,
        wasBasra: json['wasBasra'] as bool,
        basraType: BasraType.values.firstWhere(
          (e) => e.name == json['basraType'],
          orElse: () => BasraType.none,
        ),
        lastCapturePlayerId: json['lastCapturePlayerId'] as String?,
      );
}

class BasraPlayerScore {
  final String playerId;
  final int capturedCount;
  final int jackPoints;
  final int acePoints;
  final int twoOfSpadesPoints;
  final int tenOfDiamondsPoints;
  final int basraPoints;
  final int majorityPoints;
  final int carryOverPoints;
  final int roundScore;
  final int totalScore;
  final int basraCount;

  const BasraPlayerScore({
    required this.playerId,
    required this.capturedCount,
    required this.jackPoints,
    required this.acePoints,
    required this.twoOfSpadesPoints,
    required this.tenOfDiamondsPoints,
    required this.basraPoints,
    required this.majorityPoints,
    required this.carryOverPoints,
    required this.roundScore,
    required this.totalScore,
    required this.basraCount,
  });

  Map<String, dynamic> toJson() => {
        'playerId': playerId,
        'capturedCount': capturedCount,
        'jackPoints': jackPoints,
        'acePoints': acePoints,
        'twoOfSpadesPoints': twoOfSpadesPoints,
        'tenOfDiamondsPoints': tenOfDiamondsPoints,
        'basraPoints': basraPoints,
        'majorityPoints': majorityPoints,
        'carryOverPoints': carryOverPoints,
        'roundScore': roundScore,
        'totalScore': totalScore,
        'basraCount': basraCount,
      };

  factory BasraPlayerScore.fromJson(Map<String, dynamic> json) => BasraPlayerScore(
        playerId: json['playerId'] as String,
        capturedCount: json['capturedCount'] as int,
        jackPoints: json['jackPoints'] as int,
        acePoints: json['acePoints'] as int,
        twoOfSpadesPoints: json['twoOfSpadesPoints'] as int,
        tenOfDiamondsPoints: json['tenOfDiamondsPoints'] as int,
        basraPoints: json['basraPoints'] as int,
        majorityPoints: json['majorityPoints'] as int,
        carryOverPoints: json['carryOverPoints'] as int,
        roundScore: json['roundScore'] as int,
        totalScore: json['totalScore'] as int,
        basraCount: json['basraCount'] as int,
      );
}

class BasraGameState {
  List<PlayingCard> deck;
  List<PlayingCard> tableCards;
  List<BasraPlayer> players;
  int currentPlayerIndex;
  int dealerPlayerIndex;
  int currentRoundNumber;
  String? lastCapturePlayerId;
  int carriedMajorityPoints;
  BasraPhase phase;
  String hostId;
  String cardTheme;
  String? matchWinnerId;
  BasraTurnResult? lastTurnResult;
  List<BasraPlayerScore> lastRoundScores;
  bool lastRoundAwardedFinalTable;
  bool lastRoundWasTwentySixTie;
  int deckCountHint;

  BasraGameState({
    List<PlayingCard>? deck,
    List<PlayingCard>? tableCards,
    required this.players,
    this.currentPlayerIndex = 0,
    this.dealerPlayerIndex = 0,
    this.currentRoundNumber = 1,
    this.lastCapturePlayerId,
    this.carriedMajorityPoints = 0,
    this.phase = BasraPhase.waiting,
    required this.hostId,
    this.cardTheme = 'theme_1',
    this.matchWinnerId,
    this.lastTurnResult,
    List<BasraPlayerScore>? lastRoundScores,
    this.lastRoundAwardedFinalTable = false,
    this.lastRoundWasTwentySixTie = false,
    this.deckCountHint = 0,
  })  : deck = deck ?? [],
        tableCards = tableCards ?? [],
        lastRoundScores = lastRoundScores ?? [];

  int get remainingDeckCount => deck.isNotEmpty ? deck.length : deckCountHint;

  BasraPlayer? get currentPlayer =>
      players.isNotEmpty && currentPlayerIndex < players.length
          ? players[currentPlayerIndex]
          : null;

  BasraPlayer playerById(String id) => players.firstWhere((p) => p.id == id);

  BasraPlayer? playerByIdOrNull(String id) {
    for (final player in players) {
      if (player.id == id) return player;
    }
    return null;
  }

  bool get allHandsEmpty => players.every((p) => p.hand.isEmpty);

  int get matchTarget => kBasraMatchTarget;

  Map<String, dynamic> toJson() => {
        'deckCount': remainingDeckCount,
        'deck': deck.map((c) => c.toJson()).toList(),
        'tableCards': tableCards.map((c) => c.toJson()).toList(),
        'players': players.map((p) => p.toJson()).toList(),
        'currentPlayerIndex': currentPlayerIndex,
        'dealerPlayerIndex': dealerPlayerIndex,
        'currentRoundNumber': currentRoundNumber,
        'lastCapturePlayerId': lastCapturePlayerId,
        'carriedMajorityPoints': carriedMajorityPoints,
        'phase': phase.name,
        'hostId': hostId,
        'cardTheme': cardTheme,
        'matchWinnerId': matchWinnerId,
        'lastTurnResult': lastTurnResult?.toJson(),
        'lastRoundScores': lastRoundScores.map((s) => s.toJson()).toList(),
        'lastRoundAwardedFinalTable': lastRoundAwardedFinalTable,
        'lastRoundWasTwentySixTie': lastRoundWasTwentySixTie,
      };

  Map<String, dynamic> toSanitizedJson({String? recipientPlayerId}) {
    final json = toJson();
    json['players'] = players
        .map((p) => p.toSanitizedJson(
              isSelf: recipientPlayerId != null && p.id == recipientPlayerId,
            ))
        .toList();
    json.remove('deck');
    json['deckCount'] = deck.length;
    return json;
  }

  factory BasraGameState.fromJson(Map<String, dynamic> json) {
    return BasraGameState(
      deck: (json['deck'] as List<dynamic>?)
              ?.map((c) => PlayingCard.fromJson(c as Map<String, dynamic>))
              .toList() ??
          [],
      tableCards: (json['tableCards'] as List<dynamic>?)
              ?.map((c) => PlayingCard.fromJson(c as Map<String, dynamic>))
              .toList() ??
          [],
      players: (json['players'] as List<dynamic>)
          .map((p) => BasraPlayer.fromJson(p as Map<String, dynamic>))
          .toList(),
      currentPlayerIndex: json['currentPlayerIndex'] as int? ?? 0,
      dealerPlayerIndex: json['dealerPlayerIndex'] as int? ?? 0,
      currentRoundNumber: json['currentRoundNumber'] as int? ?? 1,
      lastCapturePlayerId: json['lastCapturePlayerId'] as String?,
      carriedMajorityPoints: json['carriedMajorityPoints'] as int? ?? 0,
      phase: BasraPhase.values.firstWhere(
        (e) => e.name == json['phase'],
        orElse: () => BasraPhase.waiting,
      ),
      hostId: json['hostId'] as String? ?? '',
      cardTheme: json['cardTheme'] as String? ?? 'theme_1',
      matchWinnerId: json['matchWinnerId'] as String?,
      lastTurnResult: json['lastTurnResult'] != null
          ? BasraTurnResult.fromJson(json['lastTurnResult'] as Map<String, dynamic>)
          : null,
      lastRoundScores: (json['lastRoundScores'] as List<dynamic>?)
              ?.map((s) => BasraPlayerScore.fromJson(s as Map<String, dynamic>))
              .toList() ??
          [],
      lastRoundAwardedFinalTable: json['lastRoundAwardedFinalTable'] as bool? ?? false,
      lastRoundWasTwentySixTie: json['lastRoundWasTwentySixTie'] as bool? ?? false,
      deckCountHint: json['deckCount'] as int? ?? 0,
    );
  }
}
