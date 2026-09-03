// lib/modes/ninety_nine/presentation/widgets/ninety_nine_top_hud.dart

import 'package:flutter/material.dart';
import 'package:estimation/core/utils/game_layout_metrics.dart';
import 'package:estimation/theme/app_theme.dart';
import 'package:estimation/widgets/hud/split_hud_panel.dart';
import 'package:estimation/widgets/performance_blur.dart';
import 'package:estimation/modes/ninety_nine/presentation/dialogs/ninety_nine_game_guide_dialog.dart';
import 'package:estimation/modes/ninety_nine/presentation/providers/ninety_nine_game_provider.dart';
import 'package:estimation/core/icons/app_icons.dart';
import 'package:estimation/core/widgets/app_buttons.dart';

class NinetyNineTopHud extends StatelessWidget {
  final NinetyNineGameProvider game;
  final VoidCallback onExitTap;

  const NinetyNineTopHud({super.key, required this.game, required this.onExitTap});

  String _phaseArabic() {
    switch (game.phase) {
      case NinetyNinePhase.waiting:
        return 'إنتظار';
      case NinetyNinePhase.playing:
        return 'اللعب';
      case NinetyNinePhase.roundFinished:
        return 'نهاية الجولة';
      case NinetyNinePhase.finished:
        return 'النهاية';
    }
  }

  Color _phaseColor() {
    switch (game.phase) {
      case NinetyNinePhase.waiting:
        return AppTheme.phaseReady;
      case NinetyNinePhase.playing:
        return AppTheme.phasePlay;
      case NinetyNinePhase.roundFinished:
      case NinetyNinePhase.finished:
        return AppTheme.phaseScoring;
    }
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final layout = GameLayoutMetrics.of(context);
        final useSplitHud = layout.shouldUseSplitHud(constraints.maxWidth);
        final isPortrait = layout.isPortrait;
        final phaseColor = _phaseColor();

        if (useSplitHud) {
          return _buildTabletSplit(context, phaseColor, layout);
        }

        return PerformanceBlur(
          borderRadius: BorderRadius.circular(22),
          sigmaX: 14,
          sigmaY: 14,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 500),
            curve: Curves.easeOut,
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xCC2A4560), Color(0xCC1D3348)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(22),
              border: Border.all(
                color: AppTheme.steelBlue.withValues(alpha: 0.15),
                width: 1.0,
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.3),
                  blurRadius: 20,
                  offset: const Offset(0, 8),
                ),
                BoxShadow(
                  color: phaseColor.withValues(alpha: 0.06),
                  blurRadius: 24,
                  spreadRadius: 2,
                ),
              ],
            ),
            child: isPortrait
                ? _buildPortrait(phaseColor, context)
                : _buildLandscape(phaseColor, context),
          ),
        );
      },
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
              _ExitButton(onTap: onExitTap),
              const SizedBox(width: 8),
              _GuideButton(context: context),
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
              _RoundPhaseCenter(
                roundNumber: game.currentRoundNumber,
                phaseColor: phaseColor,
                phaseText: _phaseArabic(),
                enlarged: true,
              ),
              const SizedBox(height: 8),
              _DirectionBadge(direction: game.direction, enlarged: true),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildPortrait(Color phaseColor, BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          children: [
            _ExitButton(onTap: onExitTap),
            const SizedBox(width: 6),
            _GuideButton(context: context),
            const SizedBox(width: 10),
            Expanded(
              child: _RoundPhaseCenter(
                roundNumber: game.currentRoundNumber,
                phaseColor: phaseColor,
                phaseText: _phaseArabic(),
              ),
            ),
            const SizedBox(width: 10),
            _DirectionBadge(direction: game.direction),
          ],
        ),
      ],
    );
  }

  Widget _buildLandscape(Color phaseColor, BuildContext context) {
    return Row(
      children: [
        _ExitButton(onTap: onExitTap),
        const SizedBox(width: 6),
        _GuideButton(context: context),
        const Spacer(),
        _RoundPhaseCenter(
          roundNumber: game.currentRoundNumber,
          phaseColor: phaseColor,
          phaseText: _phaseArabic(),
        ),
        const Spacer(),
        _DirectionBadge(direction: game.direction),
      ],
    );
  }
}

class _ExitButton extends StatelessWidget {
  final VoidCallback onTap;
  const _ExitButton({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return AppIconButton(
      icon: AppIcons.arrowBack,
      onTap: onTap,
      color: AppTheme.cream,
      backgroundColor: Colors.white.withValues(alpha: 0.06),
      borderColor: Colors.white.withValues(alpha: 0.12),
      size: AppIconButtonSize.sm,
    );
  }
}

class _GuideButton extends StatelessWidget {
  final BuildContext context;
  const _GuideButton({required this.context});

  @override
  Widget build(BuildContext context) {
    return AppIconButton(
      icon: AppIcons.helpOutline,
      color: AppTheme.mintSoft,
      size: AppIconButtonSize.sm,
      onTap: () {
        showDialog(
          context: this.context,
          builder: (_) => const NinetyNineGameGuideDialog(),
        );
      },
    );
  }
}

class _RoundPhaseCenter extends StatelessWidget {
  final int roundNumber;
  final Color phaseColor;
  final String phaseText;
  final bool enlarged;

  const _RoundPhaseCenter({
    required this.roundNumber,
    required this.phaseColor,
    required this.phaseText,
    this.enlarged = false,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          'الجولة $roundNumber',
          style: AppFonts.cooper(
            color: AppTheme.goldLight,
            fontSize: enlarged ? 16 : 13.5,
            fontWeight: FontWeight.bold,
          ),
        ),
        SizedBox(width: enlarged ? 10 : 8),
        Container(
          padding: EdgeInsets.symmetric(
            horizontal: enlarged ? 10 : 8,
            vertical: enlarged ? 4 : 2,
          ),
          decoration: BoxDecoration(
            color: phaseColor.withValues(alpha: 0.16),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: phaseColor.withValues(alpha: 0.4)),
          ),
          child: Text(
            phaseText,
            style: AppFonts.cooper(
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

class _DirectionBadge extends StatelessWidget {
  final int direction;
  final bool enlarged;

  const _DirectionBadge({required this.direction, this.enlarged = false});

  @override
  Widget build(BuildContext context) {
    final isClockwise = direction == 1;
    final color = isClockwise ? AppTheme.gold : Colors.white;

    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: enlarged ? 11 : 9,
        vertical: enlarged ? 6 : 4,
      ),
      decoration: BoxDecoration(
        color: AppTheme.navyDark.withValues(alpha: 0.7),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          AppIcon(
            isClockwise ? AppIcons.autorenew : AppIcons.swapHorizontalCircle,
            color: color,
            size: enlarged ? 17 : 15,
          ),
          const SizedBox(width: 4),
          Text(
            isClockwise ? 'مع العقارب ↻' : 'عكس العقارب ↺',
            style: AppFonts.cooper(
              color: color,
              fontSize: enlarged ? 12.5 : 11.5,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}
