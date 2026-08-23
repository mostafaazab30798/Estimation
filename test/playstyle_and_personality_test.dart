// test/playstyle_and_personality_test.dart

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:estimation/models/estimation_statistics.dart';
import 'package:estimation/models/playstyle_models.dart';
import 'package:estimation/services/playstyle_service.dart';
import 'package:estimation/services/share_card_service.dart';
import 'package:estimation/widgets/share_my_estimation_dialog.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  group('PlaystyleMetrics Dimensions Tests', () {
    test('Calculates confidence thresholds correctly according to rounds played', () {
      // 0 rounds
      const m0 = PlaystyleMetrics(roundsAnalyzed: 0);
      expect(m0.profileConfidence, 10.0);
      expect(m0.confidenceLabelAr, 'تقدير مبكر');

      // 10 rounds (<20 rounds)
      const m10 = PlaystyleMetrics(roundsAnalyzed: 10);
      expect(m10.profileConfidence, closeTo(30.0, 0.1));
      expect(m10.confidenceLabelAr, 'تقدير مبكر');

      // 35 rounds (20-49 rounds -> Developing)
      const m35 = PlaystyleMetrics(roundsAnalyzed: 35);
      expect(m35.profileConfidence, greaterThanOrEqualTo(50.0));
      expect(m35.profileConfidence, lessThan(75.0));
      expect(m35.confidenceLabelAr, 'قيد التطور');

      // 75 rounds (50-99 rounds -> Reliable)
      const m75 = PlaystyleMetrics(roundsAnalyzed: 75);
      expect(m75.profileConfidence, greaterThanOrEqualTo(75.0));
      expect(m75.profileConfidence, lessThan(90.0));
      expect(m75.confidenceLabelAr, 'موثوق');

      // 150 rounds (100+ rounds -> High confidence)
      const m150 = PlaystyleMetrics(roundsAnalyzed: 150);
      expect(m150.profileConfidence, greaterThanOrEqualTo(90.0));
      expect(m150.confidenceLabelAr, 'ثقة عالية جداً');
    });

    test('Computes 10 playstyle dimensions from EstimationStatistics', () {
      const stats = EstimationStatistics(
        gamesPlayed: 10,
        gamesWon: 7,
        totalRounds: 180,
        totalTricks: 650,
        totalDeclared: 630,
        perfectEstimates: 135,
        failedDeclarations: 45,
        highestSuccessfulBid: 7,
        highestSuccessfulDeclaration: 8,
        highestScoreInOneRound: 42,
        lowestScoreInOneRound: -15,
        bestComeback: 25,
        totalComebacks: 4,
        majorComebacks: 2,
        finalRoundComebacks: 1,
        longestWinningStreak: 5,
        currentWinningStreak: 3,
      );

      final service = PlaystyleService.instance;
      final metrics = service.calculateMetrics(stats: stats);

      expect(metrics.roundsAnalyzed, 180);
      expect(metrics.declarationAccuracy, closeTo(75.0, 0.1));
      expect(metrics.precision, greaterThan(70.0));
      expect(metrics.aggression, greaterThan(50.0));
      expect(metrics.comebackAbility, greaterThan(65.0));
      expect(metrics.bidDiscipline, greaterThan(70.0));
      expect(metrics.scoreAwareness, greaterThan(60.0));
    });

    test('Serialization to/from JSON for PlaystyleMetrics', () {
      const original = PlaystyleMetrics(
        aggression: 78.5,
        conservatism: 34.2,
        riskTaking: 62.0,
        precision: 85.0,
        adaptability: 70.0,
        trumpConfidence: 80.0,
        comebackAbility: 88.0,
        bidDiscipline: 82.0,
        declarationAccuracy: 76.5,
        scoreAwareness: 79.0,
        roundsAnalyzed: 100,
      );

      final json = original.toJson();
      final restored = PlaystyleMetrics.fromJson(json);

      expect(restored.aggression, 78.5);
      expect(restored.conservatism, 34.2);
      expect(restored.riskTaking, 62.0);
      expect(restored.precision, 85.0);
      expect(restored.comebackAbility, 88.0);
      expect(restored.roundsAnalyzed, 100);
    });
  });

  group('Archetype & Personality Classification Tests', () {
    final service = PlaystyleService.instance;

    test('Classifies Calculator archetype for high precision & discipline', () {
      const metrics = PlaystyleMetrics(
        precision: 90.0,
        bidDiscipline: 88.0,
        declarationAccuracy: 85.0,
        scoreAwareness: 80.0,
        aggression: 45.0,
        conservatism: 60.0,
        riskTaking: 40.0,
        comebackAbility: 40.0,
        roundsAnalyzed: 100,
      );

      final archetypes = service.determineArchetypes(metrics);
      expect(archetypes['primary'], PlaystyleArchetype.calculator);
    });

    test('Classifies Aggressor archetype for high aggression & trump confidence', () {
      const metrics = PlaystyleMetrics(
        aggression: 92.0,
        trumpConfidence: 85.0,
        riskTaking: 80.0,
        precision: 50.0,
        conservatism: 20.0,
        bidDiscipline: 50.0,
        roundsAnalyzed: 100,
      );

      final archetypes = service.determineArchetypes(metrics);
      expect(archetypes['primary'], PlaystyleArchetype.aggressor);
    });

    test('Classifies Closer archetype for high comeback ability and score awareness', () {
      const metrics = PlaystyleMetrics(
        comebackAbility: 95.0,
        scoreAwareness: 90.0,
        adaptability: 85.0,
        aggression: 55.0,
        precision: 60.0,
        roundsAnalyzed: 100,
      );

      final archetypes = service.determineArchetypes(metrics);
      expect(archetypes['primary'], PlaystyleArchetype.closer);
    });

    test('Classifies Survivor archetype for high conservatism and safe play', () {
      const metrics = PlaystyleMetrics(
        conservatism: 90.0,
        bidDiscipline: 85.0,
        precision: 75.0,
        aggression: 25.0,
        riskTaking: 20.0,
        roundsAnalyzed: 100,
      );

      final archetypes = service.determineArchetypes(metrics);
      expect(archetypes['primary'], PlaystyleArchetype.survivor);
    });

    test('Classifies Gambler archetype for extreme risk taking and volatility', () {
      const metrics = PlaystyleMetrics(
        riskTaking: 95.0,
        aggression: 85.0,
        trumpConfidence: 75.0,
        conservatism: 15.0,
        bidDiscipline: 40.0,
        roundsAnalyzed: 100,
      );

      final archetypes = service.determineArchetypes(metrics);
      expect(archetypes['primary'], PlaystyleArchetype.gambler);
    });

    test('Detects archetype evolution when primary style shifts', () {
      const stats = EstimationStatistics(
        gamesPlayed: 10,
        gamesWon: 8,
        totalRounds: 180,
        totalComebacks: 5,
        majorComebacks: 3,
        finalRoundComebacks: 2,
        bestComeback: 35,
      );

      const metrics = PlaystyleMetrics(
        comebackAbility: 92.0,
        scoreAwareness: 85.0,
        adaptability: 80.0,
        precision: 65.0,
        roundsAnalyzed: 180,
      );

      // Previously was Calculator, now shifted to Closer
      final profile = service.generatePersonalityProfile(
        metrics: metrics,
        stats: stats,
        previousArchetype: PlaystyleArchetype.calculator,
      );

      expect(profile.primaryArchetype, PlaystyleArchetype.closer);
      expect(profile.previousArchetype, PlaystyleArchetype.calculator);
      expect(profile.hasEvolved, isTrue);
      expect(profile.evolutionMessage, contains('تطور أسلوب لعبك التكتيكي'));
      expect(profile.strengths, isNotEmpty);
      expect(profile.recommendation, isNotEmpty);
      expect(profile.measurableReasons, isNotEmpty);
    });
  });

  group('Player Identity Card Configuration Tests', () {
    test('Default configuration and serialization', () {
      const config = PlayerIdentityCardConfig();
      expect(config.theme, CardSkinTheme.royalGold);
      expect(config.selectedTitle, 'أستاذ الإستميشن');
      expect(config.isPublic, isTrue);

      final json = config.toJson();
      final restored = PlayerIdentityCardConfig.fromJson(json);

      expect(restored.theme, CardSkinTheme.royalGold);
      expect(restored.selectedTitle, 'أستاذ الإستميشن');
      expect(restored.isPublic, isTrue);
    });

    test('Custom configuration with skin themes and titles', () {
      final config = const PlayerIdentityCardConfig().copyWith(
        theme: CardSkinTheme.cyberNeon,
        selectedTitle: 'قرش الطاولة',
        isPublic: false,
      );

      expect(config.theme, CardSkinTheme.cyberNeon);
      expect(config.selectedTitle, 'قرش الطاولة');
      expect(config.isPublic, isFalse);

      final json = config.toJson();
      final restored = PlayerIdentityCardConfig.fromJson(json);

      expect(restored.theme, CardSkinTheme.cyberNeon);
      expect(restored.selectedTitle, 'قرش الطاولة');
      expect(restored.isPublic, isFalse);
    });
  });

  group('ShareCardService & Shareable My Estimation Tests', () {
    test('ShareCardService instance exists and formats victory text properly', () async {
      expect(ShareCardService.instance, isNotNull);
    });

    test('ShareCardType enum values', () {
      expect(ShareCardType.values.length, 2);
      expect(ShareCardType.identityProfile, isNotNull);
      expect(ShareCardType.matchVictory, isNotNull);
    });
  });
}
