// test/achievement_system_test.dart

import 'package:flutter_test/flutter_test.dart';
import 'package:estimation/models/achievement_models.dart';
import 'package:estimation/models/estimation_statistics.dart';
import 'package:estimation/services/achievement_service.dart';

void main() {
  group('Achievement System Tests', () {
    test('Empty statistics has zero unlocked achievements', () {
      const stats = EstimationStatistics();
      final service = AchievementService.instance;

      final unlocked = service.getUnlockedAchievements(stats);
      final locked = service.getLockedAchievements(stats);

      expect(unlocked, isEmpty);
      expect(locked.length, equals(service.allAchievements.length));
      expect(service.getUnlockedCount(stats), equals(0));
      expect(service.calculateTotalAchievementXp(stats), equals(0));
    });

    test('Unlocks win-based achievements correctly with XP rewards', () {
      final service = AchievementService.instance;

      // Player with 1 win
      final stats1 = const EstimationStatistics(gamesWon: 1, gamesPlayed: 1);
      final unlocked1 = service.getUnlockedAchievements(stats1);
      expect(unlocked1.any((a) => a.id == 'first_win'), isTrue);
      expect(unlocked1.any((a) => a.id == 'boula_veteran'), isFalse);

      // Player with 12 wins
      final stats12 = const EstimationStatistics(gamesWon: 12, gamesPlayed: 15);
      final unlocked12 = service.getUnlockedAchievements(stats12);
      expect(unlocked12.any((a) => a.id == 'first_win'), isTrue);
      expect(unlocked12.any((a) => a.id == 'boula_veteran'), isTrue);
      expect(unlocked12.any((a) => a.id == 'boula_master'), isFalse);
    });

    test('Calculates progress accurately for partially completed achievements', () {
      const stats = EstimationStatistics(
        gamesWon: 5,
        perfectEstimates: 50,
        longestWinningStreak: 3,
      );

      final boulaMaster = AchievementCatalog.allAchievements.firstWhere((a) => a.id == 'boula_master');
      expect(boulaMaster.getCurrentValue(stats), equals(5));
      expect(boulaMaster.getProgress(stats), closeTo(0.10, 0.001)); // 5 / 50 = 0.1

      final perfectCallerMaster = AchievementCatalog.allAchievements.firstWhere((a) => a.id == 'perfect_caller_master');
      expect(perfectCallerMaster.getCurrentValue(stats), equals(50));
      expect(perfectCallerMaster.getProgress(stats), closeTo(0.50, 0.001)); // 50 / 100 = 0.5
    });

    test('Top display achievements provides exactly 4 elements prioritized by tier and progress', () {
      final service = AchievementService.instance;
      const stats = EstimationStatistics(
        gamesWon: 100, // Unlocks first_win, boula_veteran, boula_master, boula_legend (Diamond)
        longestWinningStreak: 10, // Unlocks streak_5, streak_10 (Diamond)
        perfectEstimates: 100, // Unlocks perfect_caller_1, perfect_caller_master (Gold)
      );

      final top = service.getTopDisplayAchievements(stats, limit: 4);
      expect(top.length, equals(4));

      // Should prioritize Diamond tier first
      expect(top.any((a) => a.tier == AchievementTier.diamond), isTrue);
    });
  });
}
