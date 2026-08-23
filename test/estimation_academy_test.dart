// test/estimation_academy_test.dart

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:estimation/models/academy_models.dart';
import 'package:estimation/core/data/academy_curriculum_data.dart';
import 'package:estimation/services/academy_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  group('Estimation Academy Curriculum Tests', () {
    test('Curriculum has 13 topics and all required properties', () {
      final curriculum = AcademyCurriculumData.getCurriculum();
      expect(curriculum.length, equals(13));

      final expectedTopicIds = [
        'getting_started',
        'reading_hand',
        'bidding',
        'declaration',
        'trump_strategy',
        'sans_strategy',
        'dash_call',
        'risk',
        'forbidden_13',
        'trick_taking',
        'score_management',
        'advanced_strategy',
        'master_challenges',
      ];

      for (int i = 0; i < expectedTopicIds.length; i++) {
        expect(curriculum[i].id, equals(expectedTopicIds[i]));
        expect(curriculum[i].title.isNotEmpty, isTrue);
        expect(curriculum[i].subtitle.isNotEmpty, isTrue);
        expect(curriculum[i].icon.isNotEmpty, isTrue);
        expect(curriculum[i].lessons.isNotEmpty, isTrue);
      }
    });

    test('All lessons have valid hands, scenarios, and optimal answers', () {
      final curriculum = AcademyCurriculumData.getCurriculum();

      for (final topic in curriculum) {
        for (final lesson in topic.lessons) {
          expect(lesson.id.isNotEmpty, isTrue);
          expect(lesson.title.isNotEmpty, isTrue);
          expect(lesson.theoryExplanation.isNotEmpty, isTrue);
          expect(lesson.concepts.isNotEmpty, isTrue);
          expect(lesson.proTip.isNotEmpty, isTrue);
          expect(lesson.xpReward, greaterThan(0));

          final scenario = lesson.scenario;
          expect(scenario.id.isNotEmpty, isTrue);
          expect(scenario.prompt.isNotEmpty, isTrue);
          expect(scenario.options.length, greaterThanOrEqualTo(2));
          expect(scenario.tacticalRationale.isNotEmpty, isTrue);

          // Verify hand validity: <= 13 cards, no duplicates
          expect(scenario.hand.length, lessThanOrEqualTo(13));
          final cardIds = scenario.hand.map((c) => c.id).toSet();
          expect(cardIds.length, equals(scenario.hand.length),
              reason: 'Lesson ${lesson.id} has duplicate cards in hand');

          // Verify optimal option exists
          final optimalOption = scenario.options.firstWhere(
            (o) => o.id == scenario.optimalOptionId,
            orElse: () => throw StateError('No matching optimal option for ${lesson.id}'),
          );
          expect(optimalOption.isOptimal, isTrue);
        }
      }
    });
  });

  group('AcademyProgress & Mastery Tier Tests', () {
    test('Mastery Tier transitions based on percentage', () {
      expect(AcademyMasteryTier.fromPercentage(0.0), equals(AcademyMasteryTier.notStarted));
      expect(AcademyMasteryTier.fromPercentage(0.14), equals(AcademyMasteryTier.notStarted));
      expect(AcademyMasteryTier.fromPercentage(0.15), equals(AcademyMasteryTier.learning));
      expect(AcademyMasteryTier.fromPercentage(0.39), equals(AcademyMasteryTier.learning));
      expect(AcademyMasteryTier.fromPercentage(0.40), equals(AcademyMasteryTier.practicing));
      expect(AcademyMasteryTier.fromPercentage(0.69), equals(AcademyMasteryTier.practicing));
      expect(AcademyMasteryTier.fromPercentage(0.70), equals(AcademyMasteryTier.proficient));
      expect(AcademyMasteryTier.fromPercentage(0.94), equals(AcademyMasteryTier.proficient));
      expect(AcademyMasteryTier.fromPercentage(0.95), equals(AcademyMasteryTier.mastered));
      expect(AcademyMasteryTier.fromPercentage(1.0), equals(AcademyMasteryTier.mastered));
    });

    test('Progress serialization toJson and fromJson preserves state', () {
      final progress = AcademyProgress(
        completedLessonIds: {'getting_started_1', 'reading_hand_1'},
        lessonAttempts: {'getting_started_1': 1, 'reading_hand_1': 2},
        lessonBestScores: {'getting_started_1': 100, 'reading_hand_1': 80},
        totalXpEarned: 80,
        lastActivity: DateTime(2026, 8, 23),
      );

      final json = progress.toJson();
      final restored = AcademyProgress.fromJson(json);

      expect(restored.completedLessonIds, equals({'getting_started_1', 'reading_hand_1'}));
      expect(restored.lessonAttempts['getting_started_1'], equals(1));
      expect(restored.lessonAttempts['reading_hand_1'], equals(2));
      expect(restored.lessonBestScores['getting_started_1'], equals(100));
      expect(restored.totalXpEarned, equals(80));
    });
  });

  group('AcademyService Tests', () {
    test('Initialization and lesson evaluation logic', () async {
      final service = AcademyService.instance;
      await service.initialize();
      await service.resetProgress();

      expect(service.totalLessonsCount, greaterThanOrEqualTo(13));
      expect(service.currentProgress.completedLessonIds.isEmpty, isTrue);

      final lessonInfo = service.getLessonWithTopic('getting_started_1');
      expect(lessonInfo, isNotNull);

      final lesson = lessonInfo!.lesson;
      final wrongOption = lesson.scenario.options.firstWhere((o) => !o.isOptimal);
      final optimalOption = lesson.scenario.options.firstWhere((o) => o.isOptimal);

      // Submit incorrect option
      final wrongResult = await service.submitAnswer(
        lesson: lesson,
        option: wrongOption,
      );
      if (wrongOption.quality == AnswerQuality.invalid || wrongOption.quality == AnswerQuality.risky) {
        expect(wrongResult, isFalse);
        expect(service.currentProgress.isLessonCompleted(lesson.id), isFalse);
      }
      expect(service.currentProgress.getAttempts(lesson.id), equals(1));

      // Submit optimal option
      final optimalResult = await service.submitAnswer(
        lesson: lesson,
        option: optimalOption,
      );
      expect(optimalResult, isTrue);
      expect(service.currentProgress.isLessonCompleted(lesson.id), isTrue);
      expect(service.currentProgress.getAttempts(lesson.id), equals(2));
      expect(service.currentProgress.totalXpEarned, equals(lesson.xpReward));
    });
  });
}
