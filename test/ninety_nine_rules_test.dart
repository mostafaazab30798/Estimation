// test/ninety_nine_rules_test.dart

import 'package:flutter_test/flutter_test.dart';
import 'package:estimation/core/constants.dart';
import 'package:estimation/core/models/card.dart';
import 'package:estimation/modes/ninety_nine/domain/models/ninety_nine_game_state.dart';
import 'package:estimation/modes/ninety_nine/domain/ninety_nine_card_rules.dart';
import 'package:estimation/modes/ninety_nine/domain/ninety_nine_game_engine.dart';
import 'package:estimation/modes/ninety_nine/presentation/providers/ninety_nine_game_provider.dart';

void main() {
  group('99 Game Mode Card Rules Tests', () {
    test('Safe cards check (4, 7, Jack, King)', () {
      expect(const PlayingCard(suit: Suit.spade, rank: Rank.four).isSafeCard, isTrue);
      expect(const PlayingCard(suit: Suit.heart, rank: Rank.seven).isSafeCard, isTrue);
      expect(const PlayingCard(suit: Suit.diamond, rank: Rank.jack).isSafeCard, isTrue);
      expect(const PlayingCard(suit: Suit.club, rank: Rank.king).isSafeCard, isTrue);

      expect(const PlayingCard(suit: Suit.spade, rank: Rank.queen).isSafeCard, isFalse);
      expect(const PlayingCard(suit: Suit.spade, rank: Rank.ace).isSafeCard, isFalse);
      expect(const PlayingCard(suit: Suit.spade, rank: Rank.ten).isSafeCard, isFalse);
    });

    test('King card effect: sets to 99, or acts as +0 if already 99', () {
      const king = PlayingCard(suit: Suit.spade, rank: Rank.king);

      expect(king.applyEffect(0), equals(99));
      expect(king.applyEffect(50), equals(99));
      expect(king.applyEffect(98), equals(99));
      expect(king.applyEffect(99), equals(99));
    });

    test('Jack card effect: -10, clamped at 0', () {
      const jack = PlayingCard(suit: Suit.heart, rank: Rank.jack);

      expect(jack.applyEffect(50), equals(40));
      expect(jack.applyEffect(5), equals(0));
      expect(jack.applyEffect(0), equals(0));
    });

    test('Queen card effect: +10, clamped at 99', () {
      const queen = PlayingCard(suit: Suit.diamond, rank: Rank.queen);

      expect(queen.applyEffect(50), equals(60));
      expect(queen.applyEffect(95), equals(99));
    });

    test('4 and 7 card effects: +0', () {
      const four = PlayingCard(suit: Suit.club, rank: Rank.four);
      const seven = PlayingCard(suit: Suit.spade, rank: Rank.seven);

      expect(four.applyEffect(42), equals(42));
      expect(seven.applyEffect(42), equals(42));
      expect(seven.isReverseCard, isTrue);
    });

    test('Ace and numeric card effects', () {
      expect(const PlayingCard(suit: Suit.spade, rank: Rank.ace).applyEffect(10), equals(11));
      expect(const PlayingCard(suit: Suit.spade, rank: Rank.two).applyEffect(10), equals(12));
      expect(const PlayingCard(suit: Suit.spade, rank: Rank.five).applyEffect(10), equals(15));
      expect(const PlayingCard(suit: Suit.spade, rank: Rank.ten).applyEffect(10), equals(20));
    });
  });

  group('NinetyNineGameEngine 2-7 Player & Round Match Tests', () {
    test('Game initialization supports 2 to 7 players', () {
      for (int count = 2; count <= 7; count++) {
        final players = List.generate(
          count,
          (i) => NinetyNinePlayer(id: 'p_$i', name: 'لاعب ${i + 1}', hand: [], isBot: i > 0, avatarId: 'avatar_1'),
        );
        final state = NinetyNineGameState(
          hostId: 'p_0',
          players: players,
          playerLosses: {for (final p in players) p.id: 0},
        );

        NinetyNineGameEngine.dealCardsAndStartRound(state, roundNumber: 1);

        expect(state.phase, equals(NinetyNinePhase.playing));
        expect(state.groundTotal, equals(0));
        expect(state.players.length, equals(count));
        expect(state.currentRoundNumber, equals(1));
      }
    });

    test('Playing card updating groundTotal and advance turn', () {
      final players = List.generate(
        4,
        (i) => NinetyNinePlayer(id: 'p_$i', name: 'لاعب ${i + 1}', hand: [], isBot: false, avatarId: 'avatar_1'),
      );
      final state = NinetyNineGameState(
        hostId: 'p_0',
        players: players,
        playerLosses: {for (final p in players) p.id: 0},
      );

      NinetyNineGameEngine.dealCardsAndStartRound(state, roundNumber: 1);

      final p0 = state.players[0];
      final cardToPlay = p0.hand.first;
      final expectedGround = cardToPlay.applyEffect(0);

      final accepted = NinetyNineGameEngine.playCard(state, p0.id, cardToPlay);

      expect(accepted, isTrue);
      expect(state.groundTotal, equals(expectedGround));
    });
  });
}
