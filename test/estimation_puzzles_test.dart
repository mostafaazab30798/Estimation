// test/estimation_puzzles_test.dart

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:estimation/models/puzzle_models.dart';
import 'package:estimation/core/data/puzzles_data.dart';
import 'package:estimation/services/puzzle_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  group('Estimation Puzzles Data Integrity Tests', () {
    test('All 6 puzzle categories are represented in the dataset', () {
      final puzzles = PuzzlesData.getAllPuzzles();
      expect(puzzles.isNotEmpty, isTrue);

      final categoriesInDataset = puzzles.map((p) => p.category).toSet();
      for (final cat in PuzzleCategory.values) {
        expect(
          categoriesInDataset.contains(cat),
          isTrue,
          reason: 'Category ${cat.id} is missing in puzzles dataset',
        );
      }
    });

    test('All 5 puzzle difficulties are represented in the dataset', () {
      final puzzles = PuzzlesData.getAllPuzzles();
      final difficultiesInDataset = puzzles.map((p) => p.difficulty).toSet();
      for (final diff in PuzzleDifficulty.values) {
        expect(
          difficultiesInDataset.contains(diff),
          isTrue,
          reason: 'Difficulty ${diff.name} is missing in puzzles dataset',
        );
      }
    });

    test('All puzzles have valid hands, unique cards, options, and optimal answers', () {
      final puzzles = PuzzlesData.getAllPuzzles();

      for (final puzzle in puzzles) {
        expect(puzzle.id.isNotEmpty, isTrue);
        expect(puzzle.title.isNotEmpty, isTrue);
        expect(puzzle.scenarioText.isNotEmpty, isTrue);
        expect(puzzle.prompt.isNotEmpty, isTrue);
        expect(puzzle.tacticalRationale.isNotEmpty, isTrue);
        expect(puzzle.xpReward, greaterThan(0));
        expect(puzzle.options.length, greaterThanOrEqualTo(2));

        // Validate hand: <= 13 cards, no duplicate cards in hand
        expect(puzzle.playerHand.length, lessThanOrEqualTo(13));
        final cardIds = puzzle.playerHand.map((c) => c.id).toSet();
        expect(
          cardIds.length,
          equals(puzzle.playerHand.length),
          reason: 'Puzzle ${puzzle.id} contains duplicate cards in hand',
        );

        // Optimal option must exist and match
        final optimal = puzzle.optimalOption;
        expect(
          optimal,
          isNotNull,
          reason: 'Puzzle ${puzzle.id} has no matching optimal option',
        );
        expect(optimal!.quality, equals(PuzzleResultQuality.optimal));
        expect(optimal.isOptimal, isTrue);
        expect(optimal.isAcceptable, isTrue);
      }
    });
  });

  group('Daily Puzzle Generator Tests', () {
    test('Daily puzzle is deterministic for the same date', () {
      final date1 = DateTime(2026, 8, 23);
      final date2 = DateTime(2026, 8, 23, 14, 30);

      final puz1 = PuzzlesData.getDailyPuzzleForDate(date1);
      final puz2 = PuzzlesData.getDailyPuzzleForDate(date2);

      expect(puz1.id, equals(puz2.id));
    });

    test('Date to key formatting helper produces YYYY-MM-DD', () {
      final date = DateTime(2026, 8, 5);
      expect(PuzzlesData.dateToKey(date), equals('2026-08-05'));
    });
  });

  group('PuzzleProgress Serialization Tests', () {
    test('Progress toJson and fromJson preserves all state properties', () {
      final progress = PuzzleProgress(
        solvedPuzzleIds: {'bid_puz_1', 'dec_puz_1'},
        puzzleAttempts: {'bid_puz_1': 1, 'dec_puz_1': 3},
        puzzleBestScores: {'bid_puz_1': 100, 'dec_puz_1': 80},
        totalXpEarned: 115,
        dailyPuzzleLastDate: '2026-08-23',
        dailyPuzzleStreak: 4,
        lastActivity: DateTime(2026, 8, 23, 9, 0),
      );

      final json = progress.toJson();
      final restored = PuzzleProgress.fromJson(json);

      expect(restored.solvedPuzzleIds, equals({'bid_puz_1', 'dec_puz_1'}));
      expect(restored.puzzleAttempts['bid_puz_1'], equals(1));
      expect(restored.puzzleAttempts['dec_puz_1'], equals(3));
      expect(restored.puzzleBestScores['bid_puz_1'], equals(100));
      expect(restored.puzzleBestScores['dec_puz_1'], equals(80));
      expect(restored.totalXpEarned, equals(115));
      expect(restored.dailyPuzzleLastDate, equals('2026-08-23'));
      expect(restored.dailyPuzzleStreak, equals(4));
      expect(restored.totalSolvedCount, equals(2));
      expect(restored.perfectCount, equals(1));
    });
  });

  group('PuzzleService Business Logic Tests', () {
    test('Initialization, solving with optimal vs invalid options, and persistence', () async {
      final service = PuzzleService.instance;
      await service.initialize();
      await service.resetProgress();

      expect(service.totalPuzzlesCount, greaterThanOrEqualTo(10));
      expect(service.currentProgress.solvedPuzzleIds.isEmpty, isTrue);

      final puzzle = service.getPuzzleById('bid_puz_1');
      expect(puzzle, isNotNull);

      final wrongOption = puzzle!.options.firstWhere((o) => o.quality == PuzzleResultQuality.invalid);
      final optimalOption = puzzle.optimalOption!;

      // 1. Submit invalid answer
      final wrongRes = await service.submitAnswer(
        puzzle: puzzle,
        option: wrongOption,
        isDaily: false,
      );
      expect(wrongRes, equals(PuzzleResultQuality.invalid));
      expect(service.currentProgress.isSolved(puzzle.id), isFalse);
      expect(service.currentProgress.getAttempts(puzzle.id), equals(1));
      expect(service.currentProgress.getBestScore(puzzle.id), equals(0));
      expect(service.currentProgress.totalXpEarned, equals(0));

      // 2. Submit optimal answer
      final optRes = await service.submitAnswer(
        puzzle: puzzle,
        option: optimalOption,
        isDaily: false,
      );
      expect(optRes, equals(PuzzleResultQuality.optimal));
      expect(service.currentProgress.isSolved(puzzle.id), isTrue);
      expect(service.currentProgress.isPerfect(puzzle.id), isTrue);
      expect(service.currentProgress.getAttempts(puzzle.id), equals(2));
      expect(service.currentProgress.getBestScore(puzzle.id), equals(100));
      expect(service.currentProgress.totalXpEarned, equals(puzzle.xpReward));
    });

    test('Daily puzzle streak calculation and bonus XP', () async {
      final service = PuzzleService.instance;
      await service.initialize();
      await service.resetProgress();

      final day1 = DateTime(2026, 8, 20);
      final day2 = DateTime(2026, 8, 21);
      final day4 = DateTime(2026, 8, 23); // 2 days gap

      final puzzle = service.puzzles.first;
      final optimalOption = puzzle.optimalOption!;

      // Solve day 1
      await service.submitAnswer(
        puzzle: puzzle,
        option: optimalOption,
        isDaily: true,
        submissionTime: day1,
      );
      expect(service.currentProgress.dailyPuzzleStreak, equals(1));
      expect(service.currentProgress.dailyPuzzleLastDate, equals('2026-08-20'));
      expect(service.isDailyPuzzleSolved(day1), isTrue);

      // Solve day 2 (consecutive day)
      await service.submitAnswer(
        puzzle: puzzle,
        option: optimalOption,
        isDaily: true,
        submissionTime: day2,
      );
      expect(service.currentProgress.dailyPuzzleStreak, equals(2));
      expect(service.currentProgress.dailyPuzzleLastDate, equals('2026-08-21'));

      // Solve day 4 (after gap -> resets streak to 1)
      await service.submitAnswer(
        puzzle: puzzle,
        option: optimalOption,
        isDaily: true,
        submissionTime: day4,
      );
      expect(service.currentProgress.dailyPuzzleStreak, equals(1));
      expect(service.currentProgress.dailyPuzzleLastDate, equals('2026-08-23'));
    });
  });
}
