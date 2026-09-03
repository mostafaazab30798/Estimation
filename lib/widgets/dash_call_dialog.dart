// lib/widgets/dash_call_dialog.dart
//
// Arabic dialog shown before the auction asking if player wants to call Dash Call.

import 'package:flutter/material.dart';

import '../core/icons/app_icons.dart';
import '../core/utils/game_layout_metrics.dart';
import '../core/widgets/app_buttons.dart';
import '../theme/app_theme.dart';
import 'hud/gameplay_dialog_shell.dart';

class DashCallDialog extends StatelessWidget {
  final void Function(bool wantsDashCall) onDecision;

  const DashCallDialog({super.key, required this.onDecision});

  static const _accent = AppTheme.playerOrange;

  @override
  Widget build(BuildContext context) {
    final layout = GameLayoutMetrics.of(context);

    return GameplayDialogShell(
      accent: _accent,
      maxWidth: GameplayDialogShell.widthFor(context, tablet: 460, largeTablet: 520),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              AppIconWell(
                icon: AppIcons.localFireDepartment,
                size: layout.isTablet ? 52 : 46,
                iconSize: layout.isTablet ? 24 : 21,
                color: _accent,
                fill: _accent.withValues(alpha: 0.14),
                borderColor: _accent.withValues(alpha: 0.34),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'DASH CALL',
                      style: AppFonts.cooper(
                        color: _accent,
                        fontSize: 10.5,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 0.9,
                      ),
                    ),
                    Text(
                      'طلب داش كول',
                      style: AppFonts.cooper(
                        color: AppTheme.cream,
                        fontSize: layout.isTablet ? 22 : 20,
                        fontWeight: FontWeight.w900,
                        height: 1.15,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          SizedBox(height: layout.isTablet ? 16 : 14),
          Text(
            'هل ترغب في إعلان تحقيق (0) أكلات قبل معرفة نوع الحكم؟',
            textAlign: TextAlign.right,
            style: AppFonts.cooper(
              color: AppTheme.steelBlue,
              fontSize: layout.isTablet ? 14 : 13,
              fontWeight: FontWeight.w600,
              height: 1.45,
            ),
          ),
          SizedBox(height: layout.isTablet ? 18 : 16),
          Container(
            padding: EdgeInsets.all(layout.isTablet ? 16 : 14),
            decoration: BoxDecoration(
              color: AppTheme.deepNavy.withValues(alpha: 0.48),
              borderRadius: BorderRadius.circular(18),
              border: Border.all(
                color: AppTheme.steelBlue.withValues(alpha: 0.16),
              ),
            ),
            child: Column(
              children: [
                _RewardRow(
                  icon: AppIcons.emojiEvents,
                  label: 'النجاح في الأوفر (Over)',
                  value: '+33',
                  valueColor: AppTheme.playerGreen,
                  compact: layout.isTablet,
                ),
                SizedBox(height: layout.isTablet ? 10 : 8),
                _RewardRow(
                  icon: AppIcons.shield,
                  label: 'النجاح في الأندر (Under)',
                  value: '+25',
                  valueColor: AppTheme.playerGreen,
                  compact: layout.isTablet,
                ),
                SizedBox(height: layout.isTablet ? 10 : 8),
                _RewardRow(
                  icon: AppIcons.errorOutline,
                  label: 'عند الخسارة',
                  value: '-33 / -25',
                  valueColor: AppTheme.errorRed,
                  compact: layout.isTablet,
                ),
              ],
            ),
          ),
          SizedBox(height: layout.isTablet ? 22 : 18),
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  style: OutlinedButton.styleFrom(
                    padding: EdgeInsets.symmetric(
                      vertical: layout.isTablet ? 14 : 12,
                    ),
                    side: BorderSide(
                      color: AppTheme.steelBlue.withValues(alpha: 0.35),
                    ),
                    foregroundColor: AppTheme.cream,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                  onPressed: () {
                    Navigator.of(context).pop();
                    onDecision(false);
                  },
                  child: Text(
                    'لا، دخول المزاد',
                    style: AppFonts.cooper(
                      fontWeight: FontWeight.w800,
                      fontSize: layout.isTablet ? 14 : 13,
                    ),
                  ),
                ),
              ),
              SizedBox(width: layout.isTablet ? 12 : 10),
              Expanded(
                child: FilledButton(
                  style: FilledButton.styleFrom(
                    padding: EdgeInsets.symmetric(
                      vertical: layout.isTablet ? 14 : 12,
                    ),
                    backgroundColor: AppTheme.gold,
                    foregroundColor: AppTheme.navyDark,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                    elevation: 0,
                  ),
                  onPressed: () {
                    Navigator.of(context).pop();
                    onDecision(true);
                  },
                  child: Text(
                    'نعم، داش كول',
                    style: AppFonts.cooper(
                      fontWeight: FontWeight.w900,
                      fontSize: layout.isTablet ? 14 : 13,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _RewardRow extends StatelessWidget {
  final AppIconData icon;
  final String label;
  final String value;
  final Color valueColor;
  final bool compact;

  const _RewardRow({
    required this.icon,
    required this.label,
    required this.value,
    required this.valueColor,
    this.compact = false,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        AppIcon(
          icon,
          size: compact ? 16 : 15,
          color: AppTheme.steelBlue,
          strokeWidth: AppIconTokens.stroke,
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            label,
            style: AppFonts.cooper(
              color: AppTheme.cream.withValues(alpha: 0.88),
              fontSize: compact ? 13 : 12,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
        Text(
          value,
          style: AppFonts.cooper(
            color: valueColor,
            fontSize: compact ? 14 : 13,
            fontWeight: FontWeight.w900,
          ),
        ),
      ],
    );
  }
}
