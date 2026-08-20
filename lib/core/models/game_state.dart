// lib/core/models/game_state.dart
import 'card.dart';
import 'bid.dart';
import 'player.dart';
import '../constants.dart';

enum GamePhase {
  lobby,
  dealing,
  voidCheck,    // after deal, before auction — players may request redeal
  dashCall,     // pre-auction prompt — players may call Dash Call (0 blind)
  auction,
  declarations, // players declare trick targets
  trickTaking,
  scoring,
  matchEnd,
}

class GameState {
  // ── Lobby ──────────────────────────────────────────────────
  List<Player> players; // ordered by seatIndex
  GamePhase phase;

  // ── Round meta ─────────────────────────────────────────────
  int roundNumber;     // 1-based (1 to 18)
  int totalRounds;     // Default 18 for official Boula
  int dealerSeatIndex; // rotates each round
  bool isDoubleRound;  // true if previous round was all-passed (2x points)

  // ── Pre-auction Dash Call ──────────────────────────────────
  Set<String> dashCallPassed; // player IDs who responded to Dash Call prompt

  // ── Auction ────────────────────────────────────────────────
  Bid? currentHighBid;
  String? currentHighBidderPlayerId;
  int auctionTurnSeatIndex; // whose turn it is to bid
  String? bidderPlayerId;   // auction winner (set when auction ends)

  // ── Trick-taking & Trump ───────────────────────────────────
  Trump? trump;
  Suit? get trumpSuit => trump?.suit; // Backward compatibility
  set trumpSuit(dynamic val) {
    if (val is Trump?) {
      trump = val;
    } else if (val is Suit?) {
      trump = val != null ? Trump.fromSuit(val) : null;
    }
  }

  List<TrickCard> currentTrick; // cards played so far in this trick
  int trickLeaderSeatIndex;     // who leads current trick
  int tricksPlayedThisRound;
  int currentPlayerSeatIndex;   // whose turn to play a card

  // ── Round scores (populated at end of round) ───────────────
  Map<String, int> lastRoundScoreDeltas; // playerId → score delta

  // ── Void-check ─────────────────────────────────────────────
  Set<String> voidCheckPassed; // player IDs who confirmed no redeal needed
  String? voidDeclaringPlayerId; // player ID who declared a void suit
  Set<String> voidRedealRejections; // player IDs who rejected the redeal

  // ── Theme ──────────────────────────────────────────────────
  String cardTheme;

  GameState({
    required this.players,
    this.phase = GamePhase.lobby,
    this.roundNumber = 1,
    this.totalRounds = kBoulaTotalRounds,
    this.dealerSeatIndex = 0,
    this.isDoubleRound = false,
    Set<String>? dashCallPassed,
    this.currentHighBid,
    this.currentHighBidderPlayerId,
    this.auctionTurnSeatIndex = 0,
    this.bidderPlayerId,
    this.trump,
    Suit? trumpSuit,
    List<TrickCard>? currentTrick,
    this.trickLeaderSeatIndex = 0,
    this.tricksPlayedThisRound = 0,
    this.currentPlayerSeatIndex = 0,
    Map<String, int>? lastRoundScoreDeltas,
    Set<String>? voidCheckPassed,
    this.voidDeclaringPlayerId,
    Set<String>? voidRedealRejections,
    this.cardTheme = 'theme_1',
  })  : dashCallPassed = dashCallPassed ?? {},
        currentTrick = currentTrick ?? [],
        lastRoundScoreDeltas = lastRoundScoreDeltas ?? {},
        voidCheckPassed = voidCheckPassed ?? {},
        voidRedealRejections = voidRedealRejections ?? {} {
    if (trump == null && trumpSuit != null) {
      trump = Trump.fromSuit(trumpSuit);
    }
  }

  Trump? get fixedTrump => fixedTrumpForRound(roundNumber, totalRounds);

  Player? get bidder =>
      bidderPlayerId == null
          ? null
          : players.firstWhere(
              (p) => p.id == bidderPlayerId,
              orElse: () => players.isNotEmpty ? players.first : Player(id: 'unknown', name: 'Unknown', seatIndex: 0),
            );

  Player get currentPlayer =>
      players.firstWhere(
        (p) => p.seatIndex == currentPlayerSeatIndex,
        orElse: () => players.isNotEmpty ? players.first : Player(id: 'unknown', name: 'Unknown', seatIndex: currentPlayerSeatIndex),
      );

  Player playerById(String id) => players.firstWhere(
        (p) => p.id == id,
        orElse: () => players.isNotEmpty ? players.first : Player(id: id, name: 'Unknown', seatIndex: 0),
      );

  Player playerBySeat(int seat) =>
      players.firstWhere(
        (p) => p.seatIndex == seat,
        orElse: () => players.isNotEmpty ? players.first : Player(id: 'unknown', name: 'Unknown', seatIndex: seat),
      );

  bool get hasBots => players.any((p) => p.id.startsWith('bot_'));

  bool get isMatchOver {
    final reachedRoundLimit = roundNumber >= totalRounds && 
        (phase == GamePhase.scoring || phase == GamePhase.matchEnd);
    final reachedScore = players.any((p) => p.totalScore >= kMatchEndScore);
    return reachedRoundLimit || (totalRounds != kBoulaTotalRounds && reachedScore);
  }

  Player? get matchWinner {
    if (!isMatchOver) return null;
    return players.reduce((a, b) => a.totalScore > b.totalScore ? a : b);
  }

  // ── Serialisation ──────────────────────────────────────────

  Map<String, dynamic> toJson() => {
        'players': players.map((p) => p.toJson()).toList(),
        'phase': phase.name,
        'roundNumber': roundNumber,
        'totalRounds': totalRounds,
        'dealerSeatIndex': dealerSeatIndex,
        'isDoubleRound': isDoubleRound,
        'dashCallPassed': dashCallPassed.toList(),
        'currentHighBid': currentHighBid?.toJson(),
        'currentHighBidderPlayerId': currentHighBidderPlayerId,
        'auctionTurnSeatIndex': auctionTurnSeatIndex,
        'bidderPlayerId': bidderPlayerId,
        'trump': trump?.name,
        'trumpSuit': trumpSuit?.name,
        'currentTrick': currentTrick.map((t) => t.toJson()).toList(),
        'trickLeaderSeatIndex': trickLeaderSeatIndex,
        'tricksPlayedThisRound': tricksPlayedThisRound,
        'currentPlayerSeatIndex': currentPlayerSeatIndex,
        'lastRoundScoreDeltas': lastRoundScoreDeltas,
        'voidCheckPassed': voidCheckPassed.toList(),
        'voidDeclaringPlayerId': voidDeclaringPlayerId,
        'voidRedealRejections': voidRedealRejections.toList(),
        'cardTheme': cardTheme,
      };

  factory GameState.fromJson(Map<String, dynamic> json) {
    final trumpName = json['trump'] as String? ?? json['trumpSuit'] as String?;
    final trumpVal = trumpName != null ? Trump.fromString(trumpName) : null;

    return GameState(
      players: (json['players'] as List<dynamic>)
          .map((p) => Player.fromJson(p as Map<String, dynamic>))
          .toList(),
      phase: GamePhase.values.firstWhere((e) => e.name == json['phase']),
      roundNumber: json['roundNumber'] as int? ?? 1,
      totalRounds: json['totalRounds'] as int? ?? kBoulaTotalRounds,
      dealerSeatIndex: json['dealerSeatIndex'] as int? ?? 0,
      isDoubleRound: json['isDoubleRound'] as bool? ?? false,
      dashCallPassed: json['dashCallPassed'] != null
          ? Set<String>.from(json['dashCallPassed'] as List<dynamic>)
          : null,
      currentHighBid: json['currentHighBid'] == null
          ? null
          : Bid.fromJson(json['currentHighBid'] as Map<String, dynamic>),
      currentHighBidderPlayerId:
          json['currentHighBidderPlayerId'] as String?,
      auctionTurnSeatIndex: json['auctionTurnSeatIndex'] as int? ?? 0,
      bidderPlayerId: json['bidderPlayerId'] as String?,
      trump: trumpVal,
      currentTrick: (json['currentTrick'] as List<dynamic>?)
              ?.map((t) => TrickCard.fromJson(t as Map<String, dynamic>))
              .toList() ??
          [],
      trickLeaderSeatIndex: json['trickLeaderSeatIndex'] as int? ?? 0,
      tricksPlayedThisRound: json['tricksPlayedThisRound'] as int? ?? 0,
      currentPlayerSeatIndex: json['currentPlayerSeatIndex'] as int? ?? 0,
      lastRoundScoreDeltas: Map<String, int>.from(
          json['lastRoundScoreDeltas'] as Map<String, dynamic>? ?? {}),
      voidCheckPassed: Set<String>.from(
          json['voidCheckPassed'] as List<dynamic>? ?? []),
      voidDeclaringPlayerId: json['voidDeclaringPlayerId'] as String?,
      voidRedealRejections: json['voidRedealRejections'] != null 
          ? Set<String>.from(json['voidRedealRejections'] as List<dynamic>)
          : null,
      cardTheme: json['cardTheme'] as String? ?? 'theme_1',
    );
  }
}
