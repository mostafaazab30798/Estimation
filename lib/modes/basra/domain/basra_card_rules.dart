// lib/modes/basra/domain/basra_card_rules.dart

import 'package:estimation/core/constants.dart';
import 'package:estimation/core/models/card.dart';

/// Basra-specific helpers on the shared [PlayingCard] model.
///
/// Q and K have no numeric value. J is not 11. Only 7♦ is the special seven.
extension BasraCardRules on PlayingCard {
  /// Numeric value used for sum captures. Null for J, Q and K.
  int? get basraNumericValue {
    switch (rank) {
      case Rank.ace:
        return 1;
      case Rank.two:
        return 2;
      case Rank.three:
        return 3;
      case Rank.four:
        return 4;
      case Rank.five:
        return 5;
      case Rank.six:
        return 6;
      case Rank.seven:
        return 7;
      case Rank.eight:
        return 8;
      case Rank.nine:
        return 9;
      case Rank.ten:
        return 10;
      case Rank.jack:
      case Rank.queen:
      case Rank.king:
        return null;
    }
  }

  bool get isBasraNumeric => basraNumericValue != null;

  bool get isJack => rank == Rank.jack;

  bool get isQueen => rank == Rank.queen;

  bool get isKing => rank == Rank.king;

  bool get isSevenOfDiamonds => rank == Rank.seven && suit == Suit.diamond;

  /// Special cards that must not appear on the initial face-up table.
  bool get isInitialTableForbidden => isJack || isSevenOfDiamonds;

  bool get isTwoOfSpades => rank == Rank.two && suit == Suit.spade;

  bool get isTenOfDiamonds => rank == Rank.ten && suit == Suit.diamond;
}

int basraTableNumericTotal(Iterable<PlayingCard> cards) {
  var total = 0;
  for (final card in cards) {
    total += card.basraNumericValue ?? 0;
  }
  return total;
}
