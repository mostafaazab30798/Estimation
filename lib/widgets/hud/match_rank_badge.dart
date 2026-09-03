// lib/widgets/hud/match_rank_badge.dart
//
// Styled presentation of the four match-rank PNG assets —
// framed medallion with glow and optional title.

import 'package:flutter/material.dart';
import '../../models/match_rank.dart';
import '../../theme/app_theme.dart';
import 'package:estimation/core/icons/app_icons.dart';

enum MatchRankBadgeSize { tiny, compact, medium, large }

/// Decorative medallion wrapping a [MatchRank] asset.
class MatchRankBadge extends StatelessWidget {
  final int rankIndex;
  final MatchRankBadgeSize size;
  final bool showLabel;
  final bool glow;

  const MatchRankBadge({
    super.key,
    required this.rankIndex,
    this.size = MatchRankBadgeSize.compact,
    this.showLabel = false,
    this.glow = true,
  });

  @override
  Widget build(BuildContext context) {
    final rank = MatchRank.fromIndex(rankIndex);
    if (rank == null) return const SizedBox.shrink();

    final dims = _dimsFor(size);
    final medallion = _RankMedallion(
      rank: rank,
      diameter: dims.diameter,
      glow: glow,
      imageInset: dims.imageInset,
      borderWidth: dims.borderWidth,
    );

    if (!showLabel) return medallion;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        medallion,
        SizedBox(height: dims.labelGap),
        Text(
          rank.titleAr,
          style: AppFonts.cooper(
            fontSize: dims.labelSize,
            fontWeight: FontWeight.w900,
            color: rank.accentColor,
            height: 1.1,
            shadows: [
              Shadow(
                color: rank.accentColor.withValues(alpha: 0.45),
                blurRadius: 8,
              ),
            ],
          ),
        ),
      ],
    );
  }

  static _BadgeDims _dimsFor(MatchRankBadgeSize size) {
    switch (size) {
      case MatchRankBadgeSize.tiny:
        return const _BadgeDims(
          diameter: 22,
          imageInset: 2,
          borderWidth: 1.2,
          labelSize: 9,
          labelGap: 2,
        );
      case MatchRankBadgeSize.compact:
        return const _BadgeDims(
          diameter: 38,
          imageInset: 3,
          borderWidth: 1.6,
          labelSize: 11,
          labelGap: 3,
        );
      case MatchRankBadgeSize.medium:
        return const _BadgeDims(
          diameter: 56,
          imageInset: 4.5,
          borderWidth: 2,
          labelSize: 13,
          labelGap: 4,
        );
      case MatchRankBadgeSize.large:
        return const _BadgeDims(
          diameter: 88,
          imageInset: 7,
          borderWidth: 2.4,
          labelSize: 15,
          labelGap: 6,
        );
    }
  }
}

class _BadgeDims {
  final double diameter;
  final double imageInset;
  final double borderWidth;
  final double labelSize;
  final double labelGap;

  const _BadgeDims({
    required this.diameter,
    required this.imageInset,
    required this.borderWidth,
    required this.labelSize,
    required this.labelGap,
  });
}

class _RankMedallion extends StatelessWidget {
  final MatchRank rank;
  final double diameter;
  final bool glow;
  final double imageInset;
  final double borderWidth;

  const _RankMedallion({
    required this.rank,
    required this.diameter,
    required this.glow,
    required this.imageInset,
    required this.borderWidth,
  });

  @override
  Widget build(BuildContext context) {
    final isKing = rank.index == 0;

    return Container(
      width: diameter,
      height: diameter,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: RadialGradient(
          colors: [
            Color.alphaBlend(
              rank.accentColor.withValues(alpha: isKing ? 0.35 : 0.22),
              const Color(0xFF0A0A12),
            ),
            const Color(0xFF050508),
          ],
          stops: const [0.35, 1.0],
        ),
        border: Border.all(
          color: rank.accentColor.withValues(alpha: isKing ? 0.95 : 0.7),
          width: borderWidth,
        ),
        boxShadow: [
          if (glow)
            BoxShadow(
              color: rank.accentColor.withValues(alpha: isKing ? 0.5 : 0.32),
              blurRadius: isKing ? diameter * 0.35 : diameter * 0.25,
              spreadRadius: 0,
            ),
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.5),
            blurRadius: 3,
            offset: const Offset(0, 1),
          ),
        ],
      ),
      child: Padding(
        padding: EdgeInsets.all(imageInset),
        child: ClipOval(
          child: Image.asset(
            rank.assetPath,
            fit: BoxFit.cover,
            filterQuality: FilterQuality.high,
            errorBuilder: (_, __, ___) => AppIcon(
              AppIcons.emojiEvents,
              color: rank.accentColor,
              size: diameter * 0.45,
            ),
          ),
        ),
      ),
    );
  }
}

/// Inline rank chip: medallion + Arabic title, used in standings lists.
class MatchRankChip extends StatelessWidget {
  final int rankIndex;
  final bool compact;

  const MatchRankChip({
    super.key,
    required this.rankIndex,
    this.compact = false,
  });

  @override
  Widget build(BuildContext context) {
    final rank = MatchRank.fromIndex(rankIndex);
    if (rank == null) return const SizedBox.shrink();

    final badgeSize =
        compact ? MatchRankBadgeSize.compact : MatchRankBadgeSize.medium;
    final fontSize = compact ? 12.0 : 14.0;
    final padH = compact ? 7.0 : 10.0;
    final padV = compact ? 4.0 : 5.0;
    final gap = compact ? 6.0 : 8.0;

    return FittedBox(
      fit: BoxFit.scaleDown,
      alignment: AlignmentDirectional.centerStart,
      child: Container(
        padding: EdgeInsets.symmetric(horizontal: padH, vertical: padV),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(compact ? 14 : 16),
          gradient: LinearGradient(
            colors: [
              rank.accentColor.withValues(alpha: 0.22),
              AppTheme.navyDark.withValues(alpha: 0.85),
            ],
          ),
          border: Border.all(
            color: rank.accentColor.withValues(alpha: 0.55),
            width: 1.1,
          ),
          boxShadow: [
            BoxShadow(
              color: rank.accentColor.withValues(alpha: 0.18),
              blurRadius: 8,
            ),
          ],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            MatchRankBadge(
              rankIndex: rankIndex,
              size: badgeSize,
              glow: rankIndex == 0,
            ),
            SizedBox(width: gap),
            Text(
              rank.titleAr,
              style: AppFonts.cooper(
                fontSize: fontSize,
                fontWeight: FontWeight.w900,
                color: rank.accentColor,
                height: 1,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
