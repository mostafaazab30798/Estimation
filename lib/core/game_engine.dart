// lib/core/game_engine.dart
//
// Pure game logic — official Egyptian Estimation (Pocket Estimation) rules.

import 'dart:math';
import 'models/card.dart';
import 'models/bid.dart';
import 'models/player.dart';
import 'models/game_state.dart';
import 'constants.dart';

class GameEngine {
  static final Random _rng = Random();

  // ── Deck helpers ────────────────────────────────────────────

  /// Shuffle and deal 13 cards to each of 4 players, one at a time.
  static void dealCards(GameState state) {
    final deck = PlayingCard.fullDeck()..shuffle(_rng);
    // Clear existing hands
    for (final p in state.players) {
      p.hand = [];
    }
    // Deal one at a time, round-robin
    for (int i = 0; i < deck.length; i++) {
      final seatIndex = i % state.players.length;
      state.playerBySeat(seatIndex).hand.add(deck[i]);
    }
    // Auto-sort each hand
    for (final p in state.players) {
      autoSort(p.hand);
    }
  }

  /// Sort a hand in-place per spec §4.
  static void autoSort(List<PlayingCard> hand) {
    hand.sort((a, b) => a.sortKey.compareTo(b.sortKey));
  }

  // ── Void-suit check (Preserved Custom Rule) ─────────────────

  /// Returns true if this player's hand has zero cards of any suit.
  static bool hasVoidSuit(Player player) {
    final suits = player.hand.map((c) => c.suit).toSet();
    return suits.length < Suit.values.length;
  }

  /// Player confirms void check (or triggers redeal)
  static void passVoidCheck(GameState state, String playerId) {
    state.voidCheckPassed.add(playerId);
    if (state.voidCheckPassed.length == state.players.length) {
      // Void check complete -> Proceed to Pre-Auction Dash Call phase
      state.dashCallPassed.clear();
      state.phase = GamePhase.dashCall;
      state.currentPlayerSeatIndex =
          (state.dealerSeatIndex + 1) % state.players.length;
    }
  }

  // ── Pre-Auction Dash Call ────────────────────────────────────

  /// Submit Dash Call response (true = calls Dash Call, false = passes)
  static void submitDashCall(
      GameState state, String playerId, bool wantsDashCall) {
    final player = state.playerById(playerId);
    if (player.seatIndex != state.currentPlayerSeatIndex) return;

    state.dashCallPassed.add(playerId);
    if (wantsDashCall) {
      player.isDashCall = true;
      player.declared = 0;
      player.hasPassed = true; // Cannot bid in auction if Dash Called
    }

    if (state.dashCallPassed.length == state.players.length) {
      // Dash call phase complete -> Advance to Auction
      state.auctionTurnSeatIndex =
          (state.dealerSeatIndex + 1) % state.players.length;
      state.phase = GamePhase.auction;
      _checkAuctionState(state);
    } else {
      state.currentPlayerSeatIndex =
          (state.currentPlayerSeatIndex + 1) % state.players.length;
    }
  }

  // ── Auction ─────────────────────────────────────────────────

  /// Validate that [bid] is a legal raise over the current highest bid.
  static bool isValidBid(Bid bid, Bid? currentHighBid,
      {Trump? fixedTrump, int roundNumber = 1}) {
    if (bid.trickCount < kMinBidTricks) return false;

    // Last 5 rounds fixed trump rule
    if (fixedTrump != null) {
      if (bid.trump != fixedTrump) {
        // Can only override fixed trump if bidding 8 or more
        if (bid.trickCount < kOverrideFixedTrumpTricks) return false;
      }
    }

    if (currentHighBid == null) return true; // first bid
    return bid.beats(currentHighBid);
  }

  /// Submit a bid for [player]. Updates state's auction fields.
  static bool submitBid(GameState state, String playerId, Bid bid) {
    final player = state.playerById(playerId);
    if (player.seatIndex != state.auctionTurnSeatIndex) return false;
    if (player.isDashCall) return false;

    final fixed = state.fixedTrump;
    if (!isValidBid(bid, state.currentHighBid,
        fixedTrump: fixed, roundNumber: state.roundNumber)) {
      return false;
    }

    state.currentHighBid = bid;
    state.currentHighBidderPlayerId = playerId;
    _advanceAuctionTurn(state, passed: false);
    return true;
  }

  /// Player passes in the auction.
  static void passBid(GameState state, String playerId) {
    final player = state.playerById(playerId);
    if (player.seatIndex != state.auctionTurnSeatIndex) return;

    player.hasPassed = true;
    _advanceAuctionTurn(state, passed: true);
  }

  static void _checkAuctionState(GameState state) {
    final activePlayers = state.players.where((p) => !p.hasPassed).toList();
    if (activePlayers.isEmpty) {
      _handleAllPass(state);
    } else if (activePlayers.length == 1 &&
        state.currentHighBidderPlayerId != null &&
        activePlayers.first.id == state.currentHighBidderPlayerId) {
      _finaliseAuction(state);
    } else if (state.playerBySeat(state.auctionTurnSeatIndex).hasPassed) {
      _advanceAuctionTurn(state, passed: false);
    }
  }

  static void _advanceAuctionTurn(GameState state, {required bool passed}) {
    final activePlayers = state.players.where((p) => !p.hasPassed).toList();

    // If only the high bidder is left, auction is won
    if (activePlayers.length == 1 &&
        state.currentHighBidderPlayerId != null &&
        activePlayers.first.id == state.currentHighBidderPlayerId) {
      _finaliseAuction(state);
      return;
    }

    // All players passed (no one bid)
    if (activePlayers.isEmpty) {
      _handleAllPass(state);
      return;
    }

    // Advance to next non-passed player
    state.auctionTurnSeatIndex = _getNextChronologicalSeat(
      state,
      state.auctionTurnSeatIndex,
      (p) => !p.hasPassed,
    );
  }

  static void _handleAllPass(GameState state) {
    // Official Rule: All-pass skips the round and doubles next round's points (Double x2)
    state.isDoubleRound = true;
    startNextRound(state);
  }

  static int _getNextChronologicalSeat(
      GameState state, int currentSeat, bool Function(Player) isValid) {
    int next = (currentSeat + 1) % state.players.length;
    while (next != currentSeat) {
      if (isValid(state.playerBySeat(next))) {
        return next;
      }
      next = (next + 1) % state.players.length;
    }
    return currentSeat;
  }

  static void _finaliseAuction(GameState state) {
    final bidder = state.playerById(state.currentHighBidderPlayerId!);
    state.bidderPlayerId = bidder.id;

    // Set trump (check for fixed trump rule vs override)
    final fixed = state.fixedTrump;
    if (fixed != null &&
        (state.currentHighBid!.trickCount < kOverrideFixedTrumpTricks ||
            state.currentHighBid!.trump == fixed)) {
      state.trump = fixed;
    } else {
      state.trump = state.currentHighBid!.trump;
    }

    // Bidder leads first trick
    state.trickLeaderSeatIndex = bidder.seatIndex;

    // Bidder declares first
    state.currentPlayerSeatIndex = bidder.seatIndex;
    state.phase = GamePhase.declarations;
  }

  static void triggerRedeal(GameState state) {
    _resetForNewDeal(state);
    state.phase = GamePhase.dealing;
  }

  // ── Declarations ────────────────────────────────────────────

  /// Compute the forbidden declaration for the last declaring player (if applicable)
  static int? getForbiddenDeclaration(GameState state, String playerId) {
    final player = state.playerById(playerId);
    if (player.isDashCall) return null;

    final declaredPlayers =
        state.players.where((p) => p.declared != null).toList();
    if (declaredPlayers.length == state.players.length - 1) {
      final sum = declaredPlayers.fold<int>(0, (s, p) => s + (p.declared ?? 0));
      final forbidden = 13 - sum;
      if (forbidden >= 0 && forbidden <= 13) return forbidden;
    }
    return null;
  }

  /// Compute the max allowed declaration for a player (cannot exceed Bidder)
  static int? getMaxAllowedDeclaration(GameState state, String playerId) {
    final player = state.playerById(playerId);
    if (player.isDashCall) return 0;
    if (player.id == state.bidderPlayerId) return 13;

    final bidder = state.bidder;
    if (bidder != null && bidder.declared != null) {
      return bidder.declared;
    }
    return 13;
  }

  /// Players submit their trick declarations.
  /// Enforces: Bidder min, Non-bidder max <= Bidder, Forbidden 13, and Risk.
  static bool submitDeclaration(
      GameState state, String playerId, int declared) {
    final player = state.playerById(playerId);
    if (state.currentPlayerSeatIndex != player.seatIndex) return false;

    // Dash Call lock
    if (player.isDashCall && declared != 0) return false;

    // Bidder min declaration check
    if (player.id == state.bidderPlayerId && state.currentHighBid != null) {
      if (declared < state.currentHighBid!.trickCount) return false;
    }

    // Non-bidder max declaration check (cannot exceed bidder)
    final maxAllowed = getMaxAllowedDeclaration(state, playerId);
    if (maxAllowed != null && declared > maxAllowed) return false;

    // Forbidden 13 check for last player
    final forbidden = getForbiddenDeclaration(state, playerId);
    if (forbidden != null && declared == forbidden) return false;

    // Risk check for last player
    final declaredPlayers =
        state.players.where((p) => p.declared != null).toList();
    if (declaredPlayers.length == state.players.length - 1) {
      final sum = declaredPlayers.fold<int>(0, (s, p) => s + (p.declared ?? 0)) + declared;
      if (sum <= 11) {
        player.isRisk = true;
      }
    }

    player.declared = declared;

    // Advance to next undeclared player
    if (state.players.every((p) => p.declared != null)) {
      state.currentPlayerSeatIndex = state.trickLeaderSeatIndex;
      state.phase = GamePhase.trickTaking;
    } else {
      state.currentPlayerSeatIndex = _getNextChronologicalSeat(
        state,
        state.currentPlayerSeatIndex,
        (p) => p.declared == null,
      );
    }
    return true;
  }

  // ── Trick-taking ─────────────────────────────────────────────

  /// Returns true if [player] is allowed to play [card] right now.
  /// Enforces follow-suit rule (spec §8).
  static bool canPlayCard(
      GameState state, Player player, PlayingCard card) {
    if (state.currentPlayerSeatIndex != player.seatIndex) return false;
    if (!player.hand.contains(card)) return false;

    if (state.currentTrick.isEmpty) return true; // leader may play anything

    final ledSuit = state.currentTrick.first.card.suit;
    final hasLedSuit = player.hand.any((c) => c.suit == ledSuit);
    if (hasLedSuit && card.suit != ledSuit) return false; // must follow suit
    return true;
  }

  /// Play [card] for [player]. Returns true if the trick is now complete
  /// (4 cards played), otherwise false.
  static bool playCard(
      GameState state, String playerId, PlayingCard card) {
    final player = state.playerById(playerId);
    player.hand.remove(card);
    state.currentTrick.add(TrickCard(playerId: playerId, card: card));

    if (state.currentTrick.length < state.players.length) {
      state.currentPlayerSeatIndex =
          (state.currentPlayerSeatIndex + 1) % state.players.length;
      return false;
    }

    return true; // Trick complete!
  }

  /// Resolves the completed trick, updates scores, and advances to the next trick/phase.
  static void resolveTrick(GameState state) {
    final winnerId = _resolveTrick(state);
    final winner = state.playerById(winnerId);
    winner.takenTricks.add(List.from(state.currentTrick));
    winner.actual++;
    state.tricksPlayedThisRound++;
    state.currentTrick = [];
    state.trickLeaderSeatIndex = winner.seatIndex;
    state.currentPlayerSeatIndex = winner.seatIndex;

    if (state.tricksPlayedThisRound == kTricksPerRound) {
      state.phase = GamePhase.scoring;
    }
  }

  /// Determine winner of the completed trick per official rules.
  static String _resolveTrick(GameState state) {
    final trump = state.trump;
    final ledSuit = state.currentTrick.first.card.suit;

    // If trump is Sans (No Trump), highest of led suit always wins
    if (trump == null || trump.isSans) {
      final ledCards = state.currentTrick
          .where((tc) => tc.card.suit == ledSuit)
          .toList();
      ledCards.sort(
          (a, b) => b.card.rank.sortIndex.compareTo(a.card.rank.sortIndex));
      return ledCards.first.playerId;
    }

    // Standard Trump: check for trump cards first
    final trumpSuit = trump.suit!;
    final trumpCards =
        state.currentTrick.where((tc) => tc.card.suit == trumpSuit).toList();
    if (trumpCards.isNotEmpty) {
      trumpCards.sort(
          (a, b) => b.card.rank.sortIndex.compareTo(a.card.rank.sortIndex));
      return trumpCards.first.playerId;
    }

    // No trump played -> highest led-suit card wins
    final ledCards = state.currentTrick
        .where((tc) => tc.card.suit == ledSuit)
        .toList();
    ledCards.sort(
        (a, b) => b.card.rank.sortIndex.compareTo(a.card.rank.sortIndex));
    return ledCards.first.playerId;
  }

  // ── Scoring ─────────────────────────────────────────────────

  /// Compute and apply round scores using official Egyptian Estimation rules.
  static Map<String, int> computeAndApplyScores(GameState state) {
    final deltas = <String, int>{};

    int totalDeclared = 0;
    int bidderDeclared = 0;
    for (final p in state.players) {
      totalDeclared += (p.declared ?? 0);
      if (p.id == state.bidderPlayerId) {
        bidderDeclared = p.declared ?? 0;
      }
    }

    final isUnder = totalDeclared < 13;
    final multiplier = state.isDoubleRound ? 2 : 1;

    for (final p in state.players) {
      final declared = p.declared ?? 0;
      final actual = p.actual;
      final isBidder = p.id == state.bidderPlayerId;
      final isWith = !isBidder && (declared == bidderDeclared);
      final isDashCall = p.isDashCall;
      final isRisk = p.isRisk;

      int delta;

      if (isDashCall) {
        // Pre-auction Dash Call scoring
        if (actual == 0) {
          delta = !isUnder ? 33 : 25; // Win: +33 in Over, +25 in Under
        } else {
          delta = !isUnder ? -33 : -25; // Fail: -33 in Over, -25 in Under
        }
      } else if (actual == declared) {
        // Made declaration
        delta = actual + state.roundNumber;

        // Caller, With, or Risk bonus (+10)
        if (isBidder || isWith || isRisk) {
          delta += 10;
        }

        // Regular Dash (0) in Under bonus (+10)
        if (isUnder && declared == 0) {
          delta += 10;
        }
      } else {
        // Failed declaration
        delta = -(declared - actual).abs() - state.roundNumber;

        // Caller, With, or Risk penalty (-10)
        if (isBidder || isWith || isRisk) {
          delta -= 10;
        }
      }

      delta = delta * multiplier;
      p.totalScore += delta;
      deltas[p.id] = delta;
    }

    state.lastRoundScoreDeltas = deltas;
    state.isDoubleRound = false; // Reset multiplier after scoring applied
    return deltas;
  }

  // ── Round transition ─────────────────────────────────────────

  static void startNextRound(GameState state) {
    if (state.roundNumber >= state.totalRounds) {
      state.phase = GamePhase.matchEnd;
      return;
    }

    state.roundNumber++;
    state.dealerSeatIndex = (state.dealerSeatIndex + 1) % state.players.length;
    final firstBidder = (state.dealerSeatIndex + 1) % state.players.length;
    state.auctionTurnSeatIndex = firstBidder;

    for (final p in state.players) {
      p.resetForRound();
    }
    _resetRoundState(state);
    state.phase = GamePhase.dealing;
  }

  static void _resetForNewDeal(GameState state) {
    for (final p in state.players) {
      p.resetForRound();
    }
    _resetRoundState(state);
  }

  static void _resetRoundState(GameState state) {
    state.currentHighBid = null;
    state.currentHighBidderPlayerId = null;
    state.bidderPlayerId = null;
    state.trump = null;
    state.currentTrick = [];
    state.trickLeaderSeatIndex = 0;
    state.tricksPlayedThisRound = 0;
    state.currentPlayerSeatIndex = 0;
    state.voidCheckPassed = {};
    state.dashCallPassed = {};
  }

  /// Prepare initial GameState for a new match.
  static GameState createInitialState(List<Player> players,
      {int totalRounds = kBoulaTotalRounds}) {
    final state = GameState(
      players: players,
      phase: GamePhase.lobby,
      roundNumber: 1,
      totalRounds: totalRounds,
      dealerSeatIndex: 0,
      auctionTurnSeatIndex: 1,
    );
    return state;
  }
}
