// lib/modes/basra/domain/basra_scoring.dart

import 'package:estimation/core/constants.dart';
import 'package:estimation/core/models/card.dart';
import 'package:estimation/modes/basra/domain/basra_card_rules.dart';
import 'package:estimation/modes/basra/domain/basra_constants.dart';
import 'package:estimation/modes/basra/domain/models/basra_game_state.dart';

class BasraScoreBreakdown {
  final int capturedCount;
  final int jackPoints;
  final int acePoints;
  final int twoOfSpadesPoints;
  final int tenOfDiamondsPoints;
  final int basraPoints;
  final int majorityPoints;
  final int total;

  const BasraScoreBreakdown({
    required this.capturedCount,
    required this.jackPoints,
    required this.acePoints,
    required this.twoOfSpadesPoints,
    required this.tenOfDiamondsPoints,
    required this.basraPoints,
    required this.majorityPoints,
    required this.total,
  });
}

class BasraScoring {
  const BasraScoring._();

  /// Round score for one player, excluding carry-over majority points.
  static BasraScoreBreakdown calculateBasraRoundScore({
    required List<PlayingCard> capturedCards,
    required int basraCount,
  }) {
    final jackPoints = capturedCards.where((c) => c.isJack).length * kBasraJackPoints;
    final acePoints = capturedCards.where((c) => c.rank == Rank.ace).length * kBasraAcePoints;
    final twoOfSpadesPoints =
        capturedCards.any((c) => c.isTwoOfSpades) ? kBasraTwoOfSpadesPoints : 0;
    final tenOfDiamondsPoints =
        capturedCards.any((c) => c.isTenOfDiamonds) ? kBasraTenOfDiamondsPoints : 0;
    final basraPoints = basraCount * kBasraBasraBonus;
    final majorityPoints =
        capturedCards.length >= kBasraMajorityThreshold ? kBasraMajorityPoints : 0;

    return BasraScoreBreakdown(
      capturedCount: capturedCards.length,
      jackPoints: jackPoints,
      acePoints: acePoints,
      twoOfSpadesPoints: twoOfSpadesPoints,
      tenOfDiamondsPoints: tenOfDiamondsPoints,
      basraPoints: basraPoints,
      majorityPoints: majorityPoints,
      total: majorityPoints +
          jackPoints +
          acePoints +
          twoOfSpadesPoints +
          tenOfDiamondsPoints +
          basraPoints,
    );
  }

  static bool isTwentySixTie(List<BasraPlayer> players) {
    final withTwentySix = players.where((p) => p.capturedCards.length == 26).length;
    return withTwentySix == 2 &&
        players.every((p) => p.capturedCards.length < kBasraMajorityThreshold);
  }

  static BasraPlayer? majorityWinner(List<BasraPlayer> players) {
    BasraPlayer? winner;
    for (final player in players) {
      if (player.capturedCards.length >= kBasraMajorityThreshold) {
        if (winner != null) return winner;
        winner = player;
      }
    }
    return winner;
  }
}
