// lib/core/ai/estimation_bot_ai.dart

import 'dart:math';
import '../models/card.dart';
import '../models/bid.dart';
import '../models/player.dart';
import '../models/game_state.dart';
import '../constants.dart';
import '../game_engine.dart';

class HandEvaluation {
  final double expectedTricks;
  final Suit? bestSuit;
  final Map<Suit, double> suitEvaluations;
  final bool isStrongDashCandidate;

  const HandEvaluation({
    required this.expectedTricks,
    this.bestSuit,
    required this.suitEvaluations,
    required this.isStrongDashCandidate,
  });
}

class EstimationBotAi {
  // ── 1. Hand Evaluation ──────────────────────────────────────────────────

  /// Evaluates hand strength and expected tricks given a trump suit (or evaluates all suits if trumpSuit is null).
  static HandEvaluation evaluateHand(List<PlayingCard> hand, [Suit? trumpSuit]) {
    final suitsMap = <Suit, List<PlayingCard>>{
      for (final s in Suit.values) s: [],
    };
    for (final c in hand) {
      suitsMap[c.suit]?.add(c);
    }

    // Sort each suit descending (Ace first)
    for (final list in suitsMap.values) {
      list.sort((a, b) => b.rank.sortIndex.compareTo(a.rank.sortIndex));
    }

    final suitEvals = <Suit, double>{};
    for (final candidateTrump in Suit.values) {
      suitEvals[candidateTrump] = _evalWithTrump(suitsMap, candidateTrump);
    }

    // Best suit for bidding
    Suit? bestSuit;
    double maxTricks = -1;
    for (final entry in suitEvals.entries) {
      if (entry.value > maxTricks) {
        maxTricks = entry.value;
        bestSuit = entry.key;
      }
    }

    final currentExpected = trumpSuit != null
        ? (suitEvals[trumpSuit] ?? 0.0)
        : (bestSuit != null ? (suitEvals[bestSuit] ?? 0.0) : 0.0);

    // Check if hand is strong candidate for Dash (0 tricks)
    final hasNoAces = !hand.any((c) => c.rank == Rank.ace);
    final hasNoKings = !hand.any((c) => c.rank == Rank.king);
    final highCardsCount = hand.where((c) => c.rank.sortIndex >= Rank.jack.sortIndex).length;
    final isDash = hasNoAces && hasNoKings && highCardsCount <= 2 && currentExpected < 1.3;

    return HandEvaluation(
      expectedTricks: currentExpected,
      bestSuit: bestSuit,
      suitEvaluations: suitEvals,
      isStrongDashCandidate: isDash,
    );
  }

  static double _evalWithTrump(Map<Suit, List<PlayingCard>> suitsMap, Suit trumpSuit) {
    double total = 0.0;
    final trumpCards = suitsMap[trumpSuit] ?? [];
    final trumpLen = trumpCards.length;

    // Trump suit evaluation
    for (int i = 0; i < trumpCards.length; i++) {
      final card = trumpCards[i];
      if (card.rank == Rank.ace) {
        total += 1.0;
      } else if (card.rank == Rank.king) {
        total += trumpLen >= 2 ? 0.9 : 0.6;
      } else if (card.rank == Rank.queen) {
        total += trumpLen >= 3 ? 0.75 : (trumpLen >= 2 ? 0.5 : 0.3);
      } else if (card.rank == Rank.jack) {
        total += trumpLen >= 4 ? 0.5 : (trumpLen >= 3 ? 0.3 : 0.1);
      }
    }

    // Trump length bonus (control & ruffing power)
    if (trumpLen >= 4) {
      total += (trumpLen - 3) * 0.65;
    }

    // Non-trump suits evaluation
    for (final suit in Suit.values) {
      if (suit == trumpSuit) continue;
      final cards = suitsMap[suit] ?? [];
      final len = cards.length;

      if (len == 0) {
        // Void in side suit: can ruff if we have enough trumps
        if (trumpLen >= 4) {
          total += 0.85;
        } else if (trumpLen >= 2) {
          total += 0.4;
        }
        continue;
      }

      if (len == 1) {
        // Singleton in side suit
        final card = cards.first;
        if (card.rank == Rank.ace) {
          total += 0.95;
        } else {
          if (trumpLen >= 4) {
            total += 0.6;
          } else if (trumpLen >= 2) {
            total += 0.3;
          }
        }
        continue;
      }

      if (len == 2) {
        // Doubleton
        final hasAce = cards.any((c) => c.rank == Rank.ace);
        final hasKing = cards.any((c) => c.rank == Rank.king);
        if (hasAce && hasKing) {
          total += 1.8;
        } else if (hasAce) {
          total += 1.0;
        } else if (hasKing) {
          total += 0.45;
        }
        if (trumpLen >= 4) total += 0.3; // ruff 3rd round
        continue;
      }

      // Length >= 3
      final hasAce = cards.any((c) => c.rank == Rank.ace);
      final hasKing = cards.any((c) => c.rank == Rank.king);
      final hasQueen = cards.any((c) => c.rank == Rank.queen);
      final hasJack = cards.any((c) => c.rank == Rank.jack);

      if (hasAce) total += 0.95;
      if (hasKing) {
        total += hasAce ? 0.9 : 0.6;
      }
      if (hasQueen) {
        total += (hasAce && hasKing) ? 0.8 : (hasAce || hasKing ? 0.45 : 0.2);
      }
      if (hasJack && (hasAce || hasKing) && len >= 4) {
        total += 0.25;
      }
    }

    return total;
  }

  // ── 2. Auction Bidding ──────────────────────────────────────────────────

  /// Determines the best bid for the bot in the auction phase.
  /// Returns `null` if the bot should pass.
  static Bid? decideAuctionBid(GameState state, Player bot) {
    final eval = evaluateHand(bot.hand);
    final bestSuit = eval.bestSuit;
    if (bestSuit == null) return null;

    final bestExpected = eval.suitEvaluations[bestSuit] ?? 0.0;
    final trumpCards = bot.hand.where((c) => c.suit == bestSuit).length;

    // Minimum requirements to open or compete in auction:
    // Need at least 4 trump cards and reasonable expected tricks (>= 3.8)
    if (trumpCards < 4 || bestExpected < 3.8) {
      return null;
    }

    final maxSafeBidTricks = bestExpected.floor().clamp(4, 13);
    final currentHigh = state.currentHighBid;

    if (currentHigh == null) {
      // Opening bid
      return Bid(trickCount: min(maxSafeBidTricks, 4), trumpSuit: bestSuit);
    }

    // Try to find the lowest legal bid in bestSuit (or other strong suits) that beats currentHigh
    final candidateSuits = Suit.values.where((s) {
      final len = bot.hand.where((c) => c.suit == s).length;
      final exp = eval.suitEvaluations[s] ?? 0.0;
      return len >= 4 && exp >= 3.8;
    }).toList()
      ..sort((a, b) => (eval.suitEvaluations[b] ?? 0).compareTo(eval.suitEvaluations[a] ?? 0));

    for (final suit in candidateSuits) {
      final suitExp = eval.suitEvaluations[suit] ?? 0.0;
      final maxTricksForSuit = suitExp.floor().clamp(4, 13);

      for (int tc = currentHigh.trickCount; tc <= maxTricksForSuit; tc++) {
        final bid = Bid(trickCount: tc, trumpSuit: suit);
        if (GameEngine.isValidBid(bid, currentHigh)) {
          return bid;
        }
      }
    }

    return null; // Pass
  }

  // ── 3. Declarations ─────────────────────────────────────────────────────

  /// Calculates the bot's declaration (0–13).
  static int decideDeclaration(GameState state, Player bot) {
    final trump = state.trumpSuit;
    final eval = evaluateHand(bot.hand, trump);

    int declaration;
    final isBidder = state.bidderPlayerId == bot.id;
    final currentHigh = state.currentHighBid;

    if (isBidder && currentHigh != null) {
      // Bidder must declare at least the winning bid
      declaration = max(currentHigh.trickCount, eval.expectedTricks.round());
    } else {
      if (eval.isStrongDashCandidate) {
        declaration = 0;
      } else {
        declaration = eval.expectedTricks.round().clamp(0, 13);
      }
    }

    // Check if bot is the 4th (last) player to declare
    final declarationsDone = state.players.where((p) => p.declared != null).toList();
    if (declarationsDone.length == 3) {
      final sumPrevious = declarationsDone.fold<int>(0, (acc, p) => acc + (p.declared ?? 0));
      final forbidden = 13 - sumPrevious;

      if (declaration == forbidden) {
        final minAllowed = (isBidder && currentHigh != null) ? currentHigh.trickCount : 0;
        // If forbidden, decide whether to shift +1 or -1
        if (declaration == minAllowed) {
          declaration = min(13, declaration + 1);
        } else if (declaration == 13) {
          declaration = max(minAllowed, declaration - 1);
        } else {
          // Adjust based on decimal expectation
          if (eval.expectedTricks < declaration) {
            declaration = max(minAllowed, declaration - 1);
          } else {
            declaration = min(13, declaration + 1);
          }
        }
      }
    }

    return declaration.clamp(
      (isBidder && currentHigh != null) ? currentHigh.trickCount : 0,
      13,
    );
  }

  // ── 4. Void Check & Redeal ──────────────────────────────────────────────

  static bool shouldDeclareVoid(Player bot) {
    if (!GameEngine.hasVoidSuit(bot)) return false;
    final eval = evaluateHand(bot.hand);
    // Declare void and request redeal if hand is weak (< 2.5 expected tricks)
    return eval.expectedTricks < 2.5;
  }

  static bool shouldApproveRedeal(Player bot, GameState state) {
    final eval = evaluateHand(bot.hand);
    // If bot has a strong hand, reject redeal to preserve the advantage
    return eval.expectedTricks < 3.5;
  }

  // ── 5. Trick Taking Strategy ────────────────────────────────────────────

  /// Chooses the optimal card to play for [bot] in the current trick.
  static PlayingCard chooseCardToPlay(GameState state, Player bot) {
    final validCards = bot.hand
        .where((card) => GameEngine.canPlayCard(state, bot, card))
        .toList();

    if (validCards.isEmpty) {
      return bot.hand.first;
    }
    if (validCards.length == 1) {
      return validCards.first;
    }

    final declared = bot.declared ?? 0;
    final actual = bot.actual;
    final needed = declared - actual;
    final tricksLeft = 13 - state.tricksPlayedThisRound;
    final wantToWin = needed > 0 && needed <= tricksLeft;
    final trump = state.trumpSuit;

    // Track played cards so far to identify active master cards
    final playedCards = _collectPlayedCards(state);

    if (state.currentTrick.isEmpty) {
      return _chooseLeadCard(bot, validCards, trump, wantToWin, playedCards);
    } else {
      return _chooseFollowCard(state, bot, validCards, trump, wantToWin, playedCards);
    }
  }

  // ── Lead Card Selection ─────────────────────────────────────────────────

  static PlayingCard _chooseLeadCard(
    Player bot,
    List<PlayingCard> validCards,
    Suit? trump,
    bool wantToWin,
    Set<String> playedCards,
  ) {
    if (wantToWin) {
      // 1. Lead master non-trump cards (Ace, or King if Ace played)
      final masterNonTrump = validCards.where((c) {
        if (c.suit == trump) return false;
        return _isMasterCard(c, playedCards);
      }).toList();

      if (masterNonTrump.isNotEmpty) {
        masterNonTrump.sort((a, b) => b.rank.sortIndex.compareTo(a.rank.sortIndex));
        return masterNonTrump.first;
      }

      // 2. If holding top trumps (Ace/King of trump), pull trumps
      if (trump != null) {
        final topTrumps = validCards.where((c) => c.suit == trump && _isMasterCard(c, playedCards)).toList();
        if (topTrumps.isNotEmpty) {
          topTrumps.sort((a, b) => b.rank.sortIndex.compareTo(a.rank.sortIndex));
          return topTrumps.first;
        }
      }

      // 3. Lead high card in longest side suit
      final sideSuits = Suit.values.where((s) => s != trump).toList();
      Suit? longestSideSuit;
      int maxLen = 0;
      for (final s in sideSuits) {
        final count = validCards.where((c) => c.suit == s).length;
        if (count > maxLen) {
          maxLen = count;
          longestSideSuit = s;
        }
      }

      if (longestSideSuit != null) {
        final inSuit = validCards.where((c) => c.suit == longestSideSuit).toList()
          ..sort((a, b) => b.rank.sortIndex.compareTo(a.rank.sortIndex));
        return inSuit.first;
      }

      // Fallback: highest card
      final sorted = List<PlayingCard>.from(validCards)
        ..sort((a, b) => b.rank.sortIndex.compareTo(a.rank.sortIndex));
      return sorted.first;
    } else {
      // DUCKING / AVOIDING TRICKS (Bot has reached target or called Dash)
      // 1. Lead lowest card in a deep suit (3+ cards) where bot has low ranks
      final safeSuits = Suit.values.where((s) => s != trump).toList();
      PlayingCard? safestCard;
      int lowestRank = 999;

      for (final s in safeSuits) {
        final inSuit = validCards.where((c) => c.suit == s).toList();
        if (inSuit.length >= 2) {
          inSuit.sort((a, b) => a.rank.sortIndex.compareTo(b.rank.sortIndex));
          final lowest = inSuit.first;
          if (lowest.rank.sortIndex < lowestRank) {
            lowestRank = lowest.rank.sortIndex;
            safestCard = lowest;
          }
        }
      }

      if (safestCard != null) return safestCard;

      // 2. Play absolute lowest non-trump card
      final nonTrump = validCards.where((c) => c.suit != trump).toList();
      if (nonTrump.isNotEmpty) {
        nonTrump.sort((a, b) => a.rank.sortIndex.compareTo(b.rank.sortIndex));
        return nonTrump.first;
      }

      // 3. Forced to lead trump: lead lowest trump
      final sorted = List<PlayingCard>.from(validCards)
        ..sort((a, b) => a.rank.sortIndex.compareTo(b.rank.sortIndex));
      return sorted.first;
    }
  }

  // ── Follow Card Selection ───────────────────────────────────────────────

  static PlayingCard _chooseFollowCard(
    GameState state,
    Player bot,
    List<PlayingCard> validCards,
    Suit? trump,
    bool wantToWin,
    Set<String> playedCards,
  ) {
    final trick = state.currentTrick;
    final ledSuit = trick.first.card.suit;
    final isLastToPlay = trick.length == state.players.length - 1;
    final currentWinner = _getCurrentTrickWinner(trick, trump);

    final ledCards = validCards.where((c) => c.suit == ledSuit).toList();

    // ── SUBCASE A: Bot HAS cards of led suit (Must follow suit)
    if (ledCards.isNotEmpty) {
      if (wantToWin) {
        if (currentWinner.card.suit == trump && ledSuit != trump) {
          // Trick is already trumped; led suit card cannot win
          ledCards.sort((a, b) => a.rank.sortIndex.compareTo(b.rank.sortIndex));
          return ledCards.first;
        }

        // Winning cards in led suit
        final winningCards = ledCards.where((c) {
          return c.rank.sortIndex > currentWinner.card.rank.sortIndex;
        }).toList();

        if (winningCards.isNotEmpty) {
          winningCards.sort((a, b) => a.rank.sortIndex.compareTo(b.rank.sortIndex));
          if (isLastToPlay) {
            // Play lowest winning card to take trick efficiently
            return winningCards.first;
          } else {
            // Earlier in trick: play highest winning card
            return winningCards.last;
          }
        } else {
          // Cannot win with led suit: play lowest card
          ledCards.sort((a, b) => a.rank.sortIndex.compareTo(b.rank.sortIndex));
          return ledCards.first;
        }
      } else {
        // DUCKING / AVOIDING TRICK
        if (currentWinner.card.suit == trump && ledSuit != trump) {
          // Trick is trumped by someone else: safely discard highest led card under the trump!
          ledCards.sort((a, b) => b.rank.sortIndex.compareTo(a.rank.sortIndex));
          return ledCards.first;
        }

        // Cards lower than current winner (safe cards)
        final safeCards = ledCards.where((c) {
          return c.rank.sortIndex < currentWinner.card.rank.sortIndex;
        }).toList();

        if (safeCards.isNotEmpty) {
          // Play highest safe card to ditch high cards safely under the winner
          safeCards.sort((a, b) => b.rank.sortIndex.compareTo(a.rank.sortIndex));
          return safeCards.first;
        } else {
          // Forced to play higher than current winner: play lowest
          ledCards.sort((a, b) => a.rank.sortIndex.compareTo(b.rank.sortIndex));
          return ledCards.first;
        }
      }
    }

    // ── SUBCASE B: Bot is VOID in led suit (Can trump or discard)
    final trumpCards = trump != null ? validCards.where((c) => c.suit == trump).toList() : <PlayingCard>[];
    final nonTrumpCards = validCards.where((c) => c.suit != trump).toList();

    if (wantToWin) {
      if (trumpCards.isNotEmpty) {
        if (currentWinner.card.suit == trump) {
          // Current winner already trumped: can we overtrump?
          final overtrumps = trumpCards.where((c) {
            return c.rank.sortIndex > currentWinner.card.rank.sortIndex;
          }).toList();

          if (overtrumps.isNotEmpty) {
            overtrumps.sort((a, b) => a.rank.sortIndex.compareTo(b.rank.sortIndex));
            return isLastToPlay ? overtrumps.first : overtrumps.last;
          }
        } else {
          // Trick not yet trumped: any trump wins!
          trumpCards.sort((a, b) => a.rank.sortIndex.compareTo(b.rank.sortIndex));
          return trumpCards.first; // Lowest trump takes trick
        }
      }

      // No trumps or cannot overtrump: discard lowest useless card
      if (nonTrumpCards.isNotEmpty) {
        nonTrumpCards.sort((a, b) => a.rank.sortIndex.compareTo(b.rank.sortIndex));
        return nonTrumpCards.first;
      }
      // Only trumps left
      trumpCards.sort((a, b) => a.rank.sortIndex.compareTo(b.rank.sortIndex));
      return trumpCards.first;
    } else {
      // DUCKING / AVOIDING TRICK
      // DO NOT TRUMP! Discard dangerous high off-suit honors (Aces, Kings, Queens)
      if (nonTrumpCards.isNotEmpty) {
        nonTrumpCards.sort((a, b) => b.rank.sortIndex.compareTo(a.rank.sortIndex));
        return nonTrumpCards.first;
      }

      // Only trumps left in hand: play lowest trump
      trumpCards.sort((a, b) => a.rank.sortIndex.compareTo(b.rank.sortIndex));
      return trumpCards.first;
    }
  }

  // ── Helper Utilities ────────────────────────────────────────────────────

  static TrickCard _getCurrentTrickWinner(List<TrickCard> trick, Suit? trump) {
    final ledSuit = trick.first.card.suit;
    final trumps = trick.where((tc) => tc.card.suit == trump).toList();
    if (trumps.isNotEmpty) {
      trumps.sort((a, b) => b.card.rank.sortIndex.compareTo(a.card.rank.sortIndex));
      return trumps.first;
    }
    final ledCards = trick.where((tc) => tc.card.suit == ledSuit).toList();
    ledCards.sort((a, b) => b.card.rank.sortIndex.compareTo(a.card.rank.sortIndex));
    return ledCards.first;
  }

  static Set<String> _collectPlayedCards(GameState state) {
    final played = <String>{};
    for (final p in state.players) {
      for (final trick in p.takenTricks) {
        for (final tc in trick) {
          played.add(tc.card.id);
        }
      }
    }
    for (final tc in state.currentTrick) {
      played.add(tc.card.id);
    }
    return played;
  }

  static bool _isMasterCard(PlayingCard card, Set<String> playedCards) {
    for (int r = card.rank.sortIndex + 1; r <= Rank.ace.sortIndex; r++) {
      final higherRank = Rank.values.firstWhere((rk) => rk.sortIndex == r);
      final id = '${card.suit.name}_${higherRank.name}';
      if (!playedCards.contains(id)) {
        return false;
      }
    }
    return true;
  }
}
