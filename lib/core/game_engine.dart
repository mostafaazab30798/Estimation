// lib/core/game_engine.dart
//
// Pure game logic — no Flutter imports, fully testable.

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

  // ── Void-suit check ─────────────────────────────────────────

  /// Returns true if this player's hand has zero cards of any suit.
  static bool hasVoidSuit(Player player) {
    final suits = player.hand.map((c) => c.suit).toSet();
    return suits.length < Suit.values.length;
  }

  // ── Auction ─────────────────────────────────────────────────

  /// Validate that [bid] is a legal raise over the current highest bid.
  static bool isValidBid(Bid bid, Bid? currentHighBid) {
    if (bid.trickCount < 4) return false;
    if (currentHighBid == null) return true; // first bid, any bid >= 4 is legal
    return bid.beats(currentHighBid);
  }

  /// Submit a bid for [player]. Updates state's auction fields.
  /// Returns true if bid was accepted.
  static bool submitBid(GameState state, String playerId, Bid bid) {
    final player = state.playerById(playerId);
    if (player.seatIndex != state.auctionTurnSeatIndex) return false;
    
    if (!isValidBid(bid, state.currentHighBid)) return false;
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

  static void _advanceAuctionTurn(GameState state, {required bool passed}) {
    // Check if auction is over: all players except the current high bidder have passed
    final activePlayers = state.players.where((p) => !p.hasPassed).toList();
    if (activePlayers.length == 1 &&
        activePlayers.first.id == state.currentHighBidderPlayerId) {
      // Auction over
      _finaliseAuction(state);
      return;
    }

    // Check if all 4 have passed (no bid yet)
    if (activePlayers.isEmpty) {
      // Forced redeal
      _triggerRedeal(state);
      return;
    }

    // Advance to next non-passed player
    state.auctionTurnSeatIndex = _getNextChronologicalSeat(
      state,
      state.auctionTurnSeatIndex,
      (p) => !p.hasPassed,
    );
  }

  static int _getNextChronologicalSeat(GameState state, int currentSeat, bool Function(Player) isValid) {
    if (state.voidCheckPassed.length == state.players.length) {
      final readyList = state.voidCheckPassed.toList();
      final currentId = state.playerBySeat(currentSeat).id;
      final currIdx = readyList.indexOf(currentId);
      if (currIdx != -1) {
        for (int i = 1; i < state.players.length; i++) {
          final nextId = readyList[(currIdx + i) % state.players.length];
          final nextPlayer = state.playerById(nextId);
          if (isValid(nextPlayer)) {
            return nextPlayer.seatIndex;
          }
        }
      }
    }

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
    state.trumpSuit = state.currentHighBid!.trumpSuit;
    
    // The bidder must declare their tricks first
    bidder.declared = null;
    
    // The Bidder leads the first trick
    state.trickLeaderSeatIndex = bidder.seatIndex;
    
    // Bidder declares first
    state.currentPlayerSeatIndex = bidder.seatIndex;
    
    state.phase = GamePhase.declarations;
  }

  static void _triggerRedeal(GameState state) {
    _resetForNewDeal(state);
    state.phase = GamePhase.dealing;
  }

  // ── Declarations ────────────────────────────────────────────

  /// Players submit their trick declarations (0–13). Bidder cannot declare less than bid.
  static void submitDeclaration(
      GameState state, String playerId, int declared) {
    final player = state.playerById(playerId);
    if (state.currentPlayerSeatIndex != player.seatIndex) return;
    
    player.declared = declared;

    // Check if all players have declared
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
      // Trick not yet complete — advance to next player
      state.currentPlayerSeatIndex =
          (state.currentPlayerSeatIndex + 1) % state.players.length;
      return false;
    }

    return true; // Trick complete! Waiting for resolveTrick
  }

  /// Resolves the completed trick, updates scores, and advances to the next trick/phase.
  static void resolveTrick(GameState state) {
    // Trick complete — determine winner
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

  /// Determine winner of the completed trick per spec §8.1.
  static String _resolveTrick(GameState state) {
    final trump = state.trumpSuit;
    final ledSuit = state.currentTrick.first.card.suit;

    // Check for any trump cards
    final trumpCards =
        state.currentTrick.where((tc) => tc.card.suit == trump).toList();
    if (trumpCards.isNotEmpty) {
      // Highest trump wins
      trumpCards.sort(
          (a, b) => b.card.rank.sortIndex.compareTo(a.card.rank.sortIndex));
      return trumpCards.first.playerId;
    }

    // No trump — highest led-suit card wins
    final ledCards = state.currentTrick
        .where((tc) => tc.card.suit == ledSuit)
        .toList();
    ledCards.sort(
        (a, b) => b.card.rank.sortIndex.compareTo(a.card.rank.sortIndex));
    return ledCards.first.playerId;
  }

  // ── Scoring ─────────────────────────────────────────────────

  /// Compute and apply round scores using Egyptian Estimation rules.
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

    for (final p in state.players) {
      final declared = p.declared ?? 0;
      final actual = p.actual;
      final isBidder = p.id == state.bidderPlayerId;
      final isWith = !isBidder && (declared == bidderDeclared);
      
      int delta;
      if (actual == declared) {
        delta = actual + state.roundNumber;
        
        // Bidder bonus or "With" (Ma'aha) bonus
        if (isBidder || isWith) {
          delta += 10;
        }
        
        // Dash (0) bonus on Under games
        if (isUnder && declared == 0) {
          delta += 10;
        }
      } else {
        // Failed
        delta = -(declared - actual).abs() - state.roundNumber;
        
        // Bidder penalty or "With" penalty
        if (isBidder || isWith) {
          delta -= 10;
        }
      }
      
      p.totalScore += delta;
      deltas[p.id] = delta;
    }
    state.lastRoundScoreDeltas = deltas;
    return deltas;
  }

  // ── Round transition ─────────────────────────────────────────

  static void startNextRound(GameState state) {
    state.roundNumber++;
    state.dealerSeatIndex = (state.dealerSeatIndex + 1) % state.players.length;
    // First bidder = seat after dealer
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
    state.trumpSuit = null;
    state.currentTrick = [];
    state.trickLeaderSeatIndex = 0;
    state.tricksPlayedThisRound = 0;
    state.currentPlayerSeatIndex = 0;
    state.voidCheckPassed = {};
  }

  /// Prepare initial GameState for a new match.
  static GameState createInitialState(List<Player> players) {
    final state = GameState(
      players: players,
      phase: GamePhase.lobby,
      roundNumber: 1,
      dealerSeatIndex: 0,
      auctionTurnSeatIndex: 1,
    );
    return state;
  }
}

