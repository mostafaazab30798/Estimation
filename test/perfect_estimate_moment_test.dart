// test/perfect_estimate_moment_test.dart

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:estimation/widgets/perfect_estimate_overlay.dart';
import 'package:estimation/core/models/player.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Perfect Estimate Detection & Logic', () {
    test('Player declared == actual constitutes a perfect estimate', () {
      final p1 = Player(
        id: 'p1',
        name: 'Ahmed',
        seatIndex: 0,
        declared: 7,
        actual: 7,
      );

      final p2 = Player(
        id: 'p2',
        name: 'Mona',
        seatIndex: 1,
        declared: 3,
        actual: 4,
      );

      final p3 = Player(
        id: 'p3',
        name: 'Omar',
        seatIndex: 2,
        declared: 0,
        actual: 0,
      );

      expect(p1.declared != null && p1.declared == p1.actual, isTrue);
      expect(p2.declared != null && p2.declared == p2.actual, isFalse);
      expect(p3.declared != null && p3.declared == p3.actual, isTrue);
    });
  });

  group('PerfectEstimateOverlay Widget Tests', () {
    testWidgets('renders declared and won trick counts and +XP badge', (tester) async {
      bool dismissed = false;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: PerfectEstimateOverlay(
              declared: 7,
              won: 7,
              xpBonus: 25,
              displayDuration: const Duration(seconds: 1),
              onDismissed: () {
                dismissed = true;
              },
            ),
          ),
        ),
      );

      await tester.pump();
      await tester.pump(const Duration(milliseconds: 200));

      expect(find.text('7'), findsNWidgets(2));
      expect(find.text('declared • صرّح'), findsOneWidget);
      expect(find.text('won • ربح'), findsOneWidget);
      expect(find.text('+25 XP BONUS'), findsOneWidget);
      expect(find.text('🎯'), findsOneWidget);

      // Tap to dismiss
      await tester.tap(find.byType(PerfectEstimateOverlay));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 700));
      await tester.pump(const Duration(milliseconds: 50));

      expect(dismissed, isTrue);
    });

    testWidgets('shows dedicated messaging for a successful Dash Call',
        (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: PerfectEstimateOverlay(
              declared: 0,
              won: 0,
              isDashCall: true,
              displayDuration: Duration(seconds: 10),
            ),
          ),
        ),
      );

      await tester.pump(const Duration(milliseconds: 500));

      expect(find.text('PERFECT DASH CALL'), findsOneWidget);
      expect(find.text('داش كول مثالي'), findsOneWidget);
      expect(find.text('⚡'), findsOneWidget);
    });
  });
}
