// lib/widgets/level_up_dialog.dart

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
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
    final isTierUp = widget.newTier.type != widget.oldTier.type;

    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 24),
      child: ScaleTransition(
        scale: _scale,
        child: RotationTransition(
          turns: _rotate,
          child: Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  AppTheme.navyDark,
                  const Color(0xFF0F172A),
                ],
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
              ),
              borderRadius: BorderRadius.circular(28),
              border: Border.all(
                color: widget.newTier.primaryColor.withValues(alpha: 0.6),
                width: 2.5,
              ),
              boxShadow: [
                BoxShadow(
                  color: widget.newTier.primaryColor.withValues(alpha: 0.35),
                  blurRadius: 30,
                  spreadRadius: 2,
                ),
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.7),
                  blurRadius: 20,
                  offset: const Offset(0, 10),
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Starburst / Trophy Badge Icon
                Container(
                  padding: const EdgeInsets.all(16),
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
                    style: const TextStyle(fontSize: 44),
                  ),
                ),
                const SizedBox(height: 16),

                // Main Title
                Text(
                  isTierUp ? 'ترقية رتبة جديدة!' : 'ارتقاء في المستوى!',
                  style: GoogleFonts.cairo(
                    fontSize: 22,
                    fontWeight: FontWeight.w900,
                    color: AppTheme.cream,
                  ),
                  textAlign: TextAlign.center,
                ),

                const SizedBox(height: 6),

                // Subtitle
                Text(
                  isTierUp
                      ? 'تهانينا! لقد بلغت رتبة ${widget.newTier.titleAr}'
                      : 'أداء رائع ومميز في الجولة!',
                  style: GoogleFonts.cairo(
                    fontSize: 13,
                    color: AppTheme.steelBlue,
                  ),
                  textAlign: TextAlign.center,
                ),

                const SizedBox(height: 20),

                // Level Change Badge
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.06),
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(color: Colors.white12),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        'مستوى ${widget.oldLevel}',
                        style: GoogleFonts.cairo(
                          fontSize: 16,
                          color: Colors.white60,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(width: 14),
                      const AppIcon(AppIcons.arrowForward, color: AppTheme.gold, size: 20),
                      const SizedBox(width: 14),
                      Text(
                        'مستوى ${widget.newLevel}',
                        style: GoogleFonts.cairo(
                          fontSize: 20,
                          color: AppTheme.gold,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 16),

                // Rank Tier Badge Widget
                RankTierBadge(
                  tier: widget.newTier,
                  level: widget.newLevel,
                  showLabel: true,
                ),

                const SizedBox(height: 24),

                // Continue Button
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: () => Navigator.pop(context),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: widget.newTier.primaryColor,
                      foregroundColor: AppTheme.navyDark,
                      padding: const EdgeInsets.symmetric(vertical: 13),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                      elevation: 4,
                    ),
                    child: Text(
                      'استمرار اللعب',
                      style: GoogleFonts.cairo(
                        fontSize: 15,
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
