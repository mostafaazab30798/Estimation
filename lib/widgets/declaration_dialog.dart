// lib/widgets/declaration_dialog.dart
//
// Post-auction declaration dialog for non-Bidder players.

import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

class DeclarationDialog extends StatefulWidget {
  final void Function(int declared) onSubmit;
  final int? forbiddenDeclaration;
  final int? minDeclaration;

  const DeclarationDialog({
    super.key, 
    required this.onSubmit, 
    this.forbiddenDeclaration,
    this.minDeclaration,
  });

  @override
  State<DeclarationDialog> createState() => _DeclarationDialogState();
}

class _DeclarationDialogState extends State<DeclarationDialog> {
  late int _declared = 0;

  @override
  void initState() {
    super.initState();
    int initial = (widget.minDeclaration ?? 0).clamp(0, 13);
    if (initial == widget.forbiddenDeclaration) {
      if (initial < 13) {
        initial++;
      } else if (initial > 0) {
        initial--;
      }
    }
    _declared = initial;
  }

  @override
  Widget build(BuildContext context) {
    final isPortrait = MediaQuery.of(context).orientation == Orientation.portrait;
    final dialogWidth = MediaQuery.of(context).size.width * (isPortrait ? 0.92 : 0.65);

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
          border: Border.all(color: AppTheme.gold.withValues(alpha: 0.4), width: 1.5),
          boxShadow: AppTheme.neumorphicTurnGlow(AppTheme.navyDeep),
        ),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'كم لمة تتوقع؟',
                style: Theme.of(context).textTheme.headlineMedium,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 6),
              Text(
                'حدد عدد اللمات التي ستربحها هذه الجولة',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: AppTheme.textSecondary),
                textAlign: TextAlign.center,
              ),
              if (widget.minDeclaration != null) ...[
                const SizedBox(height: 8),
                Text(
                  'لأنك صاحب المزاد، يجب أن تتوقع ${widget.minDeclaration} لمات أو أكثر',
                  style: const TextStyle(color: AppTheme.gold, fontWeight: FontWeight.bold, fontSize: 13),
                  textAlign: TextAlign.center,
                ),
              ],
              if (widget.forbiddenDeclaration != null) ...[
                const SizedBox(height: 10),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                  decoration: BoxDecoration(
                    color: AppTheme.errorRed.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: AppTheme.errorRed.withValues(alpha: 0.3)),
                  ),
                  child: Text(
                    'الرقم ${widget.forbiddenDeclaration} ممنوع (مجموع اللمات = 13)!',
                    style: const TextStyle(color: AppTheme.errorRed, fontWeight: FontWeight.bold, fontSize: 12),
                    textAlign: TextAlign.center,
                  ),
                ),
              ],
              const SizedBox(height: 18),
              // Number grid 0–13
              Wrap(
                spacing: 8,
                runSpacing: 8,
                alignment: WrapAlignment.center,
                children: [
                  for (int i = 0; i <= 13; i++)
                    Builder(
                      builder: (context) {
                        final isForbidden = i == widget.forbiddenDeclaration;
                        final isBelowMin = widget.minDeclaration != null && i < widget.minDeclaration!;
                        final isDisabled = isForbidden || isBelowMin;
                        return GestureDetector(
                          onTap: isDisabled
                              ? null
                              : () => setState(() => _declared = i),
                          child: Opacity(
                            opacity: isDisabled ? 0.3 : 1.0,
                            child: AnimatedContainer(
                              duration: const Duration(milliseconds: 120),
                              width: 42,
                              height: 42,
                              decoration: BoxDecoration(
                                color: _declared == i
                                    ? AppTheme.gold
                                    : AppTheme.surfaceCard,
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(
                                  color: _declared == i
                                      ? AppTheme.gold
                                      : Colors.white12,
                                  width: _declared == i ? 2 : 1,
                                ),
                                boxShadow: _declared == i ? [
                                  BoxShadow(color: AppTheme.gold.withValues(alpha: 0.3), blurRadius: 8, spreadRadius: 1)
                                ] : [],
                              ),
                              alignment: Alignment.center,
                              child: Text(
                                '$i',
                                style: TextStyle(
                                  color: _declared == i
                                      ? AppTheme.navyDark
                                      : AppTheme.textPrimary,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 18,
                                ),
                              ),
                            ),
                          ),
                        );
                      }
                    ),
                ],
              ),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    backgroundColor: AppTheme.gold,
                    foregroundColor: AppTheme.navyDark,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    elevation: 4,
                  ),
                  onPressed: () {
                    Navigator.of(context).pop();
                    widget.onSubmit(_declared);
                  },
                  child: Text('تأكيد: $_declared لمة', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
