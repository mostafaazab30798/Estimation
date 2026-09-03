import 'package:flutter/material.dart';
import 'package:delightful_toast/delight_toast.dart';
import 'package:delightful_toast/toast/utils/enums.dart';
import '../../theme/app_theme.dart';
import 'package:estimation/core/icons/app_icons.dart';

class SnackbarHelper {
  static void showSuccess(BuildContext context, String message, {String? title}) {
    _show(
      context: context,
      title: title,
      message: message,
      icon: AppIcons.checkCircle,
      color: AppTheme.playerGreen,
    );
  }

  static void showError(BuildContext context, String message, {String? title}) {
    _show(
      context: context,
      title: title,
      message: message,
      icon: AppIcons.error,
      color: AppTheme.playerRed,
    );
  }

  static void showInfo(BuildContext context, String message, {String? title}) {
    _show(
      context: context,
      title: title,
      message: message,
      icon: AppIcons.info,
      color: AppTheme.accentLight,
    );
  }

  static void showWarning(BuildContext context, String message, {String? title}) {
    _show(
      context: context,
      title: title,
      message: message,
      icon: AppIcons.warning,
      color: AppTheme.gold,
    );
  }

  static void _show({
    required BuildContext context,
    String? title,
    required String message,
    required AppIconData icon,
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
              AppIcon(icon, color: color, size: 24),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (title != null) ...[
                      Text(
                        title,
                        style: AppFonts.cooper(
                          color: AppTheme.white,
                          fontSize: 13,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: 2),
                    ],
                    Text(
                      message,
                      style: AppFonts.cooper(
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
