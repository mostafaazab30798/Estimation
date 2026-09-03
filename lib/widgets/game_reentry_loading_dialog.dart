import 'dart:async';

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../core/widgets/app_dialog.dart';
import '../theme/app_theme.dart';

/// Runs [operation] while a non-dismissible game re-entry dialog is visible.
Future<T> runWithGameReentryLoading<T>(
  BuildContext context, {
  required Future<T> Function() operation,
}) async {
  final shown = Completer<void>();
  late BuildContext dialogContext;

  unawaited(
    showDialog<void>(
      context: context,
      useRootNavigator: true,
      barrierDismissible: false,
      barrierColor: Colors.black.withValues(alpha: 0.68),
      builder: (context) {
        dialogContext = context;
        if (!shown.isCompleted) shown.complete();
        return const _GameReentryLoadingDialog();
      },
    ),
  );

  await shown.future;
  try {
    return await operation();
  } finally {
    if (dialogContext.mounted) {
      Navigator.of(dialogContext, rootNavigator: true).pop();
    }
  }
}

class _GameReentryLoadingDialog extends StatelessWidget {
  const _GameReentryLoadingDialog();

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      child: AppAlertDialog(
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 28,
          vertical: 30,
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(
              width: 34,
              height: 34,
              child: CircularProgressIndicator(
                color: AppTheme.gold,
                strokeWidth: 2.5,
              ),
            ),
            const SizedBox(height: 20),
            Text(
              'جاري العودة إلى المباراة',
              textAlign: TextAlign.center,
              style: GoogleFonts.cairo(
                color: AppTheme.cream,
                fontSize: 17,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              'نستعيد مقعدك وآخر حالة للعب…',
              textAlign: TextAlign.center,
              style: GoogleFonts.cairo(
                color: AppTheme.steelBlue,
                fontSize: 13,
                fontWeight: FontWeight.w400,
                height: 1.45,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
