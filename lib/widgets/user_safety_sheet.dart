// lib/widgets/user_safety_sheet.dart

import 'package:flutter/material.dart';
import '../core/widgets/app_dialog.dart';
import 'package:url_launcher/url_launcher.dart';

import '../services/ugc_service.dart';
import '../theme/app_theme.dart';
import '../core/utils/snackbar_helper.dart';
import 'package:estimation/core/icons/app_icons.dart';

/// Report / block actions for another player's profile or leaderboard row.
Future<void> showUserSafetySheet(
  BuildContext context, {
  required String reportedUserId,
  required String displayName,
  String? contextType,
  String? contextId,
}) async {
  if (reportedUserId.isEmpty) return;

  await showModalBottomSheet<void>(
    context: context,
    backgroundColor: Colors.transparent,
    builder: (ctx) {
      return Container(
        decoration: const BoxDecoration(
          color: AppTheme.navyDark,
          borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
          border: Border(top: BorderSide(color: Colors.white12)),
        ),
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 42,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.white24,
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            const SizedBox(height: 16),
            Text(
              displayName,
              style: AppFonts.cooper(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: AppTheme.cream,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              'الإبلاغ أو الحظر يخفي هذا اللاعب عنك في التصنيف والغرف.',
              textAlign: TextAlign.center,
              style: AppFonts.cooper(fontSize: 12, color: AppTheme.steelBlue),
            ),
            const SizedBox(height: 18),
            ListTile(
              leading: const AppIcon(AppIcons.flag, color: AppTheme.gold),
              title: Text('إبلاغ عن لاعب',
                  style: AppFonts.cooper(color: AppTheme.cream)),
              subtitle: Text('اسم مسيء أو صورة غير لائقة',
                  style: AppFonts.cooper(
                      fontSize: 11, color: AppTheme.steelBlue)),
              onTap: () async {
                Navigator.pop(ctx);
                await _submitReport(
                  context,
                  reportedUserId: reportedUserId,
                  displayName: displayName,
                  contextType: contextType,
                  contextId: contextId,
                );
              },
            ),
            ListTile(
              leading: const AppIcon(AppIcons.block, color: AppTheme.errorRed),
              title: Text('حظر اللاعب',
                  style: AppFonts.cooper(color: AppTheme.cream)),
              subtitle: Text('لن تراه في التصنيف أو تتفاعل معه',
                  style: AppFonts.cooper(
                      fontSize: 11, color: AppTheme.steelBlue)),
              onTap: () async {
                Navigator.pop(ctx);
                final ok = await UgcService.instance.blockUser(reportedUserId);
                if (!context.mounted) return;
                if (ok) {
                  SnackbarHelper.showSuccess(
                    context,
                    'تم حظر $displayName.',
                    title: 'تم الحظر',
                  );
                } else {
                  SnackbarHelper.showError(
                    context,
                    'تعذر تنفيذ الحظر. حاول مرة أخرى.',
                    title: 'خطأ',
                  );
                }
              },
            ),
            ListTile(
              leading: const AppIcon(AppIcons.infoOutline, color: AppTheme.mintSoft),
              title: Text('إرشادات المجتمع',
                  style: AppFonts.cooper(color: AppTheme.cream)),
              onTap: () {
                Navigator.pop(ctx);
                launchUrl(Uri.parse(kTermsOfServiceUrl),
                    mode: LaunchMode.platformDefault);
              },
            ),
          ],
        ),
      );
    },
  );
}

Future<void> _submitReport(
  BuildContext context, {
  required String reportedUserId,
  required String displayName,
  String? contextType,
  String? contextId,
}) async {
  final reasonController = TextEditingController();
  final detailsController = TextEditingController();
  String selectedReason = 'inappropriate_name';

  final submitted = await showDialog<bool>(
    context: context,
    builder: (ctx) {
      return StatefulBuilder(
        builder: (context, setState) {
          return AppAlertDialog(
            title: Text(
              'إبلاغ عن $displayName',
              style: AppFonts.cooper(
                fontWeight: FontWeight.bold,
                color: AppTheme.cream,
              ),
            ),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  DropdownButtonFormField<String>(
                    initialValue: selectedReason,
                    dropdownColor: AppTheme.navyDark,
                    style: AppFonts.cooper(color: AppTheme.cream),
                    decoration: InputDecoration(
                      labelText: 'سبب الإبلاغ',
                      labelStyle:
                          AppFonts.cooper(color: AppTheme.steelBlue),
                    ),
                    items: const [
                      DropdownMenuItem(
                        value: 'inappropriate_name',
                        child: Text('اسم مسيء'),
                      ),
                      DropdownMenuItem(
                        value: 'inappropriate_photo',
                        child: Text('صورة غير لائقة'),
                      ),
                      DropdownMenuItem(
                        value: 'harassment',
                        child: Text('مضايقة'),
                      ),
                      DropdownMenuItem(
                        value: 'other',
                        child: Text('أخرى'),
                      ),
                    ],
                    onChanged: (v) {
                      if (v != null) setState(() => selectedReason = v);
                    },
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: detailsController,
                    maxLines: 3,
                    style: AppFonts.cooper(color: AppTheme.cream),
                    decoration: InputDecoration(
                      labelText: 'تفاصيل إضافية (اختياري)',
                      labelStyle:
                          AppFonts.cooper(color: AppTheme.steelBlue),
                      border: const OutlineInputBorder(),
                    ),
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: Text('إلغاء',
                    style: AppFonts.cooper(color: Colors.white60)),
              ),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.gold,
                  foregroundColor: AppTheme.navyDark,
                ),
                onPressed: () => Navigator.pop(ctx, true),
                child: Text('إرسال',
                    style: AppFonts.cooper(fontWeight: FontWeight.bold)),
              ),
            ],
          );
        },
      );
    },
  );

  reasonController.dispose();

  if (submitted != true || !context.mounted) {
    detailsController.dispose();
    return;
  }

  final ok = await UgcService.instance.submitReport(
    reportedUserId: reportedUserId,
    reason: selectedReason,
    details: detailsController.text.trim().isEmpty
        ? null
        : detailsController.text.trim(),
    contextType: contextType,
    contextId: contextId,
  );
  detailsController.dispose();

  if (!context.mounted) return;
  if (ok) {
    SnackbarHelper.showSuccess(
      context,
      'تم استلام بلاغك. سيتم مراجعته خلال 48 ساعة.',
      title: 'شكراً لك',
    );
  } else {
    SnackbarHelper.showError(
      context,
      'تعذر إرسال البلاغ. حاول مرة أخرى.',
      title: 'خطأ',
    );
  }
}
