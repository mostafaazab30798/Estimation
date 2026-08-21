// lib/widgets/dash_call_dialog.dart
//
// Arabic dialog shown before the auction asking if player wants to call Dash Call.

import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

class DashCallDialog extends StatelessWidget {
  final void Function(bool wantsDashCall) onDecision;

  const DashCallDialog({super.key, required this.onDecision});

  @override
  Widget build(BuildContext context) {
    final isPortrait = MediaQuery.of(context).orientation == Orientation.portrait;
    final dialogWidth = MediaQuery.of(context).size.width * (isPortrait ? 0.90 : 0.55);

    return Dialog(
      alignment: Alignment.center,
      insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      backgroundColor: Colors.transparent,
      elevation: 0,
      child: Container(
        width: dialogWidth,
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: AppTheme.navyDark,
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: AppTheme.gold.withValues(alpha: 0.5), width: 2),
          boxShadow: AppTheme.neumorphicTurnGlow(AppTheme.navyDeep),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Title Header
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Text('🔥', style: TextStyle(fontSize: 24)),
                const SizedBox(width: 8),
                Text(
                  'طلب داش كول (Dash Call)',
                  style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                        color: AppTheme.gold,
                        fontWeight: FontWeight.bold,
                        fontSize: 19,
                      ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              'هل ترغب في إعلان تحقيق (0) أكلات قبل معرفة نوع الحكم؟',
              textAlign: TextAlign.center,
              style: Theme.of(context)
                  .textTheme
                  .bodyMedium
                  ?.copyWith(color: AppTheme.textSecondary, fontSize: 13),
            ),
            const SizedBox(height: 14),

            // Risk & Reward Information Box
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppTheme.surfaceCard,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: Colors.white12),
              ),
              child: const Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text('🏆 النجاح في الأوفر (Over):',
                          style: TextStyle(color: Colors.white70, fontSize: 12)),
                      Text('+33 نقطة',
                          style: TextStyle(
                              color: Color(0xFF4CAF50),
                              fontWeight: FontWeight.bold,
                              fontSize: 13)),
                    ],
                  ),
                  SizedBox(height: 6),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text('🛡️ النجاح في الأندر (Under):',
                          style: TextStyle(color: Colors.white70, fontSize: 12)),
                      Text('+25 نقطة',
                          style: TextStyle(
                              color: Color(0xFF4CAF50),
                              fontWeight: FontWeight.bold,
                              fontSize: 13)),
                    ],
                  ),
                  SizedBox(height: 6),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text('💀 عند الخسارة:',
                          style: TextStyle(color: Colors.white70, fontSize: 12)),
                      Text('-33 / -25 نقطة',
                          style: TextStyle(
                              color: AppTheme.errorRed,
                              fontWeight: FontWeight.bold,
                              fontSize: 13)),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 18),

            // Action Buttons
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      side: BorderSide(color: Colors.white24, width: 1.5),
                      foregroundColor: AppTheme.textPrimary,
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12)),
                    ),
                    onPressed: () {
                      Navigator.of(context).pop();
                      onDecision(false);
                    },
                    child: const Text('لا، دخول المزاد',
                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      backgroundColor: AppTheme.gold,
                      foregroundColor: AppTheme.navyDark,
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12)),
                      elevation: 4,
                    ),
                    onPressed: () {
                      Navigator.of(context).pop();
                      onDecision(true);
                    },
                    child: const Text('نعم، داش كول 🔥',
                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
