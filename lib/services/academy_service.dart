// lib/services/academy_service.dart

import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/academy_models.dart';
import '../core/data/academy_curriculum_data.dart';
import 'auth_service.dart';

class AcademyService {
  static const String _kStorageKey = 'estimation_academy_progress_v1';

  AcademyService._internal() {
    _curriculum = AcademyCurriculumData.getCurriculum();
  }
  static final AcademyService instance = AcademyService._internal();

  late final List<AcademyTopic> _curriculum;
  final ValueNotifier<AcademyProgress> progressNotifier =
      ValueNotifier<AcademyProgress>(const AcademyProgress());

  bool _isInitialized = false;

  List<AcademyTopic> get topics => List.unmodifiable(_curriculum);

  AcademyProgress get currentProgress => progressNotifier.value;

  int get totalLessonsCount {
    return _curriculum.fold<int>(0, (sum, t) => sum + t.lessons.length);
  }

  /// Initialize service and load saved progress
  Future<void> initialize() async {
    if (_isInitialized) return;
    await loadProgress();
    _isInitialized = true;
  }

  /// Loads saved progress from SharedPreferences
  Future<AcademyProgress> loadProgress() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final rawJson = prefs.getString(_kStorageKey);
      if (rawJson != null && rawJson.isNotEmpty) {
        final decoded = jsonDecode(rawJson) as Map<String, dynamic>;
        final loadedProgress = AcademyProgress.fromJson(decoded);
        progressNotifier.value = loadedProgress;
        return loadedProgress;
      }
    } catch (e) {
      debugPrint('[AcademyService] Error loading progress: $e');
    }
    progressNotifier.value = const AcademyProgress();
    return progressNotifier.value;
  }

  /// Saves current progress to SharedPreferences
  Future<void> _saveProgress() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final jsonStr = jsonEncode(progressNotifier.value.toJson());
      await prefs.setString(_kStorageKey, jsonStr);
    } catch (e) {
      debugPrint('[AcademyService] Error saving progress: $e');
    }
  }

  /// Finds a topic by its id
  AcademyTopic? getTopicById(String topicId) {
    try {
      return _curriculum.firstWhere((t) => t.id == topicId);
    } catch (_) {
      return null;
    }
  }

  /// Finds a lesson and its parent topic by lesson id
  ({AcademyLesson lesson, AcademyTopic topic})? getLessonWithTopic(String lessonId) {
    for (final topic in _curriculum) {
      for (final lesson in topic.lessons) {
        if (lesson.id == lessonId) {
          return (lesson: lesson, topic: topic);
        }
      }
    }
    return null;
  }

  /// Returns the next unfinished lesson in sequential order
  AcademyLesson? getNextUnfinishedLesson() {
    for (final topic in _curriculum) {
      for (final lesson in topic.lessons) {
        if (!progressNotifier.value.isLessonCompleted(lesson.id)) {
          return lesson;
        }
      }
    }
    return null;
  }

  /// Records an attempt and evaluates completion of a lesson
  Future<bool> submitAnswer({
    required AcademyLesson lesson,
    required AcademyScenarioOption option,
  }) async {
    final prev = progressNotifier.value;

    final currentAttempts = prev.getAttempts(lesson.id) + 1;
    final updatedAttempts = Map<String, int>.from(prev.lessonAttempts);
    updatedAttempts[lesson.id] = currentAttempts;

    final isOptimal = option.isOptimal;
    final isAcceptable = option.isAcceptable;

    // Calculate score for this attempt (100 for optimal, 80 for strong, 0 otherwise)
    final attemptScore = isOptimal ? 100 : (isAcceptable ? 80 : 0);

    final updatedScores = Map<String, int>.from(prev.lessonBestScores);
    final prevBest = updatedScores[lesson.id] ?? 0;
    if (attemptScore > prevBest) {
      updatedScores[lesson.id] = attemptScore;
    }

    final updatedCompleted = Set<String>.from(prev.completedLessonIds);
    int awardedXp = 0;

    // Complete lesson if acceptable or optimal
    if (isAcceptable) {
      if (!updatedCompleted.contains(lesson.id)) {
        updatedCompleted.add(lesson.id);
        awardedXp = lesson.xpReward;

        // Sync XP with user profile if authenticated
        try {
          final auth = AuthService.instance;
          if (auth.isAuthenticated) {
            await auth.recordGameResult(won: true, xpGain: awardedXp);
          }
        } catch (e) {
          debugPrint('[AcademyService] XP reward sync error: $e');
        }
      }
    }

    progressNotifier.value = prev.copyWith(
      completedLessonIds: updatedCompleted,
      lessonAttempts: updatedAttempts,
      lessonBestScores: updatedScores,
      totalXpEarned: prev.totalXpEarned + awardedXp,
      lastActivity: DateTime.now(),
    );

    await _saveProgress();
    return isAcceptable;
  }

  /// Resets all academy progress (for testing / fresh start)
  Future<void> resetProgress() async {
    progressNotifier.value = const AcademyProgress();
    await _saveProgress();
  }
}
