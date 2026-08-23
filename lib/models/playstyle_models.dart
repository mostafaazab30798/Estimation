// lib/models/playstyle_models.dart

import 'package:flutter/material.dart';

/// 10 numerical dimensions (0–100) representing a player's strategic tendencies in Estimation.
class PlaystyleMetrics {
  /// Aggression (0–100): High trick bids, frequent bidding ambition, willingness to take the auction lead.
  final double aggression;

  /// Conservatism (0–100): Preference for low contracts, safe passes, and minimizing penalty risks.
  final double conservatism;

  /// Risk Taking (0–100): Acceptance of volatile opportunities (Dash calls, Risk calls, high bids).
  final double riskTaking;

  /// Precision (0–100): Closeness of actual tricks to declared tricks; penalty minimization.
  final double precision;

  /// Adaptability (0–100): Performance when not the bidder or playing with challenging cards.
  final double adaptability;

  /// Trump Confidence (0–100): Performance in trump rounds vs sans/no-trump rounds.
  final double trumpConfidence;

  /// Comeback Ability (0–100): Performance when trailing, clutch recovery, 4th-to-1st comebacks.
  final double comebackAbility;

  /// Bid Discipline (0–100): Ratio of successful bids to overbids/failed bids.
  final double bidDiscipline;

  /// Declaration Accuracy (0–100): Exact match percentage (Perfect estimates / Total declarations).
  final double declarationAccuracy;

  /// Score Awareness (0–100): High score preservation, point delta efficiency, lead protection.
  final double scoreAwareness;

  /// Total rounds analyzed to compute these metrics
  final int roundsAnalyzed;

  const PlaystyleMetrics({
    this.aggression = 50.0,
    this.conservatism = 50.0,
    this.riskTaking = 50.0,
    this.precision = 50.0,
    this.adaptability = 50.0,
    this.trumpConfidence = 50.0,
    this.comebackAbility = 50.0,
    this.bidDiscipline = 50.0,
    this.declarationAccuracy = 50.0,
    this.scoreAwareness = 50.0,
    this.roundsAnalyzed = 0,
  });

  /// Confidence percentage (0.0% to 100.0%) based on total rounds played.
  /// <20 rounds   -> Early estimate (15% - 45%)
  /// 20–49 rounds -> Developing (50% - 74%)
  /// 50–99 rounds -> Reliable (75% - 89%)
  /// 100+ rounds  -> High confidence (90% - 100%)
  double get profileConfidence {
    if (roundsAnalyzed <= 0) return 10.0;
    if (roundsAnalyzed < 20) {
      return 15.0 + (roundsAnalyzed / 20.0) * 30.0; // 15% - 45%
    } else if (roundsAnalyzed < 50) {
      return 50.0 + ((roundsAnalyzed - 20) / 30.0) * 24.0; // 50% - 74%
    } else if (roundsAnalyzed < 100) {
      return 75.0 + ((roundsAnalyzed - 50) / 50.0) * 14.0; // 75% - 89%
    } else {
      return (90.0 + ((roundsAnalyzed - 100) / 100.0) * 10.0).clamp(90.0, 100.0);
    }
  }

  /// Human readable confidence tier label in Arabic
  String get confidenceLabelAr {
    if (roundsAnalyzed < 20) return 'تقدير مبكر';
    if (roundsAnalyzed < 50) return 'قيد التطور';
    if (roundsAnalyzed < 100) return 'موثوق';
    return 'ثقة عالية جداً';
  }

  /// Human readable confidence tier label in English
  String get confidenceLabelEn {
    if (roundsAnalyzed < 20) return 'Early Estimate';
    if (roundsAnalyzed < 50) return 'Developing';
    if (roundsAnalyzed < 100) return 'Reliable';
    return 'High Confidence';
  }

  Map<String, dynamic> toJson() => {
        'aggression': aggression,
        'conservatism': conservatism,
        'riskTaking': riskTaking,
        'precision': precision,
        'adaptability': adaptability,
        'trumpConfidence': trumpConfidence,
        'comebackAbility': comebackAbility,
        'bidDiscipline': bidDiscipline,
        'declarationAccuracy': declarationAccuracy,
        'scoreAwareness': scoreAwareness,
        'roundsAnalyzed': roundsAnalyzed,
      };

  factory PlaystyleMetrics.fromJson(Map<String, dynamic> json) {
    return PlaystyleMetrics(
      aggression: (json['aggression'] as num?)?.toDouble() ?? 50.0,
      conservatism: (json['conservatism'] as num?)?.toDouble() ?? 50.0,
      riskTaking: (json['riskTaking'] as num?)?.toDouble() ?? 50.0,
      precision: (json['precision'] as num?)?.toDouble() ?? 50.0,
      adaptability: (json['adaptability'] as num?)?.toDouble() ?? 50.0,
      trumpConfidence: (json['trumpConfidence'] as num?)?.toDouble() ?? 50.0,
      comebackAbility: (json['comebackAbility'] as num?)?.toDouble() ?? 50.0,
      bidDiscipline: (json['bidDiscipline'] as num?)?.toDouble() ?? 50.0,
      declarationAccuracy:
          (json['declarationAccuracy'] as num?)?.toDouble() ?? 50.0,
      scoreAwareness: (json['scoreAwareness'] as num?)?.toDouble() ?? 50.0,
      roundsAnalyzed: (json['roundsAnalyzed'] as num?)?.toInt() ?? 0,
    );
  }

  factory PlaystyleMetrics.empty() => const PlaystyleMetrics();
}

/// The 6 tactical archetypes in Estimation
enum PlaystyleArchetype {
  calculator, // الحاسب الدقيق
  aggressor,  // المهاجم الشرس
  survivor,   // المدافع الحذر
  gambler,    // المقامر الجريء
  closer,     // حاسم النهايات
  adapter;    // المرن المتكيف

  String get titleAr {
    switch (this) {
      case PlaystyleArchetype.calculator:
        return 'الحاسب الدقيق';
      case PlaystyleArchetype.aggressor:
        return 'المهاجم الشرس';
      case PlaystyleArchetype.survivor:
        return 'المدافع الحذر';
      case PlaystyleArchetype.gambler:
        return 'المقامر الجريء';
      case PlaystyleArchetype.closer:
        return 'حاسم النهايات';
      case PlaystyleArchetype.adapter:
        return 'المرن المتكيف';
    }
  }

  String get titleEn {
    switch (this) {
      case PlaystyleArchetype.calculator:
        return 'The Calculator';
      case PlaystyleArchetype.aggressor:
        return 'The Aggressor';
      case PlaystyleArchetype.survivor:
        return 'The Survivor';
      case PlaystyleArchetype.gambler:
        return 'The Gambler';
      case PlaystyleArchetype.closer:
        return 'The Closer';
      case PlaystyleArchetype.adapter:
        return 'The Adapter';
    }
  }

  String get emoji {
    switch (this) {
      case PlaystyleArchetype.calculator:
        return '🧠';
      case PlaystyleArchetype.aggressor:
        return '🔥';
      case PlaystyleArchetype.survivor:
        return '🛡️';
      case PlaystyleArchetype.gambler:
        return '🎲';
      case PlaystyleArchetype.closer:
        return '👑';
      case PlaystyleArchetype.adapter:
        return '🔄';
    }
  }

  Color get primaryColor {
    switch (this) {
      case PlaystyleArchetype.calculator:
        return const Color(0xFF38BDF8); // Electric Cyan
      case PlaystyleArchetype.aggressor:
        return const Color(0xFFEF4444); // Fiery Red
      case PlaystyleArchetype.survivor:
        return const Color(0xFF10B981); // Emerald Shield
      case PlaystyleArchetype.gambler:
        return const Color(0xFFF59E0B); // Amber Gold
      case PlaystyleArchetype.closer:
        return const Color(0xFFA855F7); // Royal Purple
      case PlaystyleArchetype.adapter:
        return const Color(0xFF06B6D4); // Cyan Teal
    }
  }

  Color get secondaryColor {
    switch (this) {
      case PlaystyleArchetype.calculator:
        return const Color(0xFF0284C7);
      case PlaystyleArchetype.aggressor:
        return const Color(0xFFB91C1C);
      case PlaystyleArchetype.survivor:
        return const Color(0xFF047857);
      case PlaystyleArchetype.gambler:
        return const Color(0xFFD97706);
      case PlaystyleArchetype.closer:
        return const Color(0xFF7E22CE);
      case PlaystyleArchetype.adapter:
        return const Color(0xFF0E7490);
    }
  }

  String get taglineAr {
    switch (this) {
      case PlaystyleArchetype.calculator:
        return 'يتحسب لكل ورقة ولا يترك مجالاً للصدفة';
      case PlaystyleArchetype.aggressor:
        return 'يفرض إيقاعه على الطاولة ويسيطر على المزاد';
      case PlaystyleArchetype.survivor:
        return 'يتفادى الفخاخ ويحافظ على نقاطه بهدوء وثبات';
      case PlaystyleArchetype.gambler:
        return 'يعشق المخاطرة والكولات الجريئة ويقلب الموازين';
      case PlaystyleArchetype.closer:
        return 'يظهر في اللحظات الحاسمة ويحسم الجولات الأخيرة';
      case PlaystyleArchetype.adapter:
        return 'يتكيف مع كل سيناريو بمرونة تكتيكية عالية';
    }
  }

  String get descriptionAr {
    switch (this) {
      case PlaystyleArchetype.calculator:
        return 'نادراً ما تقدم على مزايدة غير محسوبة. تفضل العقود الموثوقة وتحقق نتائج مطابقة تماماً لتوقعاتك مع أعلى درجات الانضباط.';
      case PlaystyleArchetype.aggressor:
        return 'تمتلك جرأة عالية في انتزاع المزاد والكول بأعداد لامات مرتفعة. هجومك المتواصل يربك الخصوم ويمنحك السيطرة.';
      case PlaystyleArchetype.survivor:
        return 'تتجنب المخاطر الزائدة وتبني انتصاراتك على تفادي العقوبات ونقاط السالب، مع تركيز دقيق على حماية رصيدك من النقاط.';
      case PlaystyleArchetype.gambler:
        return 'لا تخشى كولات الداش والريسك والمزايدات العالية عند استشعار الفرصة. أسلوبك يصنع تقلبات حادة ودرامية في نتائج المباريات.';
      case PlaystyleArchetype.closer:
        return 'تتقن إدارة الفارق النقطي وصناعة الريمونتادا من المراكز المتأخرة، وتبرز قوتك الحقيقية في الجولات الختامية للمباراة.';
      case PlaystyleArchetype.adapter:
        return 'تمتلك توازناً متفوقاً بين الهجوم والدفاع، وتغير استراتيجيتك بذكاء حسب توزيع الورق وموقف الخصوم على الطاولة.';
    }
  }

  static PlaystyleArchetype fromString(String? name) {
    if (name == null) return PlaystyleArchetype.calculator;
    return PlaystyleArchetype.values.firstWhere(
      (a) => a.name.toLowerCase() == name.toLowerCase(),
      orElse: () => PlaystyleArchetype.calculator,
    );
  }
}

/// Dynamic Player Personality Profile turning numbers into actionable human identity
class PlayerPersonalityProfile {
  final PlaystyleArchetype primaryArchetype;
  final PlaystyleArchetype secondaryArchetype;
  final PlaystyleArchetype? previousArchetype;
  final bool hasEvolved;
  final String evolutionMessage;
  final List<String> strengths;
  final List<String> weaknesses;
  final String signatureBehavior;
  final String recommendation;
  final List<String> measurableReasons;
  final PlaystyleMetrics metrics;
  final bool isPublic;
  final DateTime lastUpdated;

  const PlayerPersonalityProfile({
    required this.primaryArchetype,
    required this.secondaryArchetype,
    this.previousArchetype,
    this.hasEvolved = false,
    this.evolutionMessage = '',
    required this.strengths,
    required this.weaknesses,
    required this.signatureBehavior,
    required this.recommendation,
    required this.measurableReasons,
    required this.metrics,
    this.isPublic = true,
    required this.lastUpdated,
  });

  Map<String, dynamic> toJson() => {
        'primaryArchetype': primaryArchetype.name,
        'secondaryArchetype': secondaryArchetype.name,
        'previousArchetype': previousArchetype?.name,
        'hasEvolved': hasEvolved,
        'evolutionMessage': evolutionMessage,
        'strengths': strengths,
        'weaknesses': weaknesses,
        'signatureBehavior': signatureBehavior,
        'recommendation': recommendation,
        'measurableReasons': measurableReasons,
        'metrics': metrics.toJson(),
        'isPublic': isPublic,
        'lastUpdated': lastUpdated.toIso8601String(),
      };

  factory PlayerPersonalityProfile.fromJson(Map<String, dynamic> json) {
    return PlayerPersonalityProfile(
      primaryArchetype: PlaystyleArchetype.fromString(
          json['primaryArchetype'] as String?),
      secondaryArchetype: PlaystyleArchetype.fromString(
          json['secondaryArchetype'] as String?),
      previousArchetype: json['previousArchetype'] != null
          ? PlaystyleArchetype.fromString(json['previousArchetype'] as String?)
          : null,
      hasEvolved: json['hasEvolved'] as bool? ?? false,
      evolutionMessage: json['evolutionMessage'] as String? ?? '',
      strengths: (json['strengths'] as List<dynamic>?)
              ?.map((e) => e.toString())
              .toList() ??
          [],
      weaknesses: (json['weaknesses'] as List<dynamic>?)
              ?.map((e) => e.toString())
              .toList() ??
          [],
      signatureBehavior: json['signatureBehavior'] as String? ?? '',
      recommendation: json['recommendation'] as String? ?? '',
      measurableReasons: (json['measurableReasons'] as List<dynamic>?)
              ?.map((e) => e.toString())
              .toList() ??
          [],
      metrics: json['metrics'] != null
          ? PlaystyleMetrics.fromJson(json['metrics'] as Map<String, dynamic>)
          : const PlaystyleMetrics(),
      isPublic: json['isPublic'] as bool? ?? true,
      lastUpdated: json['lastUpdated'] != null
          ? DateTime.tryParse(json['lastUpdated'].toString()) ?? DateTime.now()
          : DateTime.now(),
    );
  }

  factory PlayerPersonalityProfile.initial() {
    return PlayerPersonalityProfile(
      primaryArchetype: PlaystyleArchetype.calculator,
      secondaryArchetype: PlaystyleArchetype.adapter,
      hasEvolved: false,
      evolutionMessage: '',
      strengths: [
        'دقة جيدة في تقدير اللامات',
        'انضباط في المزايدة والمحافظة على النقاط',
      ],
      weaknesses: [
        'الحاجة لخوض المزيد من المباريات لتحديد النمط بدقة كاملة',
      ],
      signatureBehavior: 'يلعب بحذر ويحسب خطواته بهدوء',
      recommendation: 'استمر في خوض مباريات كاملة لتثبيت نمط لعبك التكتيكي.',
      measurableReasons: [
        '• تقييم أولي مبني على بداية الجولات',
        '• انضباط واعد في قراءة الورق',
      ],
      metrics: const PlaystyleMetrics(),
      isPublic: true,
      lastUpdated: DateTime.now(),
    );
  }
}

/// Visual theme skins for the Player Identity Card
enum CardSkinTheme {
  royalGold,      // كينج الذهب
  midnightVelvet, // كحلي ملكي
  emeraldMaster,  // زمرد الأستاذ
  crimsonDragon,  // تنين أحمر
  cyberNeon;      // سايبر مستقبلي

  String get titleAr {
    switch (this) {
      case CardSkinTheme.royalGold:
        return 'كينج الذهب 👑';
      case CardSkinTheme.midnightVelvet:
        return 'كحلي ملكي 💎';
      case CardSkinTheme.emeraldMaster:
        return 'زمرد الأستاذ 🌲';
      case CardSkinTheme.crimsonDragon:
        return 'تنين أحمر 🔥';
      case CardSkinTheme.cyberNeon:
        return 'سايبر نيون ⚡';
    }
  }

  List<Color> get gradientColors {
    switch (this) {
      case CardSkinTheme.royalGold:
        return const [
          Color(0xFF231B08),
          Color(0xFF140F04),
          Color(0xFF2E240C),
        ];
      case CardSkinTheme.midnightVelvet:
        return const [
          Color(0xFF0F172A),
          Color(0xFF1E1B4B),
          Color(0xFF090D16),
        ];
      case CardSkinTheme.emeraldMaster:
        return const [
          Color(0xFF064E3B),
          Color(0xFF022C22),
          Color(0xFF065F46),
        ];
      case CardSkinTheme.crimsonDragon:
        return const [
          Color(0xFF450A0A),
          Color(0xFF1C0505),
          Color(0xFF7F1D1D),
        ];
      case CardSkinTheme.cyberNeon:
        return const [
          Color(0xFF2E1065),
          Color(0xFF083344),
          Color(0xFF1E1B4B),
        ];
    }
  }

  Color get borderColor {
    switch (this) {
      case CardSkinTheme.royalGold:
        return const Color(0xFFFFD700);
      case CardSkinTheme.midnightVelvet:
        return const Color(0xFF60A5FA);
      case CardSkinTheme.emeraldMaster:
        return const Color(0xFF34D399);
      case CardSkinTheme.crimsonDragon:
        return const Color(0xFFF87171);
      case CardSkinTheme.cyberNeon:
        return const Color(0xFFC084FC);
    }
  }

  Color get accentGlow {
    switch (this) {
      case CardSkinTheme.royalGold:
        return const Color(0xFFF59E0B);
      case CardSkinTheme.midnightVelvet:
        return const Color(0xFF3B82F6);
      case CardSkinTheme.emeraldMaster:
        return const Color(0xFF10B981);
      case CardSkinTheme.crimsonDragon:
        return const Color(0xFFEF4444);
      case CardSkinTheme.cyberNeon:
        return const Color(0xFFA855F7);
    }
  }

  static CardSkinTheme fromString(String? name) {
    if (name == null) return CardSkinTheme.royalGold;
    return CardSkinTheme.values.firstWhere(
      (s) => s.name.toLowerCase() == name.toLowerCase(),
      orElse: () => CardSkinTheme.royalGold,
    );
  }
}

/// Configuration and preferences for the Player Identity Card
class PlayerIdentityCardConfig {
  final CardSkinTheme theme;
  final String selectedTitle;
  final String showcaseStat; // 'accuracy' | 'win_streak' | 'comebacks' | 'perfect_estimates'
  final bool isPublic;

  const PlayerIdentityCardConfig({
    this.theme = CardSkinTheme.royalGold,
    this.selectedTitle = 'أستاذ الإستميشن',
    this.showcaseStat = 'accuracy',
    this.isPublic = true,
  });

  static const List<String> availableTitles = [
    'أستاذ الإستميشن',
    'قرش الطاولة',
    'بطل البولة',
    'الداهية التكتيكي',
    'حاسم النهائيات',
    'المعلم الكبير',
    'ملك السانز',
    'قاهر الكولات',
  ];

  Map<String, dynamic> toJson() => {
        'theme': theme.name,
        'selectedTitle': selectedTitle,
        'showcaseStat': showcaseStat,
        'isPublic': isPublic,
      };

  factory PlayerIdentityCardConfig.fromJson(Map<String, dynamic> json) {
    return PlayerIdentityCardConfig(
      theme: CardSkinTheme.fromString(json['theme'] as String?),
      selectedTitle:
          json['selectedTitle'] as String? ?? 'أستاذ الإستميشن',
      showcaseStat: json['showcaseStat'] as String? ?? 'accuracy',
      isPublic: json['isPublic'] as bool? ?? true,
    );
  }

  PlayerIdentityCardConfig copyWith({
    CardSkinTheme? theme,
    String? selectedTitle,
    String? showcaseStat,
    bool? isPublic,
  }) {
    return PlayerIdentityCardConfig(
      theme: theme ?? this.theme,
      selectedTitle: selectedTitle ?? this.selectedTitle,
      showcaseStat: showcaseStat ?? this.showcaseStat,
      isPublic: isPublic ?? this.isPublic,
    );
  }
}
