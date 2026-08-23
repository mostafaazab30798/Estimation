// lib/screens/academy/academy_lesson_screen.dart

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../models/academy_models.dart';
import '../../core/constants.dart';
import '../../core/models/card.dart';
import '../../services/academy_service.dart';
import '../../services/audio_service.dart';
import '../../theme/app_theme.dart';
import '../../widgets/playing_card_widget.dart';

class AcademyLessonScreen extends StatefulWidget {
  final String lessonId;

  const AcademyLessonScreen({
    super.key,
    required this.lessonId,
  });

  @override
  State<AcademyLessonScreen> createState() => _AcademyLessonScreenState();
}

class _AcademyLessonScreenState extends State<AcademyLessonScreen> {
  final AcademyService _service = AcademyService.instance;
  late String _currentLessonId;

  AcademyLesson? _lesson;
  AcademyTopic? _topic;

  String? _selectedOptionId;
  bool _isSubmitted = false;
  bool _isEvaluating = false;

  @override
  void initState() {
    super.initState();
    _currentLessonId = widget.lessonId;
    _loadLesson();
  }

  void _loadLesson() {
    final result = _service.getLessonWithTopic(_currentLessonId);
    if (result != null) {
      setState(() {
        _lesson = result.lesson;
        _topic = result.topic;
        _selectedOptionId = null;
        _isSubmitted = false;
        _isEvaluating = false;
      });
    }
  }

  void _onSelectOption(AcademyScenarioOption option) async {
    if (_isEvaluating || _isSubmitted) return;

    HapticFeedback.selectionClick();
    AudioService.instance.playCard();

    setState(() {
      _selectedOptionId = option.id;
      _isEvaluating = true;
    });

    await Future.delayed(const Duration(milliseconds: 300));
    if (!mounted) return;

    final isAcceptable = await _service.submitAnswer(
      lesson: _lesson!,
      option: option,
    );

    if (isAcceptable) {
      HapticFeedback.heavyImpact();
      AudioService.instance.playWin();
    } else {
      HapticFeedback.mediumImpact();
    }

    if (mounted) {
      setState(() {
        _isEvaluating = false;
        _isSubmitted = true;
      });
    }
  }

  void _goToNextLesson() {
    if (_lesson == null || _topic == null) return;

    final lessonsInTopic = _topic!.lessons;
    final currentIndex = lessonsInTopic.indexWhere((l) => l.id == _currentLessonId);

    if (currentIndex >= 0 && currentIndex < lessonsInTopic.length - 1) {
      // Next lesson in current topic
      setState(() {
        _currentLessonId = lessonsInTopic[currentIndex + 1].id;
        _loadLesson();
      });
    } else {
      // Find next lesson across all topics
      final allTopics = _service.topics;
      final topicIndex = allTopics.indexWhere((t) => t.id == _topic!.id);
      if (topicIndex >= 0 && topicIndex < allTopics.length - 1) {
        final nextTopic = allTopics[topicIndex + 1];
        if (nextTopic.lessons.isNotEmpty) {
          setState(() {
            _currentLessonId = nextTopic.lessons.first.id;
            _loadLesson();
          });
          return;
        }
      }
      Navigator.pop(context);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_lesson == null || _topic == null) {
      return Scaffold(
        backgroundColor: AppTheme.deepNavy,
        body: const Center(child: CircularProgressIndicator(color: AppTheme.gold)),
      );
    }

    final lesson = _lesson!;
    final topic = _topic!;
    final scenario = lesson.scenario;
    final isPortrait = MediaQuery.of(context).size.width < 700;

    return Scaffold(
      backgroundColor: AppTheme.deepNavy,
      body: Stack(
        fit: StackFit.expand,
        children: [
          // Background Wallpaper
          Positioned.fill(
            child: Image.asset(
              'assets/wallpapers/w1.jpg',
              fit: BoxFit.cover,
              errorBuilder: (_, __, ___) => Container(
                decoration: const BoxDecoration(gradient: AppTheme.bgGradient),
              ),
            ),
          ),

          // Gradient Tint
          Positioned.fill(
            child: Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Colors.black.withValues(alpha: 0.70),
                    AppTheme.deepNavy.withValues(alpha: 0.90),
                    AppTheme.deepNavy.withValues(alpha: 0.98),
                  ],
                ),
              ),
            ),
          ),

          // Main SafeArea
          SafeArea(
            child: Column(
              children: [
                // Top Header
                _buildHeader(topic, lesson),

                // Scrollable Content
                Expanded(
                  child: SingleChildScrollView(
                    physics: const BouncingScrollPhysics(),
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    child: Center(
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 860),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            // ── Section 1: Theory & Concepts ─────────────────
                            _buildTheoryCard(lesson),

                            const SizedBox(height: 16),

                            // ── Section 2: Interactive Simulator ────────────
                            _buildSimulatorCard(scenario, isPortrait),

                            const SizedBox(height: 16),

                            // ── Section 3: Feedback & Explanation ───────────
                            if (_isSubmitted) _buildFeedbackCard(scenario, lesson),

                            const SizedBox(height: 24),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ── Header ─────────────────────────────────────────────────────────────────

  Widget _buildHeader(AcademyTopic topic, AcademyLesson lesson) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          // Back Button
          InkWell(
            onTap: () {
              HapticFeedback.lightImpact();
              AudioService.instance.playCard();
              Navigator.pop(context);
            },
            borderRadius: BorderRadius.circular(20),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: AppTheme.navyDark.withValues(alpha: 0.8),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: AppTheme.gold.withValues(alpha: 0.35),
                  width: 1,
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(
                    Icons.arrow_back_ios_new_rounded,
                    color: AppTheme.gold,
                    size: 14,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    'المواضيع',
                    style: GoogleFonts.cairo(
                      color: AppTheme.goldLight,
                      fontWeight: FontWeight.bold,
                      fontSize: 11.5,
                    ),
                  ),
                ],
              ),
            ),
          ),

          // Topic / Lesson Title
          Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Text(
                    '${topic.icon} ${topic.title}',
                    style: GoogleFonts.cairo(
                      fontSize: 11,
                      color: topic.accentColor,
                      fontWeight: FontWeight.bold,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  Text(
                    lesson.title,
                    style: GoogleFonts.cairo(
                      fontSize: 14,
                      fontWeight: FontWeight.w900,
                      color: AppTheme.white,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
          ),

          // Difficulty Badge
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(
              color: lesson.difficulty.color.withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                color: lesson.difficulty.color.withValues(alpha: 0.6),
                width: 0.8,
              ),
            ),
            child: Text(
              lesson.difficulty.arabicLabel,
              style: GoogleFonts.cairo(
                color: lesson.difficulty.color,
                fontSize: 10,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ── Theory Card ────────────────────────────────────────────────────────────

  Widget _buildTheoryCard(AcademyLesson lesson) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.navyDark.withValues(alpha: 0.85),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.3),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              const Text('📖', style: TextStyle(fontSize: 18)),
              const SizedBox(width: 8),
              Text(
                'الشرح والنظرية التكتيكية',
                style: GoogleFonts.cairo(
                  fontSize: 15,
                  fontWeight: FontWeight.w900,
                  color: AppTheme.goldLight,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            lesson.theoryExplanation,
            style: GoogleFonts.cairo(
              fontSize: 13,
              color: AppTheme.cream,
              height: 1.5,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 12),

          // Key Concepts list
          for (final concept in lesson.concepts) ...[
            Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('🔹', style: TextStyle(fontSize: 10)),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      concept,
                      style: GoogleFonts.cairo(
                        fontSize: 12,
                        color: AppTheme.steelBlue,
                        height: 1.35,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],

          const SizedBox(height: 10),

          // Pro-Tip Box
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: AppTheme.gold.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: AppTheme.gold.withValues(alpha: 0.4),
                width: 0.8,
              ),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('💡', style: TextStyle(fontSize: 16)),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    lesson.proTip,
                    style: GoogleFonts.cairo(
                      color: AppTheme.goldLight,
                      fontSize: 11.5,
                      fontWeight: FontWeight.w600,
                      height: 1.3,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ── Simulator Card ─────────────────────────────────────────────────────────

  Widget _buildSimulatorCard(AcademyScenario scenario, bool isPortrait) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            const Color(0xFF1E1B4B).withValues(alpha: 0.95),
            AppTheme.navyDark.withValues(alpha: 0.98),
          ],
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: AppTheme.gold.withValues(alpha: 0.4),
          width: 1.2,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.4),
            blurRadius: 14,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Simulator Title & Scenario Type Pill
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  const Text('🃏', style: TextStyle(fontSize: 18)),
                  const SizedBox(width: 8),
                  Text(
                    'المحاكاة التفاعلية لليد',
                    style: GoogleFonts.cairo(
                      fontSize: 15,
                      fontWeight: FontWeight.w900,
                      color: AppTheme.white,
                    ),
                  ),
                ],
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: AppTheme.accentBlue.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: AppTheme.accentBlue.withValues(alpha: 0.5),
                    width: 0.8,
                  ),
                ),
                child: Text(
                  scenario.type.arabicTitle,
                  style: GoogleFonts.cairo(
                    color: AppTheme.accentBlue,
                    fontSize: 10.5,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),

          const SizedBox(height: 12),

          // Context HUD Bar
          _buildContextHud(scenario.context),

          const SizedBox(height: 14),

          // Player Hand View (Cards)
          Text(
            'ورق يدك (Hand):',
            style: GoogleFonts.cairo(
              color: AppTheme.goldLight,
              fontSize: 12,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 6),
          _buildHandView(scenario.hand, isPortrait),

          const SizedBox(height: 16),

          // Scenario Prompt
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(
              color: Colors.black.withValues(alpha: 0.35),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.white12),
            ),
            child: Row(
              children: [
                const Text('❓', style: TextStyle(fontSize: 16)),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    scenario.prompt,
                    style: GoogleFonts.cairo(
                      color: AppTheme.white,
                      fontSize: 13,
                      fontWeight: FontWeight.w800,
                      height: 1.3,
                    ),
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 14),

          // Interactive Option Buttons
          for (final option in scenario.options) ...[
            _buildOptionButton(option),
            const SizedBox(height: 8),
          ],
        ],
      ),
    );
  }

  // ── Context HUD ────────────────────────────────────────────────────────────

  Widget _buildContextHud(AcademyScenarioContext ctx) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.04),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
      ),
      child: Wrap(
        spacing: 12,
        runSpacing: 6,
        children: [
          _buildHudItem('الجولة', '${ctx.roundNumber}/${ctx.totalRounds}'),
          if (ctx.trump != null)
            _buildHudItem(
              'القطوع',
              '${ctx.trump!.label} ${ctx.trump!.arabicName}',
              color: ctx.trump!.color == SuitColor.red
                  ? AppTheme.suitRed
                  : (ctx.trump!.isSans ? AppTheme.gold : AppTheme.cream),
            )
          else
            _buildHudItem('القطوع', 'لم يحدد بعد'),
          _buildHudItem('موقعك', ctx.playerPosition),
          if (ctx.highBidInfo != null)
            _buildHudItem('المزاد', ctx.highBidInfo!, color: AppTheme.goldLight),
          if (ctx.otherBidsInfo != null)
            _buildHudItem('الطلبات', ctx.otherBidsInfo!),
          if (ctx.scoreSituation != null)
            _buildHudItem('النتيجة', ctx.scoreSituation!, color: Colors.orangeAccent),
        ],
      ),
    );
  }

  Widget _buildHudItem(String label, String value, {Color? color}) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          '$label: ',
          style: GoogleFonts.cairo(
            color: AppTheme.steelBlue,
            fontSize: 11,
            fontWeight: FontWeight.w500,
          ),
        ),
        Text(
          value,
          style: GoogleFonts.cairo(
            color: color ?? AppTheme.cream,
            fontSize: 11,
            fontWeight: FontWeight.bold,
          ),
        ),
      ],
    );
  }

  // ── Hand View ──────────────────────────────────────────────────────────────

  Widget _buildHandView(List<PlayingCard> hand, bool isPortrait) {
    final cardWidth = isPortrait ? 52.0 : 64.0;
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      physics: const BouncingScrollPhysics(),
      child: Row(
        children: [
          for (int i = 0; i < hand.length; i++) ...[
            Padding(
              padding: const EdgeInsets.only(right: 6),
              child: PlayingCardWidget(
                card: hand[i],
                width: cardWidth,
                playable: false,
              ),
            ),
          ],
        ],
      ),
    );
  }

  // ── Option Button ──────────────────────────────────────────────────────────

  Widget _buildOptionButton(AcademyScenarioOption option) {
    final isSelected = _selectedOptionId == option.id;

    Color borderColor = Colors.white12;
    Color bgColor = Colors.white.withValues(alpha: 0.05);

    if (_isSubmitted) {
      if (option.isOptimal) {
        borderColor = const Color(0xFF10B981);
        bgColor = const Color(0xFF10B981).withValues(alpha: 0.2);
      } else if (isSelected && !option.isOptimal) {
        borderColor = option.quality.color;
        bgColor = option.quality.color.withValues(alpha: 0.2);
      }
    } else if (isSelected) {
      borderColor = AppTheme.gold;
      bgColor = AppTheme.gold.withValues(alpha: 0.15);
    }

    return InkWell(
      onTap: () => _onSelectOption(option),
      borderRadius: BorderRadius.circular(12),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: bgColor,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: borderColor, width: isSelected ? 1.5 : 1.0),
        ),
        child: Row(
          children: [
            // Option Indicator Circle
            Container(
              width: 24,
              height: 24,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: isSelected
                    ? AppTheme.gold
                    : Colors.white.withValues(alpha: 0.1),
                border: Border.all(
                  color: isSelected ? AppTheme.gold : Colors.white24,
                ),
              ),
              alignment: Alignment.center,
              child: _isSubmitted && option.isOptimal
                  ? const Icon(Icons.check_rounded, color: Colors.black, size: 16)
                  : (_isSubmitted && isSelected && !option.isOptimal
                      ? const Icon(Icons.close_rounded, color: Colors.black, size: 16)
                      : (isSelected
                          ? const Icon(Icons.circle, color: Colors.black, size: 10)
                          : null)),
            ),
            const SizedBox(width: 12),

            // Option Label
            Expanded(
              child: Text(
                option.label,
                style: GoogleFonts.cairo(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: isSelected ? AppTheme.white : AppTheme.cream,
                ),
              ),
            ),

            if (_isSubmitted)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: option.quality.color.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: option.quality.color),
                ),
                child: Text(
                  option.quality.arabicLabel,
                  style: GoogleFonts.cairo(
                    color: option.quality.color,
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  // ── Feedback & Explanation Card ────────────────────────────────────────────

  Widget _buildFeedbackCard(AcademyScenario scenario, AcademyLesson lesson) {
    final chosenOption = scenario.options.firstWhere(
      (o) => o.id == _selectedOptionId,
      orElse: () => scenario.options.first,
    );
    final isSuccess = chosenOption.isAcceptable;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.navyDark.withValues(alpha: 0.95),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: chosenOption.quality.color,
          width: 1.4,
        ),
        boxShadow: [
          BoxShadow(
            color: chosenOption.quality.color.withValues(alpha: 0.25),
            blurRadius: 16,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Header Status
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Icon(
                    isSuccess ? Icons.stars_rounded : Icons.info_outline_rounded,
                    color: chosenOption.quality.color,
                    size: 24,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    chosenOption.quality.arabicLabel,
                    style: GoogleFonts.cairo(
                      fontSize: 16,
                      fontWeight: FontWeight.w900,
                      color: chosenOption.quality.color,
                    ),
                  ),
                ],
              ),
              if (isSuccess)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: AppTheme.gold.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: AppTheme.gold),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Text('⭐', style: TextStyle(fontSize: 11)),
                      const SizedBox(width: 4),
                      Text(
                        '+${lesson.xpReward} XP',
                        style: GoogleFonts.cairo(
                          color: AppTheme.gold,
                          fontWeight: FontWeight.w900,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          ),

          const SizedBox(height: 10),

          // Chosen Option Feedback
          Text(
            chosenOption.feedback,
            style: GoogleFonts.cairo(
              fontSize: 13,
              color: AppTheme.white,
              fontWeight: FontWeight.w600,
              height: 1.4,
            ),
          ),

          const SizedBox(height: 12),

          // Tactical Rationale
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.05),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.white12),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Text('🧠', style: TextStyle(fontSize: 14)),
                    const SizedBox(width: 6),
                    Text(
                      'التحليل والتفسير التكتيكي:',
                      style: GoogleFonts.cairo(
                        color: AppTheme.goldLight,
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  scenario.tacticalRationale,
                  style: GoogleFonts.cairo(
                    color: AppTheme.cream,
                    fontSize: 12,
                    height: 1.4,
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 16),

          // Action Buttons: Next Lesson or Retry
          Row(
            children: [
              if (!chosenOption.isOptimal)
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () {
                      HapticFeedback.lightImpact();
                      setState(() {
                        _selectedOptionId = null;
                        _isSubmitted = false;
                      });
                    },
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppTheme.cream,
                      side: const BorderSide(color: Colors.white24),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                    ),
                    icon: const Icon(Icons.refresh_rounded, size: 18),
                    label: Text(
                      'إعادة المحاولة',
                      style: GoogleFonts.cairo(
                        fontWeight: FontWeight.bold,
                        fontSize: 13,
                      ),
                    ),
                  ),
                ),
              if (!chosenOption.isOptimal) const SizedBox(width: 10),
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: _goToNextLesson,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.gold,
                    foregroundColor: Colors.black,
                    elevation: 4,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                  icon: const Icon(Icons.arrow_forward_rounded, size: 18),
                  label: Text(
                    'الدرس التالي ➡️',
                    style: GoogleFonts.cairo(
                      fontWeight: FontWeight.w900,
                      fontSize: 13,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
