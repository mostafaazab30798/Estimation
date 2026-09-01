// W1.2 — Protocol confidentiality: simulated wire frames must not leak opponent cards.

import 'package:flutter_test/flutter_test.dart';
import 'package:estimation/core/models/card.dart';
import 'package:estimation/core/constants.dart';
import 'package:estimation/core/models/game_state.dart';
import 'package:estimation/core/models/player.dart';
import 'package:estimation/core/utils/wire_frame_inspector.dart';
import 'package:estimation/modes/basra/domain/models/basra_game_state.dart';
import 'package:estimation/modes/ninety_nine/domain/models/ninety_nine_game_state.dart';

void main() {
  group('Protocol confidentiality (W1.2 wire frames)', () {
    test('Estimation broadcast frame masks all opponent hands', () {
      final state = GameState(
        phase: GamePhase.trickTaking,
        players: [
          Player(
            id: 'human',
            name: 'Human',
            seatIndex: 0,
            hand: const [PlayingCard(suit: Suit.spade, rank: Rank.ace)],
          ),
          Player(
            id: 'opponent',
            name: 'Opponent',
            seatIndex: 1,
            hand: const [PlayingCard(suit: Suit.heart, rank: Rank.king)],
          ),
        ],
      );

      final wire = state.toSanitizedJson();
      final leaks = findOpponentHandLeaks(
        payload: wire,
        viewerPlayerId: 'human',
      );

      expect(leaks, isEmpty, reason: 'sanitized frame leaked: $leaks');
    });

    test('99 broadcast frame masks opponent hands', () {
      final state = NinetyNineGameState(
        hostId: 'human',
        players: [
          NinetyNinePlayer(
            id: 'human',
            name: 'Human',
            hand: const [PlayingCard(suit: Suit.diamond, rank: Rank.nine)],
          ),
          NinetyNinePlayer(
            id: 'opponent',
            name: 'Opponent',
            hand: const [PlayingCard(suit: Suit.club, rank: Rank.four)],
          ),
        ],
        playerLosses: const {'human': 0, 'opponent': 0},
      );

      final wire = state.toSanitizedJson();
      final leaks = findOpponentHandLeaks(
        payload: wire,
        viewerPlayerId: 'human',
      );

      expect(leaks, isEmpty);
    });

    test('Basra broadcast frame strips deck and masks hands', () {
      final state = BasraGameState(
        hostId: 'human',
        deck: const [PlayingCard(suit: Suit.spade, rank: Rank.two)],
        players: [
          BasraPlayer(
            id: 'human',
            name: 'Human',
            hand: const [PlayingCard(suit: Suit.heart, rank: Rank.ace)],
          ),
          BasraPlayer(
            id: 'opponent',
            name: 'Opponent',
            hand: const [PlayingCard(suit: Suit.club, rank: Rank.king)],
          ),
        ],
      );

      final wire = state.toSanitizedJson();
      expect(wire.containsKey('deck'), isFalse);
      expect(wire['deckCount'], 1);

      final leaks = findOpponentHandLeaks(
        payload: wire,
        viewerPlayerId: 'human',
      );
      expect(leaks, isEmpty);
    });

    test('raw toJson would fail leak inspection (canary)', () {
      final state = GameState(
        players: [
          Player(
            id: 'human',
            name: 'Human',
            seatIndex: 0,
            hand: const [PlayingCard(suit: Suit.spade, rank: Rank.ace)],
          ),
          Player(
            id: 'opponent',
            name: 'Opponent',
            seatIndex: 1,
            hand: const [PlayingCard(suit: Suit.heart, rank: Rank.king)],
          ),
        ],
      );

      final leaks = findOpponentHandLeaks(
        payload: state.toJson(),
        viewerPlayerId: 'human',
      );

      expect(leaks, isNotEmpty);
    });
  });
}
