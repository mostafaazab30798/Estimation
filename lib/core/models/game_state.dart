// lib/core/models/game_state.dart
import 'card.dart';
import 'bid.dart';
import 'player.dart';
import '../constants.dart';

enum GamePhase {
  lobby,
  dealing,
  voidCheck,   // after deal, before auction — players may request redeal
  auction,
  declarations, // non-Bidder players declare trick targets
  trickTaking,
  scoring,
  matchEnd,
}

class GameState {
  // ── Lobby ──────────────────────────────────────────────────
  List<Player> players; // ordered by seatIndex
  GamePhase phase;

  // ── Round meta ─────────────────────────────────────────────
  int roundNumber;     // 1-based
  int dealerSeatIndex; // rotates each round

  // ── Auction ────────────────────────────────────────────────
  Bid? currentHighBid;
  String? currentHighBidderPlayerId;
  int auctionTurnSeatIndex; // whose turn it is to bid
  String? bidderPlayerId;   // auction winner (set when auction ends)

  // ── Trick-taking ───────────────────────────────────────────
  Suit? trumpSuit;
  List<TrickCard> currentTrick; // cards played so far in this trick
  int trickLeaderSeatIndex;     // who leads current trick
  int tricksPlayedThisRound;
  // whose turn to play a card
  int currentPlayerSeatIndex;

  // ── Round scores (populated at end of round) ───────────────
  Map<String, int> lastRoundScoreDeltas; // playerId → score delta

  // ── Void-check ─────────────────────────────────────────────
  Set<String> voidCheckPassed; // player IDs who have confirmed no redeal needed
  String? voidDeclaringPlayerId; // player ID who declared a void suit
  Set<String> voidRedealRejections; // player IDs who rejected the redeal

  // ── Theme ──────────────────────────────────────────────────
  String cardTheme;

  GameState({
    required this.players,
    this.phase = GamePhase.lobby,
    this.roundNumber = 1,
    this.dealerSeatIndex = 0,
    this.currentHighBid,
    this.currentHighBidderPlayerId,
    this.auctionTurnSeatIndex = 0,
    this.bidderPlayerId,
    this.trumpSuit,
    List<TrickCard>? currentTrick,
    this.trickLeaderSeatIndex = 0,
    this.tricksPlayedThisRound = 0,
    this.currentPlayerSeatIndex = 0,
    Map<String, int>? lastRoundScoreDeltas,
    Set<String>? voidCheckPassed,
    this.voidDeclaringPlayerId,
    Set<String>? voidRedealRejections,
    this.cardTheme = 'theme_1',
  })  : currentTrick = currentTrick ?? [],
        lastRoundScoreDeltas = lastRoundScoreDeltas ?? {},
        voidCheckPassed = voidCheckPassed ?? {},
        voidRedealRejections = voidRedealRejections ?? {};

  Player? get bidder =>
      bidderPlayerId == null
          ? null
          : players.firstWhere((p) => p.id == bidderPlayerId);

  Player get currentPlayer =>
      players.firstWhere((p) => p.seatIndex == currentPlayerSeatIndex);

  Player playerById(String id) => players.firstWhere((p) => p.id == id);

  Player playerBySeat(int seat) =>
      players.firstWhere((p) => p.seatIndex == seat);

  bool get hasBots => players.any((p) => p.id.startsWith('bot_'));

  bool get isMatchOver {
    final reachedScore = players.any((p) => p.totalScore >= kMatchEndScore);
    if (hasBots) {
      return reachedScore;
    } else {
      final reachedRoundLimit = roundNumber >= 7 && 
          (phase == GamePhase.scoring || phase == GamePhase.matchEnd);
      return reachedScore || reachedRoundLimit;
    }
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
        'dealerSeatIndex': dealerSeatIndex,
        'currentHighBid': currentHighBid?.toJson(),
        'currentHighBidderPlayerId': currentHighBidderPlayerId,
        'auctionTurnSeatIndex': auctionTurnSeatIndex,
        'bidderPlayerId': bidderPlayerId,
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
    return GameState(
      players: (json['players'] as List<dynamic>)
          .map((p) => Player.fromJson(p as Map<String, dynamic>))
          .toList(),
      phase: GamePhase.values.firstWhere((e) => e.name == json['phase']),
      roundNumber: json['roundNumber'] as int,
      dealerSeatIndex: json['dealerSeatIndex'] as int,
      currentHighBid: json['currentHighBid'] == null
          ? null
          : Bid.fromJson(json['currentHighBid'] as Map<String, dynamic>),
      currentHighBidderPlayerId:
          json['currentHighBidderPlayerId'] as String?,
      auctionTurnSeatIndex: json['auctionTurnSeatIndex'] as int,
      bidderPlayerId: json['bidderPlayerId'] as String?,
      trumpSuit: json['trumpSuit'] == null
          ? null
          : Suit.fromString(json['trumpSuit'] as String),
      currentTrick: (json['currentTrick'] as List<dynamic>)
          .map((t) => TrickCard.fromJson(t as Map<String, dynamic>))
          .toList(),
      trickLeaderSeatIndex: json['trickLeaderSeatIndex'] as int,
      tricksPlayedThisRound: json['tricksPlayedThisRound'] as int,
      currentPlayerSeatIndex: json['currentPlayerSeatIndex'] as int,
      lastRoundScoreDeltas: Map<String, int>.from(
          json['lastRoundScoreDeltas'] as Map<String, dynamic>),
      voidCheckPassed:
          Set<String>.from(json['voidCheckPassed'] as List<dynamic>),
      voidDeclaringPlayerId: json['voidDeclaringPlayerId'] as String?,
      voidRedealRejections: json['voidRedealRejections'] != null 
          ? Set<String>.from(json['voidRedealRejections'] as List<dynamic>)
          : null,
      cardTheme: json['cardTheme'] as String? ?? 'theme_1',
    );
  }
}

