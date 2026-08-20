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
  final Trump? bestTrump;
  final Map<Trump, double> trumpEvaluations;
  final bool isStrongDashCandidate;

  // Compatibility getter
  Suit? get bestSuit => bestTrump?.suit;
  Map<Suit, double> get suitEvaluations => {
        for (final entry in trumpEvaluations.entries)
          if (entry.key.suit != null) entry.key.suit!: entry.value,
      };

  const HandEvaluation({
    required this.expectedTricks,
    this.bestTrump,
    required this.trumpEvaluations,
    required this.isStrongDashCandidate,
  });
}

class EstimationBotAi {
  // ── 1. Hand Evaluation ──────────────────────────────────────────────────

  /// Evaluates hand strength and expected tricks given a trump contract (or all contracts if null).
  static HandEvaluation evaluateHand(List<PlayingCard> hand, [dynamic trumpContract]) {
    Trump? targetTrump;
    if (trumpContract is Trump?) {
      targetTrump = trumpContract;
    } else if (trumpContract is Suit?) {
      targetTrump = trumpContract != null ? Trump.fromSuit(trumpContract) : null;
    }

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

    final trumpEvals = <Trump, double>{};
    for (final candidate in Trump.values) {
      if (candidate == Trump.sans) {
        trumpEvals[candidate] = _evalWithSans(suitsMap);
      } else {
        trumpEvals[candidate] = _evalWithTrump(suitsMap, candidate.suit!);
      }
    }

    // Find best trump contract
    Trump? best;
    double maxTricks = -1;
    for (final entry in trumpEvals.entries) {
      if (entry.value > maxTricks) {
        maxTricks = entry.value;
        best = entry.key;
      }
    }

    final currentExpected = targetTrump != null
        ? (trumpEvals[targetTrump] ?? 0.0)
        : (best != null ? (trumpEvals[best] ?? 0.0) : 0.0);

    // Check if hand is strong candidate for Dash (0 tricks)
    final hasNoAces = !hand.any((c) => c.rank == Rank.ace);
    final hasNoKings = !hand.any((c) => c.rank == Rank.king);
    final highCardsCount =
        hand.where((c) => c.rank.sortIndex >= Rank.jack.sortIndex).length;
    final isDash = hasNoAces &&
        hasNoKings &&
        highCardsCount <= 2 &&
        currentExpected < 1.1;

    return HandEvaluation(
      expectedTricks: currentExpected,
      bestTrump: best,
      trumpEvaluations: trumpEvals,
      isStrongDashCandidate: isDash,
    );
  }

  static double _evalWithSans(Map<Suit, List<PlayingCard>> suitsMap) {
    double total = 0.0;
    for (final suit in Suit.values) {
      final cards = suitsMap[suit] ?? [];
      final len = cards.length;
      if (len == 0) continue;

      final hasAce = cards.any((c) => c.rank == Rank.ace);
      final hasKing = cards.any((c) => c.rank == Rank.king);
      final hasQueen = cards.any((c) => c.rank == Rank.queen);
      final hasJack = cards.any((c) => c.rank == Rank.jack);

      if (hasAce) total += 1.0;
      if (hasKing && (hasAce || len >= 2)) total += 0.8;
      if (hasQueen && hasAce && hasKing) total += 0.65;
      else if (hasQueen && (hasAce || hasKing) && len >= 3) total += 0.4;
      if (hasJack && hasAce && hasKing && len >= 4) total += 0.3;

      // Long running suit potential in Sans
      if (hasAce && hasKing && len >= 5) {
        total += (len - 4) * 0.7;
      }
    }
    return total;
  }

  static double _evalWithTrump(
      Map<Suit, List<PlayingCard>> suitsMap, Suit trumpSuit) {
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
        if (trumpLen >= 4) total += 0.3;
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

  // ── 2. Pre-Auction Dash Call ────────────────────────────────────────────

  /// Determines whether the bot should take the risk of a pre-auction Dash Call.
  static bool shouldCallDash(Player bot) {
    final eval = evaluateHand(bot.hand);
    return eval.isStrongDashCandidate && eval.expectedTricks < 0.85;
  }

  // ── 3. Auction Bidding ──────────────────────────────────────────────────

  /// Determines the best bid for the bot in the auction phase.
  /// Returns `null` if the bot should pass.
  static Bid? decideAuctionBid(GameState state, Player bot) {
    if (bot.isDashCall) return null;

    final eval = evaluateHand(bot.hand);
    final fixed = state.fixedTrump;
    final currentHigh = state.currentHighBid;

    // Handle last 5 rounds with fixed trump
    if (fixed != null) {
      final fixedExp = eval.trumpEvaluations[fixed] ?? 0.0;
      final maxFixedTricks = fixedExp.floor().clamp(4, 13);

      if (currentHigh == null) {
        if (fixedExp >= 3.8) {
          return Bid(trickCount: min(maxFixedTricks, 4), trump: fixed);
        }
      } else {
        // Try raising in fixed trump
        for (int tc = currentHigh.trickCount; tc <= maxFixedTricks; tc++) {
          final b = Bid(trickCount: tc, trump: fixed);
          if (GameEngine.isValidBid(b, currentHigh, fixedTrump: fixed, roundNumber: state.roundNumber)) {
            return b;
          }
        }
      }

      // Check for 8+ override powerhouse in a different trump
      for (final t in Trump.values) {
        if (t == fixed) continue;
        final tExp = eval.trumpEvaluations[t] ?? 0.0;
        if (tExp >= 7.8) {
          final overrideBid = Bid(trickCount: max(8, tExp.floor()), trump: t);
          if (GameEngine.isValidBid(overrideBid, currentHigh, fixedTrump: fixed, roundNumber: state.roundNumber)) {
            return overrideBid;
          }
        }
      }
      return null; // Pass
    }

    // Regular free auction
    final candidateTrumps = Trump.values.where((t) {
      final exp = eval.trumpEvaluations[t] ?? 0.0;
      if (t == Trump.sans) {
        return exp >= 4.2;
      }
      final len = bot.hand.where((c) => c.suit == t.suit).length;
      return len >= 4 && exp >= 3.8;
    }).toList()
      ..sort((a, b) => (eval.trumpEvaluations[b] ?? 0).compareTo(eval.trumpEvaluations[a] ?? 0));

    if (candidateTrumps.isEmpty) return null;

    if (currentHigh == null) {
      final best = candidateTrumps.first;
      final exp = eval.trumpEvaluations[best] ?? 0.0;
      final maxSafe = exp.floor().clamp(4, 13);
      return Bid(trickCount: min(maxSafe, 4), trump: best);
    }

    for (final t in candidateTrumps) {
      final tExp = eval.trumpEvaluations[t] ?? 0.0;
      final maxTricks = tExp.floor().clamp(4, 13);

      for (int tc = currentHigh.trickCount; tc <= maxTricks; tc++) {
        final bid = Bid(trickCount: tc, trump: t);
        if (GameEngine.isValidBid(bid, currentHigh)) {
          return bid;
        }
      }
    }

    return null; // Pass
  }

  // ── 4. Declarations ─────────────────────────────────────────────────────

  /// Calculates the bot's declaration (0–13), adhering to official rules.
  static int decideDeclaration(GameState state, Player bot) {
    if (bot.isDashCall) return 0;

    final trump = state.trump;
    final eval = evaluateHand(bot.hand, trump);

    int declaration;
    final isBidder = state.bidderPlayerId == bot.id;
    final currentHigh = state.currentHighBid;

    if (isBidder && currentHigh != null) {
      declaration = max(currentHigh.trickCount, eval.expectedTricks.round());
    } else {
      if (eval.isStrongDashCandidate) {
        declaration = 0;
      } else {
        declaration = eval.expectedTricks.round().clamp(0, 13);
      }
    }

    // Constraint: Non-bidders cannot declare > Bidder
    final maxAllowed = GameEngine.getMaxAllowedDeclaration(state, bot.id);
    if (maxAllowed != null && declaration > maxAllowed) {
      declaration = maxAllowed;
    }

    // Constraint: Forbidden 13 for 4th player
    final forbidden = GameEngine.getForbiddenDeclaration(state, bot.id);
    if (forbidden != null && declaration == forbidden) {
      final minAllowed = (isBidder && currentHigh != null) ? currentHigh.trickCount : 0;
      final maxLimit = maxAllowed ?? 13;

      if (declaration == minAllowed && declaration < maxLimit) {
        declaration++;
      } else if (declaration == maxLimit && declaration > minAllowed) {
        declaration--;
      } else {
        if (eval.expectedTricks < declaration && declaration > minAllowed) {
          declaration--;
        } else if (declaration < maxLimit) {
          declaration++;
        } else if (declaration > minAllowed) {
          declaration--;
        }
      }
    }

    return declaration;
  }

  // ── 5. Void Check & Redeal (Preserved) ──────────────────────────────────

  static bool shouldDeclareVoid(Player bot) {
    if (!GameEngine.hasVoidSuit(bot)) return false;
    final eval = evaluateHand(bot.hand);
    return eval.expectedTricks < 2.5;
  }

  static bool shouldApproveRedeal(Player bot, GameState state) {
    final eval = evaluateHand(bot.hand);
    return eval.expectedTricks < 3.5;
  }

  // ── 6. Trick Taking Strategy ────────────────────────────────────────────

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
    final trump = state.trump;

    final playedCards = _collectPlayedCards(state);

    if (state.currentTrick.isEmpty) {
      return _chooseLeadCard(bot, validCards, trump, wantToWin, playedCards);
    } else {
      return _chooseFollowCard(
          state, bot, validCards, trump, wantToWin, playedCards);
    }
  }

  // ── Lead Card Selection ─────────────────────────────────────────────────

  static PlayingCard _chooseLeadCard(
    Player bot,
    List<PlayingCard> validCards,
    Trump? trump,
    bool wantToWin,
    Set<String> playedCards,
  ) {
    final isSans = trump == null || trump.isSans;
    final trumpSuit = trump?.suit;

    if (wantToWin) {
      // 1. Lead master non-trump cards
      final masterCards = validCards.where((c) {
        if (!isSans && c.suit == trumpSuit) return false;
        return _isMasterCard(c, playedCards);
      }).toList();

      if (masterCards.isNotEmpty) {
        masterCards.sort((a, b) => b.rank.sortIndex.compareTo(a.rank.sortIndex));
        return masterCards.first;
      }

      // 2. If holding top trumps in trump game, pull trumps
      if (!isSans && trumpSuit != null) {
        final topTrumps = validCards
            .where((c) => c.suit == trumpSuit && _isMasterCard(c, playedCards))
            .toList();
        if (topTrumps.isNotEmpty) {
          topTrumps.sort((a, b) => b.rank.sortIndex.compareTo(a.rank.sortIndex));
          return topTrumps.first;
        }
      }

      // 3. Lead high card in longest side suit
      final candidateSuits = isSans
          ? Suit.values
          : Suit.values.where((s) => s != trumpSuit).toList();

      Suit? longestSuit;
      int maxLen = 0;
      for (final s in candidateSuits) {
        final count = validCards.where((c) => c.suit == s).length;
        if (count > maxLen) {
          maxLen = count;
          longestSuit = s;
        }
      }

      if (longestSuit != null) {
        final inSuit = validCards.where((c) => c.suit == longestSuit).toList()
          ..sort((a, b) => b.rank.sortIndex.compareTo(a.rank.sortIndex));
        return inSuit.first;
      }

      final sorted = List<PlayingCard>.from(validCards)
        ..sort((a, b) => b.rank.sortIndex.compareTo(a.rank.sortIndex));
      return sorted.first;
    } else {
      // DUCKING / AVOIDING TRICKS
      final safeSuits = isSans
          ? Suit.values
          : Suit.values.where((s) => s != trumpSuit).toList();

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

      final nonTrump = isSans
          ? validCards
          : validCards.where((c) => c.suit != trumpSuit).toList();
      if (nonTrump.isNotEmpty) {
        nonTrump.sort((a, b) => a.rank.sortIndex.compareTo(b.rank.sortIndex));
        return nonTrump.first;
      }

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
    Trump? trump,
    bool wantToWin,
    Set<String> playedCards,
  ) {
    final trick = state.currentTrick;
    final ledSuit = trick.first.card.suit;
    final isLastToPlay = trick.length == state.players.length - 1;
    final isSans = trump == null || trump.isSans;
    final trumpSuit = trump?.suit;

    final currentWinner = _getCurrentTrickWinner(trick, trump);
    final ledCards = validCards.where((c) => c.suit == ledSuit).toList();

    // ── SUBCASE A: Bot HAS cards of led suit (Must follow suit)
    if (ledCards.isNotEmpty) {
      if (wantToWin) {
        if (!isSans && currentWinner.card.suit == trumpSuit && ledSuit != trumpSuit) {
          // Trick is already trumped; led suit card cannot win
          ledCards.sort((a, b) => a.rank.sortIndex.compareTo(b.rank.sortIndex));
          return ledCards.first;
        }

        final winningCards = ledCards.where((c) {
          return c.rank.sortIndex > currentWinner.card.rank.sortIndex;
        }).toList();

        if (winningCards.isNotEmpty) {
          winningCards.sort((a, b) => a.rank.sortIndex.compareTo(b.rank.sortIndex));
          return isLastToPlay ? winningCards.first : winningCards.last;
        } else {
          ledCards.sort((a, b) => a.rank.sortIndex.compareTo(b.rank.sortIndex));
          return ledCards.first;
        }
      } else {
        // DUCKING / AVOIDING TRICK
        if (!isSans && currentWinner.card.suit == trumpSuit && ledSuit != trumpSuit) {
          // Discard highest led card safely under the trump
          ledCards.sort((a, b) => b.rank.sortIndex.compareTo(a.rank.sortIndex));
          return ledCards.first;
        }

        final safeCards = ledCards.where((c) {
          return c.rank.sortIndex < currentWinner.card.rank.sortIndex;
        }).toList();

        if (safeCards.isNotEmpty) {
          safeCards.sort((a, b) => b.rank.sortIndex.compareTo(a.rank.sortIndex));
          return safeCards.first;
        } else {
          ledCards.sort((a, b) => a.rank.sortIndex.compareTo(b.rank.sortIndex));
          return ledCards.first;
        }
      }
    }

    // ── SUBCASE B: Bot is VOID in led suit
    if (isSans || trumpSuit == null) {
      // In Sans, cannot trump. Discard useless low cards or high honors when ducking
      if (wantToWin) {
        validCards.sort((a, b) => a.rank.sortIndex.compareTo(b.rank.sortIndex));
        return validCards.first;
      } else {
        validCards.sort((a, b) => b.rank.sortIndex.compareTo(a.rank.sortIndex));
        return validCards.first;
      }
    }

    final trumpCards = validCards.where((c) => c.suit == trumpSuit).toList();
    final nonTrumpCards = validCards.where((c) => c.suit != trumpSuit).toList();

    if (wantToWin) {
      if (trumpCards.isNotEmpty) {
        if (currentWinner.card.suit == trumpSuit) {
          final overtrumps = trumpCards.where((c) {
            return c.rank.sortIndex > currentWinner.card.rank.sortIndex;
          }).toList();

          if (overtrumps.isNotEmpty) {
            overtrumps.sort((a, b) => a.rank.sortIndex.compareTo(b.rank.sortIndex));
            return isLastToPlay ? overtrumps.first : overtrumps.last;
          }
        } else {
          trumpCards.sort((a, b) => a.rank.sortIndex.compareTo(b.rank.sortIndex));
          return trumpCards.first;
        }
      }

      if (nonTrumpCards.isNotEmpty) {
        nonTrumpCards.sort((a, b) => a.rank.sortIndex.compareTo(b.rank.sortIndex));
        return nonTrumpCards.first;
      }
      trumpCards.sort((a, b) => a.rank.sortIndex.compareTo(b.rank.sortIndex));
      return trumpCards.first;
    } else {
      // DUCKING: Discard high off-suit honors, avoid trumping
      if (nonTrumpCards.isNotEmpty) {
        nonTrumpCards.sort((a, b) => b.rank.sortIndex.compareTo(a.rank.sortIndex));
        return nonTrumpCards.first;
      }
      trumpCards.sort((a, b) => a.rank.sortIndex.compareTo(b.rank.sortIndex));
      return trumpCards.first;
    }
  }

  // ── Helper Utilities ────────────────────────────────────────────────────

  static TrickCard _getCurrentTrickWinner(List<TrickCard> trick, Trump? trump) {
    final ledSuit = trick.first.card.suit;
    if (trump != null && !trump.isSans && trump.suit != null) {
      final trumps = trick.where((tc) => tc.card.suit == trump.suit).toList();
      if (trumps.isNotEmpty) {
        trumps.sort((a, b) => b.card.rank.sortIndex.compareTo(a.card.rank.sortIndex));
        return trumps.first;
      }
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
