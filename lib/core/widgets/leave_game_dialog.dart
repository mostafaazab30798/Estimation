import 'package:flutter/material.dart';

import '../icons/app_icons.dart';
import '../utils/game_layout_metrics.dart';
import '../../theme/app_theme.dart';
import '../../widgets/hud/gameplay_dialog_shell.dart';

/// In-game leave confirmation — shared across Kotchina, 99, and Basra.
class LeaveGameDialog extends StatelessWidget {
  final Future<void> Function() onLeave;

  const LeaveGameDialog({super.key, required this.onLeave});

  static Future<void> show(
    BuildContext context, {
    required Future<void> Function() onLeave,
  }) {
    return showDialog<void>(
      context: context,
      builder: (_) => LeaveGameDialog(onLeave: onLeave),
    );
  }

  @override
  Widget build(BuildContext context) {
    final layout = GameLayoutMetrics.of(context);

    return GameplayDialogShell(
      accent: AppTheme.playerRed,
      maxWidth: GameplayDialogShell.widthFor(context, tablet: 420, largeTablet: 460),
      alignment: Alignment.center,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: layout.isTablet ? 62 : 58,
            height: layout.isTablet ? 62 : 58,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: AppTheme.playerRed.withValues(alpha: 0.14),
              border: Border.all(
                color: AppTheme.playerRed.withValues(alpha: 0.32),
              ),
            ),
            child: const AppIcon(
              AppIcons.exitToApp,
              color: AppTheme.playerRed,
              size: 28,
            ),
          ),
          SizedBox(height: layout.isTablet ? 18 : 16),
          Text(
            'مغادرة اللعبة',
            style: AppFonts.dg(
              color: AppTheme.cream,
              fontSize: layout.isTablet ? 20 : 18,
              fontWeight: FontWeight.w800,
            ),
            textAlign: TextAlign.center,
          ),
          SizedBox(height: layout.isTablet ? 10 : 8),
          Text(
            'هل أنت متأكد أنك تريد مغادرة اللعبة والعودة للرئيسية؟ سيتم فصلك من الغرفة.',
            style: AppFonts.cooper(
              color: AppTheme.steelBlue,
              fontSize: layout.isTablet ? 13.5 : 12.5,
              height: 1.45,
            ),
            textAlign: TextAlign.center,
          ),
          SizedBox(height: layout.isTablet ? 26 : 24),
          Row(
            children: [
              Expanded(
                child: InkWell(
                  onTap: () => Navigator.pop(context),
                  borderRadius: BorderRadius.circular(14),
                  child: Container(
                    padding: EdgeInsets.symmetric(
                      vertical: layout.isTablet ? 14 : 13,
                    ),
                    decoration: BoxDecoration(
                      color: AppTheme.steelBlue.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(
                        color: AppTheme.steelBlue.withValues(alpha: 0.28),
                      ),
                    ),
                    child: Text(
                      'إلغاء',
                      style: AppFonts.cooper(
                        color: AppTheme.cream,
                        fontSize: layout.isTablet ? 15 : 14,
                        fontWeight: FontWeight.w700,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ),
                ),
              ),
              SizedBox(width: layout.isTablet ? 14 : 12),
              Expanded(
                child: InkWell(
                  onTap: () async {
                    Navigator.pop(context);
                    await onLeave();
                  },
                  borderRadius: BorderRadius.circular(14),
                  child: Container(
                    padding: EdgeInsets.symmetric(
                      vertical: layout.isTablet ? 14 : 13,
                    ),
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [AppTheme.playerRed, Color(0xFFB03050)],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.circular(14),
                      boxShadow: [
                        BoxShadow(
                          color: AppTheme.playerRed.withValues(alpha: 0.35),
                          blurRadius: 12,
                        ),
                      ],
                    ),
                    child: Text(
                      'مغادرة',
                      style: AppFonts.cooper(
                        color: Colors.white,
                        fontSize: layout.isTablet ? 15 : 14,
                        fontWeight: FontWeight.w700,
                      ),
                      textAlign: TextAlign.center,
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
