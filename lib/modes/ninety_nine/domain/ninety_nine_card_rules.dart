// lib/modes/ninety_nine/domain/ninety_nine_card_rules.dart

import '../../../core/constants.dart';
import '../../../core/models/card.dart';

/// Extension on [PlayingCard] providing card effects and safe card checks for "99" mode.
extension NinetyNineCardEffect on PlayingCard {
  /// A "safe" card (ورقة منقذة) can be played when [groundTotal == 99] to prevent elimination.
  /// Safe cards: 4, 7, Jack (ولد), King (شايب).
  bool get isSafeCard =>
      rank == Rank.four ||
      rank == Rank.seven ||
      rank == Rank.jack ||
      rank == Rank.king;

  /// Returns whether this card reverses play direction (7 reverses direction).
  bool get isReverseCard => rank == Rank.seven;

  /// Human readable description in Arabic for the effect of this card in 99 mode.
  String get effectLabel {
    switch (rank) {
      case Rank.four:
        return '+0 آمنة';
      case Rank.seven:
        return 'عكس اتجاه (+0)';
      case Rank.king:
        return '= 99';
      case Rank.jack:
        return '-10';
      case Rank.queen:
        return '+10';
      case Rank.ace:
        return '+1';
      case Rank.two:
        return '+2';
      case Rank.three:
        return '+3';
      case Rank.five:
        return '+5';
      case Rank.six:
        return '+6';
      case Rank.eight:
        return '+8';
      case Rank.nine:
        return '+9';
      case Rank.ten:
        return '+10';
    }
  }

  /// Short badge text for card overlay pill in 99 hand visualization
  String get badgeLabel {
    switch (rank) {
      case Rank.four:
        return '+0 🛡️';
      case Rank.seven:
        return '🔄';
      case Rank.king:
        return '👑 99';
      case Rank.jack:
        return '-10 🛡️';
      case Rank.queen:
        return '+10';
      case Rank.ace:
        return '+1';
      case Rank.two:
        return '+2';
      case Rank.three:
        return '+3';
      case Rank.five:
        return '+5';
      case Rank.six:
        return '+6';
      case Rank.eight:
        return '+8';
      case Rank.nine:
        return '+9';
      case Rank.ten:
        return '+10';
    }
  }

  /// Unclamped ground total after this card. Used to detect illegal overflow (> 99).
  int unclampedEffect(int currentGround) {
    switch (rank) {
      case Rank.four:
      case Rank.seven:
        return currentGround; // +0
      case Rank.king:
        // If groundTotal is ALREADY 99, King acts as +0 instead of re-setting to 99
        return currentGround == 99 ? currentGround : 99;
      case Rank.jack:
        return currentGround - 10;
      case Rank.queen:
        return currentGround + 10;
      case Rank.ace:
        return currentGround + 1;
      case Rank.two:
        return currentGround + 2;
      case Rank.three:
        return currentGround + 3;
      case Rank.five:
        return currentGround + 5;
      case Rank.six:
        return currentGround + 6;
      case Rank.eight:
        return currentGround + 8;
      case Rank.nine:
        return currentGround + 9;
      case Rank.ten:
        return currentGround + 10;
    }
  }

  /// True when this card can be played without making the ground exceed 99.
  /// Safe cards (4, 7, Jack, King) never overflow. Additive cards are illegal
  /// when [currentGround] + their value would go past 99.
  bool isLegalPlay(int currentGround) => unclampedEffect(currentGround) <= 99;

  /// Calculates the new ground total after applying this card's effect to [currentGround].
  /// Callers must reject illegal overflow plays with [isLegalPlay] first.
  int applyEffect(int currentGround) {
    return unclampedEffect(currentGround).clamp(0, 99);
  }
}

