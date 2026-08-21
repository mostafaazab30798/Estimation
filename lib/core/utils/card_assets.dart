// lib/core/utils/card_assets.dart

import '../constants.dart';
import '../models/card.dart';

/// Returns suit code character for image filenames ('S', 'H', 'D', 'C').
String suitCode(Suit suit) {
  switch (suit) {
    case Suit.spade:
      return 'S';
    case Suit.heart:
      return 'H';
    case Suit.diamond:
      return 'D';
    case Suit.club:
      return 'C';
  }
}

/// Returns rank code character for image filenames ('2'-'10', 'J', 'Q', 'K', 'A').
String rankCode(Rank rank) {
  switch (rank) {
    case Rank.two:
      return '2';
    case Rank.three:
      return '3';
    case Rank.four:
      return '4';
    case Rank.five:
      return '5';
    case Rank.six:
      return '6';
    case Rank.seven:
      return '7';
    case Rank.eight:
      return '8';
    case Rank.nine:
      return '9';
    case Rank.ten:
      return '10';
    case Rank.jack:
      return 'J';
    case Rank.queen:
      return 'Q';
    case Rank.king:
      return 'K';
    case Rank.ace:
      return 'A';
  }
}

/// Resolves the full asset path for a playing card given the active [theme].
String getCardAssetPath(PlayingCard? card, String theme) {
  if (card == null) return 'assets/back.png';
  return 'assets/$theme/${rankCode(card.rank)}_${suitCode(card.suit)}.png';
}
