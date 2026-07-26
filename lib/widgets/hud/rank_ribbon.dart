// lib/widgets/hud/rank_ribbon.dart
//
// Small floating tag that visually communicates a player's
// current standing in the match without relying on long text strings.

import 'package:flutter/material.dart';
import '../../theme/app_theme.dart';

/// Rank indices and their visual treatment:
///
///  0 → Gold   (كينج)
///  1 → Silver (صب كينج)
///  2 → Bronze (صب كوز)
///  3 → Dark-red (كوز)
class RankRibbon extends StatelessWidget {
  final int rankIndex;
  final bool compact;

  const RankRibbon({super.key, required this.rankIndex, this.compact = false});

  @override
  Widget build(BuildContext context) {
    if (rankIndex < 0 || rankIndex > 3) return const SizedBox.shrink();

    final cfg = _kRankConfigs[rankIndex];
    final fontSize = compact ? 12.0 : 16.0;

    return Container(
      padding: const EdgeInsets.all(2),
      decoration: BoxDecoration(
        color: AppTheme.navyDark, // Dark background to contrast with avatar
        shape: BoxShape.circle,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.6),
            blurRadius: 4,
            spreadRadius: 1,
          ),
        ],
      ),
      child: Text(cfg.emoji, style: TextStyle(fontSize: fontSize)),
    );
  }
}

class _RankConfig {
  final String emoji;
  const _RankConfig(this.emoji);
}

const _kRankConfigs = [
  _RankConfig('👑'),
  _RankConfig('🥈'),
  _RankConfig('🥉'),
  _RankConfig('🤡'),
];
