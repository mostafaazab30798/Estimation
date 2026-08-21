// lib/models/rank_tier.dart

import 'package:flutter/material.dart';

enum RankTierType {
  bronze,
  silver,
  gold,
  platinum,
  diamond,
  master,
  grandKing,
}

class RankTier {
  final RankTierType type;
  final String titleAr;
  final String titleEn;
  final String badgeEmoji;
  final int minLevel;
  final int maxLevel;
  final Color primaryColor;
  final Color secondaryColor;
  final List<Color> gradient;

  const RankTier({
    required this.type,
    required this.titleAr,
    required this.titleEn,
    required this.badgeEmoji,
    required this.minLevel,
    required this.maxLevel,
    required this.primaryColor,
    required this.secondaryColor,
    required this.gradient,
  });

  /// 🥉 Bronze Tier: Levels 1 - 4
  static const bronze = RankTier(
    type: RankTierType.bronze,
    titleAr: 'مبتدئ (برونزي)',
    titleEn: 'Bronze Apprentice',
    badgeEmoji: '🥉',
    minLevel: 1,
    maxLevel: 4,
    primaryColor: Color(0xFFCD7F32),
    secondaryColor: Color(0xFF8B4513),
    gradient: [Color(0xFFCD7F32), Color(0xFFA0522D), Color(0xFF8B4513)],
  );

  /// 🥈 Silver Tier: Levels 5 - 9
  static const silver = RankTier(
    type: RankTierType.silver,
    titleAr: 'هاوي (فضي)',
    titleEn: 'Silver Player',
    badgeEmoji: '🥈',
    minLevel: 5,
    maxLevel: 9,
    primaryColor: Color(0xFFE0E0E0),
    secondaryColor: Color(0xFF757575),
    gradient: [Color(0xFFEEEEEE), Color(0xFFBDBDBD), Color(0xFF757575)],
  );

  /// 🥇 Gold Tier: Levels 10 - 14
  static const gold = RankTier(
    type: RankTierType.gold,
    titleAr: 'محترف (ذهبي)',
    titleEn: 'Gold Master',
    badgeEmoji: '🥇',
    minLevel: 10,
    maxLevel: 14,
    primaryColor: Color(0xFFFFD700),
    secondaryColor: Color(0xFFB8860B),
    gradient: [Color(0xFFFFE082), Color(0xFFFFD700), Color(0xFFB8860B)],
  );

  /// 💎 Platinum Tier: Levels 15 - 19
  static const platinum = RankTier(
    type: RankTierType.platinum,
    titleAr: 'خبير (بلاتيني)',
    titleEn: 'Platinum Expert',
    badgeEmoji: '💎',
    minLevel: 15,
    maxLevel: 19,
    primaryColor: Color(0xFF00E5FF),
    secondaryColor: Color(0xFF0097A7),
    gradient: [Color(0xFF80D8FF), Color(0xFF00E5FF), Color(0xFF0097A7)],
  );

  /// 💠 Diamond Tier: Levels 20 - 29
  static const diamond = RankTier(
    type: RankTierType.diamond,
    titleAr: 'أستاذ (ألماسي)',
    titleEn: 'Diamond Legend',
    badgeEmoji: '💠',
    minLevel: 20,
    maxLevel: 29,
    primaryColor: Color(0xFFB388FF),
    secondaryColor: Color(0xFF7C4DFF),
    gradient: [Color(0xFFD1C4E9), Color(0xFFB388FF), Color(0xFF6200EA)],
  );

  /// ⚔️ Master Tier: Levels 30 - 49
  static const master = RankTier(
    type: RankTierType.master,
    titleAr: 'أسطورة (ماستر)',
    titleEn: 'Grand Champion',
    badgeEmoji: '⚔️',
    minLevel: 30,
    maxLevel: 49,
    primaryColor: Color(0xFFFF4081),
    secondaryColor: Color(0xFFC2185B),
    gradient: [Color(0xFFFF80AB), Color(0xFFFF4081), Color(0xFF880E4F)],
  );

  /// 👑 Grand King Tier: Levels 50+
  static const grandKing = RankTier(
    type: RankTierType.grandKing,
    titleAr: 'كينج الكوتشينة 👑',
    titleEn: 'Grand King of Kotshina',
    badgeEmoji: '👑',
    minLevel: 50,
    maxLevel: 9999,
    primaryColor: Color(0xFFFFB300),
    secondaryColor: Color(0xFFFF6F00),
    gradient: [Color(0xFFFFF176), Color(0xFFFFD54F), Color(0xFFFF8F00), Color(0xFFE65100)],
  );

  static const List<RankTier> allTiers = [
    bronze,
    silver,
    gold,
    platinum,
    diamond,
    master,
    grandKing,
  ];

  /// Get the RankTier corresponding to a given player level
  factory RankTier.fromLevel(int level) {
    if (level <= 4) return bronze;
    if (level <= 9) return silver;
    if (level <= 14) return gold;
    if (level <= 19) return platinum;
    if (level <= 29) return diamond;
    if (level <= 49) return master;
    return grandKing;
  }

  /// Next rank tier or null if maxed
  RankTier? get nextTier {
    final idx = allTiers.indexOf(this);
    if (idx >= 0 && idx < allTiers.length - 1) {
      return allTiers[idx + 1];
    }
    return null;
  }

  /// Calculate level progress inside the current rank tier (0.0 to 1.0)
  double getTierProgress(int currentLevel) {
    if (maxLevel >= 9999) return 1.0;
    final totalSpan = (maxLevel - minLevel) + 1;
    final currentOffset = currentLevel - minLevel;
    return (currentOffset / totalSpan).clamp(0.0, 1.0);
  }
}
