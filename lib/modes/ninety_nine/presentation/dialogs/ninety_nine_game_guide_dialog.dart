// lib/modes/ninety_nine/presentation/dialogs/ninety_nine_game_guide_dialog.dart

import 'package:flutter/material.dart';
import '../../../../core/utils/game_layout_metrics.dart';
import '../../../../theme/app_theme.dart';
import 'package:estimation/core/icons/app_icons.dart';

class NinetyNineGameGuideDialog extends StatefulWidget {
  const NinetyNineGameGuideDialog({super.key});

  static Future<void> show(BuildContext context) {
    return showDialog(
      context: context,
      barrierColor: Colors.black.withValues(alpha: 0.75),
      builder: (context) => const NinetyNineGameGuideDialog(),
    );
  }

  @override
  State<NinetyNineGameGuideDialog> createState() => _NinetyNineGameGuideDialogState();
}

class _NinetyNineGameGuideDialogState extends State<NinetyNineGameGuideDialog>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  final List<_GuideTab> _tabs = const [
    _GuideTab(title: 'الأساسيات 🎯', icon: AppIcons.sportsEsports),
    _GuideTab(title: 'الأوراق والخصائص 🎴', icon: AppIcons.style),
    _GuideTab(title: 'الاستبعاد والفوز 🏆', icon: AppIcons.emojiEvents),
  ];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: _tabs.length, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final layout = GameLayoutMetrics.of(context);
    final isMobile = !layout.isTablet;
    final screenSize = MediaQuery.of(context).size;

    return Directionality(
      textDirection: TextDirection.rtl,
      child: Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: EdgeInsets.symmetric(
          horizontal: layout.isTablet ? 28 : 10,
          vertical: layout.isTablet ? 32 : 16,
        ),
        child: Container(
          constraints: BoxConstraints(
            maxWidth: layout.isLargeTablet ? 740 : 680,
            maxHeight: screenSize.height * 0.85,
          ),
          decoration: AppTheme.dialogDecoration(
            accent: const Color(0xFFEF4444),
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(AppTheme.dialogRadius),
            child: Column(
              children: [
                // ── Header Bar ──────────────────────────────────────────────
                Container(
                  padding: const EdgeInsets.fromLTRB(16, 16, 20, 12),
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.3),
                    border: Border(
                      bottom: BorderSide(
                        color: const Color(0xFFEF4444).withValues(alpha: 0.2),
                      ),
                    ),
                  ),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: const Color(0xFFEF4444).withValues(alpha: 0.2),
                          shape: BoxShape.circle,
                        ),
                        child: const AppIcon(
                          AppIcons.localFireDepartment,
                          color: Color(0xFFEF4444),
                          size: 22,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'دليل قواعد لعبة الـ 99 🔥',
                              style: AppFonts.cooper(
                                color: Colors.white,
                                fontSize: isMobile ? 16 : 18,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            Text(
                              'تعلم كيفية اللعب والأوراق المنقذة لتجنب الخسارة',
                              style: AppFonts.cooper(
                                color: AppTheme.steelBlue,
                                fontSize: isMobile ? 11 : 12,
                              ),
                            ),
                          ],
                        ),
                      ),
                      IconButton(
                        onPressed: () => Navigator.pop(context),
                        icon: const AppIcon(AppIcons.close, color: Colors.white70),
                        tooltip: 'إغلاق',
                      ),
                    ],
                  ),
                ),

                // ── Tab Bar Navigation ──────────────────────────────────────
                Container(
                  color: Colors.black.withValues(alpha: 0.2),
                  child: TabBar(
                    controller: _tabController,
                    indicatorColor: const Color(0xFFEF4444),
                    indicatorWeight: 3,
                    labelColor: const Color(0xFFEF4444),
                    unselectedLabelColor: AppTheme.steelBlue,
                    labelStyle: AppFonts.cooper(
                      fontSize: isMobile ? 12 : 14,
                      fontWeight: FontWeight.bold,
                    ),
                    tabs: _tabs
                        .map((t) => Tab(
                              icon: AppIcon(t.icon, size: 18),
                              text: t.title,
                            ))
                        .toList(),
                  ),
                ),

                // ── Tab Views Body ──────────────────────────────────────────
                Expanded(
                  child: TabBarView(
                    controller: _tabController,
                    children: [
                      _buildOverviewTab(isMobile),
                      _buildCardsTab(isMobile),
                      _buildRulesTab(isMobile),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildOverviewTab(bool isMobile) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      physics: const BouncingScrollPhysics(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildInfoCard(
            title: '🎯 هدف اللعبة الأساسي',
            description:
                'تبدأ مجموع الأرض من الصفر (0). يرمي كل لاعب ورقة في دوره لتضاف أو تطبق قيمتها على مجموع الأرض. الهدف هو عدم تجاوز مجموع 99 والتخلص من أوراقك بأمان دون التعرض للاستبعاد!',
            accentColor: AppTheme.gold,
          ),
          const SizedBox(height: 16),
          _buildInfoCard(
            title: '🔄 طريقة وسير اللعب',
            description:
                '• يتم توزيع الأوراق بين اللاعبين الأربعة بأسلوب التناوب (Round-Robin).\n'
                '• يلعب كل لاعب ورقة واحدة في دوره وتتحدث مجموع الأرض فوراً.\n'
                '• تستمر الجولة في الاتجاه الموحد حتى يتغير بفعل الأوراق الخاصة (مثل الكارت 7).',
            accentColor: const Color(0xFF38BDF8),
          ),
          const SizedBox(height: 16),
          _buildInfoCard(
            title: '🚫 ممنوع تجاوز 99',
            description:
                'لا يجوز لعب أي ورقة تجعل مجموع الأرض أكبر من 99. تلك الأوراق تُقفل في يدك. '
                'يمكنك لعب ورقة تصل بالمجموع إلى 99 تماماً، أما ما فوق ذلك فمحظور. '
                'الأوراق المنقذة (4، 7، الولد، الشايب) لا تتجاوز الحد أبداً.',
            accentColor: const Color(0xFFEF4444),
          ),
          const SizedBox(height: 16),
          _buildInfoCard(
            title: '⚠️ لحظة الخطر (عند الوصول لـ 99)',
            description:
                'عندما تصل الأرض لمجموع 99 تماماً، يبدأ التوتر الحقيقي! اللاعب الذي يأتي دوره ولا يملك أي ورقة آمنة في يده يخسر الجولة ويتم استبعاده فوراً!',
            accentColor: const Color(0xFFEF4444),
          ),
        ],
      ),
    );
  }

  Widget _buildCardsTab(bool isMobile) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      physics: const BouncingScrollPhysics(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '🎴 الأوراق الخاصة وتأثيراتها:',
            style: AppFonts.cooper(
              color: AppTheme.cream,
              fontSize: 16,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 12),
          _buildCardRuleTile(
            cardName: 'الشايب 👑 (King)',
            effect: 'يرفع مجموع الأرض لـ 99 فوراً! (إذا كانت الأرض 99 يضيف +0).',
            badge: 'ورقة منقذة 🛡️',
            badgeColor: const Color(0xFFEF4444),
          ),
          _buildCardRuleTile(
            cardName: 'الولد 🃏 (Jack)',
            effect: 'يخصم -10 من مجموع الأرض (لا يقل المجموع عن 0).',
            badge: 'ورقة منقذة 🛡️',
            badgeColor: const Color(0xFF10B981),
          ),
          _buildCardRuleTile(
            cardName: 'البنت 👸 (Queen)',
            effect: 'تضيف +10 لمجموع الأرض. لا يمكن لعبها إذا كان المجموع سيصبح أكبر من 99.',
            badge: 'تأثير خاص',
            badgeColor: AppTheme.gold,
          ),
          _buildCardRuleTile(
            cardName: 'الرقم 7 🔄',
            effect: 'تضيف +0 لمجموع الأرض وتعكس اتجاه اللعب لجميع اللاعبين.',
            badge: 'ورقة منقذة 🛡️',
            badgeColor: const Color(0xFF38BDF8),
          ),
          _buildCardRuleTile(
            cardName: 'الرقم 4 🛡️',
            effect: 'تضيف +0 لمجموع الأرض الحالي للحفاظ عليه كما هو (ولا تقوم بتصفير الأرض).',
            badge: 'ورقة منقذة 🛡️',
            badgeColor: AppTheme.gold,
          ),
          _buildCardRuleTile(
            cardName: 'الآس 🎴 (Ace)',
            effect: 'يضيف +1 فقط لمجموع الأرض.',
            badge: 'عادي',
            badgeColor: Colors.white38,
          ),
          _buildCardRuleTile(
            cardName: 'باقي الأرقام (2, 3, 5, 6, 8, 9, 10)',
            effect: 'تضيف قيمتها الرقمية الوجهية فوراً لمجموع الأرض. تُقفل إذا كانت ستجعل المجموع أكبر من 99.',
            badge: 'إضافة وجهية',
            badgeColor: Colors.white38,
          ),
        ],
      ),
    );
  }

  Widget _buildRulesTab(bool isMobile) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      physics: const BouncingScrollPhysics(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildInfoCard(
            title: '🛡️ الأوراق المنقذة (Safe Cards)',
            description:
                'الأوراق المنقذة التي تحميك عندما يصل مجموع الأرض لـ 99 هي:\n'
                '• الرقم 4 (+0)\n'
                '• الرقم 7 (عكس الاتجاه +0)\n'
                '• الولد J (-10)\n'
                '• الشايب K (يضبط الأرض على 99 أو +0)\n\n'
                'احتفظ بهذه الأوراق في يدك لاستخدامها كدرع حماية في اللحظات الحرة!',
            accentColor: const Color(0xFF10B981),
          ),
          const SizedBox(height: 16),
          _buildInfoCard(
            title: '☠️ الاستبعاد ونهاية الجولة',
            description:
                '• إذا لم تملك أي ورقة يمكن لعبها دون تجاوز 99 (بما في ذلك عند وصول الأرض لـ 99 بدون أوراق آمنة)، تُستبعد وتخسر الجولة.\n'
                '• يستمر اللعب بين باقي اللاعبين حتى يتبقى لاعب واحد فقط يكون هو الفائز بالجولة!',
            accentColor: const Color(0xFFEF4444),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoCard({
    required String title,
    required String description,
    required Color accentColor,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.35),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: accentColor.withValues(alpha: 0.35)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: AppFonts.cooper(
              color: accentColor,
              fontSize: 15,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            description,
            style: AppFonts.cooper(
              color: AppTheme.cream,
              fontSize: 13,
              height: 1.5,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCardRuleTile({
    required String cardName,
    required String effect,
    required String badge,
    required Color badgeColor,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  cardName,
                  style: AppFonts.cooper(
                    color: Colors.white,
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  effect,
                  style: AppFonts.cooper(
                    color: AppTheme.steelBlue,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: badgeColor.withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: badgeColor.withValues(alpha: 0.5)),
            ),
            child: Text(
              badge,
              style: AppFonts.cooper(
                color: Colors.white,
                fontSize: 10,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _GuideTab {
  final String title;
  final AppIconData icon;

  const _GuideTab({required this.title, required this.icon});
}
