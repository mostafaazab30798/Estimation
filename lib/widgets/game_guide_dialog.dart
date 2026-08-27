// lib/widgets/game_guide_dialog.dart

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../theme/app_theme.dart';
import '../core/constants.dart';
import 'package:estimation/core/icons/app_icons.dart';

class GameGuideDialog extends StatefulWidget {
  const GameGuideDialog({super.key});

  static Future<void> show(BuildContext context) {
    return showDialog(
      context: context,
      barrierColor: Colors.black.withValues(alpha: 0.75),
      builder: (context) => const GameGuideDialog(),
    );
  }

  @override
  State<GameGuideDialog> createState() => _GameGuideDialogState();
}

class _GameGuideDialogState extends State<GameGuideDialog>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  final List<_GuideCategory> _categories = const [
    _GuideCategory(
      title: 'الأساسيات',
      icon: AppIcons.emojiEvents,
    ),
    _GuideCategory(
      title: 'المزاد والمراحل',
      icon: AppIcons.style,
    ),
    _GuideCategory(
      title: 'قواعد اللعب',
      icon: AppIcons.touchApp,
    ),
    _GuideCategory(
      title: 'النقاط والبونص',
      icon: AppIcons.calculate,
    ),
  ];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: _categories.length, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final screenSize = MediaQuery.of(context).size;
    final isMobile = screenSize.width < 600;

    return Directionality(
      textDirection: TextDirection.rtl,
      child: Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: EdgeInsets.symmetric(
          horizontal: isMobile ? 10 : 28,
          vertical: isMobile ? 16 : 32,
        ),
        child: Container(
          constraints: BoxConstraints(
            maxWidth: 720,
            maxHeight: screenSize.height * 0.88,
          ),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [Color(0xFA1D3348), Color(0xFA122232)],
              begin: Alignment.topRight,
              end: Alignment.bottomLeft,
            ),
            borderRadius: BorderRadius.circular(24),
            border: Border.all(
              color: AppTheme.accentBlue.withValues(alpha: 0.35),
              width: 1.5,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.5),
                blurRadius: 30,
                spreadRadius: 4,
              ),
              BoxShadow(
                color: AppTheme.accentBlue.withValues(alpha: 0.15),
                blurRadius: 40,
                spreadRadius: -5,
              ),
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(24),
            child: Column(
              children: [
                // ── Header ───────────────────────────────────────────
                _buildHeader(context),

                // ── Tabs Bar ─────────────────────────────────────────
                _buildTabBar(),

                // ── Tab Contents ─────────────────────────────────────
                Expanded(
                  child: TabBarView(
                    controller: _tabController,
                    children: [
                      _buildOverviewTab(),
                      _buildAuctionAndPhasesTab(),
                      _buildGameplayRulesTab(),
                      _buildScoringTab(),
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

  // ── Header ─────────────────────────────────────────────────────────────

  Widget _buildHeader(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: AppTheme.navyDark.withValues(alpha: 0.6),
        border: Border(
          bottom: BorderSide(
            color: Colors.white.withValues(alpha: 0.08),
          ),
        ),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  AppTheme.accentBlue.withValues(alpha: 0.3),
                  AppTheme.accentLight.withValues(alpha: 0.15),
                ],
              ),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: AppTheme.accentBlue.withValues(alpha: 0.4),
              ),
            ),
            child: const AppIcon(
              AppIcons.menuBook,
              color: AppTheme.mintSoft,
              size: 22,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'دليل وقواعد لعبة الإستميشن',
                  style: GoogleFonts.cairo(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 2),
                Text(
                  'شرح كامل لقواعد اللعب، المزاد، والاحتساب',
                  style: GoogleFonts.cairo(
                    color: AppTheme.accentLight.withValues(alpha: 0.8),
                    fontSize: 11,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          IconButton(
            onPressed: () => Navigator.of(context).pop(),
            icon: const AppIcon(AppIcons.close, color: Colors.white70, size: 20),
            constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
            style: IconButton.styleFrom(
              backgroundColor: Colors.white.withValues(alpha: 0.08),
              padding: const EdgeInsets.all(6),
            ),
          ),
        ],
      ),
    );
  }

  // ── Tab Bar ────────────────────────────────────────────────────────────

  Widget _buildTabBar() {
    return Container(
      color: Colors.black.withValues(alpha: 0.2),
      child: TabBar(
        controller: _tabController,
        isScrollable: true,
        indicatorColor: AppTheme.mintSoft,
        indicatorWeight: 3,
        dividerColor: Colors.transparent,
        labelColor: AppTheme.mintSoft,
        unselectedLabelColor: Colors.white60,
        tabAlignment: TabAlignment.start,
        padding: const EdgeInsets.symmetric(horizontal: 4),
        labelStyle: GoogleFonts.cairo(
          fontWeight: FontWeight.bold,
          fontSize: 12.5,
        ),
        unselectedLabelStyle: GoogleFonts.cairo(
          fontWeight: FontWeight.w500,
          fontSize: 12.5,
        ),
        tabs: _categories
            .map(
              (cat) => Tab(
                height: 44,
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    AppIcon(cat.icon, size: 16),
                    const SizedBox(width: 6),
                    Text(cat.title),
                  ],
                ),
              ),
            )
            .toList(),
      ),
    );
  }

  // ── Tab 1: Overview & Basics ───────────────────────────────────────────

  Widget _buildOverviewTab() {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        _buildGuideCard(
          title: '📌 ما هي لعبة الإستميشن؟',
          accentColor: AppTheme.accentBlue,
          content: [
            'لعبة الإستميشن (Egyptian Estimation) هي لعبة كوتشينة استراتيجية مصرية شهيرة تعتمد على التوقع والتقدير الدقيق لعدد "الأكلات" (Tricks) التي تستطيع اليد تحقيقها.',
            'تلعب اللعبة بـ 4 لاعبين وكوتشينة كاملة (52 كارت)، حيث يحصل كل لاعب على 13 كارت في كل جولة.',
          ],
        ),
        const SizedBox(height: 14),
        _buildGuideCard(
          title: '🏆 هدف اللعبة وكيف تفوز؟',
          accentColor: AppTheme.gold,
          content: [
            'الهدف هو جمع أعلى عدد من النقاط عبر الوصول للتوقع الدقيق لعدد أكلاتك.',
            'تنتهي المباراة عندما يصل أي لاعب إلى 50 نقطة أولاً، ويتم إعلان الفائز بالمباراة! 👑',
          ],
        ),
        const SizedBox(height: 14),
        _buildGuideCard(
          title: '♠️ قوة الألوان والتسلسل القياسي',
          accentColor: AppTheme.mintSoft,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'ترتيب قوة الألوان في مزاد الحكم من الأقوى للأضعف:',
                style: GoogleFonts.cairo(color: Colors.white70, fontSize: 12.5),
              ),
              const SizedBox(height: 12),
              // Responsive Wrap layout for suit badges to prevent overflow
              Center(
                child: Wrap(
                  alignment: WrapAlignment.center,
                  spacing: 10,
                  runSpacing: 10,
                  children: [
                    _buildSuitBadge(Suit.spade, 'أقوى لون (سبيد)'),
                    _buildSuitBadge(Suit.heart, 'هارت'),
                    _buildSuitBadge(Suit.diamond, 'كارو'),
                    _buildSuitBadge(Suit.club, 'أضعف لون (تريفل)'),
                  ],
                ),
              ),
              const SizedBox(height: 14),
              Text(
                'ترتيب قوة الكروت داخل اللون الواحد:',
                style: GoogleFonts.cairo(color: Colors.white70, fontSize: 12.5),
              ),
              const SizedBox(height: 8),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.3),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
                ),
                child: Text(
                  'A (الآس) > K (الشايب) > Q (البنت) > J (الولد) > 10 > 9 > 8 > 7 > 6 > 5 > 4 > 3 > 2',
                  textAlign: TextAlign.center,
                  style: GoogleFonts.cairo(
                    color: AppTheme.gold,
                    fontWeight: FontWeight.bold,
                    fontSize: 11.5,
                    height: 1.4,
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  // ── Tab 2: Auction & Round Flow ────────────────────────────────────────

  Widget _buildAuctionAndPhasesTab() {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        _buildGuideCard(
          title: '🔄 تسلسل الجولة الرسمية (البولة)',
          accentColor: AppTheme.accentLight,
          content: [
            '1️⃣ توزيع 13 كارت لكل لاعب.',
            '2️⃣ فحص الفويد (Void Check): ميزة تسمح بطلب إعادة التوزيع لمن لا يملك كروت من لون معين.',
            '3️⃣ داش كول (Dash Call): فرصة قبل المزاد لطلب (0) أكلات دون معرفة الحكم بنقاط عالية (+33/+25).',
            '4️⃣ المزاد (Auction): المزايدة من 4 إلى 13 أكلة، وخيار "السانز" (Sans) هو الأقوى.',
            '5️⃣ التصريح (Declarations): طلب اللمات مع الالتزام بعدم تجاوز الكولر ومنع مجموع 13 للرابع.',
            '6️⃣ اللعب وحساب النتائج (مع مضاعفة x2 في حال تمرير المزاد بالكامل).',
          ],
        ),
        const SizedBox(height: 14),
        _buildGuideCard(
          title: '👑 المزاد وأنواع القطوع (بما في ذلك السانز)',
          accentColor: AppTheme.gold,
          content: [
            '• ترتيب قوة الحكم: سانز (No Trump) > سبيد (♠) > هارت (♥) > كارو (♦) > تريفل (♣).',
            '• في عقد "السانز" (بلا لون)، لا توجد كروت حكم تقطع، وأعلى كارت من لون الأكلة هو الفائز دائماً.',
            '• في آخر 5 جولات من البولة (14 إلى 18)، تكون الألوان إجبارية بالترتيب: (سانز، سبيد، هارت، كارو، تريفل) ولا تتغير إلا بطلب 8 لمات فأكثر.',
            '• إذا مرر جميع اللاعبين المزاد (Pass)، يتم تخطي الدور ومضاعفة نقاط الجولة التالية (Double x2).',
          ],
        ),
        const SizedBox(height: 14),
        _buildGuideCard(
          title: '📣 قواعد التصريح الصارمة',
          accentColor: AppTheme.mintSoft,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildRoundTypeRow(
                title: 'ممنوع الـ 13 🚫',
                color: AppTheme.playerRed,
                description: 'يُمنع اللاعب الرابع تماماً من طلب الرقم المتمم للـ 13، لضمان وجود خاسر في الجولة.',
              ),
              const SizedBox(height: 8),
              _buildRoundTypeRow(
                title: 'سقف الكولر 👑',
                color: AppTheme.gold,
                description: 'لا يجوز لأي لاعب طلب أكلات أعلى من صاحب المزاد (الكولر)، بل يطلب مساوياً له (ويز) أو أقل منه.',
              ),
              const SizedBox(height: 8),
              _buildRoundTypeRow(
                title: 'ريسك (Risk) ⚡',
                color: Colors.amberAccent,
                description: 'إذا جعل اللاعب الأخير مجموع أكلات الأندر ≤ 11 يحصل على بونص ريسك إضافي (+10) عند النجاح!',
              ),
            ],
          ),
        ),
      ],
    );
  }

  // ── Tab 3: Gameplay Rules & Follow Suit ────────────────────────────────

  Widget _buildGameplayRulesTab() {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        _buildGuideCard(
          title: '🎯 قانون اتباع اللون (Follow Suit Rule)',
          accentColor: AppTheme.playerRed,
          content: [
            '⚠️ أهم قاعدة في اللعبة: يجب عليك دائماً لعب كارت من نفس لون الكارت المقصوص (أول كارت مكسور في الأكلة) طالما يمتلكه يدك!',
            '• إذا كنت تمتلك كارت من نفس اللون، لا يجوز لك رمي لون آخر أو القطع بالحكم.',
            '• إذا لم تكن تمتلك كارت من لون الأكلة: يمكنك رمي أي كارت من لون آخر أو "القطع" بكارت حكم للفوز بالأكلة!',
          ],
        ),
        const SizedBox(height: 14),
        _buildGuideCard(
          title: '🗡️ من يفوز بالأكلة (Trick Winning)?',
          accentColor: AppTheme.accentBlue,
          content: [
            '1️⃣ في جولات السانز: أعلى كارت من لون الأكلة المقصوصة يفوز دائماً.',
            '2️⃣ في جولات الحكم: يفوز أعلى كارت حكم، وإن لم يُلعب حكم يفوز أعلى كارت من لون الأكلة.',
            '3️⃣ الكروت من الألوان الأخرى غير الحكم لا تفوز أبداً (رمي/كبس).',
            '4️⃣ الفائز بالأكلة هو من يبدأ برمياً أول كارت في الأكلة التالية!',
          ],
        ),
      ],
    );
  }

  // ── Tab 4: Scoring & Bonuses ───────────────────────────────────────────

  Widget _buildScoringTab() {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        _buildGuideCard(
          title: '✅ حساب النقاط عند النجاح (Actual == Declared)',
          accentColor: const Color(0xFF4CAF50),
          content: [
            '• النقاط الأساسية = عدد الأكلات المحققة + رقم الجولة الحالي.',
            '• بونص صاحب الحكم (The Bidder): يضاف +10 نقاط إضافية!',
            '• بونص "معاها" (With / ويز): طلب نفس رقم الكولر يعطي +10 نقاط إضافية!',
            '• بونص "الريسك" (Risk): تحقيق توقع الريسك يعطي +10 نقاط إضافية!',
            '• بونص الداش العادي (0): في جولات الأندر يعطي +10 نقاط إضافية!',
            '• مكافأة الداش كول (Dash Call): +33 في جولات الأوفر، و +25 في جولات الأندر!',
          ],
        ),
        const SizedBox(height: 14),
        _buildGuideCard(
          title: '❌ الخصم والعقوبات عند الفشل (Actual != Declared)',
          accentColor: AppTheme.playerRed,
          content: [
            '• الخصم الأساسي = - (الفرق بين توقعك والأكلات الفعلية) - رقم الجولة.',
            '• عقوبة الكولر أو "معاها" أو "الريسك": يخصم -10 نقاط إضافية فوق الخصم الأساسي!',
            '• عقوبة خسارة الداش كول: -33 نقطة في الأوفر، و -25 نقطة في الأندر!',
          ],
        ),
        const SizedBox(height: 14),
        _buildGuideCard(
          title: '📊 جدول أمثلة حسابية',
          accentColor: AppTheme.mintSoft,
          child: Column(
            children: [
              _buildExampleRow(
                round: 'الجولة 5',
                role: 'صاحب الحكم',
                declared: 5,
                actual: 5,
                resultText: '+20 نقطة (5 + 5 + 10 بونص)',
                isSuccess: true,
              ),
              const SizedBox(height: 8),
              _buildExampleRow(
                round: 'الجولة 5',
                role: 'لاعب عالي',
                declared: 3,
                actual: 3,
                resultText: '+8 نقاط (3 + 5)',
                isSuccess: true,
              ),
              const SizedBox(height: 8),
              _buildExampleRow(
                round: 'الجولة 5',
                role: 'داش في أندر',
                declared: 0,
                actual: 0,
                resultText: '+15 نقطة (0 + 5 + 10 داش)',
                isSuccess: true,
              ),
              const SizedBox(height: 8),
              _buildExampleRow(
                round: 'الجولة 5',
                role: 'صاحب الحكم',
                declared: 5,
                actual: 4,
                resultText: '-16 نقطة ( -1 -5 -10 عقوبة)',
                isSuccess: false,
              ),
            ],
          ),
        ),
      ],
    );
  }

  // ── Helper UI Widgets ──────────────────────────────────────────────────

  Widget _buildGuideCard({
    required String title,
    required Color accentColor,
    List<String>? content,
    Widget? child,
  }) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppTheme.navyDark.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: accentColor.withValues(alpha: 0.3),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 4,
                height: 18,
                decoration: BoxDecoration(
                  color: accentColor,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  title,
                  style: GoogleFonts.cairo(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 14.5,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          if (content != null)
            ...content.map(
              (text) => Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: Text(
                  text,
                  style: GoogleFonts.cairo(
                    color: Colors.white.withValues(alpha: 0.88),
                    fontSize: 12.5,
                    height: 1.45,
                  ),
                ),
              ),
            ),
          if (child != null) child,
        ],
      ),
    );
  }

  Widget _buildSuitBadge(Suit suit, String subtitle) {
    final isRed = suit.color == SuitColor.red;
    final color = isRed ? AppTheme.suitRed : AppTheme.mintSoft;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: color.withValues(alpha: 0.4)),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                suit.label,
                style: TextStyle(
                  color: color,
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(width: 5),
              Text(
                suit.arabicName,
                style: GoogleFonts.cairo(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 11.5,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 3),
        Text(
          subtitle,
          style: GoogleFonts.cairo(
            color: Colors.white54,
            fontSize: 10,
          ),
        ),
      ],
    );
  }

  Widget _buildRoundTypeRow({
    required String title,
    required Color color,
    required String description,
  }) {
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.25)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: GoogleFonts.cairo(
              color: color,
              fontWeight: FontWeight.bold,
              fontSize: 12.5,
            ),
          ),
          const SizedBox(height: 3),
          Text(
            description,
            style: GoogleFonts.cairo(
              color: Colors.white.withValues(alpha: 0.8),
              fontSize: 11.5,
              height: 1.4,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildExampleRow({
    required String round,
    required String role,
    required int declared,
    required int actual,
    required String resultText,
    required bool isSuccess,
  }) {
    final statusColor = isSuccess ? const Color(0xFF4CAF50) : AppTheme.playerRed;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.25),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: statusColor.withValues(alpha: 0.3)),
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final isNarrow = constraints.maxWidth < 420;
          if (isNarrow) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                      decoration: BoxDecoration(
                        color: statusColor.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        isSuccess ? 'نجاح ✅' : 'فشل ❌',
                        style: GoogleFonts.cairo(
                          color: statusColor,
                          fontWeight: FontWeight.bold,
                          fontSize: 10.5,
                        ),
                      ),
                    ),
                    Text(
                      resultText,
                      style: GoogleFonts.cairo(
                        color: statusColor,
                        fontWeight: FontWeight.bold,
                        fontSize: 11,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  '$round • $role (طلب $declared / حقق $actual)',
                  style: GoogleFonts.cairo(color: Colors.white70, fontSize: 11),
                ),
              ],
            );
          }

          return Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                decoration: BoxDecoration(
                  color: statusColor.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  isSuccess ? 'نجاح ✅' : 'فشل ❌',
                  style: GoogleFonts.cairo(
                    color: statusColor,
                    fontWeight: FontWeight.bold,
                    fontSize: 10.5,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  '$round • $role (طلب $declared / حقق $actual)',
                  style: GoogleFonts.cairo(color: Colors.white70, fontSize: 11),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(width: 6),
              Text(
                resultText,
                style: GoogleFonts.cairo(
                  color: statusColor,
                  fontWeight: FontWeight.bold,
                  fontSize: 11,
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _GuideCategory {
  final String title;
  final AppIconData icon;

  const _GuideCategory({required this.title, required this.icon});
}
