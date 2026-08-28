// lib/modes/basra/domain/basra_game_engine.dart

import 'dart:math';

import 'package:estimation/core/models/card.dart';
import 'package:estimation/modes/basra/domain/basra_capture_engine.dart';
import 'package:estimation/modes/basra/domain/basra_card_rules.dart';
import 'package:estimation/modes/basra/domain/basra_constants.dart';
import 'package:estimation/modes/basra/domain/basra_scoring.dart';
import 'package:estimation/modes/basra/domain/models/basra_game_state.dart';

class BasraGameEngine {
  const BasraGameEngine._();

  static final Random _random = Random();

  static void startMatch(BasraGameState state, {Random? random, List<PlayingCard>? deck}) {
    state.currentRoundNumber = 1;
    state.carriedMajorityPoints = 0;
    state.matchWinnerId = null;
    state.lastRoundScores = [];
    state.lastTurnResult = null;
    for (final player in state.players) {
      player.totalScore = 0;
    }
    initializeRound(state, random: random, deck: deck);
  }

  static void initializeRound(
    BasraGameState state, {
    Random? random,
    List<PlayingCard>? deck,
  }) {
    for (final player in state.players) {
      player.resetForRound();
    }
    state.tableCards = [];
    state.lastCapturePlayerId = null;
    state.lastTurnResult = null;
    state.lastRoundScores = [];
    state.lastRoundAwardedFinalTable = false;
    state.lastRoundWasTwentySixTie = false;
    state.matchWinnerId = null;

    state.dealerPlayerIndex =
        (state.currentRoundNumber - 1) % state.players.length;
    state.currentPlayerIndex =
        (state.dealerPlayerIndex + 1) % state.players.length;

    dealInitialCards(state, random: random, deck: deck);
    replaceInitialSpecialTableCards(state);
    state.phase = BasraPhase.playing;
  }

  static void dealInitialCards(
    BasraGameState state, {
    Random? random,
    List<PlayingCard>? deck,
  }) {
    final source = deck != null
        ? List<PlayingCard>.from(deck)
        : (PlayingCard.fullDeck()..shuffle(random ?? _random));

    for (final player in state.players) {
      player.hand.clear();
    }
    state.tableCards = [];

    for (var i = 0; i < kBasraHandSize; i++) {
      for (final player in state.players) {
        if (source.isEmpty) break;
        player.hand.add(source.removeLast());
      }
    }

    for (var i = 0; i < kBasraTableSize; i++) {
      if (source.isEmpty) break;
      state.tableCards.add(source.removeLast());
    }

    state.deck = source;
    _sortHands(state);
  }

  static void replaceInitialSpecialTableCards(BasraGameState state) {
    var guard = 0;
    while (state.tableCards.any((c) => c.isInitialTableForbidden) &&
        state.deck.isNotEmpty &&
        guard < 60) {
      guard++;
      for (var i = 0; i < state.tableCards.length; i++) {
        if (!state.tableCards[i].isInitialTableForbidden) continue;
        if (state.deck.isEmpty) return;
        final special = state.tableCards[i];
        state.deck.insert(0, special);
        state.tableCards[i] = state.deck.removeLast();
      }
    }
  }

  static List<PlayingCard> getPlayableCards(BasraGameState state, String playerId) {
    if (state.phase != BasraPhase.playing) return const [];
    final current = state.currentPlayer;
    if (current == null || current.id != playerId) return const [];
    return List<PlayingCard>.from(current.hand);
  }

  static bool playCard(BasraGameState state, String playerId, PlayingCard card) {
    if (!_validatePlay(state, playerId, card)) return false;

    final player = state.playerById(playerId);
    final tableBefore = List<PlayingCard>.from(state.tableCards);
    player.hand.removeWhere((c) => c == card);

    final resolved = BasraCaptureEngine.resolvePlay(card, tableBefore);
    state.tableCards = List<PlayingCard>.from(resolved.tableAfter);

    if (resolved.wasCapture) {
      player.capturedCards.addAll(resolved.captured);
      player.capturedCards.add(card);
      state.lastCapturePlayerId = playerId;
      if (resolved.basraType != BasraType.none) {
        player.basraCount += 1;
        player.roundScore += kBasraBasraBonus;
      }
    }

    state.lastTurnResult = BasraTurnResult(
      playerId: playerId,
      playedCard: card,
      capturedCards: resolved.captured,
      tableBefore: tableBefore,
      tableAfter: List<PlayingCard>.from(state.tableCards),
      wasCapture: resolved.wasCapture,
      wasBasra: resolved.basraType != BasraType.none,
      basraType: resolved.basraType,
      lastCapturePlayerId: state.lastCapturePlayerId,
    );

    if (state.allHandsEmpty) {
      if (state.deck.isNotEmpty) {
        dealNextHands(state);
        _advanceTurn(state);
      } else {
        finishRound(state);
      }
      return true;
    }

    _advanceTurn(state);
    return true;
  }

  static bool _validatePlay(BasraGameState state, String playerId, PlayingCard card) {
    if (state.phase != BasraPhase.playing) return false;
    if (state.matchWinnerId != null) return false;
    final current = state.currentPlayer;
    if (current == null || current.id != playerId) return false;
    if (current.hand.isEmpty) return false;
    return current.hand.any((c) => c == card);
  }

  static void dealNextHands(BasraGameState state) {
    if (!state.allHandsEmpty) return;
    if (state.deck.isEmpty) return;

    for (var i = 0; i < kBasraHandSize; i++) {
      for (final player in state.players) {
        if (state.deck.isEmpty) break;
        player.hand.add(state.deck.removeLast());
      }
    }
    _sortHands(state);
  }

  static void finishRound(BasraGameState state) {
    state.lastRoundAwardedFinalTable = false;
    if (state.tableCards.isNotEmpty && state.lastCapturePlayerId != null) {
      final capturer = state.playerByIdOrNull(state.lastCapturePlayerId!);
      if (capturer != null) {
        capturer.capturedCards.addAll(state.tableCards);
        state.tableCards = [];
        state.lastRoundAwardedFinalTable = true;
      }
    }

    final wasTie = BasraScoring.isTwentySixTie(state.players);
    state.lastRoundWasTwentySixTie = wasTie;

    final majority = BasraScoring.majorityWinner(state.players);
    final carryToApply =
        (!wasTie && majority != null) ? state.carriedMajorityPoints : 0;

    final scores = <BasraPlayerScore>[];
    for (final player in state.players) {
      final breakdown = BasraScoring.calculateBasraRoundScore(
        capturedCards: player.capturedCards,
        basraCount: player.basraCount,
      );
      final carry = player.id == majority?.id ? carryToApply : 0;
      final roundScore = breakdown.total + carry;
      player.roundScore = roundScore;
      player.totalScore += roundScore;
      scores.add(BasraPlayerScore(
        playerId: player.id,
        capturedCount: breakdown.capturedCount,
        jackPoints: breakdown.jackPoints,
        acePoints: breakdown.acePoints,
        twoOfSpadesPoints: breakdown.twoOfSpadesPoints,
        tenOfDiamondsPoints: breakdown.tenOfDiamondsPoints,
        basraPoints: breakdown.basraPoints,
        majorityPoints: breakdown.majorityPoints,
        carryOverPoints: carry,
        roundScore: roundScore,
        totalScore: player.totalScore,
        basraCount: player.basraCount,
      ));
    }
    state.lastRoundScores = scores;

    if (wasTie) {
      state.carriedMajorityPoints += kBasraMajorityPoints;
    } else if (majority != null) {
      state.carriedMajorityPoints = 0;
    }

    final winner = _matchWinner(state);
    if (winner != null) {
      state.matchWinnerId = winner.id;
      state.phase = BasraPhase.finished;
    } else {
      state.phase = BasraPhase.roundFinished;
    }
  }

  static void advanceToNextRound(BasraGameState state, {Random? random, List<PlayingCard>? deck}) {
    if (state.phase != BasraPhase.roundFinished) return;
    state.currentRoundNumber += 1;
    initializeRound(state, random: random, deck: deck);
  }

  static BasraPlayer? checkMatchWinner(BasraGameState state) => _matchWinner(state);

  static BasraPlayer? _matchWinner(BasraGameState state) {
    BasraPlayer? winner;
    for (final player in state.players) {
      if (player.totalScore < kBasraMatchTarget) continue;
      if (winner == null ||
          player.totalScore > winner.totalScore ||
          (player.totalScore == winner.totalScore &&
              state.players.indexOf(player) < state.players.indexOf(winner))) {
        winner = player;
      }
    }
    return winner;
  }

  static void _advanceTurn(BasraGameState state) {
    if (state.players.isEmpty) return;
    state.currentPlayerIndex =
        (state.currentPlayerIndex + 1) % state.players.length;
  }

  static void _sortHands(BasraGameState state) {
    for (final player in state.players) {
      player.hand.sort((a, b) => a.sortKey.compareTo(b.sortKey));
    }
  }
}
