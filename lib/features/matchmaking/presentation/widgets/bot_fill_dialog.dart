import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../../core/icons/app_icons.dart';
import '../../../../core/widgets/app_buttons.dart';
import '../../../../theme/app_theme.dart';
import '../../../../widgets/performance_blur.dart';

class BotFillDialog extends StatefulWidget {
  final int humanCount;
  final Future<void> Function(bool accepted) onVote;

  const BotFillDialog({
    super.key,
    required this.humanCount,
    required this.onVote,
  });

  @override
  State<BotFillDialog> createState() => _BotFillDialogState();
}

class _BotFillDialogState extends State<BotFillDialog> {
  bool _submitting = false;

  Future<void> _vote(bool accepted) async {
    if (_submitting) return;
    HapticFeedback.lightImpact();
    setState(() => _submitting = true);
    await widget.onVote(accepted);
  }

  @override
  Widget build(BuildContext context) {
    final two = widget.humanCount == 2;
    final title = two ? 'نبدأ الآن؟' : 'باقي لاعب واحد';
    final body = two
        ? 'تم العثور على لاعبين. يمكنكم مواصلة البحث أو إكمال الطاولة بلاعبين بوت.'
        : 'يمكنكم انتظار لاعب رابع، أو بدء المباراة الآن مع لاعب بوت واحد.';

    return PopScope(
      canPop: false,
      child: Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
        child: PerformanceBlur(
          sigmaX: 14,
          sigmaY: 14,
          borderRadius: BorderRadius.circular(28),
          fallbackColor: AppTheme.surface2.withValues(alpha: 0.96),
          blurColor: AppTheme.deepNavy.withValues(alpha: 0.35),
          child: Container(
            decoration: AppTheme.dialogDecoration(accent: AppTheme.gold),
            padding: const EdgeInsets.fromLTRB(22, 22, 22, 18),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    AppIconWell(
                      icon: two ? AppIcons.smartToy : AppIcons.group,
                      size: 48,
                      iconSize: 22,
                      color: AppTheme.goldLight,
                      fill: AppTheme.gold.withValues(alpha: 0.16),
                      borderColor: AppTheme.gold.withValues(alpha: 0.32),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'اقتراح سريع',
                            style: GoogleFonts.cairo(
                              color: AppTheme.steelBlue,
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                              letterSpacing: 0.6,
                              height: 1,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            title,
                            style: GoogleFonts.cairo(
                              color: AppTheme.cream,
                              fontSize: 20,
                              fontWeight: FontWeight.w800,
                              height: 1.15,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Text(
                  body,
                  style: GoogleFonts.cairo(
                    color: AppTheme.steelBlue,
                    fontSize: 14.5,
                    height: 1.55,
                  ),
                ),
                const SizedBox(height: 22),
                FilledButton(
                  onPressed: _submitting ? null : () => _vote(true),
                  style: FilledButton.styleFrom(
                    backgroundColor: AppTheme.gold,
                    foregroundColor: AppTheme.deepNavy,
                    minimumSize: const Size.fromHeight(48),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                  child: _submitting
                      ? const SizedBox.square(
                          dimension: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: AppTheme.deepNavy,
                          ),
                        )
                      : Text(
                          two ? 'ابدأ مع البوتات' : 'ابدأ مع بوت',
                          style: GoogleFonts.cairo(
                            fontWeight: FontWeight.w800,
                            fontSize: 15,
                          ),
                        ),
                ),
                const SizedBox(height: 8),
                TextButton(
                  onPressed: _submitting ? null : () => _vote(false),
                  style: TextButton.styleFrom(
                    minimumSize: const Size.fromHeight(44),
                    foregroundColor: AppTheme.steelBlue,
                  ),
                  child: Text(
                    'استمر في البحث',
                    style: GoogleFonts.cairo(
                      fontWeight: FontWeight.w700,
                      fontSize: 14,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
