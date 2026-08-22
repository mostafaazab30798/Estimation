// test/turn_timer_test.dart
//
// Comprehensive tests for Feature #24: Turn Timer (Authoritative timing rules,
// distinct phase labels 'AUCTION', 'DECLARATION', 'YOUR TURN', 5s warning state '⚠️ 5',
// and GameState synchronization).

import 'package:flutter/material.dart' hide Card;
import 'package:flutter_test/flutter_test.dart';
import 'package:estimation/core/constants.dart';
import 'package:estimation/core/models/card.dart';
import 'package:estimation/core/models/game_state.dart';
import 'package:estimation/core/models/player.dart';
import 'package:estimation/widgets/hud/turn_timer_badge.dart';
import 'package:estimation/widgets/bid_dialog.dart';
import 'package:estimation/widgets/declaration_dialog.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  List<Player> createPlayers() {
    return [
      Player(
        id: 'p1',
        name: 'Mostafa',
        seatIndex: 0,
        hand: [
          PlayingCard(suit: Suit.spade, rank: Rank.ace),
          PlayingCard(suit: Suit.heart, rank: Rank.king),
        ],
      ),
      Player(
        id: 'p2',
        name: 'Omar',
        seatIndex: 1,
        hand: [
          PlayingCard(suit: Suit.club, rank: Rank.two),
        ],
      ),
      Player(
        id: 'p3',
        name: 'Nour',
        seatIndex: 2,
        hand: [
          PlayingCard(suit: Suit.diamond, rank: Rank.seven),
        ],
      ),
      Player(
        id: 'p4',
        name: 'Hassan',
        seatIndex: 3,
        hand: [
          PlayingCard(suit: Suit.heart, rank: Rank.ten),
        ],
      ),
    ];
  }

  group('GameState Turn Timer Model Tests', () {
    test('GameState defaults to 60s turnDurationSeconds and null turnDeadlineEpochMs', () {
      final state = GameState(players: createPlayers());
      expect(state.turnDurationSeconds, 60);
      expect(state.turnDeadlineEpochMs, isNull);
    });

    test('GameState serializes and deserializes turnDurationSeconds and turnDeadlineEpochMs', () {
      final now = DateTime.now().millisecondsSinceEpoch;
      final deadline = now + 60000;

      final state = GameState(
        players: createPlayers(),
        phase: GamePhase.auction,
        turnDurationSeconds: 60,
        turnDeadlineEpochMs: deadline,
      );

      final json = state.toJson();
      expect(json['turnDurationSeconds'], 60);
      expect(json['turnDeadlineEpochMs'], deadline);

      final restored = GameState.fromJson(json);
      expect(restored.turnDurationSeconds, 60);
      expect(restored.turnDeadlineEpochMs, deadline);
      expect(restored.phase, GamePhase.auction);
    });

    test('GameState toSanitizedJson preserves turn timing fields', () {
      final deadline = DateTime.now().millisecondsSinceEpoch + 60000;
      final state = GameState(
        players: createPlayers(),
        phase: GamePhase.trickTaking,
        turnDurationSeconds: 60,
        turnDeadlineEpochMs: deadline,
      );

      final sanitized = state.toSanitizedJson(recipientPlayerId: 'p1');
      expect(sanitized['turnDurationSeconds'], 60);
      expect(sanitized['turnDeadlineEpochMs'], deadline);
    });
  });

  group('TurnTimerBadge Widget Tests', () {
    testWidgets('Renders Arabic AUCTION label and remaining seconds for auction phase', (tester) async {
      final now = DateTime.now().millisecondsSinceEpoch;
      final state = GameState(
        players: createPlayers(),
        phase: GamePhase.auction,
        turnDurationSeconds: 60,
        turnDeadlineEpochMs: now + 59800,
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: TurnTimerBadge(
              state: state,
              isMyTurn: true,
            ),
          ),
        ),
      );

      expect(find.text('المزاد'), findsOneWidget);
      expect(find.textContaining('60 ث'), findsOneWidget);
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
    });

    testWidgets('Renders Arabic DECLARATION label and 60s for declaration phase', (tester) async {
      final now = DateTime.now().millisecondsSinceEpoch;
      final state = GameState(
        players: createPlayers(),
        phase: GamePhase.declarations,
        turnDurationSeconds: 60,
        turnDeadlineEpochMs: now + 59500,
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: TurnTimerBadge(
              state: state,
              isMyTurn: true,
            ),
          ),
        ),
      );

      expect(find.text('التصريح'), findsOneWidget);
      expect(find.textContaining('60 ث'), findsOneWidget);
    });

    testWidgets('Renders دورك (YOUR TURN) and 60s for trick-taking phase when isMyTurn is true', (tester) async {
      final now = DateTime.now().millisecondsSinceEpoch;
      final state = GameState(
        players: createPlayers(),
        phase: GamePhase.trickTaking,
        turnDurationSeconds: 60,
        turnDeadlineEpochMs: now + 59800,
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: TurnTimerBadge(
              state: state,
              isMyTurn: true,
            ),
          ),
        ),
      );

      expect(find.text('دورك'), findsOneWidget);
      expect(find.textContaining('60 ث'), findsOneWidget);
    });

    testWidgets('Renders opponent name TURN in Arabic when isMyTurn is false', (tester) async {
      final now = DateTime.now().millisecondsSinceEpoch;
      final state = GameState(
        players: createPlayers(),
        phase: GamePhase.trickTaking,
        turnDurationSeconds: 60,
        turnDeadlineEpochMs: now + 59800,
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: TurnTimerBadge(
              state: state,
              isMyTurn: false,
              activePlayerName: 'عمر',
            ),
          ),
        ),
      );

      expect(find.text('دور عمر'), findsOneWidget);
      expect(find.textContaining('60 ث'), findsOneWidget);
    });

    testWidgets('Renders ⚠️ warning state when remaining time is 5 seconds or less', (tester) async {
      final now = DateTime.now().millisecondsSinceEpoch;
      final state = GameState(
        players: createPlayers(),
        phase: GamePhase.trickTaking,
        turnDurationSeconds: 60,
        turnDeadlineEpochMs: now + 4800, // 5s remaining
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: TurnTimerBadge(
              state: state,
              isMyTurn: true,
            ),
          ),
        ),
      );

      expect(find.text('دورك'), findsOneWidget);
      expect(find.textContaining('⚠️'), findsOneWidget);
      expect(find.text('5'), findsOneWidget);
    });

    testWidgets('Renders ⚠️ 3 when 3 seconds remaining', (tester) async {
      final now = DateTime.now().millisecondsSinceEpoch;
      final state = GameState(
        players: createPlayers(),
        phase: GamePhase.auction,
        turnDurationSeconds: 60,
        turnDeadlineEpochMs: now + 2800, // 3s remaining
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: TurnTimerBadge(
              state: state,
              isMyTurn: true,
            ),
          ),
        ),
      );

      expect(find.text('المزاد'), findsOneWidget);
      expect(find.textContaining('⚠️'), findsOneWidget);
      expect(find.text('3'), findsOneWidget);
    });
  });

  group('Dialog Turn Timer Integration Tests', () {
    testWidgets('BidDialog integrates TurnTimerBadge with Arabic AUCTION label', (tester) async {
      final now = DateTime.now().millisecondsSinceEpoch;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: BidDialog(
              deadlineEpochMs: now + 59500,
              durationSeconds: 60,
              onBid: (_) {},
              onPass: () {},
            ),
          ),
        ),
      );

      expect(find.text('المزاد'), findsWidgets);
      expect(find.textContaining('60 ث'), findsOneWidget);
      expect(find.byType(TurnTimerBadge), findsOneWidget);
    });

    testWidgets('DeclarationDialog integrates TurnTimerBadge with Arabic DECLARATION label', (tester) async {
      final now = DateTime.now().millisecondsSinceEpoch;
      final players = createPlayers();
      final state = GameState(
        players: players,
        phase: GamePhase.declarations,
        turnDurationSeconds: 60,
        turnDeadlineEpochMs: now + 59500,
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: DeclarationDialog(
              state: state,
              me: players[0],
              onSubmit: (_) {},
            ),
          ),
        ),
      );

      expect(find.text('كم لمة تتوقع؟'), findsOneWidget);
      expect(find.text('التصريح'), findsOneWidget);
      expect(find.textContaining('60 ث'), findsOneWidget);
      expect(find.byType(TurnTimerBadge), findsOneWidget);
    });
  });

  group('Turn Timing Constants Verification', () {
    test('Constants match specified durations', () {
      expect(kAuctionTurnTimeout.inSeconds, 60);
      expect(kDeclarationTurnTimeout.inSeconds, 60);
      expect(kTrickTurnTimeout.inSeconds, 60);
      expect(kDashCallTurnTimeout.inSeconds, 60);
      expect(kTurnWarningThresholdSeconds, 5);
    });
  });
}
