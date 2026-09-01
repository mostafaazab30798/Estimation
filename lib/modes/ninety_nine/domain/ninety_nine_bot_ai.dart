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

    final legal = hand.where((c) => c.isLegalPlay(groundTotal)).toList();
    if (legal.isEmpty) return hand.first;
    if (legal.length == 1) return legal.first;

    // 1. When ground total is 99, we MUST play a safe card if we have one (4, 7, Jack, King)
    if (groundTotal == 99) {
      // Priority 1: Jack (-10) — breaks out of the danger zone
      final jacks = legal.where((c) => c.rank == Rank.jack).toList();
      if (jacks.isNotEmpty) return jacks.first;

      // Priority 2: 7 (Reverse) — sends the danger back to the previous player
      final sevens = legal.where((c) => c.rank == Rank.seven).toList();
      if (sevens.isNotEmpty) return sevens.first;

      // Priority 3: 4 (+0) — safely passes turn
      final fours = legal.where((c) => c.rank == Rank.four).toList();
      if (fours.isNotEmpty) return fours.first;

      // Priority 4: King (=99) — safely passes turn
      return legal.first;
    }

    // 2. When ground total < 99:
    // Never play a card that would exceed 99. Save safe cards for danger.
    final normalCards = legal.where((c) => !c.isSafeCard).toList();

    if (normalCards.isNotEmpty) {
      // Prefer the highest legal total (pressure next player without overflowing)
      final sortedNormals = [...normalCards]
        ..sort((a, b) => b.applyEffect(groundTotal).compareTo(a.applyEffect(groundTotal)));

      return sortedNormals.first;
    }

    // 3. If we only have safe cards:
    // When ground < 99, prefer using 4 or King over Jack or 7 (preserve -10 and reverse for critical defense)
    final fours = legal.where((c) => c.rank == Rank.four).toList();
    if (fours.isNotEmpty) return fours.first;

    final kings = legal.where((c) => c.rank == Rank.king).toList();
    if (kings.isNotEmpty) return kings.first;

    final sevens = legal.where((c) => c.rank == Rank.seven).toList();
    if (sevens.isNotEmpty) return sevens.first;

    return legal.first;
  }
}
