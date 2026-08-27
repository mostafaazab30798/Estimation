// test/round_scores_dialog_test.dart

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:estimation/core/models/game_state.dart';
import 'package:estimation/core/models/player.dart';
import 'package:estimation/core/models/bid.dart';
import 'package:estimation/core/constants.dart';
import 'package:estimation/core/icons/app_icons.dart';
import 'package:estimation/core/widgets/app_buttons.dart';
import 'package:estimation/services/device_performance_service.dart';
import 'package:estimation/widgets/hud/top_hud.dart';

void main() {
  testWidgets('TopHud displays scores leaderboard button and opens RoundScoresDialog', (tester) async {
    final players = [
      Player(id: 'p1', name: 'Player 1', seatIndex: 0, totalScore: 100),
      Player(id: 'p2', name: 'Player 2', seatIndex: 1, totalScore: 50),
      Player(id: 'p3', name: 'Player 3', seatIndex: 2, totalScore: -20),
      Player(id: 'p4', name: 'Player 4', seatIndex: 3, totalScore: 200),
    ];

    final state = GameState(
      players: players,
      phase: GamePhase.trickTaking,
      roundNumber: 2,
      roundHistory: [
        RoundHistoryRecord(
          roundNumber: 1,
          bidderPlayerId: 'p4',
          winningBid: const Bid(trickCount: 5, trump: Trump.spade),
          trump: Trump.spade,
          playerRecords: [
            PlayerRoundRecord(
              playerId: 'p1',
              playerName: 'Player 1',
              declared: 3,
              actual: 3,
              scoreDelta: 33,
              totalScoreAfterRound: 33,
              isSuccess: true,
            ),
            PlayerRoundRecord(
              playerId: 'p2',
              playerName: 'Player 2',
              declared: 2,
              actual: 2,
              scoreDelta: 22,
              totalScoreAfterRound: 22,
              isSuccess: true,
            ),
            PlayerRoundRecord(
              playerId: 'p3',
              playerName: 'Player 3',
              declared: 3,
              actual: 1,
              scoreDelta: -20,
              totalScoreAfterRound: -20,
              isSuccess: false,
            ),
            PlayerRoundRecord(
              playerId: 'p4',
              playerName: 'Player 4',
              declared: 5,
              actual: 5,
              scoreDelta: 85,
              totalScoreAfterRound: 85,
              isBidder: true,
              isSuccess: true,
            ),
          ],
        ),
      ],
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

    // Find the leaderboard icon button in TopHud
    final scoresButtonFinder = find.byWidgetPredicate(
      (w) => w is AppIconButton && w.icon == AppIcons.leaderboard,
    );
    expect(scoresButtonFinder, findsOneWidget);

    // Tap on the scores button
    await tester.tap(scoresButtonFinder);
    await tester.pumpAndSettle();

    // Verify RoundScoresDialog is opened
    expect(find.text('لوحة النتائج'), findsOneWidget);
    expect(find.text('الجولة 2 من 18'), findsOneWidget);
    expect(find.text('الترتيب ومجموع النقاط'), findsOneWidget);
    expect(find.text('سجل الجولات'), findsOneWidget);

    // Verify player scores and ranks
    expect(find.text('Player 4'), findsWidgets); // leader
    expect(find.text('200'), findsWidgets);
    expect(find.text('كينج'), findsOneWidget);

    // Verify round 1 history entry
    expect(find.text('الجولة 1'), findsOneWidget);
    expect(find.text('سبيد 5'), findsOneWidget);
  });

  testWidgets('TopHud in last 5 rounds (14-18) renders flawlessly on narrow mobile screens (320px)', (tester) async {
    tester.view.physicalSize = const Size(320, 640);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);

    final trumps = [Trump.sans, Trump.spade, Trump.heart, Trump.diamond, Trump.club];

    for (int r = 14; r <= 18; r++) {
      final state = GameState(
        players: [
          Player(id: 'p1', name: 'Player 1', seatIndex: 0),
          Player(id: 'p2', name: 'Player 2', seatIndex: 1),
          Player(id: 'p3', name: 'Player 3', seatIndex: 2),
          Player(id: 'p4', name: 'Player 4', seatIndex: 3),
        ],
        phase: GamePhase.declarations,
        roundNumber: r,
        totalRounds: 18,
        trump: trumps[r - 14],
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

      expect(
        find.byWidgetPredicate(
          (w) => w is AppIconButton && w.icon == AppIcons.leaderboard,
        ),
        findsOneWidget,
      );
      expect(tester.takeException(), isNull); // 0 RenderFlex overflow
    }
  });
}
