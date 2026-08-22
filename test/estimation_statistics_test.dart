// test/estimation_statistics_test.dart

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:estimation/core/constants.dart';
import 'package:estimation/core/models/card.dart';
import 'package:estimation/core/models/bid.dart';
import 'package:estimation/core/models/player.dart';
import 'package:estimation/core/models/game_state.dart';
import 'package:estimation/core/game_engine.dart';
import 'package:estimation/models/estimation_statistics.dart';
import 'package:estimation/services/estimation_stats_service.dart';

void main() {
  group('EstimationStatistics Model Tests', () {
    test('Calculates winRate correctly', () {
      const stats = EstimationStatistics(gamesPlayed: 10, gamesWon: 6);
      expect(stats.winRate, 60.0);

      const emptyStats = EstimationStatistics();
      expect(emptyStats.winRate, 0.0);
    });

    test('Calculates declaration accuracy correctly (Target Spec: 63.4%)', () {
      // 634 perfect estimates out of 1000 declarations = 63.4%
      const stats = EstimationStatistics(
        perfectEstimates: 634,
        failedDeclarations: 366,
      );

      expect(stats.totalDeclarations, 1000);
      expect(stats.successfulDeclarations, 634);
      expect(stats.declarationAccuracy, closeTo(63.4, 0.01));
    });

    test('Calculates average declared and actual tricks per round', () {
      const stats = EstimationStatistics(
        totalRounds: 18,
        totalDeclared: 54, // avg 3.0
        totalTricks: 45,   // avg 2.5
      );

      expect(stats.averageDeclaredTricks, 3.0);
      expect(stats.averageActualTricks, 2.5);
    });

    test('Serialization to/from JSON preserves all 17 fields', () {
      const original = EstimationStatistics(
        gamesPlayed: 25,
        gamesWon: 15,
        totalRounds: 450,
        totalTricks: 1350,
        totalDeclared: 1400,
        perfectEstimates: 300,
        failedDeclarations: 150,
        highestSuccessfulBid: 8,
        highestSuccessfulDeclaration: 9,
        highestScoreInOneRound: 48,
        lowestScoreInOneRound: -35,
        bestComeback: 32,
        longestWinningStreak: 7,
        currentWinningStreak: 3,
      );

      final json = original.toJson();
      final restored = EstimationStatistics.fromJson(json);

      expect(restored.gamesPlayed, 25);
      expect(restored.gamesWon, 15);
      expect(restored.totalRounds, 450);
      expect(restored.totalTricks, 1350);
      expect(restored.totalDeclared, 1400);
      expect(restored.perfectEstimates, 300);
      expect(restored.failedDeclarations, 150);
      expect(restored.highestSuccessfulBid, 8);
      expect(restored.highestSuccessfulDeclaration, 9);
      expect(restored.highestScoreInOneRound, 48);
      expect(restored.lowestScoreInOneRound, -35);
      expect(restored.bestComeback, 32);
      expect(restored.longestWinningStreak, 7);
      expect(restored.currentWinningStreak, 3);
      expect(restored.winRate, 60.0);
      expect(restored.declarationAccuracy, closeTo(66.67, 0.01));
    });
  });

  group('GameState RoundHistory Recording & GameEngine Tests', () {
    test('GameEngine.computeAndApplyScores records RoundHistoryRecord in GameState', () {
      final p1 = Player(id: 'p1', name: 'Mostafa', seatIndex: 0, declared: 4, actual: 4);
      final p2 = Player(id: 'p2', name: 'Bot1', seatIndex: 1, declared: 3, actual: 2);
      final p3 = Player(id: 'p3', name: 'Bot2', seatIndex: 2, declared: 3, actual: 4);
      final p4 = Player(id: 'p4', name: 'Bot3', seatIndex: 3, declared: 2, actual: 3);

      final state = GameState(
        players: [p1, p2, p3, p4],
        roundNumber: 1,
        bidderPlayerId: 'p1',
        currentHighBid: Bid(trickCount: 4, trump: Trump.spade),
      );

      GameEngine.computeAndApplyScores(state);

      expect(state.roundHistory.length, 1);
      final roundRec = state.roundHistory.first;
      expect(roundRec.roundNumber, 1);
      expect(roundRec.bidderPlayerId, 'p1');
      expect(roundRec.playerRecords.length, 4);

      final p1Rec = roundRec.playerRecords.firstWhere((r) => r.playerId == 'p1');
      expect(p1Rec.declared, 4);
      expect(p1Rec.actual, 4);
      expect(p1Rec.isSuccess, true);
      expect(p1Rec.isBidder, true);

      final p2Rec = roundRec.playerRecords.firstWhere((r) => r.playerId == 'p2');
      expect(p2Rec.isSuccess, false);
    });
  });

  group('EstimationStatsService Match Processing Tests', () {
    setUp(() {
      SharedPreferences.setMockInitialValues({});
    });

    test('Processes match results and updates statistics, accuracy, streak, and best comeback', () async {
      final service = EstimationStatsService.instance;
      const playerName = 'Mostafa';
      const playerId = 'p1';

      final p1 = Player(id: playerId, name: playerName, seatIndex: 0);
      final p2 = Player(id: 'p2', name: 'Bot1', seatIndex: 1);
      final p3 = Player(id: 'p3', name: 'Bot2', seatIndex: 2);
      final p4 = Player(id: 'p4', name: 'Bot3', seatIndex: 3);

      final state = GameState(
        players: [p1, p2, p3, p4],
        roundNumber: 2,
        totalRounds: 2,
      );

      // Round 1: p1 trails Bot1 by 20 points
      state.roundNumber = 1;
      p1.declared = 2; p1.actual = 1; // fail: - (1) - 1 = -2
      p2.declared = 4; p2.actual = 4; // success: 4 + 1 + 10 = +15 (bidder)
      p3.declared = 3; p3.actual = 3;
      p4.declared = 4; p4.actual = 5;
      state.bidderPlayerId = 'p2';
      state.currentHighBid = Bid(trickCount: 4, trump: Trump.heart);
      GameEngine.computeAndApplyScores(state);

      // Round 2: p1 bids 7 spades, succeeds (+7 + 2 + 10 = +19), finishes with highest score and wins
      state.roundNumber = 2;
      p1.declared = 7; p1.actual = 7;
      p2.declared = 3; p2.actual = 1; // fails
      p3.declared = 2; p3.actual = 2;
      p4.declared = 1; p4.actual = 3;
      state.bidderPlayerId = playerId;
      state.currentHighBid = Bid(trickCount: 7, trump: Trump.spade);
      GameEngine.computeAndApplyScores(state);

      expect(p1.totalScore, greaterThan(p2.totalScore));

      final stats = await service.recordMatch(
        state: state,
        playerName: playerName,
        playerId: playerId,
      );

      expect(stats.gamesPlayed, 1);
      expect(stats.gamesWon, 1);
      expect(stats.winRate, 100.0);
      expect(stats.totalRounds, 2);
      expect(stats.totalTricks, 8); // 1 + 7
      expect(stats.totalDeclared, 9); // 2 + 7
      expect(stats.perfectEstimates, 1);
      expect(stats.failedDeclarations, 1);
      expect(stats.declarationAccuracy, 50.0); // 1 / 2 = 50%
      expect(stats.highestSuccessfulBid, 7);
      expect(stats.highestSuccessfulDeclaration, 7);
      expect(stats.highestScoreInOneRound, 19);
      expect(stats.lowestScoreInOneRound, -2);
      expect(stats.bestComeback, greaterThan(0)); // Trailed in round 1 and won match
      expect(stats.longestWinningStreak, 1);
      expect(stats.currentWinningStreak, 1);
    });
  });
}
