// test/anti_cheat_sanitization_test.dart

import 'package:flutter_test/flutter_test.dart';
import 'package:estimation/core/models/card.dart';
import 'package:estimation/core/models/player.dart';
import 'package:estimation/core/models/game_state.dart';
import 'package:estimation/core/constants.dart';
import 'package:estimation/modes/ninety_nine/domain/models/ninety_nine_game_state.dart';

void main() {
  group('Anti-Cheat Hand Masking & State Sanitization Tests', () {
    test('Player.toSanitizedJson masks hand for opponents and preserves for self', () {
      final player = Player(
        id: 'player_1',
        name: 'Player 1',
        seatIndex: 0,
        hand: const [
          PlayingCard(suit: Suit.spade, rank: Rank.ace),
          PlayingCard(suit: Suit.heart, rank: Rank.king),
          PlayingCard(suit: Suit.diamond, rank: Rank.ten),
        ],
      );

      // When serialized for self:
      final selfJson = player.toSanitizedJson(isSelf: true);
      final selfCards = selfJson['hand'] as List<dynamic>;
      expect(selfCards.length, 3);
      expect(selfCards[0]['suit'], 'spade');
      expect(selfCards[0]['rank'], 'ace');

      // When serialized for opponents:
      final opponentJson = player.toSanitizedJson(isSelf: false);
      final opponentCards = opponentJson['hand'] as List<dynamic>;
      expect(opponentCards.length, 3); // Preserves exact card count
      // Does not contain actual card suits/ranks
      expect(opponentCards[0]['suit'], 'spade');
      expect(opponentCards[0]['rank'], 'two');
      expect(opponentCards[1]['suit'], 'spade');
      expect(opponentCards[1]['rank'], 'two');
    });

    test('GameState.toSanitizedJson filters cards per recipient player ID', () {
      final p1 = Player(
        id: 'p1',
        name: 'P1',
        seatIndex: 0,
        hand: const [PlayingCard(suit: Suit.heart, rank: Rank.ace)],
      );
      final p2 = Player(
        id: 'p2',
        name: 'P2',
        seatIndex: 1,
        hand: const [PlayingCard(suit: Suit.club, rank: Rank.king)],
      );

      final state = GameState(
        players: [p1, p2],
        phase: GamePhase.trickTaking,
      );

      // Sanitized for p1
      final p1State = state.toSanitizedJson(recipientPlayerId: 'p1');
      final p1Players = p1State['players'] as List<dynamic>;

      // p1 sees their own Ace of Hearts
      expect(p1Players[0]['hand'][0]['suit'], 'heart');
      expect(p1Players[0]['hand'][0]['rank'], 'ace');

      // p1 sees p2 with 1 masked card (dummy 'two')
      expect(p1Players[1]['hand'].length, 1);
      expect(p1Players[1]['hand'][0]['rank'], 'two');

      // Sanitized for p2
      final p2State = state.toSanitizedJson(recipientPlayerId: 'p2');
      final p2Players = p2State['players'] as List<dynamic>;

      // p2 sees p1 with 1 masked card
      expect(p2Players[0]['hand'][0]['rank'], 'two');

      // p2 sees their own King of Clubs
      expect(p2Players[1]['hand'][0]['suit'], 'club');
      expect(p2Players[1]['hand'][0]['rank'], 'king');
    });

    test('NinetyNineGameState.toSanitizedJson filters 99 mode hands properly', () {
      final p1 = NinetyNinePlayer(
        id: 'p1',
        name: 'P1',
        hand: const [PlayingCard(suit: Suit.diamond, rank: Rank.queen)],
      );
      final p2 = NinetyNinePlayer(
        id: 'p2',
        name: 'P2',
        hand: const [PlayingCard(suit: Suit.spade, rank: Rank.four)],
      );

      final state = NinetyNineGameState(
        players: [p1, p2],
        playerLosses: {'p1': 0, 'p2': 0},
        hostId: 'p1',
      );

      final sanitized = state.toSanitizedJson(recipientPlayerId: 'p1');
      final players = sanitized['players'] as List<dynamic>;

      expect(players[0]['hand'][0]['suit'], 'diamond');
      expect(players[0]['hand'][0]['rank'], 'queen');

      expect(players[1]['hand'].length, 1);
      expect(players[1]['hand'][0]['rank'], 'two');
    });
  });
}
