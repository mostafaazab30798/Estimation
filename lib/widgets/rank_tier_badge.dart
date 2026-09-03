// lib/widgets/rank_tier_badge.dart

import 'package:flutter/material.dart';
import 'package:estimation/theme/app_theme.dart';
import '../models/rank_tier.dart';

class RankTierBadge extends StatelessWidget {
  final RankTier tier;
  final int? level;
  final bool compact;
  final bool showLabel;
  final VoidCallback? onTap;

  const RankTierBadge({
    super.key,
    required this.tier,
    this.level,
    this.compact = false,
    this.showLabel = true,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final content = InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(compact ? 10 : 16),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: EdgeInsets.symmetric(
          horizontal: compact ? 8 : 12,
          vertical: compact ? 4 : 6,
        ),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [
              tier.primaryColor.withValues(alpha: 0.25),
              tier.secondaryColor.withValues(alpha: 0.15),
            ],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(compact ? 10 : 16),
          border: Border.all(
            color: tier.primaryColor.withValues(alpha: 0.6),
            width: compact ? 1.2 : 1.6,
          ),
          boxShadow: [
            BoxShadow(
              color: tier.primaryColor.withValues(alpha: 0.25),
              blurRadius: compact ? 6 : 10,
              spreadRadius: 0,
            ),
          ],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              tier.badgeEmoji,
              style: TextStyle(fontSize: compact ? 14 : 18),
            ),
            if (showLabel) ...[
              const SizedBox(width: 6),
              Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    tier.titleAr,
                    style: AppFonts.cooper(
                      fontSize: compact ? 10 : 12,
                      fontWeight: FontWeight.w900,
                      color: tier.primaryColor,
                      height: 1.1,
                    ),
                  ),
                  if (level != null)
                    Text(
                      'مستوى $level',
                      style: AppFonts.cooper(
                        fontSize: compact ? 8.5 : 10,
                        fontWeight: FontWeight.w600,
                        color: Colors.white70,
                        height: 1.1,
                      ),
                    ),
                ],
              ),
            ],
          ],
        ),
      ),
    );

    return content;
  }
}
