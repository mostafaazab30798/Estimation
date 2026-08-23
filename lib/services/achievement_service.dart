// lib/services/achievement_service.dart

import '../models/achievement_models.dart';
import '../models/estimation_statistics.dart';

class AchievementService {
  AchievementService._internal();
  static final AchievementService instance = AchievementService._internal();

  /// List of all available achievements
  List<Achievement> get allAchievements => AchievementCatalog.allAchievements;

  /// Returns all achievements unlocked by player based on current statistics
  List<Achievement> getUnlockedAchievements(EstimationStatistics stats) {
    return allAchievements.where((a) => a.isUnlocked(stats)).toList();
  }

  /// Returns locked achievements
  List<Achievement> getLockedAchievements(EstimationStatistics stats) {
    return allAchievements.where((a) => !a.isUnlocked(stats)).toList();
  }

  /// Total count of unlocked achievements
  int getUnlockedCount(EstimationStatistics stats) {
    return getUnlockedAchievements(stats).length;
  }

  /// Total XP earned from all unlocked achievements
  int calculateTotalAchievementXp(EstimationStatistics stats) {
    return getUnlockedAchievements(stats).fold(0, (sum, a) => sum + a.xpReward);
  }

  /// Returns the top [limit] achievements for display (e.g. on the Poster card / Profile).
  /// Prioritizes unlocked high-tier achievements (Diamond > Gold > Silver > Bronze),
  /// followed by locked achievements with highest current progress.
  List<Achievement> getTopDisplayAchievements(EstimationStatistics stats, {int limit = 4}) {
    final unlocked = getUnlockedAchievements(stats);
    // Sort unlocked by tier weight descending
    unlocked.sort((a, b) => b.tier.index.compareTo(a.tier.index));

    if (unlocked.length >= limit) {
      return unlocked.take(limit).toList();
    }

    // Fill remaining slots with locked achievements that are closest to completion
    final locked = getLockedAchievements(stats);
    locked.sort((a, b) => b.getProgress(stats).compareTo(a.getProgress(stats)));

    final result = <Achievement>[...unlocked];
    for (final a in locked) {
      if (result.length >= limit) break;
      result.add(a);
    }

    return result;
  }
}
