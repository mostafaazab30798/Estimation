// lib/widgets/level_up_dialog.dart

import 'package:flutter/material.dart';
import '../core/utils/game_layout_metrics.dart';
import '../models/rank_tier.dart';
import '../theme/app_theme.dart';
import 'rank_tier_badge.dart';
import 'package:estimation/core/icons/app_icons.dart';

class LevelUpDialog extends StatefulWidget {
  final int oldLevel;
  final int newLevel;
  final RankTier oldTier;
  final RankTier newTier;

  const LevelUpDialog({
    super.key,
    required this.oldLevel,
    required this.newLevel,
    required this.oldTier,
    required this.newTier,
  });

  static Future<void> show(
    BuildContext context, {
    required int oldLevel,
    required int newLevel,
    required RankTier oldTier,
    required RankTier newTier,
  }) async {
    await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => LevelUpDialog(
        oldLevel: oldLevel,
        newLevel: newLevel,
        oldTier: oldTier,
        newTier: newTier,
      ),
    );
  }

  @override
  State<LevelUpDialog> createState() => _LevelUpDialogState();
}

class _LevelUpDialogState extends State<LevelUpDialog>
    with SingleTickerProviderStateMixin {
  late AnimationController _anim;
  late Animation<double> _scale;
  late Animation<double> _rotate;

  @override
  void initState() {
    super.initState();
    _anim = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    );
    _scale = CurvedAnimation(parent: _anim, curve: Curves.elasticOut);
    _rotate = Tween<double>(begin: -0.1, end: 0.0).animate(
      CurvedAnimation(parent: _anim, curve: Curves.easeOutBack),
    );

    _anim.forward();
  }

  @override
  void dispose() {
    _anim.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final layout = GameLayoutMetrics.of(context);
    final isTierUp = widget.newTier.type != widget.oldTier.type;

    final maxWidth = layout.isLargeTablet
        ? 480.0
        : (layout.isTablet ? 440.0 : double.infinity);

    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: EdgeInsets.symmetric(
        horizontal: layout.isTablet ? 28 : 20,
        vertical: 16,
      ),
      child: ScaleTransition(
        scale: _scale,
        child: RotationTransition(
          turns: _rotate,
          child: Container(
            width: double.infinity,
            constraints: BoxConstraints(maxWidth: maxWidth),
            padding: EdgeInsets.all(layout.isTablet ? 28 : 24),
            decoration: AppTheme.dialogDecoration(
              accent: widget.newTier.primaryColor,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  padding: EdgeInsets.all(layout.isTablet ? 18 : 16),
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: LinearGradient(
                      colors: widget.newTier.gradient,
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: widget.newTier.primaryColor.withValues(alpha: 0.5),
                        blurRadius: 18,
                      ),
                    ],
                  ),
                  child: Text(
                    isTierUp ? widget.newTier.badgeEmoji : '⭐',
                    style: TextStyle(fontSize: layout.isTablet ? 48 : 44),
                  ),
                ),
                SizedBox(height: layout.isTablet ? 18 : 16),
                Text(
                  isTierUp ? 'ترقية رتبة جديدة!' : 'ارتقاء في المستوى!',
                  style: AppFonts.dg(
                    fontSize: layout.isTablet ? 24 : 22,
                    fontWeight: FontWeight.w900,
                    color: AppTheme.cream,
                  ),
                  textAlign: TextAlign.center,
                ),
                SizedBox(height: layout.isTablet ? 8 : 6),
                Text(
                  isTierUp
                      ? 'تهانينا! لقد بلغت رتبة ${widget.newTier.titleAr}'
                      : 'أداء رائع ومميز في الجولة!',
                  style: AppFonts.cooper(
                    fontSize: layout.isTablet ? 14 : 13,
                    color: AppTheme.steelBlue,
                    height: 1.4,
                  ),
                  textAlign: TextAlign.center,
                ),
                SizedBox(height: layout.isTablet ? 22 : 20),
                Container(
                  padding: EdgeInsets.symmetric(
                    horizontal: layout.isTablet ? 22 : 20,
                    vertical: layout.isTablet ? 14 : 12,
                  ),
                  decoration: BoxDecoration(
                    color: AppTheme.deepNavy.withValues(alpha: 0.46),
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(
                      color: AppTheme.steelBlue.withValues(alpha: 0.16),
                    ),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        'مستوى ${widget.oldLevel}',
                        style: AppFonts.cooper(
                          fontSize: layout.isTablet ? 17 : 16,
                          color: Colors.white60,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      SizedBox(width: layout.isTablet ? 16 : 14),
                      const AppIcon(
                        AppIcons.arrowForward,
                        color: AppTheme.gold,
                        size: 20,
                      ),
                      SizedBox(width: layout.isTablet ? 16 : 14),
                      Text(
                        'مستوى ${widget.newLevel}',
                        style: AppFonts.cooper(
                          fontSize: layout.isTablet ? 22 : 20,
                          color: AppTheme.gold,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ],
                  ),
                ),
                SizedBox(height: layout.isTablet ? 18 : 16),
                RankTierBadge(
                  tier: widget.newTier,
                  level: widget.newLevel,
                  showLabel: true,
                ),
                SizedBox(height: layout.isTablet ? 26 : 24),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton(
                    onPressed: () => Navigator.pop(context),
                    style: FilledButton.styleFrom(
                      backgroundColor: widget.newTier.primaryColor,
                      foregroundColor: AppTheme.navyDark,
                      padding: EdgeInsets.symmetric(
                        vertical: layout.isTablet ? 15 : 13,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                      elevation: 0,
                    ),
                    child: Text(
                      'استمرار اللعب',
                      style: AppFonts.cooper(
                        fontSize: layout.isTablet ? 16 : 15,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
