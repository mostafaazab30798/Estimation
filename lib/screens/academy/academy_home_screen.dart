// lib/screens/academy/academy_home_screen.dart

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../models/academy_models.dart';
import '../../services/academy_service.dart';
import '../../theme/app_theme.dart';
import '../../core/widgets/app_buttons.dart';
import 'academy_lesson_screen.dart';
import 'package:estimation/core/icons/app_icons.dart';

class AcademyHomeScreen extends StatefulWidget {
  const AcademyHomeScreen({super.key});

  @override
  State<AcademyHomeScreen> createState() => _AcademyHomeScreenState();
}

class _AcademyHomeScreenState extends State<AcademyHomeScreen> {
  final AcademyService _service = AcademyService.instance;
  int _selectedFilter = 0; // 0 = All, 1 = In Progress, 2 = Completed
  String? _expandedTopicId;

  @override
  void initState() {
    super.initState();
    _service.initialize().then((_) {
      if (mounted) setState(() {});
    });
  }

  void _openLesson(AcademyLesson lesson) async {
    HapticFeedback.lightImpact();
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => AcademyLessonScreen(lessonId: lesson.id),
      ),
    );
    if (mounted) setState(() {});
  }

  void _resumeNextLesson(AcademyProgress progress) {
    final nextLesson = _service.getNextUnfinishedLesson();
    if (nextLesson != null) {
      _openLesson(nextLesson);
    } else if (_service.topics.isNotEmpty && _service.topics.first.lessons.isNotEmpty) {
      _openLesson(_service.topics.first.lessons.first);
    }
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<AcademyProgress>(
      valueListenable: _service.progressNotifier,
      builder: (context, progress, _) {
        final totalLessons = _service.totalLessonsCount;
        final completedCount = progress.completedLessonIds.length;
        final masteryPercentage = progress.getOverallMastery(totalLessons);
        final masteryTier = progress.getMasteryTier(totalLessons);

        final topics = _filterTopics(_service.topics, progress);

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

              // Gradient Darkness Overlay
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

              // Main Content
              SafeArea(
                child: Column(
                  children: [
                    // Top App Bar
                    _buildTopBar(context, progress),

                    // Scrollable Curriculum List
                    Expanded(
                      child: SingleChildScrollView(
                        physics: const BouncingScrollPhysics(),
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                        child: Center(
                          child: ConstrainedBox(
                            constraints: const BoxConstraints(maxWidth: 800),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                // Hero Mastery Banner
                                _buildMasteryHeroCard(
                                  progress,
                                  masteryTier,
                                  masteryPercentage,
                                  completedCount,
                                  totalLessons,
                                ),

                                const SizedBox(height: 14),

                                // Filter Chips
                                _buildFilterChips(),

                                const SizedBox(height: 12),

                                // Topic List
                                for (final topic in topics) ...[
                                  _buildTopicCard(topic, progress),
                                  const SizedBox(height: 12),
                                ],

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
      },
    );
  }

  List<AcademyTopic> _filterTopics(List<AcademyTopic> allTopics, AcademyProgress progress) {
    if (_selectedFilter == 1) {
      // In Progress / Incomplete
      return allTopics.where((t) {
        final p = progress.getTopicProgress(t);
        return p < 1.0;
      }).toList();
    } else if (_selectedFilter == 2) {
      // Completed
      return allTopics.where((t) {
        final p = progress.getTopicProgress(t);
        return p >= 1.0;
      }).toList();
    }
    return allTopics;
  }

  // ── Top Bar ────────────────────────────────────────────────────────────────

  Widget _buildTopBar(BuildContext context, AcademyProgress progress) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          // Back Button
          AppIconCapsule(
            icon: AppIcons.arrowBackIosNew,
            label: 'رجوع',
            accent: AppTheme.gold,
            dense: true,
            onTap: () {
              Navigator.pop(context);
            },
          ),

          // Title & Badge
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'أكاديمية الإستميشن',
                style: GoogleFonts.cairo(
                  fontSize: 17,
                  fontWeight: FontWeight.w900,
                  color: AppTheme.white,
                ),
              ),
              const SizedBox(width: 6),
              const Text('🧠', style: TextStyle(fontSize: 16)),
            ],
          ),

          // XP Badge & Sound Toggle
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: AppTheme.gold.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                    color: AppTheme.gold.withValues(alpha: 0.4),
                    width: 0.8,
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text('⭐', style: TextStyle(fontSize: 11)),
                    const SizedBox(width: 4),
                    Text(
                      '${progress.totalXpEarned} XP',
                      style: GoogleFonts.cairo(
                        color: AppTheme.gold,
                        fontSize: 11.5,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ── Hero Mastery Card ──────────────────────────────────────────────────────

  Widget _buildMasteryHeroCard(
    AcademyProgress progress,
    AcademyMasteryTier tier,
    double masteryPercentage,
    int completedCount,
    int totalLessons,
  ) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            tier.color.withValues(alpha: 0.25),
            const Color(0xFF1E1B4B).withValues(alpha: 0.9),
            AppTheme.navyDark.withValues(alpha: 0.95),
          ],
        ),
        border: Border.all(
          color: tier.color.withValues(alpha: 0.5),
          width: 1.2,
        ),
        boxShadow: [
          BoxShadow(
            color: tier.color.withValues(alpha: 0.2),
            blurRadius: 16,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              // Tier Badge Circle
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: tier.color.withValues(alpha: 0.2),
                  border: Border.all(color: tier.color, width: 1.5),
                ),
                alignment: Alignment.center,
                child: Text(
                  tier.badge,
                  style: const TextStyle(fontSize: 22),
                ),
              ),
              const SizedBox(width: 12),

              // Title and Tier
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'مستوى الإتقان الأكاديمي',
                      style: GoogleFonts.cairo(
                        fontSize: 11,
                        color: AppTheme.steelBlue,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    Text(
                      tier.title,
                      style: GoogleFonts.cairo(
                        fontSize: 17,
                        fontWeight: FontWeight.w900,
                        color: tier.color,
                        height: 1.1,
                      ),
                    ),
                  ],
                ),
              ),

              // Percentage Tag
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.white12),
                ),
                child: Text(
                  '${(masteryPercentage * 100).toInt()}%',
                  style: GoogleFonts.cairo(
                    color: AppTheme.white,
                    fontSize: 14,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
            ],
          ),

          const SizedBox(height: 14),

          // Animated Progress Bar
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: LinearProgressIndicator(
              value: masteryPercentage,
              minHeight: 8,
              backgroundColor: Colors.white.withValues(alpha: 0.1),
              valueColor: AlwaysStoppedAnimation<Color>(tier.color),
            ),
          ),

          const SizedBox(height: 14),

          // Action Row
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              // Lessons count badge
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const AppIcon(
                    AppIcons.checkCircleOutline,
                    color: AppTheme.gold,
                    size: 16,
                  ),
                  const SizedBox(width: 6),
                  Text(
                    '$completedCount من أصل $totalLessons درس مكتمل',
                    style: GoogleFonts.cairo(
                      color: AppTheme.cream,
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),

              // Resume Button
              ElevatedButton.icon(
                onPressed: () => _resumeNextLesson(progress),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.gold,
                  foregroundColor: Colors.black,
                  elevation: 4,
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
                icon: const AppIcon(AppIcons.playArrow, size: 18),
                label: Text(
                  completedCount == totalLessons ? 'مراجعة الدروس 🔄' : 'استئناف ⚡',
                  style: GoogleFonts.cairo(
                    fontWeight: FontWeight.w900,
                    fontSize: 12,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ── Filter Chips ───────────────────────────────────────────────────────────

  Widget _buildFilterChips() {
    final filters = ['جميع المواضيع', 'قيد التقدم ⏳', 'المكتملة ✅'];
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          for (int i = 0; i < filters.length; i++) ...[
            if (i > 0) const SizedBox(width: 8),
            ChoiceChip(
              label: Text(filters[i]),
              labelStyle: GoogleFonts.cairo(
                fontSize: 11.5,
                fontWeight: FontWeight.bold,
                color: _selectedFilter == i ? Colors.black : AppTheme.cream,
              ),
              selected: _selectedFilter == i,
              selectedColor: AppTheme.gold,
              backgroundColor: AppTheme.navyDark.withValues(alpha: 0.8),
              side: BorderSide(
                color: _selectedFilter == i
                    ? AppTheme.gold
                    : Colors.white.withValues(alpha: 0.12),
              ),
              onSelected: (selected) {
                if (selected) {
                  HapticFeedback.selectionClick();
                  setState(() => _selectedFilter = i);
                }
              },
            ),
          ],
        ],
      ),
    );
  }

  // ── Topic Card ─────────────────────────────────────────────────────────────

  Widget _buildTopicCard(AcademyTopic topic, AcademyProgress progress) {
    final topicProgress = progress.getTopicProgress(topic);
    final isCompleted = topicProgress >= 1.0;
    final isExpanded = _expandedTopicId == topic.id;

    return Container(
      decoration: BoxDecoration(
        color: AppTheme.navyDark.withValues(alpha: 0.85),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: isCompleted
              ? AppTheme.gold.withValues(alpha: 0.6)
              : topic.accentColor.withValues(alpha: 0.35),
          width: isCompleted ? 1.4 : 1.0,
        ),
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
          // Topic Header (Tap to expand/collapse)
          InkWell(
            onTap: () {
              HapticFeedback.selectionClick();
              setState(() {
                _expandedTopicId = isExpanded ? null : topic.id;
              });
            },
            borderRadius: BorderRadius.circular(18),
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Row(
                children: [
                  // Icon Emblem
                  Container(
                    width: 42,
                    height: 42,
                    decoration: BoxDecoration(
                      color: topic.accentColor.withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: topic.accentColor.withValues(alpha: 0.5),
                      ),
                    ),
                    alignment: Alignment.center,
                    child: Text(
                      topic.icon,
                      style: const TextStyle(fontSize: 20),
                    ),
                  ),
                  const SizedBox(width: 12),

                  // Topic Title & Subtitle
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Flexible(
                              child: Text(
                                topic.title,
                                style: GoogleFonts.cairo(
                                  fontSize: 15,
                                  fontWeight: FontWeight.w900,
                                  color: AppTheme.white,
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            if (isCompleted) ...[
                              const SizedBox(width: 6),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 6, vertical: 1),
                                decoration: BoxDecoration(
                                  color: AppTheme.gold.withValues(alpha: 0.2),
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: Text(
                                  'مكتمل ⭐',
                                  style: GoogleFonts.cairo(
                                    color: AppTheme.gold,
                                    fontSize: 9.5,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                            ],
                          ],
                        ),
                        const SizedBox(height: 2),
                        Text(
                          topic.subtitle,
                          style: GoogleFonts.cairo(
                            fontSize: 11,
                            color: AppTheme.steelBlue,
                            fontWeight: FontWeight.w500,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),

                  // Topic Completion Gauge & Chevron
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        '${(topicProgress * topic.lessons.length).toInt()}/${topic.lessons.length}',
                        style: GoogleFonts.cairo(
                          color: isCompleted ? AppTheme.gold : AppTheme.cream,
                          fontSize: 11.5,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      AppIcon(
                        isExpanded
                            ? AppIcons.keyboardArrowUp
                            : AppIcons.keyboardArrowDown,
                        color: AppTheme.steelBlue,
                        size: 20,
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),

          // Topic Progress Bar
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(
                value: topicProgress,
                minHeight: 4,
                backgroundColor: Colors.white.withValues(alpha: 0.06),
                valueColor: AlwaysStoppedAnimation<Color>(
                  isCompleted ? AppTheme.gold : topic.accentColor,
                ),
              ),
            ),
          ),

          // Expanded Lessons Section
          if (isExpanded) ...[
            const SizedBox(height: 10),
            const Divider(color: Colors.white10, height: 1),
            for (final lesson in topic.lessons)
              _buildLessonTile(lesson, topic, progress),
          ] else ...[
            const SizedBox(height: 8),
          ],
        ],
      ),
    );
  }

  // ── Lesson Tile ────────────────────────────────────────────────────────────

  Widget _buildLessonTile(
    AcademyLesson lesson,
    AcademyTopic topic,
    AcademyProgress progress,
  ) {
    final isDone = progress.isLessonCompleted(lesson.id);

    return InkWell(
      onTap: () => _openLesson(lesson),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          border: Border(
            bottom: BorderSide(color: Colors.white.withValues(alpha: 0.05)),
          ),
        ),
        child: Row(
          children: [
            // Status Icon Circle
            Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: isDone
                    ? AppTheme.gold.withValues(alpha: 0.2)
                    : Colors.white.withValues(alpha: 0.06),
                border: Border.all(
                  color: isDone
                      ? AppTheme.gold
                      : Colors.white.withValues(alpha: 0.15),
                ),
              ),
              alignment: Alignment.center,
              child: AppIcon(
                isDone ? AppIcons.checkRounded : AppIcons.playArrow,
                color: isDone ? AppTheme.gold : AppTheme.cream,
                size: 16,
              ),
            ),
            const SizedBox(width: 12),

            // Lesson Title & Duration
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    lesson.title,
                    style: GoogleFonts.cairo(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: isDone ? AppTheme.white : AppTheme.cream,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Row(
                    children: [
                      // Difficulty chip
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 6, vertical: 1),
                        decoration: BoxDecoration(
                          color: lesson.difficulty.color.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          lesson.difficulty.arabicLabel,
                          style: GoogleFonts.cairo(
                            color: lesson.difficulty.color,
                            fontSize: 9.5,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      const SizedBox(width: 6),
                      Text(
                        '⏱️ ${lesson.estimatedDuration}',
                        style: GoogleFonts.cairo(
                          color: AppTheme.steelBlue,
                          fontSize: 10,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),

            // XP Reward Pill
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.04),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: Colors.white12),
              ),
              child: Text(
                '+${lesson.xpReward} XP',
                style: GoogleFonts.cairo(
                  fontSize: 11,
                  fontWeight: FontWeight.w800,
                  color: AppTheme.goldLight,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
