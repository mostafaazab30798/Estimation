// lib/modes/basra/domain/basra_bot_ai.dart

import 'package:estimation/core/models/card.dart';
import 'package:estimation/modes/basra/domain/basra_capture_engine.dart';
import 'package:estimation/modes/basra/domain/basra_card_rules.dart';
import 'package:estimation/modes/basra/domain/models/basra_game_state.dart';

class BasraBotAi {
  const BasraBotAi._();

  static PlayingCard chooseCard({
    required List<PlayingCard> hand,
    required List<PlayingCard> tableCards,
  }) {
    if (hand.isEmpty) throw StateError('Hand is empty');
    if (hand.length == 1) return hand.first;

    PlayingCard? best;
    var bestScore = -0x7fffffff;

    for (final card in hand) {
      final resolved = BasraCaptureEngine.resolvePlay(card, tableCards);
      final score = _scoreCandidate(card, tableCards, resolved);
      if (score > bestScore ||
          (score == bestScore &&
              best != null &&
              card.id.compareTo(best.id) < 0) ||
          best == null) {
        bestScore = score;
        best = card;
      }
    }

    return best!;
  }

  static int _scoreCandidate(
    PlayingCard card,
    List<PlayingCard> tableCards,
    ({
      List<PlayingCard> captured,
      List<PlayingCard> tableAfter,
      bool wasCapture,
      bool wasSweep,
      BasraType basraType,
    }) resolved,
  ) {
    if (!resolved.wasCapture) {
      var dump = 40 - (card.basraNumericValue ?? 12);
      if (card.isJack || card.isSevenOfDiamonds) dump -= 80;
      if (card.isTenOfDiamonds || card.isTwoOfSpades) dump -= 30;
      if (tableCards.isEmpty && (card.isJack || card.isSevenOfDiamonds)) {
        dump -= 40;
      }
      return dump;
    }

    var score = 100 + resolved.captured.length * 12;
    if (resolved.basraType != BasraType.none) score += 200;
    for (final captured in resolved.captured) {
      if (captured.isJack) score += 18;
      if (captured.basraNumericValue == 1) score += 18;
      if (captured.isTwoOfSpades) score += 28;
      if (captured.isTenOfDiamonds) score += 36;
    }
    if (card.isJack) score += 8;
    if (card.isSevenOfDiamonds) score += 10;
    return score;
  }
}
