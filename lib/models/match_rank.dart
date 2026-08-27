// lib/models/match_rank.dart
//
// The four in-match standings (King → Kooz) with art assets and labels.

import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

/// Match standing for a single player (0 = King … 3 = Kooz).
class MatchRank {
  final int index;
  final String titleAr;
  final String titleEn;
  final String assetPath;
  final Color accentColor;

  const MatchRank({
    required this.index,
    required this.titleAr,
    required this.titleEn,
    required this.assetPath,
    required this.accentColor,
  });

  static const king = MatchRank(
    index: 0,
    titleAr: 'كينج',
    titleEn: 'King',
    assetPath: 'assets/ranks/king.png',
    accentColor: AppTheme.rankGold,
  );

  static const subKing = MatchRank(
    index: 1,
    titleAr: 'صب كينج',
    titleEn: 'Sub-King',
    assetPath: 'assets/ranks/sub-king.png',
    accentColor: AppTheme.rankSilver,
  );

  static const subKooz = MatchRank(
    index: 2,
    titleAr: 'صب كوز',
    titleEn: 'Sub-Kooz',
    assetPath: 'assets/ranks/sub-koz.png',
    accentColor: AppTheme.rankBronze,
  );

  static const kooz = MatchRank(
    index: 3,
    titleAr: 'كوز',
    titleEn: 'Kooz',
    assetPath: 'assets/ranks/koz.png',
    accentColor: AppTheme.rankLast,
  );

  static const List<MatchRank> all = [king, subKing, subKooz, kooz];

  /// Returns the rank for a 0–3 index, or null if out of range.
  static MatchRank? fromIndex(int index) {
    if (index < 0 || index >= all.length) return null;
    return all[index];
  }

  /// Legacy string used in history / share text (emoji-free, art-backed UI).
  String get labelAr => titleAr;

  /// Compact chip label used next to scores.
  String get chipLabel => titleAr;
}
