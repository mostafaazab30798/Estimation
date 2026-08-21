import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:delightful_toast/delight_toast.dart';
import 'package:delightful_toast/toast/utils/enums.dart';
import '../../theme/app_theme.dart';

class SnackbarHelper {
  static void showSuccess(BuildContext context, String message, {String? title}) {
    _show(
      context: context,
      title: title,
      message: message,
      icon: Icons.check_circle_rounded,
      color: AppTheme.playerGreen,
    );
  }

  static void showError(BuildContext context, String message, {String? title}) {
    _show(
      context: context,
      title: title,
      message: message,
      icon: Icons.error_rounded,
      color: AppTheme.playerRed,
    );
  }

  static void showInfo(BuildContext context, String message, {String? title}) {
    _show(
      context: context,
      title: title,
      message: message,
      icon: Icons.info_rounded,
      color: AppTheme.accentLight,
    );
  }

  static void showWarning(BuildContext context, String message, {String? title}) {
    _show(
      context: context,
      title: title,
      message: message,
      icon: Icons.warning_rounded,
      color: AppTheme.gold,
    );
  }

  static void _show({
    required BuildContext context,
    String? title,
    required String message,
    required IconData icon,
    required Color color,
  }) {
    DelightToastBar(
      position: DelightSnackbarPosition.bottom,
      autoDismiss: true,
      snackbarDuration: const Duration(seconds: 3),
      builder: (context) => Center(
        child: Container(
          width: 320,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            color: AppTheme.navyDark.withValues(alpha: 0.94),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: color.withValues(alpha: 0.4),
              width: 1.2,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.4),
                blurRadius: 16,
                offset: const Offset(0, 6),
              ),
              BoxShadow(
                color: color.withValues(alpha: 0.12),
                blurRadius: 10,
                spreadRadius: 1,
              ),
            ],
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, color: color, size: 24),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (title != null) ...[
                      Text(
                        title,
                        style: GoogleFonts.cairo(
                          color: AppTheme.white,
                          fontSize: 13,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: 2),
                    ],
                    Text(
                      message,
                      style: GoogleFonts.cairo(
                        color: AppTheme.cream.withValues(alpha: 0.85),
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    ).show(context);
  }
}
