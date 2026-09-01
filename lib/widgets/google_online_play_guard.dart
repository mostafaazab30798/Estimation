import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';

import '../core/icons/app_icons.dart';
import '../core/utils/google_online_auth.dart';
import '../core/utils/snackbar_helper.dart';
import '../core/widgets/app_dialog.dart';
import '../services/auth_service.dart';
import '../theme/app_theme.dart';

/// Returns `true` when the online action must be cancelled.
Future<bool> guardGoogleOnlinePlay(BuildContext context) async {
  if (AuthService.instance.isAuthenticated) return false;
  if (!context.mounted) return true;

  final signedIn = await showDialog<bool>(
        context: context,
        barrierDismissible: true,
        builder: (ctx) => const _GoogleOnlinePlayDialog(),
      ) ??
      false;

  return !signedIn;
}

class _GoogleOnlinePlayDialog extends StatelessWidget {
  const _GoogleOnlinePlayDialog();

  Future<void> _signIn(BuildContext context) async {
    try {
      final profile = await AuthService.instance.signInWithGoogle();
      if (!context.mounted) return;
      if (profile != null) {
        Navigator.pop(context, true);
        return;
      }
    } catch (e) {
      if (!context.mounted) return;
      SnackbarHelper.showError(
        context,
        'تعذر تسجيل الدخول. حاول مرة أخرى.',
        title: 'خطأ',
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return AppAlertDialog(
      title: Row(
        children: [
          const AppIcon(AppIcons.lock, color: AppTheme.gold, size: 22),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              'تسجيل الدخول مطلوب',
              style: GoogleFonts.cairo(
                color: AppTheme.gold,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
        ],
      ),
      content: Text(
        kGoogleOnlineRequiredMessage,
        style: GoogleFonts.cairo(color: AppTheme.cream, height: 1.5),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context, false),
          child: Text('إلغاء', style: GoogleFonts.cairo(color: Colors.white60)),
        ),
        Consumer<AuthService>(
          builder: (context, auth, _) {
            return FilledButton.icon(
              onPressed: auth.isLoading ? null : () => _signIn(context),
              icon: auth.isLoading
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: AppTheme.navyDark,
                      ),
                    )
                  : Image.asset(
                      'assets/google.png',
                      width: 18,
                      height: 18,
                    ),
              label: Text(
                'تسجيل الدخول بـ Google',
                style: GoogleFonts.cairo(fontWeight: FontWeight.w800),
              ),
              style: FilledButton.styleFrom(
                backgroundColor: AppTheme.cream,
                foregroundColor: AppTheme.navyDark,
              ),
            );
          },
        ),
      ],
    );
  }
}
