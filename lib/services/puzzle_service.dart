// lib/services/puzzle_service.dart

import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/puzzle_models.dart';
import '../core/data/puzzles_data.dart';
import 'auth_service.dart';

class PuzzleService {
  static const String _kStorageKey = 'estimation_puzzle_progress_v1';

  PuzzleService._internal() {
    _puzzles = PuzzlesData.getAllPuzzles();
  }
  static final PuzzleService instance = PuzzleService._internal();

  late final List<EstimationPuzzle> _puzzles;
  final ValueNotifier<PuzzleProgress> progressNotifier =
      ValueNotifier<PuzzleProgress>(const PuzzleProgress());

  bool _isInitialized = false;

  List<EstimationPuzzle> get puzzles => List.unmodifiable(_puzzles);

  PuzzleProgress get currentProgress => progressNotifier.value;

  int get totalPuzzlesCount => _puzzles.length;

  /// Initialize service and load stored user progress
  Future<void> initialize() async {
    if (_isInitialized) return;
    await loadProgress();
    _isInitialized = true;
  }

  /// Loads saved progress from SharedPreferences
  Future<PuzzleProgress> loadProgress() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final rawJson = prefs.getString(_kStorageKey);
      if (rawJson != null && rawJson.isNotEmpty) {
        final decoded = jsonDecode(rawJson) as Map<String, dynamic>;
        final loadedProgress = PuzzleProgress.fromJson(decoded);
        progressNotifier.value = loadedProgress;
        return loadedProgress;
      }
    } catch (e) {
      debugPrint('[PuzzleService] Error loading puzzle progress: $e');
    }
    progressNotifier.value = const PuzzleProgress();
    return progressNotifier.value;
  }

  /// Saves current progress to local storage
  Future<void> _saveProgress() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final jsonStr = jsonEncode(progressNotifier.value.toJson());
      await prefs.setString(_kStorageKey, jsonStr);
    } catch (e) {
      debugPrint('[PuzzleService] Error saving puzzle progress: $e');
    }
  }

  /// Find a puzzle by its unique ID
  EstimationPuzzle? getPuzzleById(String puzzleId) {
    try {
      return _puzzles.firstWhere((p) => p.id == puzzleId);
    } catch (_) {
      return null;
    }
  }

  /// Get puzzles filtered by category
  List<EstimationPuzzle> getPuzzlesByCategory(PuzzleCategory category) {
    return _puzzles.where((p) => p.category == category).toList();
  }

  /// Get puzzles filtered by difficulty
  List<EstimationPuzzle> getPuzzlesByDifficulty(PuzzleDifficulty difficulty) {
    return _puzzles.where((p) => p.difficulty == difficulty).toList();
  }

  /// Returns the daily puzzle for today (or specified date)
  EstimationPuzzle getDailyPuzzle([DateTime? date]) {
    final targetDate = date ?? DateTime.now();
    return PuzzlesData.getDailyPuzzleForDate(targetDate);
  }

  /// Checks if the daily puzzle for today has been solved
  bool isDailyPuzzleSolved([DateTime? date]) {
    final targetDate = date ?? DateTime.now();
    final todayKey = PuzzlesData.dateToKey(targetDate);
    return progressNotifier.value.dailyPuzzleLastDate == todayKey;
  }

  /// Submits an answer for a puzzle and updates progress
  Future<PuzzleResultQuality> submitAnswer({
    required EstimationPuzzle puzzle,
    required PuzzleOption option,
    bool isDaily = false,
    DateTime? submissionTime,
  }) async {
    final prev = progressNotifier.value;
    final now = submissionTime ?? DateTime.now();
    final todayKey = PuzzlesData.dateToKey(now);

    final currentAttempts = prev.getAttempts(puzzle.id) + 1;
    final updatedAttempts = Map<String, int>.from(prev.puzzleAttempts);
    updatedAttempts[puzzle.id] = currentAttempts;

    final scorePoints = option.quality.scorePoints;
    final updatedScores = Map<String, int>.from(prev.puzzleBestScores);
    final prevBest = updatedScores[puzzle.id] ?? 0;
    if (scorePoints > prevBest) {
      updatedScores[puzzle.id] = scorePoints;
    }

    final updatedSolved = Set<String>.from(prev.solvedPuzzleIds);
    int awardedXp = 0;
    int updatedStreak = prev.dailyPuzzleStreak;
    String? updatedDailyDate = prev.dailyPuzzleLastDate;

    final isSuccessful = option.quality.isSuccessful;

    if (isSuccessful) {
      final wasAlreadySolved = updatedSolved.contains(puzzle.id);
      if (!wasAlreadySolved) {
        updatedSolved.add(puzzle.id);
        awardedXp += puzzle.xpReward;
      }

      // If this was attempted as the Daily Puzzle
      if (isDaily) {
        if (prev.dailyPuzzleLastDate != todayKey) {
          final yesterday = now.subtract(const Duration(days: 1));
          final yesterdayKey = PuzzlesData.dateToKey(yesterday);

          if (prev.dailyPuzzleLastDate == yesterdayKey) {
            updatedStreak = prev.dailyPuzzleStreak + 1;
          } else {
            updatedStreak = 1; // Start new streak
          }
          updatedDailyDate = todayKey;
          // Extra daily puzzle bonus XP
          awardedXp += 25;
        }
      }

      // Sync XP with user profile if authenticated
      if (awardedXp > 0) {
        try {
          final auth = AuthService.instance;
          if (auth.isAuthenticated) {
            await auth.recordGameResult(won: true, xpGain: awardedXp);
          }
        } catch (e) {
          debugPrint('[PuzzleService] XP reward sync error: $e');
        }
      }
    }

    progressNotifier.value = prev.copyWith(
      solvedPuzzleIds: updatedSolved,
      puzzleAttempts: updatedAttempts,
      puzzleBestScores: updatedScores,
      totalXpEarned: prev.totalXpEarned + awardedXp,
      dailyPuzzleLastDate: updatedDailyDate,
      dailyPuzzleStreak: updatedStreak,
      lastActivity: now,
    );

    await _saveProgress();
    return option.quality;
  }

  /// Resets all puzzle progress (for testing / debug)
  Future<void> resetProgress() async {
    progressNotifier.value = const PuzzleProgress();
    await _saveProgress();
  }
}
