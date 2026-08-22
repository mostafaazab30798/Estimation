// test/double_round_presentation_test.dart

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:estimation/core/game_engine.dart';
import 'package:estimation/core/constants.dart';
import 'package:estimation/core/models/game_state.dart';
import 'package:estimation/core/models/player.dart';
import 'package:estimation/core/models/bid.dart';
import 'package:estimation/services/device_performance_service.dart';
import 'package:estimation/widgets/double_round_overlay.dart';
import 'package:estimation/widgets/hud/top_hud.dart';
import 'package:estimation/widgets/bid_dialog.dart';
import 'package:estimation/widgets/declaration_dialog.dart';

void main() {
  List<Player> createTestPlayers() {
    return [
      Player(id: 'p1', name: 'Player 1', seatIndex: 0),
      Player(id: 'p2', name: 'Player 2', seatIndex: 1),
      Player(id: 'p3', name: 'Player 3', seatIndex: 2),
      Player(id: 'p4', name: 'Player 4', seatIndex: 3),
    ];
  }

  group('All-Pass Double Round Engine & Scoring Tests', () {
    test('All 4 players passing auction sets isDoubleRound to true and advances round', () {
      final state = GameState(
        players: createTestPlayers(),
        phase: GamePhase.auction,
        dealerSeatIndex: 0,
        auctionTurnSeatIndex: 1,
      );

      expect(state.isDoubleRound, isFalse);
      expect(state.roundNumber, equals(1));

      GameEngine.passBid(state, 'p2');
      GameEngine.passBid(state, 'p3');
      GameEngine.passBid(state, 'p4');
      GameEngine.passBid(state, 'p1');

      expect(state.isDoubleRound, isTrue);
      expect(state.roundNumber, equals(2));
      expect(state.phase, equals(GamePhase.dealing));
    });

    test('Scores are doubled in a double round and isDoubleRound is reset after scoring', () {
      final state = GameState(
        players: createTestPlayers(),
        phase: GamePhase.scoring,
        roundNumber: 2,
        isDoubleRound: true,
        bidderPlayerId: 'p1',
        currentHighBid: const Bid(trickCount: 5, trump: Trump.spade),
        trump: Trump.spade,
      );

      // Setup declarations & actual tricks for Under (sum = 10)
      state.playerById('p1').declared = 5;
      state.playerById('p1').actual = 5; // Bidder win: normal +15, doubled = +30

      state.playerById('p2').declared = 2;
      state.playerById('p2').actual = 2; // Normal win: normal +12, doubled = +24

      state.playerById('p3').declared = 2;
      state.playerById('p3').actual = 3; // Loss: diff = 1, normal -1, doubled = -2

      state.playerById('p4').declared = 1;
      state.playerById('p4').actual = 3; // Loss: diff = 2, normal -2, doubled = -4

      final deltas = GameEngine.computeAndApplyScores(state);

      // In Round 2:
      // Bidder made 5: 5 (tricks) + 2 (round) + 10 (bidder bonus) = 17; multiplied by 2 -> 34
      expect(deltas['p1'], equals(34));
      // P2 made 2: 2 (tricks) + 2 (round) = 4; multiplied by 2 -> 8
      expect(deltas['p2'], equals(8));
      // P3 missed by 1: -1 (diff) - 2 (round) = -3; multiplied by 2 -> -6
      expect(deltas['p3'], equals(-6));
      // P4 missed by 2: -2 (diff) - 2 (round) = -4; multiplied by 2 -> -8
      expect(deltas['p4'], equals(-8));

      // Reset multiplier after scoring applied
      expect(state.isDoubleRound, isFalse);
    });
  });

  group('Double Round Presentation Widget Tests', () {
    testWidgets('DoubleRoundOverlay displays required All-Pass and Double Round copy', (tester) async {
      bool dismissed = false;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: DoubleRoundOverlay(
              displayDuration: const Duration(seconds: 10),
              onDismissed: () {
                dismissed = true;
              },
            ),
          ),
        ),
      );

      await tester.pump(const Duration(milliseconds: 100));

      expect(find.text('EVERYONE PASSED'), findsOneWidget);
      expect(find.text('DOUBLE ROUND NEXT'), findsOneWidget);
      expect(find.textContaining('All scores in the next round'), findsOneWidget);
      expect(find.textContaining('will be multiplied ×2.'), findsOneWidget);
      expect(find.text('×2 ROUND ACTIVE'), findsOneWidget);

      // Tap to dismiss
      await tester.tap(find.byType(GestureDetector));
      await tester.pump(const Duration(milliseconds: 700));
      await tester.pump(const Duration(milliseconds: 200));

      expect(dismissed, isTrue);
    });

    testWidgets('TopHud displays glowing ⚡ ×2 ROUND badge when isDoubleRound is true', (tester) async {
      tester.view.physicalSize = const Size(1024, 768);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      final state = GameState(
        players: createTestPlayers(),
        phase: GamePhase.auction,
        isDoubleRound: true,
      );

      await tester.pumpWidget(
        ChangeNotifierProvider<DevicePerformanceService>.value(
          value: DevicePerformanceService.instance,
          child: MaterialApp(
            home: Scaffold(
              body: TopHud(
                state: state,
                onExitTap: () {},
              ),
            ),
          ),
        ),
      );

      await tester.pump(const Duration(milliseconds: 100));

      expect(find.text('×2 ROUND'), findsOneWidget);
    });

    testWidgets('BidDialog renders ⚡ ×2 ROUND banner when isDoubleRound is true', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: BidDialog(
              roundNumber: 2,
              isDoubleRound: true,
              onBid: (_) {},
              onPass: () {},
            ),
          ),
        ),
      );

      await tester.pump();

      expect(find.textContaining('جولة مضاعفة (⚡ ×2 ROUND)'), findsOneWidget);
    });

    testWidgets('DeclarationDialog renders ⚡ ×2 ROUND banner when state.isDoubleRound is true', (tester) async {
      final state = GameState(
        players: createTestPlayers(),
        phase: GamePhase.declarations,
        isDoubleRound: true,
        bidderPlayerId: 'p1',
      );
      final me = state.playerById('p1');

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: DeclarationDialog(
              state: state,
              me: me,
              onSubmit: (_) {},
            ),
          ),
        ),
      );

      await tester.pump();

      expect(find.textContaining('⚡ ×2 ROUND'), findsOneWidget);
    });
  });
}
