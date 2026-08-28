// lib/modes/basra/presentation/dialogs/basra_game_guide_dialog.dart

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../../theme/app_theme.dart';
import 'package:estimation/core/icons/app_icons.dart';

class BasraGameGuideDialog extends StatelessWidget {
  const BasraGameGuideDialog({super.key});

  static Future<void> show(BuildContext context) {
    return showDialog(
      context: context,
      barrierColor: Colors.black.withValues(alpha: 0.75),
      builder: (_) => const BasraGameGuideDialog(),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
        child: Container(
          constraints: const BoxConstraints(maxWidth: 560, maxHeight: 640),
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [Color(0xFF1C2A22), Color(0xFF0E1612)],
              begin: Alignment.topRight,
              end: Alignment.bottomLeft,
            ),
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: AppTheme.gold.withValues(alpha: 0.4), width: 1.5),
          ),
          child: Column(
            children: [
              Row(
                children: [
                  const AppIcon(AppIcons.helpOutline, color: AppTheme.gold, size: 22),
                  const SizedBox(width: 8),
                  Text(
                    'دليل الباصرة',
                    style: GoogleFonts.cairo(
                      color: AppTheme.cream,
                      fontSize: 18,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const Spacer(),
                  IconButton(
                    onPressed: () => Navigator.pop(context),
                    icon: const AppIcon(AppIcons.close, color: Colors.white70, size: 20),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Expanded(
                child: ListView(
                  children: const [
                    _GuideBlock(
                      title: 'اللعب',
                      body:
                          'كل لاعب يبدأ بـ 4 أوراق، وعلى الطاولة 4 أوراق ظاهرة. في دورك تلعب ورقة واحدة فقط — لا يوجد تمرير. أول لاعب ليس هو الموزّع.',
                    ),
                    _GuideBlock(
                      title: 'الأخذ',
                      body:
                          'خذ بنفس الرتبة، أو بمجموع أوراق رقمية يساوي ورقتك. Q و K بلا قيمة رقمية ويأخذان مثيلهما فقط. الولد (J) و7 ديناري يكنسان الطاولة.',
                    ),
                    _GuideBlock(
                      title: 'الباصرة',
                      body:
                          'إذا أخذت كل أوراق الطاولة بورقة عادية تحصل على باصرة (+10). الولد لا يعطي باصرة. 7 ديناري يعطي باصرة فقط إذا مجموع الطاولة ≤ 10 ولا توجد Q أو K.',
                    ),
                    _GuideBlock(
                      title: 'النقاط والفوز',
                      body:
                          '27 ورقة أو أكثر = +30. كل ولد +1، كل آس +1، 2♠ +2، 10♦ +3. تعادل 26-26 يرحّل الـ30 للجولة التالية. أول من يصل 121 يفوز.',
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _GuideBlock extends StatelessWidget {
  final String title;
  final String body;
  const _GuideBlock({required this.title, required this.body});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: GoogleFonts.cairo(
              color: AppTheme.gold,
              fontWeight: FontWeight.w800,
              fontSize: 14,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            body,
            style: GoogleFonts.cairo(
              color: Colors.white70,
              fontSize: 13,
              height: 1.55,
            ),
          ),
        ],
      ),
    );
  }
}
