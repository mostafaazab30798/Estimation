// lib/modes/basra/domain/basra_capture_engine.dart

import 'package:estimation/core/models/card.dart';
import 'package:estimation/modes/basra/domain/basra_card_rules.dart';
import 'package:estimation/modes/basra/domain/models/basra_game_state.dart';

/// Pure capture + Basra detection. No widget or session dependencies.
class BasraCaptureEngine {
  const BasraCaptureEngine._();

  static List<PlayingCard> findSameRankCards(
    PlayingCard playedCard,
    List<PlayingCard> tableCards,
  ) {
    return tableCards.where((c) => c.rank == playedCard.rank).toList();
  }

  /// Deterministic subset-sum over numeric table cards.
  ///
  /// Policy when multiple subsets match [target]:
  /// 1. Maximize number of captured cards.
  /// 2. Then lexicographically smallest sorted card-ID sequence.
  static List<PlayingCard> findBestSumCombination(
    List<PlayingCard> tableCards,
    int target,
  ) {
    final numeric = tableCards.where((c) => c.isBasraNumeric).toList()
      ..sort((a, b) {
        final valueCmp = a.basraNumericValue!.compareTo(b.basraNumericValue!);
        if (valueCmp != 0) return valueCmp;
        return a.id.compareTo(b.id);
      });

    List<PlayingCard>? best;
    String? bestKey;

    void search(int start, int remaining, List<PlayingCard> path) {
      if (remaining == 0) {
        final key = _combinationKey(path);
        if (best == null ||
            path.length > best!.length ||
            (path.length == best!.length && key.compareTo(bestKey!) < 0)) {
          best = List<PlayingCard>.from(path);
          bestKey = key;
        }
        return;
      }
      for (var i = start; i < numeric.length; i++) {
        final value = numeric[i].basraNumericValue!;
        if (value > remaining) break;
        path.add(numeric[i]);
        search(i + 1, remaining - value, path);
        path.removeLast();
      }
    }

    search(0, target, []);
    return best ?? const [];
  }

  static String _combinationKey(List<PlayingCard> cards) {
    final ids = cards.map((c) => c.id).toList()..sort();
    return ids.join('|');
  }

  static List<PlayingCard> resolveDeterministicCapture(
    PlayingCard playedCard,
    List<PlayingCard> tableCards,
  ) {
    final sameRank = findSameRankCards(playedCard, tableCards);
    final sameRankIds = sameRank.map((c) => c.id).toSet();

    var sumCombo = const <PlayingCard>[];
    final numericValue = playedCard.basraNumericValue;
    if (numericValue != null) {
      final remaining = tableCards.where((c) => !sameRankIds.contains(c.id)).toList();
      sumCombo = findBestSumCombination(remaining, numericValue);
    }

    final captured = <PlayingCard>[...sameRank];
    final seen = sameRankIds;
    for (final card in sumCombo) {
      if (seen.add(card.id)) captured.add(card);
    }
    captured.sort((a, b) => a.id.compareTo(b.id));
    return captured;
  }

  static BasraType detectBasra({
    required PlayingCard playedCard,
    required List<PlayingCard> tableBeforePlay,
    required List<PlayingCard> capturedCards,
  }) {
    if (tableBeforePlay.isEmpty) return BasraType.none;
    if (capturedCards.length != tableBeforePlay.length) return BasraType.none;

    final capturedIds = capturedCards.map((c) => c.id).toSet();
    final tableIds = tableBeforePlay.map((c) => c.id).toSet();
    if (capturedIds.length != tableIds.length || !capturedIds.containsAll(tableIds)) {
      return BasraType.none;
    }

    if (playedCard.isJack) return BasraType.none;

    if (playedCard.isSevenOfDiamonds) {
      return _sevenOfDiamondsBasraEligible(tableBeforePlay)
          ? BasraType.sevenOfDiamonds
          : BasraType.none;
    }

    return BasraType.normal;
  }

  static bool _sevenOfDiamondsBasraEligible(List<PlayingCard> tableBeforePlay) {
    if (tableBeforePlay.any((c) => c.isQueen || c.isKing)) return false;
    return basraTableNumericTotal(tableBeforePlay) <= 10;
  }

  /// Resolves what a play would capture without mutating game state.
  static ({
    List<PlayingCard> captured,
    List<PlayingCard> tableAfter,
    bool wasCapture,
    bool wasSweep,
    BasraType basraType,
  }) resolvePlay(PlayingCard playedCard, List<PlayingCard> tableCards) {
    final tableBefore = List<PlayingCard>.from(tableCards);

    if (playedCard.isJack || playedCard.isSevenOfDiamonds) {
      if (tableBefore.isEmpty) {
        return (
          captured: const <PlayingCard>[],
          tableAfter: [playedCard],
          wasCapture: false,
          wasSweep: false,
          basraType: BasraType.none,
        );
      }
      final basraType = detectBasra(
        playedCard: playedCard,
        tableBeforePlay: tableBefore,
        capturedCards: tableBefore,
      );
      return (
        captured: tableBefore,
        tableAfter: const <PlayingCard>[],
        wasCapture: true,
        wasSweep: true,
        basraType: basraType,
      );
    }

    final captured = resolveDeterministicCapture(playedCard, tableBefore);
    if (captured.isEmpty) {
      return (
        captured: const <PlayingCard>[],
        tableAfter: [...tableBefore, playedCard],
        wasCapture: false,
        wasSweep: false,
        basraType: BasraType.none,
      );
    }

    final capturedIds = captured.map((c) => c.id).toSet();
    final tableAfter = tableBefore.where((c) => !capturedIds.contains(c.id)).toList();
    final basraType = detectBasra(
      playedCard: playedCard,
      tableBeforePlay: tableBefore,
      capturedCards: captured,
    );
    return (
      captured: captured,
      tableAfter: tableAfter,
      wasCapture: true,
      wasSweep: false,
      basraType: basraType,
    );
  }
}
