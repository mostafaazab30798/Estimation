// test/comeback_system_test.dart

import 'package:flutter_test/flutter_test.dart';
import 'package:estimation/core/models/game_state.dart';
import 'package:estimation/core/models/player.dart';
import 'package:estimation/core/models/comeback_event.dart';
import 'package:estimation/models/estimation_statistics.dart';
import 'package:estimation/services/ranking_service.dart';

void main() {
  group('Comeback System Detection Tests', () {
    late List<Player> players;

    setUp(() {
      players = [
        Player(id: 'p1', name: 'Alice', seatIndex: 0),
        Player(id: 'p2', name: 'Bob', seatIndex: 1),
        Player(id: 'p3', name: 'Charlie', seatIndex: 2),
        Player(id: 'p4', name: 'Diana', seatIndex: 3),
      ];
    });

    test('Detects Major Comeback when 4th place player moves to 1st place', () {
      // Round 1: Alice +30, Bob +20, Charlie +10, Diana -10 (Diana is 4th)
      final round1 = RoundHistoryRecord(
        roundNumber: 1,
        playerRecords: [
          const PlayerRoundRecord(
            playerId: 'p1',
            playerName: 'Alice',
            declared: 3,
            actual: 3,
            scoreDelta: 30,
            totalScoreAfterRound: 30,
            isSuccess: true,
          ),
          const PlayerRoundRecord(
            playerId: 'p2',
            playerName: 'Bob',
            declared: 2,
            actual: 2,
            scoreDelta: 20,
            totalScoreAfterRound: 20,
            isSuccess: true,
          ),
          const PlayerRoundRecord(
            playerId: 'p3',
            playerName: 'Charlie',
            declared: 1,
            actual: 1,
            scoreDelta: 10,
            totalScoreAfterRound: 10,
            isSuccess: true,
          ),
          const PlayerRoundRecord(
            playerId: 'p4',
            playerName: 'Diana',
            declared: 2,
            actual: 0,
            scoreDelta: -10,
            totalScoreAfterRound: -10,
            isSuccess: false,
          ),
        ],
      );

      // Round 2: Diana gets +50, Alice -10, Bob -10, Charlie -10
      // Standings after R2: Diana=40 (1st), Alice=20 (2nd), Bob=10 (3rd), Charlie=0 (4th)
      final round2 = RoundHistoryRecord(
        roundNumber: 2,
        playerRecords: [
          const PlayerRoundRecord(
            playerId: 'p1',
            playerName: 'Alice',
            declared: 3,
            actual: 1,
            scoreDelta: -10,
            totalScoreAfterRound: 20,
            isSuccess: false,
          ),
          const PlayerRoundRecord(
            playerId: 'p2',
            playerName: 'Bob',
            declared: 2,
            actual: 0,
            scoreDelta: -10,
            totalScoreAfterRound: 10,
            isSuccess: false,
          ),
          const PlayerRoundRecord(
            playerId: 'p3',
            playerName: 'Charlie',
            declared: 1,
            actual: 0,
            scoreDelta: -10,
            totalScoreAfterRound: 0,
            isSuccess: false,
          ),
          const PlayerRoundRecord(
            playerId: 'p4',
            playerName: 'Diana',
            declared: 5,
            actual: 5,
            scoreDelta: 50,
            totalScoreAfterRound: 40,
            isSuccess: true,
          ),
        ],
      );

      final state = GameState(
        players: players,
        roundNumber: 2,
        totalRounds: 18,
        roundHistory: [round1, round2],
      );

      final comebacks = ComebackDetector.detectRoundComebacks(
        state: state,
        roundNumber: 2,
      );

      expect(comebacks.length, 1);
      final event = comebacks.first;
      expect(event.playerId, 'p4');
      expect(event.playerName, 'Diana');
      expect(event.type, ComebackType.majorComeback);
      expect(event.previousRank, 4);
      expect(event.newRank, 1);
      expect(event.pointsDeficitOvercome, 40); // 30 - (-10) = 40
      expect(event.titleEn, 'MAJOR COMEBACK!');
    });

    test('Detects Final-Round Comeback in Round 18 / match conclusion', () {
      // Round 17: Bob is leading with 80, Alice has 70 (2nd)
      final round17 = RoundHistoryRecord(
        roundNumber: 17,
        playerRecords: [
          const PlayerRoundRecord(
            playerId: 'p1',
            playerName: 'Alice',
            declared: 2,
            actual: 2,
            scoreDelta: 20,
            totalScoreAfterRound: 70,
            isSuccess: true,
          ),
          const PlayerRoundRecord(
            playerId: 'p2',
            playerName: 'Bob',
            declared: 3,
            actual: 3,
            scoreDelta: 30,
            totalScoreAfterRound: 80,
            isSuccess: true,
          ),
          const PlayerRoundRecord(
            playerId: 'p3',
            playerName: 'Charlie',
            declared: 1,
            actual: 1,
            scoreDelta: 10,
            totalScoreAfterRound: 30,
            isSuccess: true,
          ),
          const PlayerRoundRecord(
            playerId: 'p4',
            playerName: 'Diana',
            declared: 0,
            actual: 0,
            scoreDelta: 10,
            totalScoreAfterRound: 20,
            isSuccess: true,
          ),
        ],
      );

      // Round 18 (Final): Alice gets +30 (total 100), Bob gets -20 (total 60)
      final round18 = RoundHistoryRecord(
        roundNumber: 18,
        playerRecords: [
          const PlayerRoundRecord(
            playerId: 'p1',
            playerName: 'Alice',
            declared: 3,
            actual: 3,
            scoreDelta: 30,
            totalScoreAfterRound: 100,
            isSuccess: true,
          ),
          const PlayerRoundRecord(
            playerId: 'p2',
            playerName: 'Bob',
            declared: 4,
            actual: 2,
            scoreDelta: -20,
            totalScoreAfterRound: 60,
            isSuccess: false,
          ),
          const PlayerRoundRecord(
            playerId: 'p3',
            playerName: 'Charlie',
            declared: 1,
            actual: 1,
            scoreDelta: 10,
            totalScoreAfterRound: 40,
            isSuccess: true,
          ),
          const PlayerRoundRecord(
            playerId: 'p4',
            playerName: 'Diana',
            declared: 0,
            actual: 0,
            scoreDelta: 10,
            totalScoreAfterRound: 30,
            isSuccess: true,
          ),
        ],
      );

      final state = GameState(
        players: players,
        roundNumber: 18,
        totalRounds: 18,
        roundHistory: [round17, round18],
      );

      final comebacks = ComebackDetector.detectRoundComebacks(
        state: state,
        roundNumber: 18,
      );

      expect(comebacks.length, 1);
      final event = comebacks.first;
      expect(event.playerId, 'p1');
      expect(event.playerName, 'Alice');
      expect(event.type, ComebackType.finalRoundComeback);
      expect(event.previousRank, 2);
      expect(event.newRank, 1);
      expect(event.titleEn, 'LAST ROUND COMEBACK!');
      expect(event.titleAr, 'ريمونتادا الجولة الأخيرة!');
    });

    test('Detects Rank Surge when player jumps 2+ positions without being 1st', () {
      // Round 1: Alice 50, Bob 40, Charlie 30, Diana 0 (Diana is 4th)
      final round1 = RoundHistoryRecord(
        roundNumber: 1,
        playerRecords: [
          const PlayerRoundRecord(playerId: 'p1', playerName: 'Alice', declared: 5, actual: 5, scoreDelta: 50, totalScoreAfterRound: 50, isSuccess: true),
          const PlayerRoundRecord(playerId: 'p2', playerName: 'Bob', declared: 4, actual: 4, scoreDelta: 40, totalScoreAfterRound: 40, isSuccess: true),
          const PlayerRoundRecord(playerId: 'p3', playerName: 'Charlie', declared: 3, actual: 3, scoreDelta: 30, totalScoreAfterRound: 30, isSuccess: true),
          const PlayerRoundRecord(playerId: 'p4', playerName: 'Diana', declared: 0, actual: 1, scoreDelta: 0, totalScoreAfterRound: 0, isSuccess: false),
        ],
      );

      // Round 2: Diana gets +45 (total 45), Alice +10 (total 60), Bob -10 (total 30), Charlie -10 (total 20)
      // Standings: Alice 60 (1st), Diana 45 (2nd), Bob 30 (3rd), Charlie 20 (4th)
      // Diana jumped from 4th -> 2nd (Rank Surge)
      final round2 = RoundHistoryRecord(
        roundNumber: 2,
        playerRecords: [
          const PlayerRoundRecord(playerId: 'p1', playerName: 'Alice', declared: 1, actual: 1, scoreDelta: 10, totalScoreAfterRound: 60, isSuccess: true),
          const PlayerRoundRecord(playerId: 'p2', playerName: 'Bob', declared: 2, actual: 0, scoreDelta: -10, totalScoreAfterRound: 30, isSuccess: false),
          const PlayerRoundRecord(playerId: 'p3', playerName: 'Charlie', declared: 1, actual: 0, scoreDelta: -10, totalScoreAfterRound: 20, isSuccess: false),
          const PlayerRoundRecord(playerId: 'p4', playerName: 'Diana', declared: 4, actual: 4, scoreDelta: 45, totalScoreAfterRound: 45, isSuccess: true),
        ],
      );

      final state = GameState(
        players: players,
        roundNumber: 2,
        totalRounds: 18,
        roundHistory: [round1, round2],
      );

      final comebacks = ComebackDetector.detectRoundComebacks(
        state: state,
        roundNumber: 2,
      );

      expect(comebacks.length, 1);
      final event = comebacks.first;
      expect(event.playerId, 'p4');
      expect(event.type, ComebackType.rankSurge);
      expect(event.previousRank, 4);
      expect(event.newRank, 2);
    });

    test('detectMatchComebacks finds all comeback events achieved by a player in the match', () {
      final round1 = RoundHistoryRecord(
        roundNumber: 1,
        playerRecords: [
          const PlayerRoundRecord(playerId: 'p1', playerName: 'Alice', declared: 3, actual: 3, scoreDelta: 30, totalScoreAfterRound: 30, isSuccess: true),
          const PlayerRoundRecord(playerId: 'p2', playerName: 'Bob', declared: 2, actual: 2, scoreDelta: 20, totalScoreAfterRound: 20, isSuccess: true),
          const PlayerRoundRecord(playerId: 'p3', playerName: 'Charlie', declared: 1, actual: 1, scoreDelta: 10, totalScoreAfterRound: 10, isSuccess: true),
          const PlayerRoundRecord(playerId: 'p4', playerName: 'Diana', declared: 1, actual: 0, scoreDelta: -10, totalScoreAfterRound: -10, isSuccess: false),
        ],
      );
      final round2 = RoundHistoryRecord(
        roundNumber: 2,
        playerRecords: [
          const PlayerRoundRecord(playerId: 'p1', playerName: 'Alice', declared: 1, actual: 0, scoreDelta: -10, totalScoreAfterRound: 20, isSuccess: false),
          const PlayerRoundRecord(playerId: 'p2', playerName: 'Bob', declared: 1, actual: 0, scoreDelta: -10, totalScoreAfterRound: 10, isSuccess: false),
          const PlayerRoundRecord(playerId: 'p3', playerName: 'Charlie', declared: 1, actual: 0, scoreDelta: -10, totalScoreAfterRound: 0, isSuccess: false),
          const PlayerRoundRecord(playerId: 'p4', playerName: 'Diana', declared: 5, actual: 5, scoreDelta: 50, totalScoreAfterRound: 40, isSuccess: true),
        ],
      );

      final state = GameState(
        players: [
          Player(id: 'p1', name: 'Alice', seatIndex: 0, totalScore: 20),
          Player(id: 'p2', name: 'Bob', seatIndex: 1, totalScore: 10),
          Player(id: 'p3', name: 'Charlie', seatIndex: 2, totalScore: 0),
          Player(id: 'p4', name: 'Diana', seatIndex: 3, totalScore: 40),
        ],
        roundNumber: 2,
        totalRounds: 18,
        roundHistory: [round1, round2],
      );

      final dianaComebacks = ComebackDetector.detectMatchComebacks(
        state: state,
        playerId: 'p4',
      );
      expect(dianaComebacks.length, 1);
      expect(dianaComebacks.first.type, ComebackType.majorComeback);

      final aliceComebacks = ComebackDetector.detectMatchComebacks(
        state: state,
        playerId: 'p1',
      );
      expect(aliceComebacks.isEmpty, isTrue);
    });
  });

  group('EstimationStatistics Comeback Serialization Tests', () {
    test('EstimationStatistics serializes and deserializes comeback fields correctly', () {
      const stats = EstimationStatistics(
        gamesPlayed: 10,
        gamesWon: 6,
        bestComeback: 35,
        totalComebacks: 4,
        majorComebacks: 2,
        finalRoundComebacks: 1,
      );

      final json = stats.toJson();
      expect(json['bestComeback'], 35);
      expect(json['totalComebacks'], 4);
      expect(json['majorComebacks'], 2);
      expect(json['finalRoundComebacks'], 1);

      final restored = EstimationStatistics.fromJson(json);
      expect(restored.bestComeback, 35);
      expect(restored.totalComebacks, 4);
      expect(restored.majorComebacks, 2);
      expect(restored.finalRoundComebacks, 1);
    });
  });

  group('RankingService Comeback XP Bonus Tests', () {
    test('calculateKotshinaReward awards comeback bonus XP', () {
      final round1 = RoundHistoryRecord(
        roundNumber: 1,
        playerRecords: [
          const PlayerRoundRecord(playerId: 'p1', playerName: 'Alice', declared: 3, actual: 3, scoreDelta: 30, totalScoreAfterRound: 30, isSuccess: true),
          const PlayerRoundRecord(playerId: 'p2', playerName: 'Bob', declared: 1, actual: 0, scoreDelta: -10, totalScoreAfterRound: -10, isSuccess: false),
        ],
      );
      final round2 = RoundHistoryRecord(
        roundNumber: 2,
        playerRecords: [
          const PlayerRoundRecord(playerId: 'p1', playerName: 'Alice', declared: 1, actual: 0, scoreDelta: -10, totalScoreAfterRound: 20, isSuccess: false),
          const PlayerRoundRecord(playerId: 'p2', playerName: 'Bob', declared: 5, actual: 5, scoreDelta: 50, totalScoreAfterRound: 40, isSuccess: true),
        ],
      );

      final state = GameState(
        players: [
          Player(id: 'p1', name: 'Alice', seatIndex: 0, totalScore: 20),
          Player(id: 'p2', name: 'Bob', seatIndex: 1, totalScore: 40),
        ],
        roundNumber: 2,
        totalRounds: 18,
        roundHistory: [round1, round2],
      );

      final breakdown = RankingService.instance.calculateKotshinaReward(
        state: state,
        myPlayerId: 'p2',
        myPlayerName: 'Bob',
      );

      expect(breakdown.won, isTrue);
      expect(breakdown.comebackBonus, 35); // Major comeback bonus = 35 XP
      expect(breakdown.totalXp, greaterThan(150));
    });
  });
}
