// lib/modes/ninety_nine/domain/ninety_nine_game_engine.dart

import 'dart:math';
import 'package:estimation/core/models/card.dart';
import 'package:estimation/modes/ninety_nine/domain/models/ninety_nine_game_state.dart';
import 'package:estimation/modes/ninety_nine/domain/ninety_nine_card_rules.dart';

class NinetyNineGameEngine {
  static final Random _random = Random();
  static const int maxLosses = 5;

  static void dealCardsAndStartRound(NinetyNineGameState state, {required int roundNumber}) {
    state.groundTotal = 0;
    state.direction = 1;
    state.moveHistory = [];
    state.lastPlayedCard = null;
    state.lastPlayedPlayerName = null;
    state.roundLoserId = null;
    state.currentRoundNumber = roundNumber;

    for (final p in state.players) {
      p.hand.clear();
    }

    final deck = PlayingCard.fullDeck()..shuffle(_random);

    int pIndex = 0;
    while (deck.isNotEmpty) {
      state.players[pIndex].hand.add(deck.removeLast());
      pIndex = (pIndex + 1) % state.players.length;
    }

    for (final p in state.players) {
      p.hand.sort((a, b) => a.sortKey.compareTo(b.sortKey));
    }

    state.currentPlayerIndex = (roundNumber - 1) % state.players.length;
    state.phase = NinetyNinePhase.playing;
  }

  static void advanceToNextRound(NinetyNineGameState state) {
    if (state.phase != NinetyNinePhase.roundFinished) return;
    dealCardsAndStartRound(state, roundNumber: state.currentRoundNumber + 1);
  }

  static bool playCard(NinetyNineGameState state, String playerId, PlayingCard card) {
    if (state.phase != NinetyNinePhase.playing) return false;
    
    final currentPlayer = state.currentPlayer;
    if (currentPlayer?.id != playerId) return false;

    final playerIdx = state.players.indexWhere((p) => p.id == playerId);
    if (playerIdx == -1) return false;

    final player = state.players[playerIdx];
    final cardIdx = player.hand.indexWhere((c) => c == card);
    if (cardIdx == -1) return false;

    // Cards that would make the ground exceed 99 are illegal (also covers
    // ground == 99, where only safe cards 4 / 7 / Jack / King remain legal).
    if (!card.isLegalPlay(state.groundTotal)) {
      return false;
    }

    // 1. Remove card from hand
    player.hand.removeAt(cardIdx);
    state.lastPlayedCard = card;
    state.lastPlayedPlayerName = player.name;

    // 2. Apply card effect on ground total
    state.groundTotal = card.applyEffect(state.groundTotal);

    // 3. Apply direction change if 7
    if (card.isReverseCard) {
      state.direction = -state.direction;
    }

    // Record move
    state.moveHistory.add(NinetyNineMove(
      playerId: player.id,
      playerName: player.name,
      card: card,
      newGroundTotal: state.groundTotal,
    ));

    // 4. Calculate next player index
    final nextIndex = (state.currentPlayerIndex + state.direction + state.players.length) % state.players.length;

    // 5. Elimination / Round End Check — next player loses if they have no
    // card that can be played without exceeding 99.
    final nextPlayer = state.players[nextIndex];
    final hasLegalCard =
        nextPlayer.hand.any((c) => c.isLegalPlay(state.groundTotal));

    if (!hasLegalCard) {
      state.roundLoserId = nextPlayer.id;
      final currentLosses = (state.playerLosses[nextPlayer.id] ?? 0) + 1;
      state.playerLosses[nextPlayer.id] = currentLosses;

      if (currentLosses >= maxLosses) {
        state.matchLoserId = nextPlayer.id;

        final sortedByLosses = [...state.players]
          ..sort((a, b) =>
              (state.playerLosses[a.id] ?? 0).compareTo(state.playerLosses[b.id] ?? 0));
        state.matchWinnerId = sortedByLosses.first.id;
        state.phase = NinetyNinePhase.finished;
      } else {
        state.phase = NinetyNinePhase.roundFinished;
      }
      return true;
    }

    state.currentPlayerIndex = nextIndex;
    return true;
  }
}
