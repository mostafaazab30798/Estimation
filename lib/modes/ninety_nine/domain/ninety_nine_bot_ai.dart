// lib/modes/ninety_nine/domain/ninety_nine_bot_ai.dart

import 'package:estimation/core/constants.dart';
import 'package:estimation/core/models/card.dart';
import 'ninety_nine_card_rules.dart';

class NinetyNineBotAi {
  /// Picks the optimal card for a bot to play in 99 mode given its [hand] and the current [groundTotal].
  static PlayingCard chooseCard({
    required List<PlayingCard> hand,
    required int groundTotal,
  }) {
    if (hand.isEmpty) throw StateError('Hand is empty');
    if (hand.length == 1) return hand.first;

    // 1. When ground total is 99, we MUST play a safe card if we have one (4, 7, Jack, King)
    if (groundTotal == 99) {
      final safeCards = hand.where((c) => c.isSafeCard).toList();
      if (safeCards.isNotEmpty) {
        // Priority 1: Jack (-10) — breaks out of the danger zone
        final jacks = safeCards.where((c) => c.rank == Rank.jack).toList();
        if (jacks.isNotEmpty) return jacks.first;

        // Priority 2: 7 (Reverse) — sends the danger back to the previous player
        final sevens = safeCards.where((c) => c.rank == Rank.seven).toList();
        if (sevens.isNotEmpty) return sevens.first;

        // Priority 3: 4 (+0) — safely passes turn
        final fours = safeCards.where((c) => c.rank == Rank.four).toList();
        if (fours.isNotEmpty) return fours.first;

        // Priority 4: King (=99) — safely passes turn
        return safeCards.first;
      }
      // No safe card: bot will lose
      return hand.first;
    }

    // 2. When ground total < 99:
    // Try to save safe cards (4, 7, J, K) for dangerous situations (groundTotal == 99)
    final normalCards = hand.where((c) => !c.isSafeCard).toList();

    if (normalCards.isNotEmpty) {
      // If we can reach 99 with a normal card (e.g. Queen +10, 10 +10, 9 +9, etc.), we can put pressure on the next player!
      // Sort normal cards: prefer higher cards that increase ground total towards 99 safely
      final sortedNormals = [...normalCards]
        ..sort((a, b) => b.applyEffect(groundTotal).compareTo(a.applyEffect(groundTotal)));

      return sortedNormals.first;
    }

    // 3. If we only have safe cards:
    // When ground < 99, prefer using 4 or King over Jack or 7 (preserve -10 and reverse for critical defense)
    final fours = hand.where((c) => c.rank == Rank.four).toList();
    if (fours.isNotEmpty) return fours.first;

    final kings = hand.where((c) => c.rank == Rank.king).toList();
    if (kings.isNotEmpty) return kings.first;

    final sevens = hand.where((c) => c.rank == Rank.seven).toList();
    if (sevens.isNotEmpty) return sevens.first;

    return hand.first;
  }
}
