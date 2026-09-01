// lib/modes/basra/presentation/widgets/basra_top_hud.dart

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:estimation/core/icons/app_icons.dart';
import 'package:estimation/core/utils/game_layout_metrics.dart';
import 'package:estimation/core/widgets/app_buttons.dart';
import 'package:estimation/modes/basra/domain/basra_constants.dart';
import 'package:estimation/modes/basra/presentation/dialogs/basra_game_guide_dialog.dart';
import 'package:estimation/modes/basra/presentation/providers/basra_game_provider.dart';
import 'package:estimation/theme/app_theme.dart';
import 'package:estimation/widgets/hud/split_hud_panel.dart';
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

  Color _phaseColor() {
    switch (game.phase) {
      case BasraPhase.waiting:
        return AppTheme.phaseReady;
      case BasraPhase.playing:
        return AppTheme.phasePlay;
      case BasraPhase.roundFinished:
      case BasraPhase.finished:
        return AppTheme.phaseScoring;
    }
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final layout = GameLayoutMetrics.of(context);
        final useSplitHud = layout.shouldUseSplitHud(constraints.maxWidth);
        final phaseColor = _phaseColor();

        if (useSplitHud) {
          return _buildTabletSplit(context, phaseColor, layout);
        }

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
            child: _buildPhoneRow(context, phaseColor),
          ),
        );
      },
    );
  }

  Widget _buildPhoneRow(BuildContext context, Color phaseColor) {
    return Row(
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
          child: _RoundPhaseBlock(
            roundNumber: game.currentRoundNumber,
            phaseColor: phaseColor,
            phaseText: _phaseArabic(),
          ),
        ),
        _HudChip(label: 'الكنز ${game.deckCount}'),
        const SizedBox(width: 6),
        _HudChip(label: 'الهدف $kBasraMatchTarget'),
        if (game.carriedMajorityPoints > 0) ...[
          const SizedBox(width: 6),
          _HudChip(
            label: 'مرحّل ${game.carriedMajorityPoints}',
            highlight: true,
          ),
        ],
      ],
    );
  }

  Widget _buildTabletSplit(
    BuildContext context,
    Color phaseColor,
    GameLayoutMetrics layout,
  ) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SplitHudPanel(
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              AppIconButton(
                icon: AppIcons.arrowBack,
                onTap: onExitTap,
                color: AppTheme.cream,
                backgroundColor: Colors.white.withValues(alpha: 0.06),
                borderColor: Colors.white.withValues(alpha: 0.12),
                size: AppIconButtonSize.sm,
              ),
              const SizedBox(width: 8),
              AppIconButton(
                icon: AppIcons.helpOutline,
                color: AppTheme.mintSoft,
                size: AppIconButtonSize.sm,
                onTap: () => BasraGameGuideDialog.show(context),
              ),
            ],
          ),
        ),
        const Expanded(child: SizedBox.shrink()),
        SplitHudPanel(
          glowColor: phaseColor,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 11),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              _RoundPhaseBlock(
                roundNumber: game.currentRoundNumber,
                phaseColor: phaseColor,
                phaseText: _phaseArabic(),
                enlarged: true,
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 6,
                alignment: WrapAlignment.end,
                children: [
                  _HudChip(label: 'الكنز ${game.deckCount}', enlarged: true),
                  _HudChip(label: 'الهدف $kBasraMatchTarget', enlarged: true),
                  if (game.carriedMajorityPoints > 0)
                    _HudChip(
                      label: 'مرحّل ${game.carriedMajorityPoints}',
                      highlight: true,
                      enlarged: true,
                    ),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _RoundPhaseBlock extends StatelessWidget {
  final int roundNumber;
  final Color phaseColor;
  final String phaseText;
  final bool enlarged;

  const _RoundPhaseBlock({
    required this.roundNumber,
    required this.phaseColor,
    required this.phaseText,
    this.enlarged = false,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          'الجولة $roundNumber',
          style: GoogleFonts.cairo(
            color: AppTheme.goldLight,
            fontSize: enlarged ? 16 : 13,
            fontWeight: FontWeight.w800,
          ),
        ),
        SizedBox(height: enlarged ? 6 : 2),
        Container(
          padding: EdgeInsets.symmetric(
            horizontal: enlarged ? 10 : 8,
            vertical: enlarged ? 4 : 2,
          ),
          decoration: BoxDecoration(
            color: phaseColor.withValues(alpha: 0.14),
            borderRadius: BorderRadius.circular(999),
            border: Border.all(color: phaseColor.withValues(alpha: 0.38)),
          ),
          child: Text(
            phaseText,
            style: GoogleFonts.cairo(
              color: phaseColor,
              fontSize: enlarged ? 12 : 11,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
      ],
    );
  }
}

class _HudChip extends StatelessWidget {
  final String label;
  final bool highlight;
  final bool enlarged;

  const _HudChip({
    required this.label,
    this.highlight = false,
    this.enlarged = false,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: enlarged ? 10 : 8,
        vertical: enlarged ? 5 : 4,
      ),
      decoration: BoxDecoration(
        color: AppTheme.navyDark.withValues(alpha: 0.7),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: (highlight ? AppTheme.gold : Colors.white24)
              .withValues(alpha: 0.5),
        ),
      ),
      child: Text(
        label,
        style: GoogleFonts.cairo(
          color: highlight ? AppTheme.goldLight : AppTheme.cream,
          fontSize: enlarged ? 12 : 11,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}
