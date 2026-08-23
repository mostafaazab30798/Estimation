// lib/models/achievement_models.dart

import 'estimation_statistics.dart';

enum AchievementCategory {
  wins,
  accuracy,
  streaks,
  comebacks,
  bidding,
  special,
}

enum AchievementTier {
  bronze('برونزي', 'BRONZE', 0xFFCD7F32),
  silver('فضي', 'SILVER', 0xFFC0C0C0),
  gold('ذهبي', 'GOLD', 0xFFFFD700),
  diamond('ماسي', 'DIAMOND', 0xFF67E8F9);

  final String nameAr;
  final String nameEn;
  final int colorValue;

  const AchievementTier(this.nameAr, this.nameEn, this.colorValue);
}

class Achievement {
  final String id;
  final String titleAr;
  final String titleEn;
  final String descriptionAr;
  final String descriptionEn;
  final String emoji;
  final AchievementCategory category;
  final AchievementTier tier;
  final int xpReward;
  final int requiredValue;
  final int Function(EstimationStatistics stats) extractor;

  const Achievement({
    required this.id,
    required this.titleAr,
    required this.titleEn,
    required this.descriptionAr,
    required this.descriptionEn,
    required this.emoji,
    required this.category,
    required this.tier,
    required this.xpReward,
    required this.requiredValue,
    required this.extractor,
  });

  /// Evaluates the current value achieved by player
  int getCurrentValue(EstimationStatistics stats) => extractor(stats);

  /// Evaluates progress from 0.0 to 1.0
  double getProgress(EstimationStatistics stats) {
    if (requiredValue <= 0) return 1.0;
    final current = getCurrentValue(stats);
    return (current / requiredValue).clamp(0.0, 1.0);
  }

  /// Whether the player has completed this achievement
  bool isUnlocked(EstimationStatistics stats) =>
      getCurrentValue(stats) >= requiredValue;
}

class AchievementCatalog {
  static final List<Achievement> allAchievements = [
    // ── Wins & Games ────────────────────────────────────────────────────────
    Achievement(
      id: 'first_win',
      titleAr: 'أول فوز',
      titleEn: 'First Victory',
      descriptionAr: 'حقق أول انتصار لك في لعبة إستميشن',
      descriptionEn: 'Win your first estimation game',
      emoji: '🥉',
      category: AchievementCategory.wins,
      tier: AchievementTier.bronze,
      xpReward: 100,
      requiredValue: 1,
      extractor: (s) => s.gamesWon,
    ),
    Achievement(
      id: 'boula_veteran',
      titleAr: 'مخضرم البولات',
      titleEn: 'Boula Veteran',
      descriptionAr: 'حقق 10 انتصارات في مباريات البولة الكاملة',
      descriptionEn: 'Win 10 full Boula matches',
      emoji: '🥈',
      category: AchievementCategory.wins,
      tier: AchievementTier.silver,
      xpReward: 350,
      requiredValue: 10,
      extractor: (s) => s.gamesWon,
    ),
    Achievement(
      id: 'boula_master',
      titleAr: 'بطل البولة',
      titleEn: 'Boula Master',
      descriptionAr: 'حقق 50 انتصاراً وأثبت سيطرتك على الطاولة',
      descriptionEn: 'Win 50 full estimation matches',
      emoji: '👑',
      category: AchievementCategory.wins,
      tier: AchievementTier.gold,
      xpReward: 1200,
      requiredValue: 50,
      extractor: (s) => s.gamesWon,
    ),
    Achievement(
      id: 'boula_legend',
      titleAr: 'أسطورة إستميشن',
      titleEn: 'Estimation Legend',
      descriptionAr: 'حقق 100 انتصار واخلد اسمك بين العظماء',
      descriptionEn: 'Win 100 estimation matches',
      emoji: '💎',
      category: AchievementCategory.wins,
      tier: AchievementTier.diamond,
      xpReward: 3000,
      requiredValue: 100,
      extractor: (s) => s.gamesWon,
    ),

    // ── Precision & Accuracy ────────────────────────────────────────────────
    Achievement(
      id: 'perfect_caller_1',
      titleAr: 'كول في الصميم',
      titleEn: 'Sharp Eye',
      descriptionAr: 'حقق 20 كول مثالي (Exact Estimate)',
      descriptionEn: 'Achieve 20 perfect estimates',
      emoji: '🎯',
      category: AchievementCategory.accuracy,
      tier: AchievementTier.bronze,
      xpReward: 200,
      requiredValue: 20,
      extractor: (s) => s.perfectEstimates,
    ),
    Achievement(
      id: 'perfect_caller_master',
      titleAr: 'قناص الكول',
      titleEn: 'Sniper Caller',
      descriptionAr: 'حقق 100 كول مثالي بدون زيادة أو نقصان',
      descriptionEn: 'Achieve 100 perfect estimates',
      emoji: '🎯',
      category: AchievementCategory.accuracy,
      tier: AchievementTier.gold,
      xpReward: 1500,
      requiredValue: 100,
      extractor: (s) => s.perfectEstimates,
    ),
    Achievement(
      id: 'accuracy_elite',
      titleAr: 'عقل الماستر',
      titleEn: 'Mastermind Precision',
      descriptionAr: 'حقق دقة كول تتجاوز 70% عبر المباريات',
      descriptionEn: 'Maintain 70%+ overall declaration accuracy',
      emoji: '🧠',
      category: AchievementCategory.accuracy,
      tier: AchievementTier.gold,
      xpReward: 1000,
      requiredValue: 70,
      extractor: (s) => s.gamesPlayed >= 3 ? s.declarationAccuracy.round() : 0,
    ),

    // ── Winning Streaks ─────────────────────────────────────────────────────
    Achievement(
      id: 'streak_5',
      titleAr: 'سلسلة انتصارات',
      titleEn: 'Hot Streak',
      descriptionAr: 'حقق 5 انتصارات متتالية بدون أي هزيمة',
      descriptionEn: 'Win 5 matches in a row',
      emoji: '🔥',
      category: AchievementCategory.streaks,
      tier: AchievementTier.silver,
      xpReward: 500,
      requiredValue: 5,
      extractor: (s) => s.longestWinningStreak,
    ),
    Achievement(
      id: 'streak_10',
      titleAr: 'لا يُقهر',
      titleEn: 'Unstoppable Train',
      descriptionAr: 'حقق 10 انتصارات متتالية بدون توقف',
      descriptionEn: 'Win 10 matches in a row',
      emoji: '⚡',
      category: AchievementCategory.streaks,
      tier: AchievementTier.diamond,
      xpReward: 2500,
      requiredValue: 10,
      extractor: (s) => s.longestWinningStreak,
    ),

    // ── Comebacks & Clutch Moments ──────────────────────────────────────────
    Achievement(
      id: 'comeback_hero',
      titleAr: 'سيد الريمونتادا',
      titleEn: 'Comeback King',
      descriptionAr: 'اقلب النتيجة للفوز بعد التأخر بالمركز الأخير',
      descriptionEn: 'Overcome a major deficit to win the match',
      emoji: '🛡️',
      category: AchievementCategory.comebacks,
      tier: AchievementTier.gold,
      xpReward: 800,
      requiredValue: 1,
      extractor: (s) => s.majorComebacks > 0 ? s.majorComebacks : (s.bestComeback > 30 ? 1 : 0),
    ),
    Achievement(
      id: 'clutch_closer',
      titleAr: 'حاسم الجولة الأخيرة',
      titleEn: 'Clutch Finisher',
      descriptionAr: 'احسم الفوز في الجولة 18 الفاصلة',
      descriptionEn: 'Win via final round comeback',
      emoji: '⏱️',
      category: AchievementCategory.comebacks,
      tier: AchievementTier.silver,
      xpReward: 400,
      requiredValue: 1,
      extractor: (s) => s.finalRoundComebacks,
    ),

    // ── Bidding & High Stakes ───────────────────────────────────────────────
    Achievement(
      id: 'high_roller',
      titleAr: 'قلب ميت',
      titleEn: 'High Stakes Master',
      descriptionAr: 'زايد بـ 8 لِمّات أو أكثر وحقق الكول بنجاح',
      descriptionEn: 'Successfully bid and make 8+ tricks in a round',
      emoji: '♠️',
      category: AchievementCategory.bidding,
      tier: AchievementTier.gold,
      xpReward: 900,
      requiredValue: 8,
      extractor: (s) => s.highestSuccessfulBid,
    ),
    Achievement(
      id: 'round_scorer',
      titleAr: 'سكور قياسي',
      titleEn: 'Round Record',
      descriptionAr: 'احصد 50 نقطة أو أكثر في جولة واحدة',
      descriptionEn: 'Score 50+ points in a single round',
      emoji: '📈',
      category: AchievementCategory.bidding,
      tier: AchievementTier.silver,
      xpReward: 450,
      requiredValue: 50,
      extractor: (s) => s.highestScoreInOneRound,
    ),
  ];
}
