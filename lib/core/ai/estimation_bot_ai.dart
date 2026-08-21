// lib/core/ai/estimation_bot_ai.dart
//
// Grandmaster-level AI for Egyptian Estimation (Pocket Estimation).
// Implements advanced hand evaluation, probability modeling, positional bidding,
// tactical declarations (Forbidden 13 risk optimization), card memory/void tracking,
// trump pulling, under-the-winner ducking, and dangerous honor shedding.

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
  // ── 1. Advanced Hand Evaluation ──────────────────────────────────────────

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
    
    // Kings are dangerous unless protected by at least 2 lower cards
    bool hasDangerousKings = false;
    for (final suit in Suit.values) {
      final cards = suitsMap[suit] ?? [];
      final hasKing = cards.any((c) => c.rank == Rank.king);
      if (hasKing && cards.length < 3) {
        hasDangerousKings = true;
      }
    }

    final highCardsCount =
        hand.where((c) => c.rank.sortIndex >= Rank.jack.sortIndex).length;

    final isDash = hasNoAces &&
        !hasDangerousKings &&
        highCardsCount <= 2 &&
        currentExpected < 1.05;

    return HandEvaluation(
      expectedTricks: currentExpected,
      bestTrump: best,
      trumpEvaluations: trumpEvals,
      isStrongDashCandidate: isDash,
    );
  }

  static double _evalWithSans(Map<Suit, List<PlayingCard>> suitsMap) {
    double total = 0.0;
    int stoppers = 0;

    for (final suit in Suit.values) {
      final cards = suitsMap[suit] ?? [];
      final len = cards.length;
      if (len == 0) continue;

      final hasAce = cards.any((c) => c.rank == Rank.ace);
      final hasKing = cards.any((c) => c.rank == Rank.king);
      final hasQueen = cards.any((c) => c.rank == Rank.queen);
      final hasJack = cards.any((c) => c.rank == Rank.jack);
      final hasTen = cards.any((c) => c.rank == Rank.ten);

      if (hasAce) {
        total += 1.0;
        stoppers++;
      }
      if (hasKing) {
        if (hasAce) {
          total += 0.95;
        } else if (hasQueen && len >= 3) {
          total += 0.85;
          stoppers++;
        } else if (len >= 3) {
          total += 0.65;
          stoppers++;
        } else if (len == 2) {
          total += 0.45;
        } else {
          total += 0.25; // Singleton King often captured
        }
      }
      if (hasQueen) {
        if (hasAce && hasKing) {
          total += 0.90;
        } else if ((hasAce || hasKing) && len >= 3) {
          total += 0.55;
        } else if (len >= 4) {
          total += 0.35;
        }
      }
      if (hasJack) {
        if (hasAce && hasKing && hasQueen) {
          total += 0.85;
        } else if ((hasAce && hasKing) && len >= 4) {
          total += 0.40;
        } else if ((hasAce || hasKing) && len >= 4) {
          total += 0.25;
        }
      }
      if (hasTen && hasAce && hasKing && hasQueen && len >= 5) {
        total += 0.40;
      }

      // Long running suit potential in Sans when top control exists
      if ((hasAce && hasKing) && len >= 5) {
        total += (len - 4) * 0.80;
      } else if (hasAce && len >= 5) {
        total += (len - 4) * 0.60;
      }
    }

    // Sans bonus if all 4 suits are stopped
    if (stoppers >= 4) total += 0.5;

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
        total += trumpLen >= 2 ? 0.95 : 0.65;
      } else if (card.rank == Rank.queen) {
        total += trumpLen >= 3 ? 0.85 : (trumpLen >= 2 ? 0.55 : 0.3);
      } else if (card.rank == Rank.jack) {
        total += trumpLen >= 4 ? 0.60 : (trumpLen >= 3 ? 0.35 : 0.15);
      } else if (card.rank == Rank.ten) {
        total += trumpLen >= 5 ? 0.45 : (trumpLen >= 4 ? 0.20 : 0.05);
      }
    }

    // Trump length bonus (control & pulling power)
    if (trumpLen >= 5) {
      total += (trumpLen - 4) * 0.80;
    } else if (trumpLen == 4) {
      total += 0.45;
    }

    // Non-trump suits evaluation
    for (final suit in Suit.values) {
      if (suit == trumpSuit) continue;
      final cards = suitsMap[suit] ?? [];
      final len = cards.length;

      if (len == 0) {
        // Void in side suit: can ruff if holding sufficient trumps
        if (trumpLen >= 4) {
          total += 0.90;
        } else if (trumpLen >= 3) {
          total += 0.50;
        }
        continue;
      }

      if (len == 1) {
        // Singleton in side suit
        final card = cards.first;
        if (card.rank == Rank.ace) {
          total += 0.98;
        } else {
          if (trumpLen >= 4) {
            total += 0.70;
          } else if (trumpLen >= 3) {
            total += 0.35;
          }
        }
        continue;
      }

      if (len == 2) {
        // Doubleton
        final hasAce = cards.any((c) => c.rank == Rank.ace);
        final hasKing = cards.any((c) => c.rank == Rank.king);
        if (hasAce && hasKing) {
          total += 1.90;
        } else if (hasAce) {
          total += 1.0;
        } else if (hasKing) {
          total += 0.50;
        }
        if (trumpLen >= 4) total += 0.35;
        continue;
      }

      // Length >= 3
      final hasAce = cards.any((c) => c.rank == Rank.ace);
      final hasKing = cards.any((c) => c.rank == Rank.king);
      final hasQueen = cards.any((c) => c.rank == Rank.queen);
      final hasJack = cards.any((c) => c.rank == Rank.jack);

      if (hasAce) total += 0.98;
      if (hasKing) {
        total += hasAce ? 0.95 : (hasQueen ? 0.75 : 0.55);
      }
      if (hasQueen) {
        total += (hasAce && hasKing) ? 0.85 : (hasAce || hasKing ? 0.50 : 0.20);
      }
      if (hasJack && (hasAce || hasKing) && len >= 4) {
        total += 0.30;
      }
    }

    return total;
  }

  // ── 2. Pre-Auction Dash Call ────────────────────────────────────────────

  /// Determines whether the bot should take the risk of a pre-auction Dash Call.
  static bool shouldCallDash(Player bot) {
    final eval = evaluateHand(bot.hand);
    if (!eval.isStrongDashCandidate || eval.expectedTricks > 0.75) return false;

    // Verify all 4 suits have safe small guards
    for (final suit in Suit.values) {
      final inSuit = bot.hand.where((c) => c.suit == suit).toList();
      if (inSuit.isEmpty) continue;
      // If holding King or Queen, must have at least 2 smaller cards
      final maxRank = inSuit.map((c) => c.rank.sortIndex).reduce(max);
      if (maxRank >= Rank.queen.sortIndex && inSuit.length < 3) {
        return false; // High risk of being forced to win
      }
    }
    return true;
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
        // High IQ Forbidden 13 optimization:
        // If expected value is strictly below forbidden, going down is safer (ducking strategy).
        // If expected value has extra potential, stepping up is aggressive.
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

  // ── 6. Grandmaster Trick Taking Strategy ────────────────────────────────

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

    final cardMemory = _CardMemory.fromState(state, bot);

    if (state.currentTrick.isEmpty) {
      return _chooseLeadCard(state, bot, validCards, trump, wantToWin, cardMemory);
    } else {
      return _chooseFollowCard(state, bot, validCards, trump, wantToWin, cardMemory);
    }
  }

  // ── Lead Card Selection ─────────────────────────────────────────────────

  static PlayingCard _chooseLeadCard(
    GameState state,
    Player bot,
    List<PlayingCard> validCards,
    Trump? trump,
    bool wantToWin,
    _CardMemory memory,
  ) {
    final isSans = trump == null || trump.isSans;
    final trumpSuit = trump?.suit;

    if (wantToWin) {
      // 1. Trump Pulling: If holding top trumps & opponents still hold trumps, pull trumps!
      if (!isSans && trumpSuit != null) {
        final trumpsInHand = validCards.where((c) => c.suit == trumpSuit).toList();
        final opponentsHaveTrumps = memory.remainingTrumpsInGame > trumpsInHand.length;

        if (trumpsInHand.isNotEmpty && opponentsHaveTrumps) {
          final masterTrumps = trumpsInHand.where((c) => memory.isMaster(c)).toList();
          if (masterTrumps.isNotEmpty) {
            masterTrumps.sort((a, b) => b.rank.sortIndex.compareTo(a.rank.sortIndex));
            return masterTrumps.first; // Pull trumps with master trump
          }
        }
      }

      // 2. Cash master side suit cards (Aces or promoted masters)
      final masterSideCards = validCards.where((c) {
        if (!isSans && c.suit == trumpSuit) return false;
        return memory.isMaster(c);
      }).toList();

      if (masterSideCards.isNotEmpty) {
        masterSideCards.sort((a, b) => b.rank.sortIndex.compareTo(a.rank.sortIndex));
        return masterSideCards.first;
      }

      // 3. Lead high from longest strong suit to establish tricks
      final candidateSuits = isSans
          ? Suit.values
          : Suit.values.where((s) => s != trumpSuit).toList();

      Suit? bestSuit;
      int maxLen = 0;
      for (final s in candidateSuits) {
        final inSuit = validCards.where((c) => c.suit == s).toList();
        if (inSuit.length > maxLen) {
          maxLen = inSuit.length;
          bestSuit = s;
        }
      }

      if (bestSuit != null) {
        final inSuit = validCards.where((c) => c.suit == bestSuit).toList()
          ..sort((a, b) => b.rank.sortIndex.compareTo(a.rank.sortIndex));
        return inSuit.first;
      }

      final sorted = List<PlayingCard>.from(validCards)
        ..sort((a, b) => b.rank.sortIndex.compareTo(a.rank.sortIndex));
      return sorted.first;
    } else {
      // DUCKING / AVOIDING TRICKS (0-declarer or quota reached)
      // Rule 1: NEVER lead master cards.
      final nonMasterCards = validCards.where((c) => !memory.isMaster(c)).toList();
      final pool = nonMasterCards.isNotEmpty ? nonMasterCards : validCards;

      // Rule 2: Lead low cards from longest suit (opponents are likely to hold higher)
      final safeSuits = isSans
          ? Suit.values
          : Suit.values.where((s) => s != trumpSuit).toList();

      Suit? safestSuit;
      int maxLen = 0;
      for (final s in safeSuits) {
        final inSuit = pool.where((c) => c.suit == s).toList();
        if (inSuit.length > maxLen) {
          maxLen = inSuit.length;
          safestSuit = s;
        }
      }

      if (safestSuit != null) {
        final inSuit = pool.where((c) => c.suit == safestSuit).toList()
          ..sort((a, b) => a.rank.sortIndex.compareTo(b.rank.sortIndex));
        return inSuit.first; // Lead lowest card of longest suit
      }

      pool.sort((a, b) => a.rank.sortIndex.compareTo(b.rank.sortIndex));
      return pool.first;
    }
  }

  // ── Follow Card Selection ───────────────────────────────────────────────

  static PlayingCard _chooseFollowCard(
    GameState state,
    Player bot,
    List<PlayingCard> validCards,
    Trump? trump,
    bool wantToWin,
    _CardMemory memory,
  ) {
    final trick = state.currentTrick;
    final ledSuit = trick.first.card.suit;
    final isLastToPlay = trick.length == state.players.length - 1;
    final isSans = trump == null || trump.isSans;
    final trumpSuit = trump?.suit;

    final currentWinner = _getCurrentTrickWinner(trick, trump);
    final ledCards = validCards.where((c) => c.suit == ledSuit).toList();

    // ── CASE A: Bot HAS cards of led suit (Must follow suit)
    if (ledCards.isNotEmpty) {
      if (wantToWin) {
        if (!isSans && currentWinner.card.suit == trumpSuit && ledSuit != trumpSuit) {
          // Trick is already trumped; led suit card cannot win -> play lowest card
          ledCards.sort((a, b) => a.rank.sortIndex.compareTo(b.rank.sortIndex));
          return ledCards.first;
        }

        final winningCards = ledCards.where((c) {
          return c.rank.sortIndex > currentWinner.card.rank.sortIndex;
        }).toList();

        if (winningCards.isNotEmpty) {
          winningCards.sort((a, b) => a.rank.sortIndex.compareTo(b.rank.sortIndex));
          // Economy of honors: win with the CHEAPEST winning card
          return isLastToPlay ? winningCards.first : (winningCards.length > 1 ? winningCards[winningCards.length - 1] : winningCards.first);
        } else {
          // Cannot win: play lowest
          ledCards.sort((a, b) => a.rank.sortIndex.compareTo(b.rank.sortIndex));
          return ledCards.first;
        }
      } else {
        // DUCKING / AVOIDING TRICK
        if (!isSans && currentWinner.card.suit == trumpSuit && ledSuit != trumpSuit) {
          // Trick is already trumped; safely dump highest led card underneath the trump!
          ledCards.sort((a, b) => b.rank.sortIndex.compareTo(a.rank.sortIndex));
          return ledCards.first;
        }

        // Under-the-winner ducking: play highest card that is still lower than current winner
        final safeCards = ledCards.where((c) {
          return c.rank.sortIndex < currentWinner.card.rank.sortIndex;
        }).toList();

        if (safeCards.isNotEmpty) {
          safeCards.sort((a, b) => b.rank.sortIndex.compareTo(a.rank.sortIndex));
          return safeCards.first; // Safely dump highest card under winner
        } else {
          // Forced to play above winner: play lowest to minimize chance of winning if someone else plays higher
          ledCards.sort((a, b) => a.rank.sortIndex.compareTo(b.rank.sortIndex));
          return ledCards.first;
        }
      }
    }

    // ── CASE B: Bot is VOID in led suit
    if (isSans || trumpSuit == null) {
      // In Sans, cannot trump
      if (wantToWin) {
        validCards.sort((a, b) => a.rank.sortIndex.compareTo(b.rank.sortIndex));
        return validCards.first;
      } else {
        // Shed dangerous high honors (bare Kings, Queens, Jacks)
        final dangerousHonors = validCards.where((c) {
          return c.rank.sortIndex >= Rank.jack.sortIndex && !memory.isMaster(c);
        }).toList();

        if (dangerousHonors.isNotEmpty) {
          dangerousHonors.sort((a, b) => b.rank.sortIndex.compareTo(a.rank.sortIndex));
          return dangerousHonors.first; // Ditch highest dangerous honor
        }
        validCards.sort((a, b) => a.rank.sortIndex.compareTo(b.rank.sortIndex));
        return validCards.first;
      }
    }

    // Trump game void handling:
    final trumpCards = validCards.where((c) => c.suit == trumpSuit).toList();
    final nonTrumpCards = validCards.where((c) => c.suit != trumpSuit).toList();

    if (wantToWin) {
      if (trumpCards.isNotEmpty) {
        if (currentWinner.card.suit == trumpSuit) {
          // Overruff
          final overtrumps = trumpCards.where((c) {
            return c.rank.sortIndex > currentWinner.card.rank.sortIndex;
          }).toList();

          if (overtrumps.isNotEmpty) {
            overtrumps.sort((a, b) => a.rank.sortIndex.compareTo(b.rank.sortIndex));
            return isLastToPlay ? overtrumps.first : overtrumps.last;
          }
        } else {
          // Un-trumped trick: ruff with lowest trump
          trumpCards.sort((a, b) => a.rank.sortIndex.compareTo(b.rank.sortIndex));
          return trumpCards.first;
        }
      }

      // Cannot trump or overruff: discard lowest non-trump
      if (nonTrumpCards.isNotEmpty) {
        nonTrumpCards.sort((a, b) => a.rank.sortIndex.compareTo(b.rank.sortIndex));
        return nonTrumpCards.first;
      }
      trumpCards.sort((a, b) => a.rank.sortIndex.compareTo(b.rank.sortIndex));
      return trumpCards.first;
    } else {
      // DUCKING: NEVER ruff! Shed dangerous high non-trump honors
      if (nonTrumpCards.isNotEmpty) {
        final dangerousHonors = nonTrumpCards.where((c) {
          return c.rank.sortIndex >= Rank.jack.sortIndex;
        }).toList();

        if (dangerousHonors.isNotEmpty) {
          dangerousHonors.sort((a, b) => b.rank.sortIndex.compareTo(a.rank.sortIndex));
          return dangerousHonors.first; // Safely ditch bare dangerous honor!
        }

        nonTrumpCards.sort((a, b) => b.rank.sortIndex.compareTo(a.rank.sortIndex));
        return nonTrumpCards.first;
      }

      // Forced to play trump: play lowest trump
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
}

/// Internal card memory tracking played cards, masters, and opponent trumps.
class _CardMemory {
  final Set<String> playedCards;
  final int remainingTrumpsInGame;
  final Map<String, Set<Suit>> playerKnownVoids;

  _CardMemory({
    required this.playedCards,
    required this.remainingTrumpsInGame,
    required this.playerKnownVoids,
  });

  factory _CardMemory.fromState(GameState state, Player bot) {
    final played = <String>{};
    final voids = <String, Set<Suit>>{};

    for (final p in state.players) {
      voids[p.id] = <Suit>{};
      for (final trick in p.takenTricks) {
        final ledSuit = trick.isNotEmpty ? trick.first.card.suit : null;
        for (final tc in trick) {
          played.add(tc.card.id);
          if (ledSuit != null && tc.card.suit != ledSuit) {
            voids[tc.playerId]?.add(ledSuit);
          }
        }
      }
    }

    final currentLedSuit =
        state.currentTrick.isNotEmpty ? state.currentTrick.first.card.suit : null;
    for (final tc in state.currentTrick) {
      played.add(tc.card.id);
      if (currentLedSuit != null && tc.card.suit != currentLedSuit) {
        voids[tc.playerId]?.add(currentLedSuit);
      }
    }

    // Count remaining trumps in game
    int remainingTrumps = 0;
    final trumpSuit = state.trump?.suit;
    if (trumpSuit != null) {
      for (final rank in Rank.values) {
        final id = '${trumpSuit.name}_${rank.name}';
        if (!played.contains(id)) {
          remainingTrumps++;
        }
      }
    }

    return _CardMemory(
      playedCards: played,
      remainingTrumpsInGame: remainingTrumps,
      playerKnownVoids: voids,
    );
  }

  bool isMaster(PlayingCard card) {
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
