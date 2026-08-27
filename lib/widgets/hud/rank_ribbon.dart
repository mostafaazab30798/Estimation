// lib/widgets/hud/rank_ribbon.dart
//
// Compact match-rank medallion for in-game HUD cards.

import 'package:flutter/material.dart';
import 'match_rank_badge.dart';

/// Rank indices:
///  0 → King · 1 → Sub-King · 2 → Sub-Kooz · 3 → Kooz
class RankRibbon extends StatelessWidget {
  final int rankIndex;
  final bool compact;

  const RankRibbon({super.key, required this.rankIndex, this.compact = false});

  @override
  Widget build(BuildContext context) {
    if (rankIndex < 0 || rankIndex > 3) return const SizedBox.shrink();

    return MatchRankBadge(
      rankIndex: rankIndex,
      size: compact ? MatchRankBadgeSize.tiny : MatchRankBadgeSize.compact,
      glow: rankIndex == 0,
    );
  }
}
