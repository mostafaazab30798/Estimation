import 'package:estimation/core/constants.dart';
import 'package:estimation/core/models/card.dart';
import 'package:estimation/core/models/game_state.dart';
import 'package:estimation/core/models/player.dart';
import 'package:estimation/widgets/playing_card_widget.dart';
import 'package:estimation/widgets/trick_area.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets(
    'authoritative 3-card to resolved state still renders all 4 before sweep',
    (tester) async {
      final cards = <TrickCard>[
        const TrickCard(
          playerId: 'p0',
          card: PlayingCard(suit: Suit.spade, rank: Rank.ace),
        ),
        const TrickCard(
          playerId: 'p1',
          card: PlayingCard(suit: Suit.spade, rank: Rank.king),
        ),
        const TrickCard(
          playerId: 'p2',
          card: PlayingCard(suit: Suit.spade, rank: Rank.queen),
        ),
        const TrickCard(
          playerId: 'p3',
          card: PlayingCard(suit: Suit.spade, rank: Rank.jack),
        ),
      ];
      final players = List.generate(
        4,
        (index) => Player(id: 'p$index', name: 'P$index', seatIndex: index),
      );
      var state = GameState(
        players: players,
        phase: GamePhase.trickTaking,
        currentTrick: cards.take(3).toList(),
        currentPlayerSeatIndex: 3,
      );
      late StateSetter rebuild;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: StatefulBuilder(
              builder: (context, setState) {
                rebuild = setState;
                return SizedBox.square(
                  dimension: 320,
                  child: TrickArea(
                    state: state,
                    myPlayerId: 'p0',
                    playerKeys: {
                      for (var i = 0; i < 4; i++) i: GlobalKey(),
                    },
                    areaKeys: {
                      for (var i = 0; i < 4; i++) i: GlobalKey(),
                    },
                  ),
                );
              },
            ),
          ),
        ),
      );
      expect(find.byType(PlayingCardWidget), findsNWidgets(3));

      players[0].takenTricks = [cards];
      rebuild(() {
        state = GameState(
          players: players,
          phase: GamePhase.trickTaking,
          currentTrick: const [],
          trickLeaderSeatIndex: 0,
          tricksPlayedThisRound: 1,
          currentPlayerSeatIndex: 0,
        );
      });
      await tester.pump();

      expect(find.byType(PlayingCardWidget), findsNWidgets(4));
      await tester.pump(const Duration(milliseconds: 220));
      expect(find.byType(PlayingCardWidget), findsNWidgets(4));
      await tester.pump(const Duration(milliseconds: 1100));
    },
  );
}
