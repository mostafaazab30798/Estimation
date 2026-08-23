// lib/models/puzzle_models.dart

import 'package:flutter/material.dart';
import '../core/constants.dart';
import '../core/models/card.dart';

/// Categories of Estimation puzzles
enum PuzzleCategory {
  bid(
    id: 'bid',
    arabicTitle: 'مزايدة المزاد',
    englishTitle: 'Bid Puzzle',
    icon: '♠️',
    color: Color(0xFF3B82F6),
    description: 'حدد المزايدة الأنسب بناءً على قوة يدك وموقعك على الطاولة',
  ),
  declaration(
    id: 'declaration',
    arabicTitle: 'إعلان الكول',
    englishTitle: 'Declaration Puzzle',
    icon: '🎯',
    color: Color(0xFF10B981),
    description: 'اختر الإعلان القانوني والأكثر أماناً لتحقيق المطلوب بدقة',
  ),
  trick(
    id: 'trick',
    arabicTitle: 'لعب ورقة تكتيكية',
    englishTitle: 'Trick Puzzle',
    icon: '🃏',
    color: Color(0xFF8B5CF6),
    description: 'اختر أفضل ورقة تنزل بها للتحكم في اللمة وحماية أكلاتك',
  ),
  risk(
    id: 'risk',
    arabicTitle: 'قرار الريسك',
    englishTitle: 'Risk Puzzle',
    icon: '⚡',
    color: Color(0xFFF59E0B),
    description: 'هل تأخذ قرار الريسك لمضاعفة نقاطك أم تتجنب الخسارة؟',
  ),
  dash(
    id: 'dash',
    arabicTitle: 'قرار الداش كول',
    englishTitle: 'Dash Call Puzzle',
    icon: '🛡️',
    color: Color(0xFFEC4899),
    description: 'هل تطلب داش كول (0 أكلات) بنجاح أم أن الورق يحمل خطورة؟',
  ),
  score(
    id: 'score',
    arabicTitle: 'استراتيجية النقاط',
    englishTitle: 'Score Puzzle',
    icon: '🏆',
    color: Color(0xFF06B6D4),
    description: 'أنت متأخر في الترتيب أو في الجولة الحاسمة — ما القرار الأنسب؟',
  );

  const PuzzleCategory({
    required this.id,
    required this.arabicTitle,
    required this.englishTitle,
    required this.icon,
    required this.color,
    required this.description,
  });

  final String id;
  final String arabicTitle;
  final String englishTitle;
  final String icon;
  final Color color;
  final String description;
}

/// Difficulty level of a puzzle
enum PuzzleDifficulty {
  beginner(
    arabicLabel: 'مبتدئ ⭐',
    stars: 1,
    color: Color(0xFF10B981),
    xpReward: 35,
  ),
  intermediate(
    arabicLabel: 'متوسط ⭐⭐',
    stars: 2,
    color: Color(0xFF3B82F6),
    xpReward: 55,
  ),
  advanced(
    arabicLabel: 'متقدم ⭐⭐⭐',
    stars: 3,
    color: Color(0xFFF59E0B),
    xpReward: 80,
  ),
  expert(
    arabicLabel: 'خبير ⭐⭐⭐⭐',
    stars: 4,
    color: Color(0xFF8B5CF6),
    xpReward: 110,
  ),
  master(
    arabicLabel: 'أستاذ ⭐⭐⭐⭐⭐',
    stars: 5,
    color: Color(0xFFEF4444),
    xpReward: 160,
  );

  const PuzzleDifficulty({
    required this.arabicLabel,
    required this.stars,
    required this.color,
    required this.xpReward,
  });

  final String arabicLabel;
  final int stars;
  final Color color;
  final int xpReward;
}

/// Evaluation quality for a puzzle solution
enum PuzzleResultQuality {
  optimal('أداء مثالي 🎯 (OPTIMAL)', Color(0xFF10B981), 100),
  strong('خيار جيد 💡 (STRONG)', Color(0xFF3B82F6), 80),
  weak('خيار ضعيف ⚠️ (WEAK)', Color(0xFFF59E0B), 30),
  invalid('خاطئ أو غير قانوني ❌ (INVALID)', Color(0xFFEF4444), 0);

  const PuzzleResultQuality(this.arabicLabel, this.color, this.scorePoints);
  final String arabicLabel;
  final Color color;
  final int scorePoints;

  bool get isSuccessful => this == optimal || this == strong;
}

/// An interactive option for a puzzle
class PuzzleOption {
  final String id;
  final String label;
  final PuzzleResultQuality quality;
  final String feedback;
  final PlayingCard? cardToPlay;

  const PuzzleOption({
    required this.id,
    required this.label,
    required this.quality,
    required this.feedback,
    this.cardToPlay,
  });

  bool get isOptimal => quality == PuzzleResultQuality.optimal;
  bool get isAcceptable => quality.isSuccessful;
}

/// Context of the table & game situation in the puzzle
class PuzzleContext {
  final int roundNumber;
  final int totalRounds;
  final Trump? trump;
  final String playerPosition;
  final String? highBidInfo;
  final String? otherBidsInfo;
  final List<TrickCard>? currentTrickCards;
  final String? scoreSituation;
  final String? declaredCallsInfo;
  final int? currentTricksWon;

  const PuzzleContext({
    this.roundNumber = 1,
    this.totalRounds = 18,
    this.trump,
    this.playerPosition = 'اللاعب الأول',
    this.highBidInfo,
    this.otherBidsInfo,
    this.currentTrickCards,
    this.scoreSituation,
    this.declaredCallsInfo,
    this.currentTricksWon,
  });
}

/// Standalone Estimation strategic puzzle
class EstimationPuzzle {
  final String id;
  final String title;
  final PuzzleCategory category;
  final PuzzleDifficulty difficulty;
  final String scenarioText;
  final List<PlayingCard> playerHand;
  final PuzzleContext context;
  final String prompt;
  final List<PuzzleOption> options;
  final String optimalOptionId;
  final List<String> acceptableOptionIds;
  final String tacticalRationale;
  final int? customXp;
  final bool isDailyEligible;

  const EstimationPuzzle({
    required this.id,
    required this.title,
    required this.category,
    required this.difficulty,
    required this.scenarioText,
    required this.playerHand,
    required this.context,
    required this.prompt,
    required this.options,
    required this.optimalOptionId,
    this.acceptableOptionIds = const [],
    required this.tacticalRationale,
    this.customXp,
    this.isDailyEligible = true,
  });

  int get xpReward => customXp ?? difficulty.xpReward;

  PuzzleOption? get optimalOption {
    try {
      return options.firstWhere((o) => o.id == optimalOptionId);
    } catch (_) {
      return null;
    }
  }
}

/// Persistent user progress in Puzzle Mode
class PuzzleProgress {
  final Set<String> solvedPuzzleIds;
  final Map<String, int> puzzleAttempts;
  final Map<String, int> puzzleBestScores;
  final int totalXpEarned;
  final String? dailyPuzzleLastDate; // Format 'YYYY-MM-DD'
  final int dailyPuzzleStreak;
  final DateTime? lastActivity;

  const PuzzleProgress({
    this.solvedPuzzleIds = const {},
    this.puzzleAttempts = const {},
    this.puzzleBestScores = const {},
    this.totalXpEarned = 0,
    this.dailyPuzzleLastDate,
    this.dailyPuzzleStreak = 0,
    this.lastActivity,
  });

  bool isSolved(String puzzleId) => solvedPuzzleIds.contains(puzzleId);

  int getAttempts(String puzzleId) => puzzleAttempts[puzzleId] ?? 0;

  int getBestScore(String puzzleId) => puzzleBestScores[puzzleId] ?? 0;

  bool isPerfect(String puzzleId) => getBestScore(puzzleId) == 100;

  int get totalSolvedCount => solvedPuzzleIds.length;

  int get perfectCount => puzzleBestScores.values.where((score) => score == 100).length;

  double getAccuracyRate(int totalAttempted) {
    if (totalAttempted == 0) return 0.0;
    return (solvedPuzzleIds.length / totalAttempted).clamp(0.0, 1.0);
  }

  Map<String, dynamic> toJson() => {
        'solvedPuzzleIds': solvedPuzzleIds.toList(),
        'puzzleAttempts': puzzleAttempts,
        'puzzleBestScores': puzzleBestScores,
        'totalXpEarned': totalXpEarned,
        'dailyPuzzleLastDate': dailyPuzzleLastDate,
        'dailyPuzzleStreak': dailyPuzzleStreak,
        'lastActivity': lastActivity?.toIso8601String(),
      };

  factory PuzzleProgress.fromJson(Map<String, dynamic> json) {
    final solved = (json['solvedPuzzleIds'] as List<dynamic>?)
            ?.map((e) => e.toString())
            .toSet() ??
        {};
    final attempts = (json['puzzleAttempts'] as Map<String, dynamic>?)?.map(
          (k, v) => MapEntry(k, (v as num).toInt()),
        ) ??
        {};
    final scores = (json['puzzleBestScores'] as Map<String, dynamic>?)?.map(
          (k, v) => MapEntry(k, (v as num).toInt()),
        ) ??
        {};
    final xp = (json['totalXpEarned'] as num?)?.toInt() ?? 0;
    final dailyDate = json['dailyPuzzleLastDate']?.toString();
    final streak = (json['dailyPuzzleStreak'] as num?)?.toInt() ?? 0;
    final lastAct = json['lastActivity'] != null
        ? DateTime.tryParse(json['lastActivity'].toString())
        : null;

    return PuzzleProgress(
      solvedPuzzleIds: solved,
      puzzleAttempts: attempts,
      puzzleBestScores: scores,
      totalXpEarned: xp,
      dailyPuzzleLastDate: dailyDate,
      dailyPuzzleStreak: streak,
      lastActivity: lastAct,
    );
  }

  PuzzleProgress copyWith({
    Set<String>? solvedPuzzleIds,
    Map<String, int>? puzzleAttempts,
    Map<String, int>? puzzleBestScores,
    int? totalXpEarned,
    String? dailyPuzzleLastDate,
    int? dailyPuzzleStreak,
    DateTime? lastActivity,
  }) {
    return PuzzleProgress(
      solvedPuzzleIds: solvedPuzzleIds ?? this.solvedPuzzleIds,
      puzzleAttempts: puzzleAttempts ?? this.puzzleAttempts,
      puzzleBestScores: puzzleBestScores ?? this.puzzleBestScores,
      totalXpEarned: totalXpEarned ?? this.totalXpEarned,
      dailyPuzzleLastDate: dailyPuzzleLastDate ?? this.dailyPuzzleLastDate,
      dailyPuzzleStreak: dailyPuzzleStreak ?? this.dailyPuzzleStreak,
      lastActivity: lastActivity ?? this.lastActivity,
    );
  }
}
