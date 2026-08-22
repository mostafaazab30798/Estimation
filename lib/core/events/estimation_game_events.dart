// lib/core/events/estimation_game_events.dart
//
// Strongly-typed contextual game events specifically for Egyptian Estimation.

import '../constants.dart';
import '../models/bid.dart';
import '../models/card.dart';
import '../models/comeback_event.dart';
import '../models/game_state.dart';
import '../models/player.dart';

/// Base class for all Estimation game events.
abstract class EstimationGameEvent {
  final DateTime timestamp;

  EstimationGameEvent({DateTime? timestamp})
      : timestamp = timestamp ?? DateTime.now();

  String get eventName;

  /// Optional English description/message for this event
  String get messageEn => eventName;

  /// Optional Arabic description/message for this event
  String get messageAr => eventName;

  /// Icon or emoji badge associated with the event
  String get emoji => '🎮';

  Map<String, dynamic> toJson();

  @override
  String toString() => '$eventName(timestamp: $timestamp)';
}

// ─────────────────────────────────────────────────────────────────────────────
// 1. Round & Lifecycle Events
// ─────────────────────────────────────────────────────────────────────────────

/// Triggered when a new round starts.
class RoundStarted extends EstimationGameEvent {
  final int roundNumber;
  final int totalRounds;
  final int dealerSeatIndex;
  final bool isDoubleRound;
  final Trump? fixedTrump;

  RoundStarted({
    required this.roundNumber,
    required this.totalRounds,
    required this.dealerSeatIndex,
    this.isDoubleRound = false,
    this.fixedTrump,
    super.timestamp,
  });

  @override
  String get eventName => 'RoundStarted';

  @override
  String get messageEn => 'Round $roundNumber of $totalRounds started!';

  @override
  String get messageAr => 'بدأت الجولة $roundNumber من $totalRounds!';

  @override
  String get emoji => '🏁';

  @override
  Map<String, dynamic> toJson() => {
        'eventName': eventName,
        'roundNumber': roundNumber,
        'totalRounds': totalRounds,
        'dealerSeatIndex': dealerSeatIndex,
        'isDoubleRound': isDoubleRound,
        'fixedTrump': fixedTrump?.name,
        'timestamp': timestamp.toIso8601String(),
      };
}

/// Triggered when players have finished checking for void hands.
class VoidCheckCompleted extends EstimationGameEvent {
  final int roundNumber;
  final bool redealOccurred;
  final String? declaringPlayerId;

  VoidCheckCompleted({
    required this.roundNumber,
    this.redealOccurred = false,
    this.declaringPlayerId,
    super.timestamp,
  });

  @override
  String get eventName => 'VoidCheckCompleted';

  @override
  String get messageEn => redealOccurred
      ? 'Redeal approved due to void suit!'
      : 'Void check completed. Hands confirmed!';

  @override
  String get messageAr => redealOccurred
      ? 'تمت إعادة توزيع الورق بسبب خلو لون!'
      : 'تم تأكيد فحص الأوراق، لا توجد إعادة توزيع!';

  @override
  String get emoji => '🃏';

  @override
  Map<String, dynamic> toJson() => {
        'eventName': eventName,
        'roundNumber': roundNumber,
        'redealOccurred': redealOccurred,
        'declaringPlayerId': declaringPlayerId,
        'timestamp': timestamp.toIso8601String(),
      };
}

/// Triggered when a round completes and scoring has been calculated.
class RoundCompleted extends EstimationGameEvent {
  final int roundNumber;
  final Map<String, int> scoreDeltas;
  final List<PlayerRoundRecord> records;
  final List<ComebackEvent> comebacks;

  RoundCompleted({
    required this.roundNumber,
    required this.scoreDeltas,
    required this.records,
    this.comebacks = const [],
    super.timestamp,
  });

  @override
  String get eventName => 'RoundCompleted';

  @override
  String get messageEn => 'Round $roundNumber completed!';

  @override
  String get messageAr => 'اكتملت الجولة $roundNumber!';

  @override
  String get emoji => '📊';

  @override
  Map<String, dynamic> toJson() => {
        'eventName': eventName,
        'roundNumber': roundNumber,
        'scoreDeltas': scoreDeltas,
        'records': records.map((r) => r.toJson()).toList(),
        'comebacks': comebacks.map((c) => c.toJson()).toList(),
        'timestamp': timestamp.toIso8601String(),
      };
}

/// Triggered when a Double Round (x2 multiplier) begins.
class DoubleRoundStarted extends EstimationGameEvent {
  final int roundNumber;
  final int multiplier;

  DoubleRoundStarted({
    required this.roundNumber,
    this.multiplier = 2,
    super.timestamp,
  });

  @override
  String get eventName => 'DoubleRoundStarted';

  @override
  String get messageEn => '⚡ DOUBLE ROUND ×$multiplier ACTIVATED!';

  @override
  String get messageAr => '⚡ بدأت جولة الدبل (نقاط مضاعفة ×$multiplier)!';

  @override
  String get emoji => '⚡';

  @override
  Map<String, dynamic> toJson() => {
        'eventName': eventName,
        'roundNumber': roundNumber,
        'multiplier': multiplier,
        'timestamp': timestamp.toIso8601String(),
      };
}

/// Triggered when the final round of the match/Boula begins.
class FinalRoundStarted extends EstimationGameEvent {
  final int roundNumber;
  final int totalRounds;
  final String? leaderPlayerId;
  final String? leaderPlayerName;

  FinalRoundStarted({
    required this.roundNumber,
    required this.totalRounds,
    this.leaderPlayerId,
    this.leaderPlayerName,
    super.timestamp,
  });

  @override
  String get eventName => 'FinalRoundStarted';

  @override
  String get messageEn => 'FINAL ROUND! The Boula championship is on the line!';

  @override
  String get messageAr => 'الجولة الختامية! حسم لقب البولة!';

  @override
  String get emoji => '🏆';

  @override
  Map<String, dynamic> toJson() => {
        'eventName': eventName,
        'roundNumber': roundNumber,
        'totalRounds': totalRounds,
        'leaderPlayerId': leaderPlayerId,
        'leaderPlayerName': leaderPlayerName,
        'timestamp': timestamp.toIso8601String(),
      };
}

/// Triggered when the entire match/Boula is completed.
class MatchCompleted extends EstimationGameEvent {
  final Player winner;
  final List<Player> rankings;
  final int totalRounds;

  MatchCompleted({
    required this.winner,
    required this.rankings,
    required this.totalRounds,
    super.timestamp,
  });

  @override
  String get eventName => 'MatchCompleted';

  @override
  String get messageEn => 'Match completed! Winner: ${winner.name}';

  @override
  String get messageAr => 'انتهت البولة! الفائز: ${winner.name}';

  @override
  String get emoji => '👑';

  @override
  Map<String, dynamic> toJson() => {
        'eventName': eventName,
        'winnerId': winner.id,
        'winnerName': winner.name,
        'winnerScore': winner.totalScore,
        'rankings': rankings.map((p) => p.toJson()).toList(),
        'totalRounds': totalRounds,
        'timestamp': timestamp.toIso8601String(),
      };
}

// ─────────────────────────────────────────────────────────────────────────────
// 2. Dash Call Events
// ─────────────────────────────────────────────────────────────────────────────

/// Triggered when a player makes a Dash Call (blind 0 call before auction).
class DashCallMade extends EstimationGameEvent {
  final String playerId;
  final String playerName;
  final int seatIndex;

  DashCallMade({
    required this.playerId,
    required this.playerName,
    required this.seatIndex,
    super.timestamp,
  });

  @override
  String get eventName => 'DashCallMade';

  @override
  String get messageEn => '$playerName called DASH CALL (0 Blind)!';

  @override
  String get messageAr => 'أعلن $playerName عن داش كول (0 أعمى)!';

  @override
  String get emoji => '🎯';

  @override
  Map<String, dynamic> toJson() => {
        'eventName': eventName,
        'playerId': playerId,
        'playerName': playerName,
        'seatIndex': seatIndex,
        'timestamp': timestamp.toIso8601String(),
      };
}

/// Triggered when a Dash Call was successfully made (0 tricks taken).
class DashCallSucceeded extends EstimationGameEvent {
  final String playerId;
  final String playerName;
  final int scoreDelta;
  final int roundNumber;

  DashCallSucceeded({
    required this.playerId,
    required this.playerName,
    required this.scoreDelta,
    required this.roundNumber,
    super.timestamp,
  });

  @override
  String get eventName => 'DashCallSucceeded';

  @override
  String get messageEn => '$playerName successfully won DASH CALL (+$scoreDelta pts)!';

  @override
  String get messageAr => 'نجح $playerName في الداش كول (+$scoreDelta نقطة)!';

  @override
  String get emoji => '🌟';

  @override
  Map<String, dynamic> toJson() => {
        'eventName': eventName,
        'playerId': playerId,
        'playerName': playerName,
        'scoreDelta': scoreDelta,
        'roundNumber': roundNumber,
        'timestamp': timestamp.toIso8601String(),
      };
}

/// Triggered when a Dash Call failed (player took 1 or more tricks).
class DashCallFailed extends EstimationGameEvent {
  final String playerId;
  final String playerName;
  final int actualTricks;
  final int scoreDelta;
  final int roundNumber;

  DashCallFailed({
    required this.playerId,
    required this.playerName,
    required this.actualTricks,
    required this.scoreDelta,
    required this.roundNumber,
    super.timestamp,
  });

  @override
  String get eventName => 'DashCallFailed';

  @override
  String get messageEn => '$playerName failed DASH CALL ($actualTricks tricks, $scoreDelta pts)!';

  @override
  String get messageAr => 'فشل $playerName في الداش كول ($actualTricks لمات، $scoreDelta نقطة)!';

  @override
  String get emoji => '💥';

  @override
  Map<String, dynamic> toJson() => {
        'eventName': eventName,
        'playerId': playerId,
        'playerName': playerName,
        'actualTricks': actualTricks,
        'scoreDelta': scoreDelta,
        'roundNumber': roundNumber,
        'timestamp': timestamp.toIso8601String(),
      };
}

// ─────────────────────────────────────────────────────────────────────────────
// 3. Auction Events
// ─────────────────────────────────────────────────────────────────────────────

/// Triggered when any bid is placed in the auction.
class BidPlaced extends EstimationGameEvent {
  final String playerId;
  final String playerName;
  final Bid bid;
  final int seatIndex;

  BidPlaced({
    required this.playerId,
    required this.playerName,
    required this.bid,
    required this.seatIndex,
    super.timestamp,
  });

  @override
  String get eventName => 'BidPlaced';

  @override
  String get messageEn => '$playerName bid ${bid.trickCount} ${bid.trump.name}';

  @override
  String get messageAr => 'زايد $playerName بـ ${bid.trickCount} ${bid.trump.name}';

  @override
  String get emoji => '📢';

  @override
  Map<String, dynamic> toJson() => {
        'eventName': eventName,
        'playerId': playerId,
        'playerName': playerName,
        'bid': bid.toJson(),
        'seatIndex': seatIndex,
        'timestamp': timestamp.toIso8601String(),
      };
}

/// Triggered when a new highest bid is established.
class HighBidChanged extends EstimationGameEvent {
  final String playerId;
  final String playerName;
  final Bid newHighBid;
  final Bid? previousHighBid;

  HighBidChanged({
    required this.playerId,
    required this.playerName,
    required this.newHighBid,
    this.previousHighBid,
    super.timestamp,
  });

  @override
  String get eventName => 'HighBidChanged';

  @override
  String get messageEn => '$playerName took the highest bid: ${newHighBid.trickCount} ${newHighBid.trump.name}';

  @override
  String get messageAr => 'أصبح $playerName أعلى مزايد: ${newHighBid.trickCount} ${newHighBid.trump.name}';

  @override
  String get emoji => '🔥';

  @override
  Map<String, dynamic> toJson() => {
        'eventName': eventName,
        'playerId': playerId,
        'playerName': playerName,
        'newHighBid': newHighBid.toJson(),
        'previousHighBid': previousHighBid?.toJson(),
        'timestamp': timestamp.toIso8601String(),
      };
}

/// Triggered when a player wins the auction and becomes the Bidder.
class AuctionWon extends EstimationGameEvent {
  final String bidderId;
  final String bidderName;
  final Bid winningBid;
  final Trump trump;

  AuctionWon({
    required this.bidderId,
    required this.bidderName,
    required this.winningBid,
    required this.trump,
    super.timestamp,
  });

  @override
  String get eventName => 'AuctionWon';

  @override
  String get messageEn => '$bidderName won the auction with ${winningBid.trickCount} ${trump.name}!';

  @override
  String get messageAr => 'فاز $bidderName بالمزاد بـ ${winningBid.trickCount} ${trump.name}!';

  @override
  String get emoji => '🏅';

  @override
  Map<String, dynamic> toJson() => {
        'eventName': eventName,
        'bidderId': bidderId,
        'bidderName': bidderName,
        'winningBid': winningBid.toJson(),
        'trump': trump.name,
        'timestamp': timestamp.toIso8601String(),
      };
}

/// Triggered when a player passes during auction.
class AuctionPassed extends EstimationGameEvent {
  final String playerId;
  final String playerName;
  final int seatIndex;

  AuctionPassed({
    required this.playerId,
    required this.playerName,
    required this.seatIndex,
    super.timestamp,
  });

  @override
  String get eventName => 'AuctionPassed';

  @override
  String get messageEn => '$playerName passed the auction';

  @override
  String get messageAr => 'مرر $playerName في المزاد (Pass)';

  @override
  String get emoji => '⏭️';

  @override
  Map<String, dynamic> toJson() => {
        'eventName': eventName,
        'playerId': playerId,
        'playerName': playerName,
        'seatIndex': seatIndex,
        'timestamp': timestamp.toIso8601String(),
      };
}

/// Triggered when all players pass the auction (All-Pass).
class AllPlayersPassed extends EstimationGameEvent {
  final int roundNumber;
  final int nextRoundNumber;

  AllPlayersPassed({
    required this.roundNumber,
    required this.nextRoundNumber,
    super.timestamp,
  });

  @override
  String get eventName => 'AllPlayersPassed';

  @override
  String get messageEn => 'All players passed! Round $nextRoundNumber is now a Double Round (×2)!';

  @override
  String get messageAr => 'الجميع باص! الجولة $nextRoundNumber أصبحت دبل (×2)!';

  @override
  String get emoji => '⚡';

  @override
  Map<String, dynamic> toJson() => {
        'eventName': eventName,
        'roundNumber': roundNumber,
        'nextRoundNumber': nextRoundNumber,
        'timestamp': timestamp.toIso8601String(),
      };
}

// ─────────────────────────────────────────────────────────────────────────────
// 4. Declaration Events
// ─────────────────────────────────────────────────────────────────────────────

/// Triggered when a player submits their trick declaration.
class DeclarationMade extends EstimationGameEvent {
  final String playerId;
  final String playerName;
  final int declared;
  final int seatIndex;
  final bool isRisk;
  final bool isWith;

  DeclarationMade({
    required this.playerId,
    required this.playerName,
    required this.declared,
    required this.seatIndex,
    this.isRisk = false,
    this.isWith = false,
    super.timestamp,
  });

  @override
  String get eventName => 'DeclarationMade';

  @override
  String get messageEn => '$playerName declared $declared tricks${isRisk ? ' (RISK)' : ''}${isWith ? ' (WITH)' : ''}';

  @override
  String get messageAr => 'أعلن $playerName عن $declared لمات${isRisk ? ' (ريسك)' : ''}${isWith ? ' (معاه)' : ''}';

  @override
  String get emoji => '🎯';

  @override
  Map<String, dynamic> toJson() => {
        'eventName': eventName,
        'playerId': playerId,
        'playerName': playerName,
        'declared': declared,
        'seatIndex': seatIndex,
        'isRisk': isRisk,
        'isWith': isWith,
        'timestamp': timestamp.toIso8601String(),
      };
}

/// Triggered when a player achieves a Perfect Estimate (actual == declared).
class PerfectEstimate extends EstimationGameEvent {
  final String playerId;
  final String playerName;
  final int declared;
  final int actual;
  final int scoreDelta;
  final int roundNumber;
  final bool isBidder;
  final bool isRisk;

  PerfectEstimate({
    required this.playerId,
    required this.playerName,
    required this.declared,
    required this.actual,
    required this.scoreDelta,
    required this.roundNumber,
    this.isBidder = false,
    this.isRisk = false,
    super.timestamp,
  });

  @override
  String get eventName => 'PerfectEstimate';

  @override
  String get messageEn => 'PERFECT ESTIMATE! $playerName nailed $actual tricks (+$scoreDelta pts)!';

  @override
  String get messageAr => 'تقدير مثالي! حقق $playerName بالضبط $actual لمات (+$scoreDelta نقطة)!';

  @override
  String get emoji => '🎯';

  @override
  Map<String, dynamic> toJson() => {
        'eventName': eventName,
        'playerId': playerId,
        'playerName': playerName,
        'declared': declared,
        'actual': actual,
        'scoreDelta': scoreDelta,
        'roundNumber': roundNumber,
        'isBidder': isBidder,
        'isRisk': isRisk,
        'timestamp': timestamp.toIso8601String(),
      };
}

/// Triggered when a player misses their declaration (actual != declared).
class DeclarationMissed extends EstimationGameEvent {
  final String playerId;
  final String playerName;
  final int declared;
  final int actual;
  final int difference;
  final int scoreDelta;
  final int roundNumber;
  final bool isBidder;
  final bool isRisk;

  DeclarationMissed({
    required this.playerId,
    required this.playerName,
    required this.declared,
    required this.actual,
    required this.difference,
    required this.scoreDelta,
    required this.roundNumber,
    this.isBidder = false,
    this.isRisk = false,
    super.timestamp,
  });

  @override
  String get eventName => 'DeclarationMissed';

  @override
  String get messageEn => '$playerName missed estimate (declared $declared, took $actual, $scoreDelta pts)';

  @override
  String get messageAr => 'أخفق $playerName في التقدير (طلب $declared، حصل على $actual، $scoreDelta نقطة)';

  @override
  String get emoji => '❌';

  @override
  Map<String, dynamic> toJson() => {
        'eventName': eventName,
        'playerId': playerId,
        'playerName': playerName,
        'declared': declared,
        'actual': actual,
        'difference': difference,
        'scoreDelta': scoreDelta,
        'roundNumber': roundNumber,
        'isBidder': isBidder,
        'isRisk': isRisk,
        'timestamp': timestamp.toIso8601String(),
      };
}

/// Triggered when a player attempts to declare the forbidden declaration number.
class ForbiddenDeclarationAttempt extends EstimationGameEvent {
  final String playerId;
  final String playerName;
  final int forbiddenNumber;

  ForbiddenDeclarationAttempt({
    required this.playerId,
    required this.playerName,
    required this.forbiddenNumber,
    super.timestamp,
  });

  @override
  String get eventName => 'ForbiddenDeclarationAttempt';

  @override
  String get messageEn => 'Declaration $forbiddenNumber is forbidden (Forbidden 13 rule)!';

  @override
  String get messageAr => 'الرقم $forbiddenNumber ممنوع (قاعدة مجموع الـ 13 الممنوع)!';

  @override
  String get emoji => '🚫';

  @override
  Map<String, dynamic> toJson() => {
        'eventName': eventName,
        'playerId': playerId,
        'playerName': playerName,
        'forbiddenNumber': forbiddenNumber,
        'timestamp': timestamp.toIso8601String(),
      };
}

/// Triggered when the last declaring player declares a total <= 11, entering Risk mode.
class RiskDeclaration extends EstimationGameEvent {
  final String playerId;
  final String playerName;
  final int declared;
  final int totalTableDeclared;

  RiskDeclaration({
    required this.playerId,
    required this.playerName,
    required this.declared,
    required this.totalTableDeclared,
    super.timestamp,
  });

  @override
  String get eventName => 'RiskDeclaration';

  @override
  String get messageEn => '⚠️ RISK DECLARED by $playerName! Total declared: $totalTableDeclared (±10 pts)';

  @override
  String get messageAr => '⚠️ ريسك من $playerName! إجمالي الطلبات: $totalTableDeclared (±10 نقاط)';

  @override
  String get emoji => '⚠️';

  @override
  Map<String, dynamic> toJson() => {
        'eventName': eventName,
        'playerId': playerId,
        'playerName': playerName,
        'declared': declared,
        'totalTableDeclared': totalTableDeclared,
        'timestamp': timestamp.toIso8601String(),
      };
}

// ─────────────────────────────────────────────────────────────────────────────
// 5. Trick-Taking Events
// ─────────────────────────────────────────────────────────────────────────────

/// Triggered when a trick is resolved and collected by the winner.
class TrickWon extends EstimationGameEvent {
  final String winnerId;
  final String winnerName;
  final int trickNumber;
  final List<TrickCard> trickCards;
  final TrickCard winningCard;
  final bool isBidder;

  TrickWon({
    required this.winnerId,
    required this.winnerName,
    required this.trickNumber,
    required this.trickCards,
    required this.winningCard,
    this.isBidder = false,
    super.timestamp,
  });

  @override
  String get eventName => 'TrickWon';

  @override
  String get messageEn => '$winnerName won trick #$trickNumber with ${winningCard.card}';

  @override
  String get messageAr => 'فاز $winnerName باللمة #$trickNumber بورقة ${winningCard.card}';

  @override
  String get emoji => '🃏';

  @override
  Map<String, dynamic> toJson() => {
        'eventName': eventName,
        'winnerId': winnerId,
        'winnerName': winnerName,
        'trickNumber': trickNumber,
        'trickCards': trickCards.map((tc) => tc.toJson()).toList(),
        'winningCard': winningCard.toJson(),
        'isBidder': isBidder,
        'timestamp': timestamp.toIso8601String(),
      };
}

/// Triggered when the Bidder (Caller) wins a trick.
class BidderTrickWon extends EstimationGameEvent {
  final String bidderId;
  final String bidderName;
  final int trickNumber;
  final int bidderTotalTaken;

  BidderTrickWon({
    required this.bidderId,
    required this.bidderName,
    required this.trickNumber,
    required this.bidderTotalTaken,
    super.timestamp,
  });

  @override
  String get eventName => 'BidderTrickWon';

  @override
  String get messageEn => 'Bidder $bidderName won trick #$trickNumber ($bidderTotalTaken taken)';

  @override
  String get messageAr => 'الكولر $bidderName فاز باللمة #$trickNumber (مجموع اللمات: $bidderTotalTaken)';

  @override
  String get emoji => '👑';

  @override
  Map<String, dynamic> toJson() => {
        'eventName': eventName,
        'bidderId': bidderId,
        'bidderName': bidderName,
        'trickNumber': trickNumber,
        'bidderTotalTaken': bidderTotalTaken,
        'timestamp': timestamp.toIso8601String(),
      };
}

/// Triggered when the Bidder loses a trick to another player.
class BidderTrickLost extends EstimationGameEvent {
  final String bidderId;
  final String bidderName;
  final String winnerId;
  final String winnerName;
  final int trickNumber;

  BidderTrickLost({
    required this.bidderId,
    required this.bidderName,
    required this.winnerId,
    required this.winnerName,
    required this.trickNumber,
    super.timestamp,
  });

  @override
  String get eventName => 'BidderTrickLost';

  @override
  String get messageEn => 'Bidder $bidderName lost trick #$trickNumber to $winnerName!';

  @override
  String get messageAr => 'خسر الكولر $bidderName اللمة #$trickNumber لصالح $winnerName!';

  @override
  String get emoji => '🛡️';

  @override
  Map<String, dynamic> toJson() => {
        'eventName': eventName,
        'bidderId': bidderId,
        'bidderName': bidderName,
        'winnerId': winnerId,
        'winnerName': winnerName,
        'trickNumber': trickNumber,
        'timestamp': timestamp.toIso8601String(),
      };
}

// ─────────────────────────────────────────────────────────────────────────────
// 6. Meta & Comeback Events
// ─────────────────────────────────────────────────────────────────────────────

/// Triggered when a comeback condition is detected at the end of a round.
class ComebackDetected extends EstimationGameEvent {
  final ComebackEvent comeback;

  ComebackDetected({
    required this.comeback,
    super.timestamp,
  });

  @override
  String get eventName => 'ComebackDetected';

  @override
  String get messageEn => '${comeback.titleEn}: ${comeback.playerName} ${comeback.subtitleEn}';

  @override
  String get messageAr => '${comeback.titleAr}: ${comeback.playerName} ${comeback.subtitleAr}';

  @override
  String get emoji => comeback.iconEmoji;

  @override
  Map<String, dynamic> toJson() => {
        'eventName': eventName,
        'comeback': comeback.toJson(),
        'timestamp': timestamp.toIso8601String(),
      };
}

/// Triggered when a new player overtakes 1st place in score.
class PlayerTakesLead extends EstimationGameEvent {
  final String leaderId;
  final String leaderName;
  final int leaderScore;
  final String? previousLeaderId;
  final String? previousLeaderName;
  final int roundNumber;

  PlayerTakesLead({
    required this.leaderId,
    required this.leaderName,
    required this.leaderScore,
    this.previousLeaderId,
    this.previousLeaderName,
    required this.roundNumber,
    super.timestamp,
  });

  @override
  String get eventName => 'PlayerTakesLead';

  @override
  String get messageEn => previousLeaderName != null
      ? '$leaderName overtook $previousLeaderName for 1st place ($leaderScore pts)!'
      : '$leaderName took the lead ($leaderScore pts)!';

  @override
  String get messageAr => previousLeaderName != null
      ? 'انتزع $leaderName الصدارة من $previousLeaderName ($leaderScore نقطة)!'
      : 'تصدر $leaderName الترتيب ($leaderScore نقطة)!';

  @override
  String get emoji => '👑';

  @override
  Map<String, dynamic> toJson() => {
        'eventName': eventName,
        'leaderId': leaderId,
        'leaderName': leaderName,
        'leaderScore': leaderScore,
        'previousLeaderId': previousLeaderId,
        'previousLeaderName': previousLeaderName,
        'roundNumber': roundNumber,
        'timestamp': timestamp.toIso8601String(),
      };
}
