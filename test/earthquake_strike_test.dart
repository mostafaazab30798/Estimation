// test/earthquake_strike_test.dart
//
// Tests for the Earthquake Card Strike feature in Estimation mode.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:estimation/core/constants.dart';
import 'package:estimation/core/models/card.dart';
import 'package:estimation/core/models/game_state.dart';
import 'package:estimation/core/models/player.dart';
import 'package:estimation/core/events/estimation_event_bus.dart';
import 'package:estimation/core/events/estimation_game_events.dart';
import 'package:estimation/models/earthquake_effect.dart';
import 'package:estimation/widgets/player_hand.dart';
import 'package:estimation/widgets/playing_card_widget.dart';
import 'package:estimation/widgets/earthquake/earthquake_effect_overlay.dart';
import 'package:estimation/widgets/earthquake/earthquake_crack_painter.dart';
import 'package:estimation/networking/messages.dart';
import 'package:estimation/providers/game_provider.dart';
import 'package:flutter/services.dart';

import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    SharedPreferences.setMockInitialValues({});
    try {
      await Supabase.initialize(
        url: 'https://eqmkbfxerxqihforsgvx.supabase.co',
        publishableKey: 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImVxbWtiZnhlcnhxaWhmb3JzZ3Z4Iiwicm9sZSI6ImFub24iLCJpYXQiOjE3ODQwNjQ0NTUsImV4cCI6MjA5OTY0MDQ1NX0.3F_n2TUVGTucW2DUWpv5YxqOtFkBQZaQJZKngL7gOx0',
        authOptions: const FlutterAuthClientOptions(autoRefreshToken: false),
      );
    } catch (_) {}

    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
      SystemChannels.platform,
      (MethodCall methodCall) async => null,
    );
  });

  group('Earthquake Game Event Tests', () {
    test('EarthquakeStrikeUsed event properties and JSON serialization', () {
      final card = PlayingCard(suit: Suit.spade, rank: Rank.ace);
      final event = EarthquakeStrikeUsed(
        playerId: 'p1',
        playerName: 'Mostafa',
        card: card,
        roundNumber: 3,
      );

      expect(event.eventName, equals('EarthquakeStrikeUsed'));
      expect(event.playerId, equals('p1'));
      expect(event.playerName, equals('Mostafa'));
      expect(event.card, equals(card));
      expect(event.roundNumber, equals(3));
      expect(event.messageAr, contains('زلزال'));
      expect(event.emoji, equals('🌋'));

      final json = event.toJson();
      expect(json['eventName'], equals('EarthquakeStrikeUsed'));
      expect(json['playerId'], equals('p1'));
      expect(json['playerName'], equals('Mostafa'));
      expect(json['roundNumber'], equals(3));
      expect(json['card'], isA<Map<String, dynamic>>());
    });

    test('EstimationEventBus dispatches EarthquakeStrikeUsed to subscribers', () async {
      final events = <EarthquakeStrikeUsed>[];
      final sub = EstimationEventBus.instance
          .on<EarthquakeStrikeUsed>()
          .listen((e) => events.add(e));

      final card = PlayingCard(suit: Suit.heart, rank: Rank.king);
      EstimationEventBus.instance.fire(EarthquakeStrikeUsed(
        playerId: 'p2',
        playerName: 'Sarah',
        card: card,
        roundNumber: 5,
      ));

      await Future.delayed(const Duration(milliseconds: 20));
      expect(events.length, equals(1));
      expect(events.first.playerName, equals('Sarah'));
      expect(events.first.card, equals(card));
      await sub.cancel();
    });
  });

  group('EarthquakeEffectOverlay & Painter Tests', () {
    testWidgets('EarthquakeEffectOverlay renders child and responds to trigger', (tester) async {
      bool slammed = false;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: EarthquakeEffectOverlay(
              onSlamImpact: () => slammed = true,
              child: const Text('Table Content'),
            ),
          ),
        ),
      );

      expect(find.text('Table Content'), findsOneWidget);

      // Trigger via EventBus — impact fires mid-flight, not instantly
      EstimationEventBus.instance.fire(EarthquakeStrikeUsed(
        playerId: 'p1',
        playerName: 'Mostafa',
        card: PlayingCard(suit: Suit.club, rank: Rank.ten),
        roundNumber: 1,
      ));

      await tester.pump();
      expect(slammed, isFalse);

      // Advance past impact fraction (~68% of 780ms)
      await tester.pump(const Duration(milliseconds: 560));
      expect(slammed, isTrue);

      // Verify custom painter is present during animation
      expect(find.byType(CustomPaint), findsWidgets);

      // Pump through animation completion
      await tester.pump(const Duration(milliseconds: 1500));
      await tester.pumpAndSettle();
    });

    test('EarthquakeCrackPainter shouldRepaint test', () {
      final painter1 = EarthquakeCrackPainter(progress: 0.2);
      final painter2 = EarthquakeCrackPainter(progress: 0.5);
      final painter3 = EarthquakeCrackPainter(progress: 0.2);
      final frostPainter = EarthquakeCrackPainter(
        progress: 0.2,
        effect: EarthquakeEffect.frost,
      );

      expect(painter1.shouldRepaint(painter2), isTrue);
      expect(painter1.shouldRepaint(painter3), isFalse);
      expect(painter1.shouldRepaint(frostPainter), isTrue);
    });

    test('Earthquake effect storage values are backward compatible', () {
      expect(
        EarthquakeEffect.fromStorage(null),
        EarthquakeEffect.magma,
      );
      expect(
        EarthquakeEffect.fromStorage('unknown-effect'),
        EarthquakeEffect.magma,
      );
      expect(
        EarthquakeEffect.fromStorage('frost'),
        EarthquakeEffect.frost,
      );
    });
  });

  group('PlayerHand Earthquake Hold & Once-Per-Round Tests', () {
    late GameState state;
    late Player me;
    late List<PlayingCard> hand;

    setUp(() {
      EstimationEventBus.instance.clearHistory();
      hand = [
        PlayingCard(suit: Suit.spade, rank: Rank.ace),
        PlayingCard(suit: Suit.heart, rank: Rank.ten),
      ];

      me = Player(id: 'me', name: 'MyPlayer', seatIndex: 0, hand: hand);

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

    testWidgets('Holding card for 2 seconds triggers Earthquake Strike and plays card', (tester) async {
      PlayingCard? playedCard;
      final events = <EarthquakeStrikeUsed>[];
      final sub = EstimationEventBus.instance
          .on<EarthquakeStrikeUsed>()
          .listen((e) => events.add(e));

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

      // Touch down on first card
      final firstCardFinder = find.byType(PlayingCardWidget).first;
      final gesture = await tester.startGesture(tester.getCenter(firstCardFinder));
      await tester.pump(const Duration(milliseconds: 300));

      // Check charging text appears
      expect(find.textContaining('زلزال'), findsOneWidget);

      // Advance through 2 seconds hold duration in frame increments
      for (int i = 0; i < 20; i++) {
        await tester.pump(const Duration(milliseconds: 100));
      }
      debugPrint('[TEST 4] Hold complete');

      // Advance through flight until table impact (~530ms+)
      for (int i = 0; i < 8; i++) {
        await tester.pump(const Duration(milliseconds: 100));
      }

      // Release pointer
      await gesture.up();
      for (int i = 0; i < 4; i++) {
        await tester.pump(const Duration(milliseconds: 100));
      }

      final earthquakeEvents = EstimationEventBus.instance.history
          .whereType<EarthquakeStrikeUsed>()
          .toList();

      expect(earthquakeEvents.isNotEmpty, isTrue);
      expect(earthquakeEvents.last.card, isNotNull);
      expect(playedCard, equals(earthquakeEvents.last.card));

      sub.cancel();
    });

    testWidgets('Releasing hold early (< 2s) cancels earthquake charge without playing', (tester) async {
      PlayingCard? playedCard;
      final events = <EarthquakeStrikeUsed>[];
      final sub = EstimationEventBus.instance
          .on<EarthquakeStrikeUsed>()
          .listen((e) => events.add(e));

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: PlayerHand(
              key: const Key('hand_test_5'),
              hand: hand,
              isMyTurn: true,
              state: state,
              me: me,
              onPlayCard: (c) => playedCard = c,
            ),
          ),
        ),
      );

      // Touch down for 0.8 seconds (less than 2s)
      final firstCardFinder = find.byType(PlayingCardWidget).first;
      final gesture = await tester.startGesture(tester.getCenter(firstCardFinder));
      for (int i = 0; i < 8; i++) {
        await tester.pump(const Duration(milliseconds: 100));
      }

      // Release finger
      await gesture.up();
      for (int i = 0; i < 4; i++) {
        await tester.pump(const Duration(milliseconds: 100));
      }

      // No earthquake fired and no card played
      expect(events.isEmpty, isTrue);
      expect(playedCard, isNull);
      expect(find.textContaining('زلزال'), findsNothing);

      sub.cancel();
    });
  });

  group('Multiplayer Earthquake Synchronization Tests', () {
    test('GameMessage encodes and decodes earthquake MessageType and triggerEarthquake ActionType', () {
      expect(MessageType.values.map((m) => m.name), contains('earthquake'));
      expect(ActionType.triggerEarthquake, equals('triggerEarthquake'));

      final payload = {
        'id': 'eq_123',
        'playerId': 'player_1',
        'playerName': 'Ahmed',
        'card': {'suit': 'spade', 'rank': 'ace'},
        'roundNumber': 2,
      };

      final msg = GameMessage(type: MessageType.earthquake, payload: payload);
      final jsonStr = msg.toJsonString();
      final decodedMsg = GameMessage.fromJsonString(jsonStr);

      expect(decodedMsg.type, equals(MessageType.earthquake));
      expect(decodedMsg.payload['playerName'], equals('Ahmed'));
      expect(decodedMsg.payload['id'], equals('eq_123'));
    });

    test('GameProvider handleIncomingEarthquake dispatches event and deduplicates IDs', () async {
      final events = <EarthquakeStrikeUsed>[];
      final sub = EstimationEventBus.instance
          .on<EarthquakeStrikeUsed>()
          .listen((e) => events.add(e));

      final provider = GameProvider();

      // First earthquake event from another player
      provider.handleIncomingEarthquake({
        'earthquakeId': 'strike_abc_1',
        'playerId': 'peer_player_id',
        'playerName': 'Tarek',
        'roundNumber': 4,
        'card': {'suit': 'heart', 'rank': 'king'},
      });

      await Future.delayed(Duration.zero);

      expect(events.length, equals(1));
      expect(events.first.playerId, equals('peer_player_id'));
      expect(events.first.playerName, equals('Tarek'));
      expect(events.first.card.suit, equals(Suit.heart));
      expect(events.first.card.rank, equals(Rank.king));
      expect(events.first.roundNumber, equals(4));

      // Duplicate event with same ID should be ignored
      provider.handleIncomingEarthquake({
        'earthquakeId': 'strike_abc_1',
        'playerId': 'peer_player_id',
        'playerName': 'Tarek',
        'roundNumber': 4,
        'card': {'suit': 'heart', 'rank': 'king'},
      });

      await Future.delayed(Duration.zero);

      expect(events.length, equals(1)); // Still 1

      sub.cancel();
      provider.dispose();
    });
  });
}
