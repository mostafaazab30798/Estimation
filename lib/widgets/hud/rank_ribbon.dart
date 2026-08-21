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
    final color = AppTheme.rankColors[rankIndex];
    final fontSize = compact ? 11.0 : 15.0;
    final padding = compact ? 2.0 : 3.0;

    return Container(
      padding: EdgeInsets.all(padding),
      decoration: BoxDecoration(
        color: Color.alphaBlend(
          color.withValues(alpha: 0.3),
          AppTheme.navyDark,
        ),
        shape: BoxShape.circle,
        border: Border.all(
          color: color,
          width: compact ? 1.4 : 1.8,
        ),
        boxShadow: [
          BoxShadow(
            color: color.withValues(alpha: 0.45),
            blurRadius: compact ? 5 : 8,
            spreadRadius: 1,
          ),
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
