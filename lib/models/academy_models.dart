// lib/models/academy_models.dart

import 'package:flutter/material.dart';
import '../core/constants.dart';
import '../core/models/card.dart';

/// Difficulty level of a lesson or puzzle
enum AcademyDifficulty {
  beginner(
    arabicLabel: 'مبتدئ ⭐',
    color: Color(0xFF10B981),
    xpReward: 30,
  ),
  intermediate(
    arabicLabel: 'متوسط ⭐⭐',
    color: Color(0xFF3B82F6),
    xpReward: 50,
  ),
  advanced(
    arabicLabel: 'متقدم ⭐⭐⭐',
    color: Color(0xFFF59E0B),
    xpReward: 75,
  ),
  expert(
    arabicLabel: 'خبير ⭐⭐⭐⭐',
    color: Color(0xFF8B5CF6),
    xpReward: 100,
  ),
  master(
    arabicLabel: 'أستاذ ⭐⭐⭐⭐⭐',
    color: Color(0xFFEF4444),
    xpReward: 150,
  );

  const AcademyDifficulty({
    required this.arabicLabel,
    required this.color,
    required this.xpReward,
  });

  final String arabicLabel;
  final Color color;
  final int xpReward;
}

/// Overall mastery tier in the Estimation Academy
enum AcademyMasteryTier {
  notStarted(
    title: 'لم تبدأ بعد',
    badge: '🌱',
    minPercentage: 0.0,
    color: Color(0xFF94A3B8),
  ),
  learning(
    title: 'قيد التعلم',
    badge: '📚',
    minPercentage: 0.15,
    color: Color(0xFF38BDF8),
  ),
  practicing(
    title: 'متمرس بالتدريب',
    badge: '⚔️',
    minPercentage: 0.40,
    color: Color(0xFF34D399),
  ),
  proficient(
    title: 'محترف الإستميشن',
    badge: '🎯',
    minPercentage: 0.70,
    color: Color(0xFFFBBF24),
  ),
  mastered(
    title: 'أستاذ اللعبة (Grandmaster)',
    badge: '👑',
    minPercentage: 0.95,
    color: Color(0xFFA855F7),
  );

  const AcademyMasteryTier({
    required this.title,
    required this.badge,
    required this.minPercentage,
    required this.color,
  });

  final String title;
  final String badge;
  final double minPercentage;
  final Color color;

  static AcademyMasteryTier fromPercentage(double ratio) {
    if (ratio >= 0.95) return AcademyMasteryTier.mastered;
    if (ratio >= 0.70) return AcademyMasteryTier.proficient;
    if (ratio >= 0.40) return AcademyMasteryTier.practicing;
    if (ratio >= 0.15) return AcademyMasteryTier.learning;
    return AcademyMasteryTier.notStarted;
  }
}

/// Category / type of interactive decision in a scenario
enum AcademyScenarioType {
  bid('مزايدة المزاد', 'ما هي المزايدة الأنسب بيدك؟'),
  declaration('إعلان الرقم المطلوب (الكول)', 'كم أكلة (Trick) يجب أن تطلب؟'),
  playCard('لعب ورقة تكتيكية', 'أي ورقة تختار للنزول بها؟'),
  dashCall('قرار الداش كول', 'هل تطلب داش كول (0 أكلات)؟'),
  risk('قرار الريسك', 'هل من المناسب طلب ريسك لمضاعفة النقاط؟'),
  scoreDecision('استراتيجية النقاط والترتيب', 'ما هو القرار الأنسب لترتيبك الحالي؟');

  const AcademyScenarioType(this.arabicTitle, this.defaultPrompt);
  final String arabicTitle;
  final String defaultPrompt;
}

/// Evaluation quality for an answer in interactive scenario
enum AnswerQuality {
  optimal('أداء مثالي 🎯', Color(0xFF10B981)),
  strong('خيار جيد 💡', Color(0xFF3B82F6)),
  risky('مخاطرة عالية ⚠️', Color(0xFFF59E0B)),
  invalid('خاطئ أو غير قانوني ❌', Color(0xFFEF4444));

  const AnswerQuality(this.arabicLabel, this.color);
  final String arabicLabel;
  final Color color;
}

/// An interactive option presented to the user
class AcademyScenarioOption {
  final String id;
  final String label;
  final AnswerQuality quality;
  final String feedback;
  final PlayingCard? cardToPlay;

  const AcademyScenarioOption({
    required this.id,
    required this.label,
    required this.quality,
    required this.feedback,
    this.cardToPlay,
  });

  bool get isOptimal => quality == AnswerQuality.optimal;
  bool get isAcceptable => quality == AnswerQuality.optimal || quality == AnswerQuality.strong;
}

/// Context of the game state for the interactive simulator
class AcademyScenarioContext {
  final int roundNumber;
  final int totalRounds;
  final Trump? trump;
  final String playerPosition; // e.g. 'الموزع (Dealer)', 'أول لاعب بعد الموزع', etc.
  final String? highBidInfo; // e.g. 'أعلى مزايدة حالية: 6 سبيد'
  final String? otherBidsInfo; // e.g. 'اللاعبون طلبوا: 3، 4، 3'
  final List<TrickCard>? currentTrickCards; // cards already played on table in this trick
  final String? scoreSituation; // e.g. 'أنت متأخر بـ 20 نقطة عن المتصدر'

  const AcademyScenarioContext({
    this.roundNumber = 1,
    this.totalRounds = 18,
    this.trump,
    this.playerPosition = 'اللاعب الأول',
    this.highBidInfo,
    this.otherBidsInfo,
    this.currentTrickCards,
    this.scoreSituation,
  });
}

/// Interactive Scenario attached to a lesson
class AcademyScenario {
  final String id;
  final AcademyScenarioType type;
  final List<PlayingCard> hand;
  final AcademyScenarioContext context;
  final String prompt;
  final List<AcademyScenarioOption> options;
  final String optimalOptionId;
  final String tacticalRationale;
  final int expectedTricksMin;
  final int expectedTricksMax;

  const AcademyScenario({
    required this.id,
    required this.type,
    required this.hand,
    required this.context,
    required this.prompt,
    required this.options,
    required this.optimalOptionId,
    required this.tacticalRationale,
    this.expectedTricksMin = 0,
    this.expectedTricksMax = 13,
  });
}

/// Single lesson within an Academy Topic
class AcademyLesson {
  final String id;
  final String topicId;
  final String title;
  final String subtitle;
  final AcademyDifficulty difficulty;
  final String estimatedDuration; // e.g. "3 دقائق"
  final List<String> concepts;
  final String theoryExplanation;
  final String proTip;
  final AcademyScenario scenario;
  final int? customXp;

  const AcademyLesson({
    required this.id,
    required this.topicId,
    required this.title,
    required this.subtitle,
    required this.difficulty,
    required this.estimatedDuration,
    required this.concepts,
    required this.theoryExplanation,
    required this.proTip,
    required this.scenario,
    this.customXp,
  });

  int get xpReward => customXp ?? difficulty.xpReward;
}

/// A curriculum topic containing a sequence of lessons
class AcademyTopic {
  final String id;
  final String title;
  final String subtitle;
  final String icon;
  final Color accentColor;
  final List<AcademyLesson> lessons;

  const AcademyTopic({
    required this.id,
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.accentColor,
    required this.lessons,
  });

  int get totalLessons => lessons.length;
}

/// Persistent user progress state in the Academy
class AcademyProgress {
  final Set<String> completedLessonIds;
  final Map<String, int> lessonAttempts;
  final Map<String, int> lessonBestScores;
  final int totalXpEarned;
  final DateTime? lastActivity;

  const AcademyProgress({
    this.completedLessonIds = const {},
    this.lessonAttempts = const {},
    this.lessonBestScores = const {},
    this.totalXpEarned = 0,
    this.lastActivity,
  });

  bool isLessonCompleted(String lessonId) => completedLessonIds.contains(lessonId);

  int getAttempts(String lessonId) => lessonAttempts[lessonId] ?? 0;

  double getOverallMastery(int totalLessonsInCurriculum) {
    if (totalLessonsInCurriculum == 0) return 0.0;
    return (completedLessonIds.length / totalLessonsInCurriculum).clamp(0.0, 1.0);
  }

  AcademyMasteryTier getMasteryTier(int totalLessonsInCurriculum) {
    return AcademyMasteryTier.fromPercentage(getOverallMastery(totalLessonsInCurriculum));
  }

  double getTopicProgress(AcademyTopic topic) {
    if (topic.lessons.isEmpty) return 0.0;
    final completedInTopic =
        topic.lessons.where((l) => isLessonCompleted(l.id)).length;
    return (completedInTopic / topic.lessons.length).clamp(0.0, 1.0);
  }

  Map<String, dynamic> toJson() => {
        'completedLessonIds': completedLessonIds.toList(),
        'lessonAttempts': lessonAttempts,
        'lessonBestScores': lessonBestScores,
        'totalXpEarned': totalXpEarned,
        'lastActivity': lastActivity?.toIso8601String(),
      };

  factory AcademyProgress.fromJson(Map<String, dynamic> json) {
    final completed = (json['completedLessonIds'] as List<dynamic>?)
            ?.map((e) => e.toString())
            .toSet() ??
        {};
    final attempts = (json['lessonAttempts'] as Map<String, dynamic>?)?.map(
          (k, v) => MapEntry(k, (v as num).toInt()),
        ) ??
        {};
    final scores = (json['lessonBestScores'] as Map<String, dynamic>?)?.map(
          (k, v) => MapEntry(k, (v as num).toInt()),
        ) ??
        {};
    final xp = (json['totalXpEarned'] as num?)?.toInt() ?? 0;
    final lastAct = json['lastActivity'] != null
        ? DateTime.tryParse(json['lastActivity'].toString())
        : null;

    return AcademyProgress(
      completedLessonIds: completed,
      lessonAttempts: attempts,
      lessonBestScores: scores,
      totalXpEarned: xp,
      lastActivity: lastAct,
    );
  }

  AcademyProgress copyWith({
    Set<String>? completedLessonIds,
    Map<String, int>? lessonAttempts,
    Map<String, int>? lessonBestScores,
    int? totalXpEarned,
    DateTime? lastActivity,
  }) {
    return AcademyProgress(
      completedLessonIds: completedLessonIds ?? this.completedLessonIds,
      lessonAttempts: lessonAttempts ?? this.lessonAttempts,
      lessonBestScores: lessonBestScores ?? this.lessonBestScores,
      totalXpEarned: totalXpEarned ?? this.totalXpEarned,
      lastActivity: lastActivity ?? this.lastActivity,
    );
  }
}
