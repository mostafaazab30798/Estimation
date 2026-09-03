import 'package:flutter/material.dart';

import '../core/icons/app_icons.dart';
import '../core/models/card.dart';
import '../core/utils/game_layout_metrics.dart';
import '../core/widgets/app_buttons.dart';
import '../theme/app_theme.dart';
import 'hud/gameplay_dialog_shell.dart';
import 'playing_card_widget.dart';

class TrickDisplay extends StatelessWidget {
  final List<TrickCard> trick;
  final double cardWidth;

  const TrickDisplay({super.key, required this.trick, this.cardWidth = 60});

  @override
  Widget build(BuildContext context) {
    if (trick.isEmpty) return const SizedBox();

    return Wrap(
      spacing: 8,
      runSpacing: 8,
      alignment: WrapAlignment.center,
      children: trick.map((tc) {
        return PlayingCardWidget(
          card: tc.card,
          width: cardWidth,
          playable: false,
        );
      }).toList(),
    );
  }
}

class TakenTricksDialog extends StatelessWidget {
  final List<List<TrickCard>> takenTricks;

  const TakenTricksDialog({super.key, required this.takenTricks});

  @override
  Widget build(BuildContext context) {
    final layout = GameLayoutMetrics.of(context);

    return GameplayDialogShell(
      maxWidth: GameplayDialogShell.widthFor(
        context,
        tablet: 520,
        largeTablet: 560,
      ),
      scrollable: true,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              AppIconWell(
                icon: AppIcons.layers,
                size: layout.isTablet ? 48 : 44,
                iconSize: layout.isTablet ? 22 : 20,
                color: AppTheme.goldLight,
                fill: AppTheme.gold.withValues(alpha: 0.14),
                borderColor: AppTheme.gold.withValues(alpha: 0.32),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  'اللمّات التي أخذتها',
                  style: AppFonts.dg(
                    fontSize: layout.isTablet ? 21 : 19,
                    fontWeight: FontWeight.w900,
                    color: AppTheme.cream,
                  ),
                ),
              ),
            ],
          ),
          SizedBox(height: layout.isTablet ? 18 : 16),
          if (takenTricks.isEmpty)
            Container(
              padding: EdgeInsets.all(layout.isTablet ? 28 : 24),
              decoration: BoxDecoration(
                color: AppTheme.deepNavy.withValues(alpha: 0.46),
                borderRadius: BorderRadius.circular(18),
                border: Border.all(
                  color: AppTheme.steelBlue.withValues(alpha: 0.14),
                ),
              ),
              child: Text(
                'لم تأخذ أي لمّات حتى الآن',
                textAlign: TextAlign.center,
                style: AppFonts.cooper(
                  fontSize: 15,
                  color: AppTheme.steelBlue,
                  fontWeight: FontWeight.w600,
                ),
              ),
            )
          else
            ...takenTricks.asMap().entries.map((entry) {
              final index = entry.key;
              final trick = entry.value;
              return Padding(
                padding: EdgeInsets.only(bottom: index == takenTricks.length - 1 ? 0 : 14),
                child: Container(
                  padding: EdgeInsets.all(layout.isTablet ? 16 : 14),
                  decoration: BoxDecoration(
                    color: AppTheme.deepNavy.withValues(alpha: 0.46),
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(
                      color: AppTheme.steelBlue.withValues(alpha: 0.14),
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Text(
                        'لمّة ${index + 1}',
                        style: AppFonts.cooper(
                          fontSize: 14,
                          fontWeight: FontWeight.w800,
                          color: AppTheme.gold,
                        ),
                      ),
                      const SizedBox(height: 10),
                      TrickDisplay(trick: trick),
                    ],
                  ),
                ),
              );
            }),
          SizedBox(height: layout.isTablet ? 20 : 18),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(),
            style: FilledButton.styleFrom(
              backgroundColor: AppTheme.steelBlue.withValues(alpha: 0.18),
              foregroundColor: AppTheme.cream,
              padding: EdgeInsets.symmetric(vertical: layout.isTablet ? 14 : 12),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              elevation: 0,
            ),
            child: Text(
              'إغلاق',
              style: AppFonts.cooper(fontWeight: FontWeight.w800, fontSize: 14),
            ),
          ),
        ],
      ),
    );
  }
}

class LatestTrickDialog extends StatelessWidget {
  final List<TrickCard>? trick;
  final String playerName;

  const LatestTrickDialog({super.key, required this.trick, required this.playerName});

  @override
  Widget build(BuildContext context) {
    final layout = GameLayoutMetrics.of(context);

    return GameplayDialogShell(
      maxWidth: GameplayDialogShell.widthFor(context, tablet: 460, largeTablet: 500),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              AppIconWell(
                icon: AppIcons.style,
                size: layout.isTablet ? 48 : 44,
                iconSize: layout.isTablet ? 22 : 20,
                color: AppTheme.midBlue,
                fill: AppTheme.midBlue.withValues(alpha: 0.14),
                borderColor: AppTheme.midBlue.withValues(alpha: 0.32),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  'آخر لمّة ($playerName)',
                  style: AppFonts.cooper(
                    fontSize: layout.isTablet ? 20 : 18,
                    fontWeight: FontWeight.w900,
                    color: AppTheme.cream,
                  ),
                ),
              ),
            ],
          ),
          SizedBox(height: layout.isTablet ? 18 : 16),
          Container(
            padding: EdgeInsets.all(layout.isTablet ? 18 : 16),
            decoration: BoxDecoration(
              color: AppTheme.deepNavy.withValues(alpha: 0.46),
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: AppTheme.steelBlue.withValues(alpha: 0.14)),
            ),
            child: trick == null || trick!.isEmpty
                ? Text(
                    'لم يأخذ أي لمّات حتى الآن',
                    textAlign: TextAlign.center,
                    style: AppFonts.cooper(
                      fontSize: 15,
                      color: AppTheme.steelBlue,
                      fontWeight: FontWeight.w600,
                    ),
                  )
                : TrickDisplay(trick: trick!, cardWidth: layout.isTablet ? 68 : 62),
          ),
          SizedBox(height: layout.isTablet ? 20 : 18),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(),
            style: FilledButton.styleFrom(
              backgroundColor: AppTheme.steelBlue.withValues(alpha: 0.18),
              foregroundColor: AppTheme.cream,
              padding: EdgeInsets.symmetric(vertical: layout.isTablet ? 14 : 12),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              elevation: 0,
            ),
            child: Text(
              'إغلاق',
              style: AppFonts.cooper(fontWeight: FontWeight.w800, fontSize: 14),
            ),
          ),
        ],
      ),
    );
  }
}
