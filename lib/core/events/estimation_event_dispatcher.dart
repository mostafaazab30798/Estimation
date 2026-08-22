// lib/core/events/estimation_event_dispatcher.dart
//
// Centralized dispatcher that translates game engine operations and state transitions
// into typed EstimationGameEvents on the EstimationEventBus.

import '../constants.dart';
import '../models/bid.dart';
import '../models/card.dart';
import '../models/comeback_event.dart';
import '../models/game_state.dart';
import '../models/player.dart';
import 'estimation_event_bus.dart';
import 'estimation_game_events.dart';

class EstimationEventDispatcher {
  final EstimationEventBus _bus;

  EstimationEventDispatcher({EstimationEventBus? bus})
      : _bus = bus ?? EstimationEventBus.instance;

  static final EstimationEventDispatcher instance =
      EstimationEventDispatcher();

  // ── State Transition Analyzer ──────────────────────────────────────────────

  /// Automatically detects and fires all contextual events between [oldState] and [newState].
  void dispatchStateTransition(GameState? oldState, GameState newState) {
    if (oldState == null) {
      if (newState.phase != GamePhase.lobby) {
        notifyRoundStarted(newState);
      }
      return;
    }

    // 1. Round start
    final roundChanged = oldState.roundNumber != newState.roundNumber;
    final enteredDealing = oldState.phase != GamePhase.dealing &&
        newState.phase == GamePhase.dealing;
    if (roundChanged || enteredDealing) {
      notifyRoundStarted(newState);
    }

    // 2. Void Check Completed
    if (oldState.phase == GamePhase.voidCheck &&
        newState.phase != GamePhase.voidCheck) {
      final redealOccurred = newState.phase == GamePhase.dealing;
      notifyVoidCheckCompleted(
        newState,
        redealOccurred: redealOccurred,
        declaringPlayerId: oldState.voidDeclaringPlayerId,
      );
    }

    // 3. Pre-Auction Dash Call
    for (final p in newState.players) {
      final oldP = oldState.players.where((x) => x.id == p.id).firstOrNull;
      if (p.isDashCall && (oldP == null || !oldP.isDashCall)) {
        notifyDashCallMade(p);
      }
    }

    // 4. Auction - High bid & passes
    if (newState.currentHighBid != null &&
        (oldState.currentHighBid == null ||
            oldState.currentHighBid != newState.currentHighBid)) {
      final bidderId = newState.currentHighBidderPlayerId;
      if (bidderId != null) {
        final bidder = newState.players.where((x) => x.id == bidderId).firstOrNull;
        if (bidder != null) {
          notifyBidPlaced(
            bidder,
            newState.currentHighBid!,
            previousHighBid: oldState.currentHighBid,
          );
        }
      }
    }

    if (oldState.phase == GamePhase.auction || newState.phase == GamePhase.auction) {
      for (final p in newState.players) {
        final oldP = oldState.players.where((x) => x.id == p.id).firstOrNull;
        if (p.hasPassed && (oldP == null || !oldP.hasPassed)) {
          notifyAuctionPassed(p);
        }
      }
    }

    // Auction Won
    if (oldState.phase == GamePhase.auction &&
        newState.phase == GamePhase.declarations &&
        newState.bidderPlayerId != null) {
      final bidder = newState.players.where((x) => x.id == newState.bidderPlayerId).firstOrNull;
      if (bidder != null && newState.currentHighBid != null && newState.trump != null) {
        notifyAuctionWon(bidder, newState.currentHighBid!, newState.trump!);
      }
    }

    // All players passed
    if (oldState.phase == GamePhase.auction &&
        !oldState.isDoubleRound &&
        newState.isDoubleRound) {
      notifyAllPlayersPassed(oldState.roundNumber, newState.roundNumber);
    }

    // 5. Declarations
    for (final p in newState.players) {
      final oldP = oldState.players.where((x) => x.id == p.id).firstOrNull;
      if (p.declared != null && (oldP == null || oldP.declared == null || oldP.declared != p.declared)) {
        final isWith = p.id != newState.bidderPlayerId &&
            p.declared == newState.bidder?.declared;
        notifyDeclarationMade(p, p.declared!, isRisk: p.isRisk, isWith: isWith);

        if (p.isRisk && (oldP == null || !oldP.isRisk)) {
          final totalTable = newState.players.fold<int>(0, (s, x) => s + (x.declared ?? 0));
          notifyRiskDeclaration(p, p.declared!, totalTable);
        }
      }
    }

    // 6. Trick-taking
    if (newState.tricksPlayedThisRound > oldState.tricksPlayedThisRound) {
      Player? trickWinner;
      for (final p in newState.players) {
        final oldP = oldState.players.where((x) => x.id == p.id).firstOrNull;
        if (oldP != null && p.actual > oldP.actual) {
          trickWinner = p;
          break;
        }
      }
      trickWinner ??= newState.playerBySeat(newState.trickLeaderSeatIndex);

      List<TrickCard> trickCards = [];
      if (trickWinner.takenTricks.isNotEmpty) {
        trickCards = trickWinner.takenTricks.last;
      }
      final winningCard = trickCards.where((tc) => tc.playerId == trickWinner?.id).firstOrNull ??
          (trickCards.isNotEmpty ? trickCards.last : TrickCard(playerId: trickWinner.id, card: PlayingCard(rank: Rank.ace, suit: Suit.spade)));

      notifyTrickWon(
        winner: trickWinner,
        trickNumber: newState.tricksPlayedThisRound,
        trickCards: trickCards,
        winningCard: winningCard,
        bidderPlayerId: newState.bidderPlayerId,
        players: newState.players,
      );
    }

    // 7. Scoring & Round End
    if (oldState.phase != GamePhase.scoring && newState.phase == GamePhase.scoring) {
      // Find previous leader before this round deltas
      String? prevLeaderId;
      String? prevLeaderName;
      int maxPrevScore = -999999;
      for (final p in newState.players) {
        final delta = newState.lastRoundScoreDeltas[p.id] ?? 0;
        final scoreBefore = p.totalScore - delta;
        if (scoreBefore > maxPrevScore) {
          maxPrevScore = scoreBefore;
          prevLeaderId = p.id;
          prevLeaderName = p.name;
        }
      }

      notifyRoundScoring(
        state: newState,
        scoreDeltas: newState.lastRoundScoreDeltas,
        previousLeaderId: prevLeaderId,
        previousLeaderName: prevLeaderName,
      );
    }

    // 8. Match Completion
    if (oldState.phase != GamePhase.matchEnd &&
        (newState.phase == GamePhase.matchEnd || newState.isMatchOver)) {
      notifyMatchCompleted(newState);
    }
  }

  // ── Round & Phase ──────────────────────────────────────────────────────────

  void notifyRoundStarted(GameState state) {
    final isFinal = state.roundNumber >= state.totalRounds;
    final sorted = [...state.players]
      ..sort((a, b) => b.totalScore.compareTo(a.totalScore));
    final leader = sorted.isNotEmpty ? sorted.first : null;

    if (state.isDoubleRound) {
      _bus.fire(DoubleRoundStarted(roundNumber: state.roundNumber));
    }

    if (isFinal) {
      _bus.fire(FinalRoundStarted(
        roundNumber: state.roundNumber,
        totalRounds: state.totalRounds,
        leaderPlayerId: leader?.id,
        leaderPlayerName: leader?.name,
      ));
    }

    _bus.fire(RoundStarted(
      roundNumber: state.roundNumber,
      totalRounds: state.totalRounds,
      dealerSeatIndex: state.dealerSeatIndex,
      isDoubleRound: state.isDoubleRound,
      fixedTrump: state.fixedTrump,
    ));
  }

  void notifyVoidCheckCompleted(
    GameState state, {
    bool redealOccurred = false,
    String? declaringPlayerId,
  }) {
    _bus.fire(VoidCheckCompleted(
      roundNumber: state.roundNumber,
      redealOccurred: redealOccurred,
      declaringPlayerId: declaringPlayerId,
    ));
  }

  // ── Dash Call ──────────────────────────────────────────────────────────────

  void notifyDashCallMade(Player player) {
    _bus.fire(DashCallMade(
      playerId: player.id,
      playerName: player.name,
      seatIndex: player.seatIndex,
    ));
  }

  // ── Auction ────────────────────────────────────────────────────────────────

  void notifyBidPlaced(
    Player player,
    Bid bid, {
    Bid? previousHighBid,
  }) {
    _bus.fire(BidPlaced(
      playerId: player.id,
      playerName: player.name,
      bid: bid,
      seatIndex: player.seatIndex,
    ));

    if (previousHighBid == null || bid.beats(previousHighBid)) {
      _bus.fire(HighBidChanged(
        playerId: player.id,
        playerName: player.name,
        newHighBid: bid,
        previousHighBid: previousHighBid,
      ));
    }
  }

  void notifyAuctionPassed(Player player) {
    _bus.fire(AuctionPassed(
      playerId: player.id,
      playerName: player.name,
      seatIndex: player.seatIndex,
    ));
  }

  void notifyAuctionWon(
    Player bidder,
    Bid winningBid,
    Trump trump,
  ) {
    _bus.fire(AuctionWon(
      bidderId: bidder.id,
      bidderName: bidder.name,
      winningBid: winningBid,
      trump: trump,
    ));
  }

  void notifyAllPlayersPassed(int roundNumber, int nextRoundNumber) {
    _bus.fire(AllPlayersPassed(
      roundNumber: roundNumber,
      nextRoundNumber: nextRoundNumber,
    ));
  }

  // ── Declarations ───────────────────────────────────────────────────────────

  void notifyDeclarationMade(
    Player player,
    int declared, {
    bool isRisk = false,
    bool isWith = false,
  }) {
    _bus.fire(DeclarationMade(
      playerId: player.id,
      playerName: player.name,
      declared: declared,
      seatIndex: player.seatIndex,
      isRisk: isRisk,
      isWith: isWith,
    ));
  }

  void notifyForbiddenDeclarationAttempt(
    Player player,
    int forbiddenNumber,
  ) {
    _bus.fire(ForbiddenDeclarationAttempt(
      playerId: player.id,
      playerName: player.name,
      forbiddenNumber: forbiddenNumber,
    ));
  }

  void notifyRiskDeclaration(
    Player player,
    int declared,
    int totalTableDeclared,
  ) {
    _bus.fire(RiskDeclaration(
      playerId: player.id,
      playerName: player.name,
      declared: declared,
      totalTableDeclared: totalTableDeclared,
    ));
  }

  // ── Trick-taking ───────────────────────────────────────────────────────────

  void notifyTrickWon({
    required Player winner,
    required int trickNumber,
    required List<TrickCard> trickCards,
    required TrickCard winningCard,
    required String? bidderPlayerId,
    required List<Player> players,
  }) {
    final isBidder = winner.id == bidderPlayerId;

    _bus.fire(TrickWon(
      winnerId: winner.id,
      winnerName: winner.name,
      trickNumber: trickNumber,
      trickCards: trickCards,
      winningCard: winningCard,
      isBidder: isBidder,
    ));

    if (bidderPlayerId != null) {
      final bidder = players.where((p) => p.id == bidderPlayerId).firstOrNull;
      if (bidder != null) {
        if (isBidder) {
          _bus.fire(BidderTrickWon(
            bidderId: bidder.id,
            bidderName: bidder.name,
            trickNumber: trickNumber,
            bidderTotalTaken: winner.actual,
          ));
        } else {
          _bus.fire(BidderTrickLost(
            bidderId: bidder.id,
            bidderName: bidder.name,
            winnerId: winner.id,
            winnerName: winner.name,
            trickNumber: trickNumber,
          ));
        }
      }
    }
  }

  // ── Scoring & End of Round ─────────────────────────────────────────────────

  void notifyRoundScoring({
    required GameState state,
    required Map<String, int> scoreDeltas,
    String? previousLeaderId,
    String? previousLeaderName,
  }) {
    // Detect comebacks for this round
    final comebacks = ComebackDetector.detectRoundComebacks(
      state: state,
      roundNumber: state.roundNumber,
    );

    for (final comeback in comebacks) {
      _bus.fire(ComebackDetected(comeback: comeback));
    }

    // Check individual player declaration results
    final roundRecord = state.roundHistory
        .where((r) => r.roundNumber == state.roundNumber)
        .firstOrNull;

    final records = roundRecord?.playerRecords ?? [];

    for (final pRec in records) {
      final delta = scoreDeltas[pRec.playerId] ?? pRec.scoreDelta;
      if (pRec.isDashCall) {
        if (pRec.actual == 0) {
          _bus.fire(DashCallSucceeded(
            playerId: pRec.playerId,
            playerName: pRec.playerName,
            scoreDelta: delta,
            roundNumber: state.roundNumber,
          ));
        } else {
          _bus.fire(DashCallFailed(
            playerId: pRec.playerId,
            playerName: pRec.playerName,
            actualTricks: pRec.actual,
            scoreDelta: delta,
            roundNumber: state.roundNumber,
          ));
        }
      } else {
        if (pRec.actual == pRec.declared) {
          _bus.fire(PerfectEstimate(
            playerId: pRec.playerId,
            playerName: pRec.playerName,
            declared: pRec.declared,
            actual: pRec.actual,
            scoreDelta: delta,
            roundNumber: state.roundNumber,
            isBidder: pRec.isBidder,
            isRisk: pRec.isRisk,
          ));
        } else {
          _bus.fire(DeclarationMissed(
            playerId: pRec.playerId,
            playerName: pRec.playerName,
            declared: pRec.declared,
            actual: pRec.actual,
            difference: (pRec.declared - pRec.actual).abs(),
            scoreDelta: delta,
            roundNumber: state.roundNumber,
            isBidder: pRec.isBidder,
            isRisk: pRec.isRisk,
          ));
        }
      }
    }

    // Fire generic RoundCompleted
    _bus.fire(RoundCompleted(
      roundNumber: state.roundNumber,
      scoreDeltas: scoreDeltas,
      records: records,
      comebacks: comebacks,
    ));

    // Check if leader changed
    final sortedPlayers = [...state.players]
      ..sort((a, b) => b.totalScore.compareTo(a.totalScore));
    if (sortedPlayers.isNotEmpty) {
      final currentLeader = sortedPlayers.first;
      if (previousLeaderId != null && previousLeaderId != currentLeader.id) {
        _bus.fire(PlayerTakesLead(
          leaderId: currentLeader.id,
          leaderName: currentLeader.name,
          leaderScore: currentLeader.totalScore,
          previousLeaderId: previousLeaderId,
          previousLeaderName: previousLeaderName,
          roundNumber: state.roundNumber,
        ));
      } else if (state.roundNumber == 1) {
        _bus.fire(PlayerTakesLead(
          leaderId: currentLeader.id,
          leaderName: currentLeader.name,
          leaderScore: currentLeader.totalScore,
          previousLeaderId: previousLeaderId != currentLeader.id ? previousLeaderId : null,
          previousLeaderName: previousLeaderId != currentLeader.id ? previousLeaderName : null,
          roundNumber: state.roundNumber,
        ));
      }
    }
  }

  // ── Match Completion ───────────────────────────────────────────────────────

  void notifyMatchCompleted(GameState state) {
    final sortedPlayers = [...state.players]
      ..sort((a, b) => b.totalScore.compareTo(a.totalScore));
    final winner = sortedPlayers.isNotEmpty ? sortedPlayers.first : state.players.first;

    _bus.fire(MatchCompleted(
      winner: winner,
      rankings: sortedPlayers,
      totalRounds: state.roundNumber,
    ));
  }
}
