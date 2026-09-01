// test/ninety_nine_rules_test.dart

import 'package:flutter_test/flutter_test.dart';
import 'package:estimation/core/constants.dart';
import 'package:estimation/core/models/card.dart';
import 'package:estimation/modes/ninety_nine/domain/models/ninety_nine_game_state.dart';
import 'package:estimation/modes/ninety_nine/domain/ninety_nine_card_rules.dart';
import 'package:estimation/modes/ninety_nine/domain/ninety_nine_game_engine.dart';
import 'package:estimation/modes/ninety_nine/domain/ninety_nine_bot_ai.dart';
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

    test('Queen card effect: +10, illegal if it would exceed 99', () {
      const queen = PlayingCard(suit: Suit.diamond, rank: Rank.queen);

      expect(queen.applyEffect(50), equals(60));
      expect(queen.applyEffect(89), equals(99));
      expect(queen.isLegalPlay(89), isTrue);
      expect(queen.isLegalPlay(90), isFalse);
      expect(queen.unclampedEffect(95), equals(105));
    });

    test('4 and 7 card effects: +0', () {
      const four = PlayingCard(suit: Suit.club, rank: Rank.four);
      const seven = PlayingCard(suit: Suit.spade, rank: Rank.seven);

      expect(four.applyEffect(42), equals(42));
      expect(seven.applyEffect(42), equals(42));
      expect(seven.isReverseCard, isTrue);
    });

    test('Numeric cards that would exceed 99 are illegal', () {
      const ten = PlayingCard(suit: Suit.spade, rank: Rank.ten);
      const nine = PlayingCard(suit: Suit.heart, rank: Rank.nine);
      const ace = PlayingCard(suit: Suit.club, rank: Rank.ace);
      const two = PlayingCard(suit: Suit.spade, rank: Rank.two);
      const five = PlayingCard(suit: Suit.spade, rank: Rank.five);
      const king = PlayingCard(suit: Suit.diamond, rank: Rank.king);
      const jack = PlayingCard(suit: Suit.spade, rank: Rank.jack);
      const four = PlayingCard(suit: Suit.heart, rank: Rank.four);

      expect(ace.applyEffect(10), equals(11));
      expect(two.applyEffect(10), equals(12));
      expect(five.applyEffect(10), equals(15));
      expect(ten.applyEffect(10), equals(20));

      expect(ten.isLegalPlay(89), isTrue);
      expect(ten.isLegalPlay(90), isFalse);
      expect(nine.isLegalPlay(90), isTrue);
      expect(nine.isLegalPlay(91), isFalse);
      expect(ace.isLegalPlay(98), isTrue);
      expect(ace.isLegalPlay(99), isFalse);

      expect(king.isLegalPlay(90), isTrue);
      expect(king.isLegalPlay(99), isTrue);
      expect(jack.isLegalPlay(99), isTrue);
      expect(four.isLegalPlay(99), isTrue);
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

    test('At groundTotal 99, only safe cards can be played', () {
      final state = NinetyNineGameState(
        hostId: 'p_0',
        players: [
          NinetyNinePlayer(
            id: 'p_0',
            name: 'Player 0',
            hand: [
              const PlayingCard(suit: Suit.spade, rank: Rank.five),
              const PlayingCard(suit: Suit.heart, rank: Rank.jack),
            ],
            isBot: false,
          ),
          NinetyNinePlayer(
            id: 'p_1',
            name: 'Player 1',
            hand: [
              const PlayingCard(suit: Suit.diamond, rank: Rank.four),
            ],
            isBot: false,
          ),
        ],
        playerLosses: {'p_0': 0, 'p_1': 0},
      );

      state.phase = NinetyNinePhase.playing;
      state.groundTotal = 99;
      state.currentPlayerIndex = 0;

      // 5 is NOT safe -> rejected
      final nonSafeCard = const PlayingCard(suit: Suit.spade, rank: Rank.five);
      final acceptedNonSafe = NinetyNineGameEngine.playCard(state, 'p_0', nonSafeCard);
      expect(acceptedNonSafe, isFalse);

      // Jack IS safe -> accepted and reduces total to 89
      final safeCard = const PlayingCard(suit: Suit.heart, rank: Rank.jack);
      final acceptedSafe = NinetyNineGameEngine.playCard(state, 'p_0', safeCard);
      expect(acceptedSafe, isTrue);
      expect(state.groundTotal, equals(89));
    });

    test('Cards that would make ground exceed 99 are rejected', () {
      final state = NinetyNineGameState(
        hostId: 'p_0',
        players: [
          NinetyNinePlayer(
            id: 'p_0',
            name: 'Player 0',
            hand: [
              const PlayingCard(suit: Suit.spade, rank: Rank.ten),
              const PlayingCard(suit: Suit.heart, rank: Rank.nine),
              const PlayingCard(suit: Suit.club, rank: Rank.queen),
            ],
            isBot: false,
          ),
          NinetyNinePlayer(
            id: 'p_1',
            name: 'Player 1',
            hand: [
              const PlayingCard(suit: Suit.diamond, rank: Rank.four),
            ],
            isBot: false,
          ),
        ],
        playerLosses: {'p_0': 0, 'p_1': 0},
      );

      state.phase = NinetyNinePhase.playing;
      state.groundTotal = 90;
      state.currentPlayerIndex = 0;

      expect(
        NinetyNineGameEngine.playCard(
          state,
          'p_0',
          const PlayingCard(suit: Suit.spade, rank: Rank.ten),
        ),
        isFalse,
      );
      expect(
        NinetyNineGameEngine.playCard(
          state,
          'p_0',
          const PlayingCard(suit: Suit.club, rank: Rank.queen),
        ),
        isFalse,
      );
      expect(state.groundTotal, equals(90));

      expect(
        NinetyNineGameEngine.playCard(
          state,
          'p_0',
          const PlayingCard(suit: Suit.heart, rank: Rank.nine),
        ),
        isTrue,
      );
      expect(state.groundTotal, equals(99));
    });
  });

  group('NinetyNineBotAi Tests', () {
    test('Bot picks safe card (prefers Jack -10) when groundTotal is 99', () {
      final hand = [
        const PlayingCard(suit: Suit.spade, rank: Rank.five),
        const PlayingCard(suit: Suit.heart, rank: Rank.seven),
        const PlayingCard(suit: Suit.club, rank: Rank.jack),
        const PlayingCard(suit: Suit.diamond, rank: Rank.king),
      ];

      final chosen = NinetyNineBotAi.chooseCard(hand: hand, groundTotal: 99);
      expect(chosen.rank, equals(Rank.jack));
    });

    test('Bot saves safe cards when groundTotal < 99', () {
      final hand = [
        const PlayingCard(suit: Suit.spade, rank: Rank.five),
        const PlayingCard(suit: Suit.heart, rank: Rank.seven),
        const PlayingCard(suit: Suit.club, rank: Rank.jack),
      ];

      final chosen = NinetyNineBotAi.chooseCard(hand: hand, groundTotal: 40);
      expect(chosen.rank, equals(Rank.five));
    });

    test('Bot never picks a card that would exceed 99', () {
      final hand = [
        const PlayingCard(suit: Suit.spade, rank: Rank.queen),
        const PlayingCard(suit: Suit.heart, rank: Rank.ten),
        const PlayingCard(suit: Suit.club, rank: Rank.five),
      ];

      final chosen = NinetyNineBotAi.chooseCard(hand: hand, groundTotal: 90);
      expect(chosen.rank, equals(Rank.five));
      expect(chosen.isLegalPlay(90), isTrue);
    });
  });
}

