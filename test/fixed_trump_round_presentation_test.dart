// test/fixed_trump_round_presentation_test.dart

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:estimation/core/constants.dart';
import 'package:estimation/core/models/game_state.dart';
import 'package:estimation/core/models/player.dart';
import 'package:estimation/services/device_performance_service.dart';
import 'package:estimation/widgets/fixed_trump_round_overlay.dart';
import 'package:estimation/widgets/hud/top_hud.dart';

void main() {
  List<Player> createTestPlayers() {
    return [
      Player(id: 'p1', name: 'Player 1', seatIndex: 0),
      Player(id: 'p2', name: 'Player 2', seatIndex: 1),
      Player(id: 'p3', name: 'Player 3', seatIndex: 2),
      Player(id: 'p4', name: 'Player 4', seatIndex: 3),
    ];
  }

  group('Fixed Trump Round Presentation Overlay Tests', () {
    testWidgets('Round 14 Fixed Trump Overlay displays SANS rules and direct declaration', (tester) async {
      bool dismissed = false;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: FixedTrumpRoundOverlay(
              roundNumber: 14,
              fixedTrump: Trump.sans,
              displayDuration: const Duration(seconds: 10),
              onDismissed: () {
                dismissed = true;
              },
            ),
          ),
        ),
      );

      await tester.pump(const Duration(milliseconds: 100));

      expect(find.text('CHAMPIONSHIP PHASE'), findsOneWidget);
      expect(find.text('ROUND 14'), findsOneWidget);
      expect(find.text('SANS ROUND'), findsOneWidget);
      expect(find.text('Trump is fixed to SANS.'), findsOneWidget);
      expect(find.text('Direct Declarations • Highest Declarer Starts'), findsOneWidget);
      expect(find.text('FIXED CONTRACT ACTIVE'), findsOneWidget);

      // Tap to dismiss
      await tester.tap(find.byType(GestureDetector));
      await tester.pump(const Duration(milliseconds: 700));
      await tester.pump(const Duration(milliseconds: 200));

      expect(dismissed, isTrue);
    });

    testWidgets('Round 15 Fixed Trump Overlay displays SPADE rules', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: FixedTrumpRoundOverlay(
              roundNumber: 15,
              fixedTrump: Trump.spade,
            ),
          ),
        ),
      );

      await tester.pump(const Duration(milliseconds: 100));

      expect(find.text('ROUND 15'), findsOneWidget);
      expect(find.text('SPADE ROUND'), findsOneWidget);
      expect(find.text('Trump is fixed to SPADES.'), findsOneWidget);
      expect(find.text('Direct Declarations • Highest Declarer Starts'), findsOneWidget);
    });

    testWidgets('Round 16 Fixed Trump Overlay displays HEART rules', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: FixedTrumpRoundOverlay(
              roundNumber: 16,
              fixedTrump: Trump.heart,
            ),
          ),
        ),
      );

      await tester.pump(const Duration(milliseconds: 100));

      expect(find.text('ROUND 16'), findsOneWidget);
      expect(find.text('HEART ROUND'), findsOneWidget);
      expect(find.text('Trump is fixed to HEARTS.'), findsOneWidget);
    });

    testWidgets('Round 17 Fixed Trump Overlay displays DIAMOND rules', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: FixedTrumpRoundOverlay(
              roundNumber: 17,
              fixedTrump: Trump.diamond,
            ),
          ),
        ),
      );

      await tester.pump(const Duration(milliseconds: 100));

      expect(find.text('ROUND 17'), findsOneWidget);
      expect(find.text('DIAMOND ROUND'), findsOneWidget);
      expect(find.text('Trump is fixed to DIAMONDS.'), findsOneWidget);
    });

    testWidgets('Round 18 Fixed Trump Overlay displays CLUB rules', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: FixedTrumpRoundOverlay(
              roundNumber: 18,
              fixedTrump: Trump.club,
            ),
          ),
        ),
      );

      await tester.pump(const Duration(milliseconds: 100));

      expect(find.text('ROUND 18'), findsOneWidget);
      expect(find.text('CLUB ROUND'), findsOneWidget);
      expect(find.text('Trump is fixed to CLUBS.'), findsOneWidget);
    });
  });

  group('Fixed Trump HUD Integration Tests', () {
    testWidgets('TopHud displays championship fixed badge during rounds 14-18 without flex overflow', (tester) async {
      // Test portrait mobile dimensions (360x640)
      tester.view.physicalSize = const Size(360, 640);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      final state = GameState(
        players: createTestPlayers(),
        phase: GamePhase.declarations,
        roundNumber: 14,
        totalRounds: 18,
        trump: Trump.sans,
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

      expect(find.text('♟ SANS'), findsOneWidget);
      expect(tester.takeException(), isNull); // Verify no RenderFlex overflow
    });
  });
}
