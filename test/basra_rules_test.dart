// test/basra_rules_test.dart

import 'package:flutter_test/flutter_test.dart';
import 'package:estimation/core/constants.dart';
import 'package:estimation/core/models/card.dart';
import 'package:estimation/modes/basra/domain/basra_bot_ai.dart';
import 'package:estimation/modes/basra/domain/basra_capture_engine.dart';
import 'package:estimation/modes/basra/domain/basra_card_rules.dart';
import 'package:estimation/modes/basra/domain/basra_constants.dart';
import 'package:estimation/modes/basra/domain/basra_game_engine.dart';
import 'package:estimation/modes/basra/domain/basra_scoring.dart';
import 'package:estimation/modes/basra/domain/models/basra_game_state.dart';

PlayingCard c(Suit suit, Rank rank) => PlayingCard(suit: suit, rank: rank);

List<PlayingCard> deckForDeal({
  required List<List<PlayingCard>> hands,
  required List<PlayingCard> table,
  List<PlayingCard> rest = const [],
}) {
  final stacked = <PlayingCard>[...rest];
  for (final card in table.reversed) {
    stacked.add(card);
  }
  for (var i = 3; i >= 0; i--) {
    for (var p = hands.length - 1; p >= 0; p--) {
      stacked.add(hands[p][i]);
    }
  }
  return stacked;
}

BasraGameState twoPlayers({
  List<PlayingCard>? p0Hand,
  List<PlayingCard>? p1Hand,
  List<PlayingCard>? table,
  List<PlayingCard>? deck,
}) {
  final state = BasraGameState(
    hostId: 'p0',
    players: [
      BasraPlayer(id: 'p0', name: 'A', hand: p0Hand ?? []),
      BasraPlayer(id: 'p1', name: 'B', hand: p1Hand ?? []),
    ],
  );
  state.phase = BasraPhase.playing;
  state.currentPlayerIndex = 0;
  state.dealerPlayerIndex = 1;
  state.tableCards = table ?? [];
  state.deck = deck ?? [];
  return state;
}

void main() {
  group('Basra card values', () {
    test('A–10 have numeric values; J/Q/K do not', () {
      expect(c(Suit.spade, Rank.ace).basraNumericValue, 1);
      expect(c(Suit.heart, Rank.ten).basraNumericValue, 10);
      expect(c(Suit.club, Rank.seven).basraNumericValue, 7);
      expect(c(Suit.heart, Rank.jack).basraNumericValue, isNull);
      expect(c(Suit.heart, Rank.queen).basraNumericValue, isNull);
      expect(c(Suit.heart, Rank.king).basraNumericValue, isNull);
    });

    test('Only 7♦ is the special seven', () {
      expect(c(Suit.diamond, Rank.seven).isSevenOfDiamonds, isTrue);
      expect(c(Suit.spade, Rank.seven).isSevenOfDiamonds, isFalse);
      expect(c(Suit.heart, Rank.seven).isSevenOfDiamonds, isFalse);
      expect(c(Suit.club, Rank.seven).isSevenOfDiamonds, isFalse);
    });

    test('J is not treated as numeric 11', () {
      expect(c(Suit.spade, Rank.jack).isBasraNumeric, isFalse);
      expect(c(Suit.spade, Rank.jack).basraNumericValue, isNot(11));
    });
  });

  group('Initial deal', () {
    test('4 cards per player, 4 cards on table, dealer does not start', () {
      for (final count in kBasraSupportedPlayerCounts) {
        final players = List.generate(
          count,
          (i) => BasraPlayer(id: 'p$i', name: 'P$i'),
        );
        final state = BasraGameState(hostId: 'p0', players: players);
        BasraGameEngine.startMatch(state);

        expect(state.phase, BasraPhase.playing);
        for (final player in state.players) {
          expect(player.hand, hasLength(4));
        }
        expect(state.tableCards, hasLength(4));
        expect(state.tableCards.any((c) => c.isJack), isFalse);
        expect(state.tableCards.any((c) => c.isSevenOfDiamonds), isFalse);
        expect(state.dealerPlayerIndex, 0);
        expect(state.currentPlayerIndex, 1);
        expect(state.currentPlayerIndex, isNot(state.dealerPlayerIndex));
        expect(
          state.deck.length,
          52 - (4 * count) - 4,
        );
      }
    });

    test('Initial J is replaced', () {
      final jack = c(Suit.spade, Rank.jack);
      final replacement = c(Suit.club, Rank.three);
      final state = twoPlayers();
      final deck = deckForDeal(
        hands: [
          [c(Suit.heart, Rank.ace), c(Suit.heart, Rank.two), c(Suit.heart, Rank.three), c(Suit.heart, Rank.four)],
          [c(Suit.spade, Rank.ace), c(Suit.spade, Rank.two), c(Suit.spade, Rank.three), c(Suit.spade, Rank.four)],
        ],
        table: [
          jack,
          c(Suit.diamond, Rank.two),
          c(Suit.diamond, Rank.three),
          c(Suit.diamond, Rank.four),
        ],
        rest: [replacement],
      );
      BasraGameEngine.initializeRound(state, deck: deck);
      expect(state.tableCards.any((card) => card.isJack), isFalse);
      expect(state.tableCards.contains(replacement), isTrue);
      expect(state.deck.contains(jack), isTrue);
    });

    test('Initial 7♦ is replaced', () {
      final sevenD = c(Suit.diamond, Rank.seven);
      final replacement = c(Suit.club, Rank.five);
      final state = twoPlayers();
      final deck = deckForDeal(
        hands: [
          [c(Suit.heart, Rank.ace), c(Suit.heart, Rank.two), c(Suit.heart, Rank.three), c(Suit.heart, Rank.four)],
          [c(Suit.spade, Rank.ace), c(Suit.spade, Rank.two), c(Suit.spade, Rank.three), c(Suit.spade, Rank.four)],
        ],
        table: [
          sevenD,
          c(Suit.diamond, Rank.two),
          c(Suit.diamond, Rank.three),
          c(Suit.diamond, Rank.four),
        ],
        rest: [replacement],
      );
      BasraGameEngine.initializeRound(state, deck: deck);
      expect(state.tableCards.any((card) => card.isSevenOfDiamonds), isFalse);
      expect(state.tableCards.contains(replacement), isTrue);
      expect(state.deck.contains(sevenD), isTrue);
    });

    test('Replacement continues until no initial J/7♦ remains', () {
      final state = twoPlayers();
      final deck = deckForDeal(
        hands: [
          [c(Suit.heart, Rank.ace), c(Suit.heart, Rank.two), c(Suit.heart, Rank.three), c(Suit.heart, Rank.four)],
          [c(Suit.spade, Rank.ace), c(Suit.spade, Rank.two), c(Suit.spade, Rank.three), c(Suit.spade, Rank.four)],
        ],
        table: [
          c(Suit.spade, Rank.jack),
          c(Suit.heart, Rank.jack),
          c(Suit.diamond, Rank.seven),
          c(Suit.club, Rank.two),
        ],
        rest: [
          c(Suit.club, Rank.three),
          c(Suit.club, Rank.four),
          c(Suit.club, Rank.jack),
          c(Suit.club, Rank.five),
          c(Suit.club, Rank.six),
        ],
      );
      BasraGameEngine.initializeRound(state, deck: deck);
      expect(state.tableCards.any((card) => card.isJack || card.isSevenOfDiamonds), isFalse);
      expect(state.tableCards, hasLength(4));
    });
  });

  group('Capture', () {
    test('Same-rank capture ignores suit', () {
      final captured = BasraCaptureEngine.resolveDeterministicCapture(
        c(Suit.heart, Rank.five),
        [c(Suit.club, Rank.five), c(Suit.spade, Rank.two)],
      );
      expect(captured, [c(Suit.club, Rank.five)]);
    });

    test('Numeric sum capture', () {
      final captured = BasraCaptureEngine.resolveDeterministicCapture(
        c(Suit.spade, Rank.seven),
        [c(Suit.heart, Rank.three), c(Suit.club, Rank.four)],
      );
      expect(captured.toSet(), {
        c(Suit.heart, Rank.three),
        c(Suit.club, Rank.four),
      });
    });

    test('Sum ignores J, Q and K', () {
      final table = [
        c(Suit.heart, Rank.jack),
        c(Suit.heart, Rank.queen),
        c(Suit.heart, Rank.king),
        c(Suit.club, Rank.ace),
        c(Suit.club, Rank.four),
      ];
      final captured = BasraCaptureEngine.resolveDeterministicCapture(
        c(Suit.spade, Rank.five),
        table,
      );
      expect(captured.toSet(), {c(Suit.club, Rank.ace), c(Suit.club, Rank.four)});
      expect(captured.any((card) => card.isJack || card.isQueen || card.isKing), isFalse);
    });

    test('Q captures Q only', () {
      final captured = BasraCaptureEngine.resolveDeterministicCapture(
        c(Suit.spade, Rank.queen),
        [c(Suit.heart, Rank.queen), c(Suit.club, Rank.two), c(Suit.club, Rank.three)],
      );
      expect(captured, [c(Suit.heart, Rank.queen)]);
    });

    test('K captures K only', () {
      final captured = BasraCaptureEngine.resolveDeterministicCapture(
        c(Suit.spade, Rank.king),
        [c(Suit.diamond, Rank.king), c(Suit.club, Rank.four), c(Suit.club, Rank.three)],
      );
      expect(captured, [c(Suit.diamond, Rank.king)]);
    });

    test('Q cannot capture numeric combinations', () {
      final result = BasraCaptureEngine.resolvePlay(
        c(Suit.spade, Rank.queen),
        [c(Suit.club, Rank.two), c(Suit.club, Rank.three)],
      );
      expect(result.wasCapture, isFalse);
    });

    test('Combined same-rank + sum capture', () {
      final captured = BasraCaptureEngine.resolveDeterministicCapture(
        c(Suit.heart, Rank.five),
        [
          c(Suit.club, Rank.five),
          c(Suit.spade, Rank.ace),
          c(Suit.spade, Rank.four),
        ],
      );
      expect(captured.toSet(), {
        c(Suit.club, Rank.five),
        c(Suit.spade, Rank.ace),
        c(Suit.spade, Rank.four),
      });
    });

    test('Multiple valid sums resolve deterministically', () {
      final table = [
        c(Suit.spade, Rank.ace),
        c(Suit.heart, Rank.two),
        c(Suit.club, Rank.three),
        c(Suit.diamond, Rank.four),
      ];
      final first = BasraCaptureEngine.findBestSumCombination(table, 5);
      final second = BasraCaptureEngine.findBestSumCombination(table, 5);
      expect(first, second);
      expect(first, hasLength(2));
      expect(
        first.map((card) => card.basraNumericValue).reduce((a, b) => a! + b!),
        5,
      );
    });
  });

  group('Special cards', () {
    test('J sweeps table for every suit', () {
      for (final suit in Suit.values) {
        final result = BasraCaptureEngine.resolvePlay(
          c(suit, Rank.jack),
          [c(Suit.heart, Rank.two), c(Suit.club, Rank.king)],
        );
        expect(result.wasCapture, isTrue);
        expect(result.wasSweep, isTrue);
        expect(result.captured, hasLength(2));
        expect(result.tableAfter, isEmpty);
      }
    });

    test('7♦ sweeps table; other 7s do not', () {
      final table = [c(Suit.heart, Rank.king), c(Suit.club, Rank.queen)];
      final diamond = BasraCaptureEngine.resolvePlay(c(Suit.diamond, Rank.seven), table);
      expect(diamond.wasSweep, isTrue);
      expect(diamond.captured, hasLength(2));

      final spade = BasraCaptureEngine.resolvePlay(c(Suit.spade, Rank.seven), table);
      expect(spade.wasSweep, isFalse);
      expect(spade.wasCapture, isFalse);
    });
  });

  group('Basra detection', () {
    test('Normal full-table clear awards Basra', () {
      final type = BasraCaptureEngine.detectBasra(
        playedCard: c(Suit.heart, Rank.five),
        tableBeforePlay: [c(Suit.club, Rank.two), c(Suit.spade, Rank.three)],
        capturedCards: [c(Suit.club, Rank.two), c(Suit.spade, Rank.three)],
      );
      expect(type, BasraType.normal);
    });

    test('Q or K clearing a lone match is a normal Basra', () {
      expect(
        BasraCaptureEngine.detectBasra(
          playedCard: c(Suit.heart, Rank.queen),
          tableBeforePlay: [c(Suit.spade, Rank.queen)],
          capturedCards: [c(Suit.spade, Rank.queen)],
        ),
        BasraType.normal,
      );
      expect(
        BasraCaptureEngine.detectBasra(
          playedCard: c(Suit.heart, Rank.king),
          tableBeforePlay: [c(Suit.club, Rank.king)],
          capturedCards: [c(Suit.club, Rank.king)],
        ),
        BasraType.normal,
      );
    });

    test('J full-table clear does not award normal Basra', () {
      expect(
        BasraCaptureEngine.detectBasra(
          playedCard: c(Suit.spade, Rank.jack),
          tableBeforePlay: [c(Suit.heart, Rank.two)],
          capturedCards: [c(Suit.heart, Rank.two)],
        ),
        BasraType.none,
      );
    });

    test('7♦ full-table clear does not award normal Basra', () {
      expect(
        BasraCaptureEngine.detectBasra(
          playedCard: c(Suit.diamond, Rank.seven),
          tableBeforePlay: [c(Suit.heart, Rank.queen)],
          capturedCards: [c(Suit.heart, Rank.queen)],
        ),
        BasraType.none,
      );
    });

    test('Valid 7♦ condition awards Basra', () {
      expect(
        BasraCaptureEngine.detectBasra(
          playedCard: c(Suit.diamond, Rank.seven),
          tableBeforePlay: [c(Suit.heart, Rank.three), c(Suit.club, Rank.four)],
          capturedCards: [c(Suit.heart, Rank.three), c(Suit.club, Rank.four)],
        ),
        BasraType.sevenOfDiamonds,
      );
    });

    test('7♦ with total > 10 does not award Basra', () {
      expect(
        BasraCaptureEngine.detectBasra(
          playedCard: c(Suit.diamond, Rank.seven),
          tableBeforePlay: [c(Suit.heart, Rank.five), c(Suit.club, Rank.six)],
          capturedCards: [c(Suit.heart, Rank.five), c(Suit.club, Rank.six)],
        ),
        BasraType.none,
      );
    });

    test('7♦ with Q does not award Basra', () {
      expect(
        BasraCaptureEngine.detectBasra(
          playedCard: c(Suit.diamond, Rank.seven),
          tableBeforePlay: [c(Suit.heart, Rank.queen), c(Suit.club, Rank.two)],
          capturedCards: [c(Suit.heart, Rank.queen), c(Suit.club, Rank.two)],
        ),
        BasraType.none,
      );
    });

    test('7♦ with K does not award Basra', () {
      expect(
        BasraCaptureEngine.detectBasra(
          playedCard: c(Suit.diamond, Rank.seven),
          tableBeforePlay: [c(Suit.heart, Rank.king)],
          capturedCards: [c(Suit.heart, Rank.king)],
        ),
        BasraType.none,
      );
    });

    test('Empty-table play does not award Basra', () {
      final jack = BasraCaptureEngine.resolvePlay(c(Suit.spade, Rank.jack), []);
      expect(jack.wasCapture, isFalse);
      expect(jack.basraType, BasraType.none);
      expect(jack.tableAfter, [c(Suit.spade, Rank.jack)]);

      final seven = BasraCaptureEngine.resolvePlay(c(Suit.diamond, Rank.seven), []);
      expect(seven.wasCapture, isFalse);
      expect(seven.basraType, BasraType.none);

      final five = BasraCaptureEngine.resolvePlay(c(Suit.heart, Rank.five), []);
      expect(five.wasCapture, isFalse);
      expect(five.basraType, BasraType.none);
    });

    test('Multiple Basras are counted', () {
      final state = twoPlayers(
        p0Hand: [
          c(Suit.heart, Rank.five),
          c(Suit.spade, Rank.queen),
        ],
        p1Hand: [c(Suit.club, Rank.two)],
        table: [c(Suit.club, Rank.two), c(Suit.diamond, Rank.three)],
      );
      expect(BasraGameEngine.playCard(state, 'p0', c(Suit.heart, Rank.five)), isTrue);
      expect(state.players[0].basraCount, 1);
      expect(state.lastTurnResult?.basraType, BasraType.normal);

      state.tableCards = [c(Suit.diamond, Rank.queen)];
      state.currentPlayerIndex = 0;
      expect(BasraGameEngine.playCard(state, 'p0', c(Suit.spade, Rank.queen)), isTrue);
      expect(state.players[0].basraCount, 2);
    });
  });

  group('Scoring', () {
    test('27+ cards = +30', () {
      final cards = List.generate(27, (i) => c(Suit.values[i % 4], Rank.four));
      final score = BasraScoring.calculateBasraRoundScore(capturedCards: cards, basraCount: 0);
      expect(score.majorityPoints, 30);
      expect(score.total, 30);
    });

    test('26-26 = no majority +30', () {
      final a = List.generate(26, (_) => c(Suit.heart, Rank.two));
      final b = List.generate(26, (_) => c(Suit.spade, Rank.three));
      expect(BasraScoring.calculateBasraRoundScore(capturedCards: a, basraCount: 0).majorityPoints, 0);
      expect(BasraScoring.calculateBasraRoundScore(capturedCards: b, basraCount: 0).majorityPoints, 0);
    });

    test('J = +1 each, A = +1 each, 2♠ = +2, 10♦ = +3, Basra = +10 each', () {
      final score = BasraScoring.calculateBasraRoundScore(
        capturedCards: [
          c(Suit.spade, Rank.jack),
          c(Suit.heart, Rank.jack),
          c(Suit.club, Rank.ace),
          c(Suit.diamond, Rank.ace),
          c(Suit.heart, Rank.ace),
          c(Suit.spade, Rank.two),
          c(Suit.diamond, Rank.ten),
        ],
        basraCount: 2,
      );
      expect(score.jackPoints, 2);
      expect(score.acePoints, 3);
      expect(score.twoOfSpadesPoints, 2);
      expect(score.tenOfDiamondsPoints, 3);
      expect(score.basraPoints, 20);
      expect(score.total, 2 + 3 + 2 + 3 + 20);
    });

    test('Multiple scoring bonuses stack correctly', () {
      final cards = [
        ...List.generate(27, (i) => c(Suit.values[i % 4], Rank.four)),
        c(Suit.spade, Rank.jack),
        c(Suit.heart, Rank.ace),
        c(Suit.spade, Rank.two),
        c(Suit.diamond, Rank.ten),
      ];
      final score = BasraScoring.calculateBasraRoundScore(capturedCards: cards, basraCount: 1);
      expect(score.total, 30 + 1 + 1 + 2 + 3 + 10);
    });
  });

  group('Round lifecycle and carry-over', () {
    test('New 4-card deal happens only after all hands are empty', () {
      final nextCards = [
        c(Suit.club, Rank.ace),
        c(Suit.club, Rank.two),
        c(Suit.club, Rank.three),
        c(Suit.club, Rank.four),
        c(Suit.club, Rank.five),
        c(Suit.club, Rank.six),
        c(Suit.club, Rank.eight),
        c(Suit.club, Rank.nine),
      ];
      final state = twoPlayers(
        p0Hand: [c(Suit.heart, Rank.five)],
        p1Hand: [c(Suit.heart, Rank.six)],
        table: [],
        deck: List.from(nextCards),
      );
      BasraGameEngine.playCard(state, 'p0', c(Suit.heart, Rank.five));
      expect(state.players[0].hand, isEmpty);
      expect(state.players[1].hand, hasLength(1));
      expect(state.deck, hasLength(8));
      expect(state.phase, BasraPhase.playing);

      BasraGameEngine.playCard(state, 'p1', c(Suit.heart, Rank.six));
      expect(state.players[0].hand, hasLength(4));
      expect(state.players[1].hand, hasLength(4));
      expect(state.deck, isEmpty);
    });

    test('Round ends when deck and hands are exhausted; remaining table goes to last capturer without Basra', () {
      final state = twoPlayers(
        p0Hand: [c(Suit.heart, Rank.nine)],
        p1Hand: [],
        table: [c(Suit.club, Rank.two)],
        deck: [],
      );
      state.lastCapturePlayerId = 'p1';
      BasraGameEngine.playCard(state, 'p0', c(Suit.heart, Rank.nine));
      expect(state.phase, BasraPhase.roundFinished);
      expect(state.lastRoundAwardedFinalTable, isTrue);
      expect(state.players[1].capturedCards, contains(c(Suit.club, Rank.two)));
      expect(state.players[1].capturedCards, contains(c(Suit.heart, Rank.nine)));
      expect(state.players[1].basraCount, 0);
      expect(state.tableCards, isEmpty);
    });

    test('Carry-over 30 after first 26-26 tie, 60 after second, then awarded to majority winner', () {
      final state = twoPlayers();
      state.phase = BasraPhase.playing;
      state.players[0].capturedCards.addAll(List.generate(26, (_) => c(Suit.heart, Rank.two)));
      state.players[1].capturedCards.addAll(List.generate(26, (_) => c(Suit.spade, Rank.three)));
      BasraGameEngine.finishRound(state);
      expect(state.lastRoundWasTwentySixTie, isTrue);
      expect(state.carriedMajorityPoints, 30);
      expect(state.players[0].roundScore, 0);
      expect(state.players[1].roundScore, 0);

      state.phase = BasraPhase.roundFinished;
      BasraGameEngine.advanceToNextRound(
        state,
        deck: PlayingCard.fullDeck(),
      );
      expect(state.players[0].totalScore, 0);
      expect(state.carriedMajorityPoints, 30);
      expect(state.players[0].hand, isNotEmpty);

      state.players[0].capturedCards
        ..clear()
        ..addAll(List.generate(26, (_) => c(Suit.heart, Rank.four)));
      state.players[1].capturedCards
        ..clear()
        ..addAll(List.generate(26, (_) => c(Suit.club, Rank.five)));
      BasraGameEngine.finishRound(state);
      expect(state.carriedMajorityPoints, 60);

      state.players[0].capturedCards
        ..clear()
        ..addAll(List.generate(30, (_) => c(Suit.diamond, Rank.six)));
      state.players[1].capturedCards
        ..clear()
        ..addAll(List.generate(22, (_) => c(Suit.club, Rank.seven)));
      state.phase = BasraPhase.playing;
      BasraGameEngine.finishRound(state);
      expect(state.players[0].roundScore, 30 + 60);
      expect(state.carriedMajorityPoints, 0);
    });

    test('Match ends at >= 121', () {
      final state = twoPlayers();
      state.players[0].totalScore = 110;
      state.players[0].capturedCards.addAll(List.generate(30, (_) => c(Suit.heart, Rank.four)));
      state.players[1].capturedCards.addAll(List.generate(22, (_) => c(Suit.spade, Rank.three)));
      BasraGameEngine.finishRound(state);
      expect(state.players[0].totalScore, 140);
      expect(state.phase, BasraPhase.finished);
      expect(state.matchWinnerId, 'p0');
    });

    test('Next round resets round state but preserves cumulative score and carry-over', () {
      final state = twoPlayers();
      state.players[0].totalScore = 14;
      state.players[0].basraCount = 1;
      state.players[0].capturedCards.add(c(Suit.heart, Rank.ace));
      state.carriedMajorityPoints = 30;
      state.phase = BasraPhase.roundFinished;
      BasraGameEngine.advanceToNextRound(state, deck: PlayingCard.fullDeck());
      expect(state.players[0].totalScore, 14);
      expect(state.carriedMajorityPoints, 30);
      expect(state.players[0].basraCount, 0);
      expect(state.players[0].capturedCards, isEmpty);
      expect(state.players[0].roundScore, 0);
      expect(state.currentRoundNumber, 2);
      expect(state.dealerPlayerIndex, 1);
      expect(state.currentPlayerIndex, 0);
    });

    test('Rejects plays that are not the current player / inactive round', () {
      final state = twoPlayers(
        p0Hand: [c(Suit.heart, Rank.five)],
        p1Hand: [c(Suit.spade, Rank.six)],
      );
      expect(BasraGameEngine.playCard(state, 'p1', c(Suit.spade, Rank.six)), isFalse);
      state.phase = BasraPhase.roundFinished;
      expect(BasraGameEngine.playCard(state, 'p0', c(Suit.heart, Rank.five)), isFalse);
    });
  });

  group('Bot AI', () {
    test('Prefers a capturing card over dumping a Jack on an empty table', () {
      final choice = BasraBotAi.chooseCard(
        hand: [
          c(Suit.spade, Rank.jack),
          c(Suit.heart, Rank.five),
        ],
        tableCards: [c(Suit.club, Rank.five)],
      );
      expect(choice, c(Suit.heart, Rank.five));
    });
  });
}
