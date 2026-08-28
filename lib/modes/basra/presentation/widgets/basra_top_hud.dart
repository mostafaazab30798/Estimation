// lib/modes/basra/presentation/widgets/basra_top_hud.dart

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:estimation/core/icons/app_icons.dart';
import 'package:estimation/core/widgets/app_buttons.dart';
import 'package:estimation/modes/basra/domain/basra_constants.dart';
import 'package:estimation/modes/basra/presentation/dialogs/basra_game_guide_dialog.dart';
import 'package:estimation/modes/basra/presentation/providers/basra_game_provider.dart';
import 'package:estimation/theme/app_theme.dart';
import 'package:estimation/widgets/performance_blur.dart';

class BasraTopHud extends StatelessWidget {
  final BasraGameProvider game;
  final VoidCallback onExitTap;

  const BasraTopHud({super.key, required this.game, required this.onExitTap});

  String _phaseArabic() {
    switch (game.phase) {
      case BasraPhase.waiting:
        return 'إنتظار';
      case BasraPhase.playing:
        return 'اللعب';
      case BasraPhase.roundFinished:
        return 'نهاية الجولة';
      case BasraPhase.finished:
        return 'النهاية';
    }
  }

  @override
  Widget build(BuildContext context) {
    return PerformanceBlur(
      borderRadius: BorderRadius.circular(22),
      sigmaX: 14,
      sigmaY: 14,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [Color(0xCC2A4560), Color(0xCC1D3348)],
          ),
          borderRadius: BorderRadius.circular(22),
          border: Border.all(color: AppTheme.gold.withValues(alpha: 0.2)),
        ),
        child: Row(
          children: [
            AppIconButton(
              icon: AppIcons.arrowBack,
              onTap: onExitTap,
              color: AppTheme.cream,
              backgroundColor: Colors.white.withValues(alpha: 0.06),
              borderColor: Colors.white.withValues(alpha: 0.12),
              size: AppIconButtonSize.sm,
            ),
            const SizedBox(width: 6),
            AppIconButton(
              icon: AppIcons.helpOutline,
              color: AppTheme.mintSoft,
              size: AppIconButtonSize.sm,
              onTap: () => BasraGameGuideDialog.show(context),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    'الجولة ${game.currentRoundNumber}',
                    style: GoogleFonts.cairo(
                      color: AppTheme.gold,
                      fontSize: 13,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  Text(
                    _phaseArabic(),
                    style: GoogleFonts.cairo(
                      color: AppTheme.mintSoft,
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
            ),
            _HudChip(label: 'الكنز ${game.deckCount}'),
            const SizedBox(width: 6),
            _HudChip(label: 'الهدف $kBasraMatchTarget'),
            if (game.carriedMajorityPoints > 0) ...[
              const SizedBox(width: 6),
              _HudChip(label: 'مرحّل ${game.carriedMajorityPoints}', highlight: true),
            ],
          ],
        ),
      ),
    );
  }
}

class _HudChip extends StatelessWidget {
  final String label;
  final bool highlight;
  const _HudChip({required this.label, this.highlight = false});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: AppTheme.navyDark.withValues(alpha: 0.7),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: (highlight ? AppTheme.gold : Colors.white24).withValues(alpha: 0.5),
        ),
      ),
      child: Text(
        label,
        style: GoogleFonts.cairo(
          color: highlight ? AppTheme.gold : Colors.white70,
          fontSize: 10.5,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}
