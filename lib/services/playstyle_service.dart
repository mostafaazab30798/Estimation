// lib/services/playstyle_service.dart

import 'dart:convert';
import 'dart:math';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/estimation_statistics.dart';
import '../models/playstyle_models.dart';
import '../core/models/game_state.dart';

class PlaystyleService {
  static const String _kProfilePrefix = 'playstyle_profile_v1_';
  static const String _kCardConfigPrefix = 'player_card_config_v1_';
  static const String _kPrevArchetypePrefix = 'playstyle_prev_archetype_v1_';

  PlaystyleService._internal();
  static final PlaystyleService instance = PlaystyleService._internal();

  String _getStorageKey(String prefix, String playerName) {
    final sanitized = playerName.trim().toLowerCase().replaceAll(' ', '_');
    return '$prefix$sanitized';
  }

  /// Calculates the 10 numerical playstyle dimensions from gameplay statistics and history
  PlaystyleMetrics calculateMetrics({
    required EstimationStatistics stats,
    List<RoundHistoryRecord>? recentRounds,
  }) {
    if (stats.totalRounds == 0 && stats.gamesPlayed == 0) {
      return const PlaystyleMetrics();
    }

    final totalRounds = stats.totalRounds;
    final totalDeclarations = stats.totalDeclarations;

    // 1. Declaration Accuracy (0 - 100)
    final double declarationAccuracy = stats.declarationAccuracy.clamp(0.0, 100.0);

    // 2. Precision (0 - 100)
    // Closeness of actual to declared tricks, high when accuracy is high
    final double precision = (declarationAccuracy * 0.85 + (stats.perfectEstimates > 0 ? 15.0 : 0.0)).clamp(0.0, 100.0);

    // 3. Aggression (0 - 100)
    // Average declared tricks (average player declares ~3.25 tricks out of 13)
    // Avg 2.0 tricks -> ~35, Avg 3.25 -> 50, Avg 5.0 -> 80, Avg 7.0+ -> 98
    final avgDec = stats.averageDeclaredTricks;
    double rawAggression = 50.0;
    if (totalRounds > 0) {
      rawAggression = 20.0 + (avgDec / 6.0) * 60.0 + (stats.highestSuccessfulBid > 6 ? 15.0 : (stats.highestSuccessfulBid > 4 ? 8.0 : 0.0));
    }
    final double aggression = rawAggression.clamp(10.0, 99.0);

    // 4. Conservatism (0 - 100)
    // High when average declared tricks is modest and accuracy is preserved
    double rawConservatism = 50.0;
    if (totalRounds > 0) {
      final safeDecRatio = (6.0 - avgDec).clamp(0.0, 6.0) / 6.0;
      rawConservatism = (safeDecRatio * 60.0) + (declarationAccuracy * 0.4);
    }
    final double conservatism = rawConservatism.clamp(10.0, 99.0);

    // 5. Risk Taking (0 - 100)
    // Driven by highest successful bids, volatile scores, high declarations
    double rawRiskTaking = 50.0;
    if (totalRounds > 0) {
      final bidFactor = (stats.highestSuccessfulBid / 9.0) * 45.0;
      final decFactor = (stats.highestSuccessfulDeclaration / 9.0) * 35.0;
      rawRiskTaking = 20.0 + bidFactor + decFactor;
    }
    final double riskTaking = rawRiskTaking.clamp(10.0, 99.0);

    // 6. Comeback Ability (0 - 100)
    // Driven by comebacks, major comebacks, best deficit overcome
    double rawComeback = 45.0;
    if (stats.gamesPlayed > 0) {
      final comebackRatio = (stats.totalComebacks / max(1, stats.gamesPlayed)).clamp(0.0, 2.0);
      final majorBoost = stats.majorComebacks * 12.0;
      final clutchBoost = stats.finalRoundComebacks * 10.0;
      final deficitFactor = min(30.0, stats.bestComeback * 0.75);
      rawComeback = 30.0 + (comebackRatio * 20.0) + majorBoost + clutchBoost + deficitFactor;
    }
    final double comebackAbility = rawComeback.clamp(10.0, 99.0);

    // 7. Bid Discipline (0 - 100)
    // Low failed declarations and strong declaration accuracy
    double rawBidDiscipline = 50.0;
    if (totalDeclarations > 0) {
      final failRate = stats.failedDeclarations / totalDeclarations;
      rawBidDiscipline = (1.0 - failRate) * 85.0 + 15.0;
    }
    final double bidDiscipline = rawBidDiscipline.clamp(10.0, 99.0);

    // 8. Trump Confidence (0 - 100)
    // Derived from highest bid and overall trick win efficiency
    double rawTrumpConfidence = 50.0;
    if (totalRounds > 0) {
      final avgTricks = stats.averageActualTricks;
      final trickRatio = (avgTricks / 4.0).clamp(0.0, 2.0);
      final bidBoost = (stats.highestSuccessfulBid / 8.0) * 30.0;
      rawTrumpConfidence = 35.0 + (trickRatio * 25.0) + bidBoost;
    }
    final double trumpConfidence = rawTrumpConfidence.clamp(10.0, 99.0);

    // 9. Adaptability (0 - 100)
    // Strong win rate, long win streaks, and balanced trick taking
    double rawAdaptability = 50.0;
    if (stats.gamesPlayed > 0) {
      final winFactor = stats.winRate * 0.5;
      final streakFactor = min(25.0, stats.longestWinningStreak * 4.0);
      rawAdaptability = 30.0 + winFactor + streakFactor;
    }
    final double adaptability = rawAdaptability.clamp(10.0, 99.0);

    // 10. Score Awareness (0 - 100)
    // Efficiency in round scores and win conversion
    double rawScoreAwareness = 50.0;
    if (stats.gamesPlayed > 0) {
      final winConv = stats.winRate * 0.4;
      final accuracyConv = declarationAccuracy * 0.4;
      final highRoundFactor = min(20.0, stats.highestScoreInOneRound * 0.35);
      rawScoreAwareness = 20.0 + winConv + accuracyConv + highRoundFactor;
    }
    final double scoreAwareness = rawScoreAwareness.clamp(10.0, 99.0);

    return PlaystyleMetrics(
      aggression: aggression,
      conservatism: conservatism,
      riskTaking: riskTaking,
      precision: precision,
      adaptability: adaptability,
      trumpConfidence: trumpConfidence,
      comebackAbility: comebackAbility,
      bidDiscipline: bidDiscipline,
      declarationAccuracy: declarationAccuracy,
      scoreAwareness: scoreAwareness,
      roundsAnalyzed: totalRounds,
    );
  }

  /// Determines Primary and Secondary archetypes by scoring the 6 archetypes against the 10 dimensions
  Map<String, PlaystyleArchetype> determineArchetypes(PlaystyleMetrics metrics) {
    final scores = <PlaystyleArchetype, double>{};

    // Calculator: Precision, Bid Discipline, Declaration Accuracy, Score Awareness
    scores[PlaystyleArchetype.calculator] =
        (metrics.precision * 0.35) +
        (metrics.bidDiscipline * 0.30) +
        (metrics.declarationAccuracy * 0.25) +
        (metrics.scoreAwareness * 0.10);

    // Aggressor: Aggression, Trump Confidence, Risk Taking
    scores[PlaystyleArchetype.aggressor] =
        (metrics.aggression * 0.45) +
        (metrics.trumpConfidence * 0.30) +
        (metrics.riskTaking * 0.25);

    // Survivor: Conservatism, Bid Discipline, Precision (with low penalty tolerance)
    scores[PlaystyleArchetype.survivor] =
        (metrics.conservatism * 0.45) +
        (metrics.bidDiscipline * 0.30) +
        (metrics.precision * 0.25);

    // Gambler: Risk Taking, Aggression, Volatility
    scores[PlaystyleArchetype.gambler] =
        (metrics.riskTaking * 0.50) +
        (metrics.aggression * 0.30) +
        (metrics.trumpConfidence * 0.20);

    // Closer: Comeback Ability, Score Awareness, Adaptability
    scores[PlaystyleArchetype.closer] =
        (metrics.comebackAbility * 0.50) +
        (metrics.scoreAwareness * 0.30) +
        (metrics.adaptability * 0.20);

    // Adapter: Adaptability, balanced variance across dimensions
    final dimensions = [
      metrics.aggression,
      metrics.conservatism,
      metrics.riskTaking,
      metrics.precision,
      metrics.trumpConfidence,
      metrics.comebackAbility,
    ];
    final mean = dimensions.reduce((a, b) => a + b) / dimensions.length;
    final variance = dimensions.map((d) => pow(d - mean, 2)).reduce((a, b) => a + b) / dimensions.length;
    final balanceBonus = max(0.0, 40.0 - sqrt(variance));

    scores[PlaystyleArchetype.adapter] =
        (metrics.adaptability * 0.50) +
        (metrics.precision * 0.20) +
        (balanceBonus * 0.30);

    final sorted = scores.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    final primary = sorted.isNotEmpty ? sorted[0].key : PlaystyleArchetype.calculator;
    final secondary = sorted.length > 1 ? sorted[1].key : PlaystyleArchetype.adapter;

    return {
      'primary': primary,
      'secondary': secondary,
    };
  }

  /// Synthesizes a human-readable Personality Profile from metrics, stats, and previous history
  PlayerPersonalityProfile generatePersonalityProfile({
    required PlaystyleMetrics metrics,
    required EstimationStatistics stats,
    PlaystyleArchetype? previousArchetype,
  }) {
    final archetypes = determineArchetypes(metrics);
    final primary = archetypes['primary']!;
    final secondary = archetypes['secondary']!;

    final bool hasEvolved = previousArchetype != null &&
        previousArchetype != primary &&
        metrics.roundsAnalyzed >= 20;

    String evolutionMessage = '';
    if (hasEvolved) {
      evolutionMessage =
          'تطور أسلوب لعبك التكتيكي من "${previousArchetype.titleAr}" إلى "${primary.titleAr}" بناءً على أدائك في الجولات الأخيرة.';
    }

    // ── Generate Strengths (Top performing dimensions) ───────────────────────
    final strengths = <String>[];
    if (metrics.declarationAccuracy >= 60.0) {
      strengths.add('دقة متفوقة في إعلان وتحديد اللامات (${metrics.declarationAccuracy.toStringAsFixed(1)}%)');
    }
    if (metrics.comebackAbility >= 65.0 || stats.majorComebacks > 0) {
      strengths.add('صناعة ريمونتادات حاسمة وقلب موازين المباريات (${stats.totalComebacks} ريمونتادا)');
    }
    if (metrics.aggression >= 65.0) {
      strengths.add('شجاعة في انتزاع المزاد والمبادرة بالهجوم (أعلى كول: ${stats.highestSuccessfulBid} لامات)');
    }
    if (metrics.conservatism >= 65.0) {
      strengths.add('انضباط دفاعي متميز وتفادي نقاط السالب والعقوبات');
    }
    if (metrics.bidDiscipline >= 70.0) {
      strengths.add('تحكم استراتيجي وانضباط عالي في اختيار العقود المضمونة');
    }
    if (strengths.isEmpty) {
      strengths.add('انضباط واعد وقدرة مستمرة على التعلم والتطور');
      strengths.add('ثبات في الأداء خلال الجولات المتوسطة');
    }

    // ── Generate Weaknesses / Improvement Areas ──────────────────────────────
    final weaknesses = <String>[];
    if (metrics.declarationAccuracy < 50.0 && metrics.roundsAnalyzed >= 10) {
      weaknesses.add('الحاجة لتحسين دقة الكول وتجنب التباين بين الإعلان والناتج');
    }
    if (metrics.aggression < 40.0 && metrics.roundsAnalyzed >= 10) {
      weaknesses.add('التردد أحياناً في المزايدة والمجازفة عند امتلاك أوراق رابحة');
    }
    if (metrics.riskTaking > 75.0 && metrics.declarationAccuracy < 55.0) {
      weaknesses.add('المجازفة المفرطة في كولات صعبة تؤدي إلى خسارة نقاط ثمينة');
    }
    if (metrics.comebackAbility < 40.0 && stats.gamesPlayed >= 5) {
      weaknesses.add('صعوبة تعويض الفارق عند التأخر في النقاط بالجولات الأولى');
    }
    if (weaknesses.isEmpty) {
      weaknesses.add('الحفاظ على التركيز في جولات السانز والجولات الختامية المعقدة');
    }

    // ── Generate Signature Behavior ──────────────────────────────────────────
    String signatureBehavior = primary.taglineAr;
    if (stats.longestWinningStreak >= 5) {
      signatureBehavior += ' • صاحب سلاسل انتصارات نارية (${stats.longestWinningStreak} متتالية)';
    }

    // ── Generate Tactical Recommendation ─────────────────────────────────────
    String recommendation = '';
    switch (primary) {
      case PlaystyleArchetype.calculator:
        recommendation =
            'أداؤك دقيق جداً! عندما تمتلك أوراقاً قوية، لا تتردد في رفع الكول درجة إضافية لمضاعفة مكاسبك.';
        break;
      case PlaystyleArchetype.aggressor:
        recommendation =
            'هجومك يرعب الخصوم! انتبه في جولات السانز ولا تعتمد فقط على قوة اللون الواحد لضمان المكسب.';
        break;
      case PlaystyleArchetype.survivor:
        recommendation =
            'ثباتك رائع وتفاديك للسالب ممتاز! تحين الفرصة في الجولات الأخيرة لخطف المزاد وصناعة الفارق.';
        break;
      case PlaystyleArchetype.gambler:
        recommendation =
            'كولاتك الجريئة تصنع المتعة! راجع احتمالات ورق الشريك والخصوم قبل كول الداش لتجنب المفاجآت.';
        break;
      case PlaystyleArchetype.closer:
        recommendation =
            'أنت سيد اللحظات الأخيرة! حافظ على فارق نقاط متقارب في الجولات الأولى لتنقض على الصدارة.';
        break;
      case PlaystyleArchetype.adapter:
        recommendation =
            'مرونتك ميزة ذهبية! ركز على استغلال أخطاء الخصوم في إعلان اللامات لتعزيز موقعك في الترتيب.';
        break;
    }

    // ── Measurable Evidence Bullet Points ────────────────────────────────────
    final measurableReasons = <String>[
      '• ${stats.declarationAccuracy.toStringAsFixed(1)}% دقة مطابقة إعلان الكول (${stats.perfectEstimates} كول مثالي)',
      '• ${stats.averageDeclaredTricks.toStringAsFixed(1)} متوسط لامات معلنة في الجولة',
      if (stats.highestSuccessfulBid > 0)
        '• $stats.highestSuccessfulBid أعلى مزاد كول ناجح تم تحقيقه',
      if (stats.totalComebacks > 0)
        '• ${stats.totalComebacks} ريمونتادا مسجلة (أفضل تعويض فارق: +${stats.bestComeback} نقطة)',
      if (stats.longestWinningStreak > 1)
        '• ${stats.longestWinningStreak} مباريات أطول سلسلة انتصارات متتالية',
    ];

    return PlayerPersonalityProfile(
      primaryArchetype: primary,
      secondaryArchetype: secondary,
      previousArchetype: previousArchetype,
      hasEvolved: hasEvolved,
      evolutionMessage: evolutionMessage,
      strengths: strengths.take(3).toList(),
      weaknesses: weaknesses.take(2).toList(),
      signatureBehavior: signatureBehavior,
      recommendation: recommendation,
      measurableReasons: measurableReasons,
      metrics: metrics,
      isPublic: true,
      lastUpdated: DateTime.now(),
    );
  }

  /// Loads saved PlayerPersonalityProfile for a player
  Future<PlayerPersonalityProfile> getPersonalityProfile(String playerName, EstimationStatistics stats) async {
    if (playerName.trim().isEmpty) return PlayerPersonalityProfile.initial();

    try {
      final prefs = await SharedPreferences.getInstance();
      final key = _getStorageKey(_kProfilePrefix, playerName);
      final jsonStr = prefs.getString(key);

      PlaystyleArchetype? previousArchetype;
      final prevKey = _getStorageKey(_kPrevArchetypePrefix, playerName);
      final prevStr = prefs.getString(prevKey);
      if (prevStr != null && prevStr.isNotEmpty) {
        previousArchetype = PlaystyleArchetype.fromString(prevStr);
      }

      if (jsonStr != null && jsonStr.isNotEmpty) {
        final Map<String, dynamic> data = jsonDecode(jsonStr);
        final profile = PlayerPersonalityProfile.fromJson(data);
        // Refresh with latest live stats calculations
        final metrics = calculateMetrics(stats: stats);
        return generatePersonalityProfile(
          metrics: metrics,
          stats: stats,
          previousArchetype: previousArchetype ?? profile.primaryArchetype,
        );
      }
    } catch (e) {
      debugPrint('[PlaystyleService] Error loading personality profile: $e');
    }

    final metrics = calculateMetrics(stats: stats);
    return generatePersonalityProfile(metrics: metrics, stats: stats);
  }

  /// Saves PlayerPersonalityProfile
  Future<void> savePersonalityProfile(String playerName, PlayerPersonalityProfile profile) async {
    if (playerName.trim().isEmpty) return;

    try {
      final prefs = await SharedPreferences.getInstance();
      final key = _getStorageKey(_kProfilePrefix, playerName);
      await prefs.setString(key, jsonEncode(profile.toJson()));

      // Save previous archetype history if evolved
      if (profile.primaryArchetype != profile.previousArchetype) {
        final prevKey = _getStorageKey(_kPrevArchetypePrefix, playerName);
        await prefs.setString(prevKey, profile.primaryArchetype.name);
      }
    } catch (e) {
      debugPrint('[PlaystyleService] Error saving personality profile: $e');
    }
  }

  /// Loads PlayerIdentityCardConfig
  Future<PlayerIdentityCardConfig> getIdentityCardConfig(String playerName) async {
    if (playerName.trim().isEmpty) return const PlayerIdentityCardConfig();

    try {
      final prefs = await SharedPreferences.getInstance();
      final key = _getStorageKey(_kCardConfigPrefix, playerName);
      final jsonStr = prefs.getString(key);

      if (jsonStr != null && jsonStr.isNotEmpty) {
        final Map<String, dynamic> data = jsonDecode(jsonStr);
        return PlayerIdentityCardConfig.fromJson(data);
      }
    } catch (e) {
      debugPrint('[PlaystyleService] Error loading identity card config: $e');
    }

    return const PlayerIdentityCardConfig();
  }

  /// Saves PlayerIdentityCardConfig
  Future<void> saveIdentityCardConfig(String playerName, PlayerIdentityCardConfig config) async {
    if (playerName.trim().isEmpty) return;

    try {
      final prefs = await SharedPreferences.getInstance();
      final key = _getStorageKey(_kCardConfigPrefix, playerName);
      await prefs.setString(key, jsonEncode(config.toJson()));
    } catch (e) {
      debugPrint('[PlaystyleService] Error saving identity card config: $e');
    }
  }

  /// Updates playstyle and personality when a match is completed
  Future<PlayerPersonalityProfile> updatePlaystyleFromMatch({
    required String playerName,
    required EstimationStatistics updatedStats,
    required GameState state,
  }) async {
    final profile = await getPersonalityProfile(playerName, updatedStats);
    await savePersonalityProfile(playerName, profile);
    return profile;
  }
}
