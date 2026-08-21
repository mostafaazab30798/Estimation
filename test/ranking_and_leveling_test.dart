// test/ranking_and_leveling_test.dart

import 'package:flutter_test/flutter_test.dart';
import 'package:estimation/models/rank_tier.dart';
import 'package:estimation/models/user_profile.dart';
import 'package:estimation/services/ranking_service.dart';
import 'package:estimation/core/models/game_state.dart';
import 'package:estimation/core/models/player.dart';

void main() {
  group('RankTier Progression & Formulas Tests', () {
    test('Correct RankTier mapped according to player levels', () {
      expect(RankTier.fromLevel(1).type, equals(RankTierType.bronze));
      expect(RankTier.fromLevel(4).type, equals(RankTierType.bronze));
      expect(RankTier.fromLevel(5).type, equals(RankTierType.silver));
      expect(RankTier.fromLevel(9).type, equals(RankTierType.silver));
      expect(RankTier.fromLevel(10).type, equals(RankTierType.gold));
      expect(RankTier.fromLevel(14).type, equals(RankTierType.gold));
      expect(RankTier.fromLevel(15).type, equals(RankTierType.platinum));
      expect(RankTier.fromLevel(19).type, equals(RankTierType.platinum));
      expect(RankTier.fromLevel(20).type, equals(RankTierType.diamond));
      expect(RankTier.fromLevel(29).type, equals(RankTierType.diamond));
      expect(RankTier.fromLevel(30).type, equals(RankTierType.master));
      expect(RankTier.fromLevel(49).type, equals(RankTierType.master));
      expect(RankTier.fromLevel(50).type, equals(RankTierType.grandKing));
      expect(RankTier.fromLevel(100).type, equals(RankTierType.grandKing));
    });

    test('RankTier progress within tier range is bounded [0.0, 1.0]', () {
      final bronze = RankTier.bronze;
      expect(bronze.getTierProgress(1), closeTo(0.0, 0.01));
      expect(bronze.getTierProgress(4), closeTo(0.75, 0.01));

      final silver = RankTier.silver;
      expect(silver.getTierProgress(5), closeTo(0.0, 0.01));
      expect(silver.getTierProgress(7), closeTo(0.4, 0.01));
    });
  });

  group('UserProfile XP & Level Formula Tests', () {
    test('calculateLevel computes level accurately from total XP', () {
      expect(UserProfile.calculateLevel(0), equals(1));
      expect(UserProfile.calculateLevel(99), equals(1));
      expect(UserProfile.calculateLevel(100), equals(2));
      expect(UserProfile.calculateLevel(399), equals(2));
      expect(UserProfile.calculateLevel(400), equals(3));
      expect(UserProfile.calculateLevel(900), equals(4));
      expect(UserProfile.calculateLevel(10000), equals(11));
    });

    test('UserProfile progress bar calculations', () {
      const profileLvl1 = UserProfile(
        id: 'u1',
        email: 'test@example.com',
        username: 'Player1',
        avatarUrl: 'preset:king',
        xp: 50,
        level: 1,
      );
      expect(profileLvl1.currentLevelBaseXp, equals(0));
      expect(profileLvl1.nextLevelTargetXp, equals(100));
      expect(profileLvl1.levelProgress, closeTo(0.5, 0.01));
      expect(profileLvl1.rankTier.type, equals(RankTierType.bronze));
    });
  });

  group('RankingService Match Reward Calculation Tests', () {
    test('Kotshina match reward calculates winner bonuses and placement XP', () {
      final p1 = Player(id: 'p1', name: 'Winner', seatIndex: 0, totalScore: 60);
      final p2 = Player(id: 'p2', name: 'Second', seatIndex: 1, totalScore: 40);
      final p3 = Player(id: 'p3', name: 'Third', seatIndex: 2, totalScore: 20);
      final p4 = Player(id: 'p4', name: 'Fourth', seatIndex: 3, totalScore: 10);

      final state = GameState(players: [p1, p2, p3, p4]);

      final rewardP1 = RankingService.instance.calculateKotshinaReward(
        state: state,
        myPlayerId: 'p1',
        myPlayerName: 'Winner',
      );

      expect(rewardP1.won, isTrue);
      expect(rewardP1.placementXp, equals(100));
      expect(rewardP1.winBonus, equals(50));
      expect(rewardP1.highScorerBonus, equals(25)); // score >= 50
      expect(rewardP1.totalXp, greaterThanOrEqualTo(175));

      final rewardP4 = RankingService.instance.calculateKotshinaReward(
        state: state,
        myPlayerId: 'p4',
        myPlayerName: 'Fourth',
      );

      expect(rewardP4.won, isFalse);
      expect(rewardP4.placementXp, equals(15));
      expect(rewardP4.winBonus, equals(0));
    });

    test('Ninety-Nine match reward calculates winner vs participants', () {
      final winReward = RankingService.instance.calculateNinetyNineReward(
        won: true,
        roundsSurvived: 6,
      );

      expect(winReward.won, isTrue);
      expect(winReward.placementXp, equals(80));
      expect(winReward.winBonus, equals(40));
      expect(winReward.accuracyBonus, equals(30)); // 6 rounds * 5
      expect(winReward.totalXp, equals(150));

      final loseReward = RankingService.instance.calculateNinetyNineReward(
        won: false,
        roundsSurvived: 3,
      );

      expect(loseReward.won, isFalse);
      expect(loseReward.placementXp, equals(30));
      expect(loseReward.winBonus, equals(0));
      expect(loseReward.accuracyBonus, equals(15));
      expect(loseReward.totalXp, equals(45));
    });
  });
}
