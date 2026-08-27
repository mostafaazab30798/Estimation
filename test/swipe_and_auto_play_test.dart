// test/swipe_and_auto_play_test.dart
//
// Tests for:
// 1. Upward swipe/throw gesture playing a card from hand
// 2. Automatic play when only 1 legal card remains (last card or forced follow-suit)

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:estimation/core/constants.dart';
import 'package:estimation/core/models/card.dart';
import 'package:estimation/core/models/game_state.dart';
import 'package:estimation/core/models/player.dart';
import 'package:estimation/core/game_engine.dart';
import 'package:estimation/widgets/player_hand.dart';
import 'package:estimation/widgets/playing_card_widget.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Swipe-to-Play Gesture Tests', () {
    late GameState state;
    late Player me;
    late List<PlayingCard> hand;

    setUp(() {
      hand = [
        PlayingCard(suit: Suit.spade, rank: Rank.ace),
        PlayingCard(suit: Suit.heart, rank: Rank.ten),
      ];

      me = Player(id: 'me', name: 'Player 1', seatIndex: 0, hand: hand);

      state = GameState(
        phase: GamePhase.trickTaking,
        roundNumber: 1,
        currentPlayerSeatIndex: 0,
        players: [
          me,
          Player(id: 'p2', name: 'Bot 1', seatIndex: 1),
          Player(id: 'p3', name: 'Bot 2', seatIndex: 2),
          Player(id: 'p4', name: 'Bot 3', seatIndex: 3),
        ],
      );
    });

    testWidgets('Swiping card upward plays the card immediately', (tester) async {
      PlayingCard? playedCard;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: PlayerHand(
              hand: hand,
              isMyTurn: true,
              state: state,
              me: me,
              onPlayCard: (c) => playedCard = c,
            ),
          ),
        ),
      );

      final firstCardFinder = find.byType(PlayingCardWidget).first;
      final startLocation = tester.getCenter(firstCardFinder);

      // Drag upward by 60 pixels (throw gesture)
      final gesture = await tester.startGesture(startLocation);
      await gesture.moveBy(const Offset(0, -60));
      await tester.pump();
      await gesture.up();
      await tester.pump();

      expect(playedCard, equals(hand[0]));
    });

    testWidgets('Double tap also plays the card', (tester) async {
      PlayingCard? playedCard;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: PlayerHand(
              hand: hand,
              isMyTurn: true,
              state: state,
              me: me,
              onPlayCard: (c) => playedCard = c,
            ),
          ),
        ),
      );

      final secondCardFinder = find.byType(PlayingCardWidget).at(1);

      // First tap selects
      await tester.tap(secondCardFinder);
      await tester.pump(const Duration(milliseconds: 50));
      expect(playedCard, isNull);

      // Second tap confirms play
      await tester.tap(secondCardFinder);
      await tester.pump(const Duration(milliseconds: 50));
      expect(playedCard, equals(hand[1]));
    });
  });

  group('Auto-Play Legal Move Rules Tests', () {
    test('When player has only 1 card left in hand, exactly 1 legal move exists', () {
      final me = Player(
        id: 'me',
        name: 'Player',
        seatIndex: 0,
        hand: [PlayingCard(suit: Suit.club, rank: Rank.seven)],
      );

      final state = GameState(
        phase: GamePhase.trickTaking,
        currentPlayerSeatIndex: 0,
        currentTrick: [
          TrickCard(playerId: 'p2', card: PlayingCard(suit: Suit.diamond, rank: Rank.king)),
        ],
        players: [me, Player(id: 'p2', name: 'Bot 1', seatIndex: 1)],
      );

      final legalMoves = me.hand.where((c) => GameEngine.canPlayCard(state, me, c)).toList();
      expect(legalMoves.length, equals(1));
      expect(legalMoves.first, equals(me.hand.first));
    });

    test('When led suit matches only 1 card in hand, forced follow-suit yields exactly 1 legal move', () {
      final me = Player(
        id: 'me',
        name: 'Player',
        seatIndex: 0,
        hand: [
          PlayingCard(suit: Suit.heart, rank: Rank.eight), // Only 1 Heart
          PlayingCard(suit: Suit.spade, rank: Rank.ace),
          PlayingCard(suit: Suit.spade, rank: Rank.king),
          PlayingCard(suit: Suit.club, rank: Rank.ten),
        ],
      );

      final state = GameState(
        phase: GamePhase.trickTaking,
        currentPlayerSeatIndex: 0,
        currentTrick: [
          TrickCard(playerId: 'p2', card: PlayingCard(suit: Suit.heart, rank: Rank.jack)), // Heart led
        ],
        players: [me, Player(id: 'p2', name: 'Bot 1', seatIndex: 1)],
      );

      final legalMoves = me.hand.where((c) => GameEngine.canPlayCard(state, me, c)).toList();
      // Must follow suit with the 8 of hearts: exactly 1 legal move!
      expect(legalMoves.length, equals(1));
      expect(legalMoves.first.suit, equals(Suit.heart));
      expect(legalMoves.first.rank, equals(Rank.eight));
    });

    test('When player has multiple cards of led suit, they have multiple choices (no auto-play)', () {
      final me = Player(
        id: 'me',
        name: 'Player',
        seatIndex: 0,
        hand: [
          PlayingCard(suit: Suit.heart, rank: Rank.eight),
          PlayingCard(suit: Suit.heart, rank: Rank.ace),
          PlayingCard(suit: Suit.club, rank: Rank.ten),
        ],
      );

      final state = GameState(
        phase: GamePhase.trickTaking,
        currentPlayerSeatIndex: 0,
        currentTrick: [
          TrickCard(playerId: 'p2', card: PlayingCard(suit: Suit.heart, rank: Rank.jack)),
        ],
        players: [me, Player(id: 'p2', name: 'Bot 1', seatIndex: 1)],
      );

      final legalMoves = me.hand.where((c) => GameEngine.canPlayCard(state, me, c)).toList();
      expect(legalMoves.length, equals(2));
    });
  });
}
