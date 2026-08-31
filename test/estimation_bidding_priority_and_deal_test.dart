// test/estimation_bidding_priority_and_deal_test.dart

import 'package:flutter_test/flutter_test.dart';
import 'package:estimation/core/constants.dart';
import 'package:estimation/core/game_engine.dart';
import 'package:estimation/core/models/bid.dart';
import 'package:estimation/core/models/player.dart';
import 'package:estimation/core/models/game_state.dart';
import 'package:estimation/providers/game_provider.dart';
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
      );
    } catch (_) {}
  });

  List<Player> createFourPlayers() {
    return [
      Player(id: 'host', name: 'Host (Bottom)', seatIndex: 0),
      Player(id: 'right', name: 'Right Player', seatIndex: 1),
      Player(id: 'top', name: 'Top Player', seatIndex: 2),
      Player(id: 'left', name: 'Left Player', seatIndex: 3),
    ];
  }

  group('Estimation Bidding Priority & Dealer Rotation Tests', () {
    test('Round 1 initial state has auction starting with Host (Seat 0)', () {
      final players = createFourPlayers();
      final state = GameEngine.createInitialState(players);

      expect(state.roundNumber, equals(1));
      expect(state.dealerSeatIndex, equals(3)); // Left player dealt to host first
      expect(state.auctionTurnSeatIndex, equals(0)); // Host bids first
    });

    test('Bidding priority order follows Host (0) -> Right (1) -> Top (2) -> Left (3) -> Host (0)', () {
      final players = createFourPlayers();
      final state = GameState(
        players: players,
        phase: GamePhase.auction,
        roundNumber: 1,
        dealerSeatIndex: 3,
        auctionTurnSeatIndex: 0,
      );

      // 1. Host bids 4 (min bid is 4)
      final bid1 = Bid(trickCount: 4, trump: Trump.spade);
      expect(GameEngine.submitBid(state, 'host', bid1), isTrue);
      expect(state.currentHighBid, equals(bid1));
      expect(state.currentHighBidderPlayerId, equals('host'));
      // Next is Right (Seat 1)
      expect(state.auctionTurnSeatIndex, equals(1));

      // 2. Right passes
      GameEngine.passBid(state, 'right');
      // Next is Top (Seat 2)
      expect(state.auctionTurnSeatIndex, equals(2));

      // 3. Top bids 5
      final bid2 = Bid(trickCount: 5, trump: Trump.heart);
      expect(GameEngine.submitBid(state, 'top', bid2), isTrue);
      expect(state.currentHighBid, equals(bid2));
      // Next is Left (Seat 3)
      expect(state.auctionTurnSeatIndex, equals(3));

      // 4. Left passes
      GameEngine.passBid(state, 'left');
      // Next wraps around back to Host (Seat 0) because Right and Left have passed!
      expect(state.auctionTurnSeatIndex, equals(0));
    });

    test('Round 2 starts auction with Right Player (Seat 1)', () {
      final players = createFourPlayers();
      final state = GameEngine.createInitialState(players);

      GameEngine.startNextRound(state);

      expect(state.roundNumber, equals(2));
      expect(state.dealerSeatIndex, equals(0)); // Host is dealer
      expect(state.auctionTurnSeatIndex, equals(1)); // Right player bids first
      expect(state.currentPlayerSeatIndex, equals(1));
    });

    test('Round 3 starts auction with Top Player (Seat 2)', () {
      final players = createFourPlayers();
      final state = GameEngine.createInitialState(players);

      GameEngine.startNextRound(state); // Round 2
      GameEngine.startNextRound(state); // Round 3

      expect(state.roundNumber, equals(3));
      expect(state.dealerSeatIndex, equals(1)); // Right player is dealer
      expect(state.auctionTurnSeatIndex, equals(2)); // Top player bids first
      expect(state.currentPlayerSeatIndex, equals(2));
    });

    test('Round 4 starts auction with Left Player (Seat 3)', () {
      final players = createFourPlayers();
      final state = GameEngine.createInitialState(players);

      GameEngine.startNextRound(state); // Round 2
      GameEngine.startNextRound(state); // Round 3
      GameEngine.startNextRound(state); // Round 4

      expect(state.roundNumber, equals(4));
      expect(state.dealerSeatIndex, equals(2)); // Top player is dealer
      expect(state.auctionTurnSeatIndex, equals(3)); // Left player bids first
      expect(state.currentPlayerSeatIndex, equals(3));
    });

    test('Round 5 loops back and starts auction with Host (Seat 0)', () {
      final players = createFourPlayers();
      final state = GameEngine.createInitialState(players);

      for (int i = 0; i < 4; i++) {
        GameEngine.startNextRound(state);
      }

      expect(state.roundNumber, equals(5));
      expect(state.dealerSeatIndex, equals(3)); // Left player is dealer
      expect(state.auctionTurnSeatIndex, equals(0)); // Host bids first
      expect(state.currentPlayerSeatIndex, equals(0));
    });
  });

  group('Direct Deal to DashCall or VoidCheck', () {
    test('Starting test game deal enters dashCall, or voidCheck if a hand is void', () async {
      final provider = GameProvider();
      await provider.startTestGame('Host Player');
      provider.startGame();

      final state = provider.state!;
      expect(state.players.length, equals(4));
      expect(provider.myHand.length, equals(13));

      final hasVoid = state.players.any(GameEngine.hasVoidSuit);
      if (hasVoid) {
        expect(state.phase, equals(GamePhase.voidCheck));
        expect(state.voidDeclaringPlayerId, isNotNull);
      } else {
        expect(state.phase, equals(GamePhase.dashCall));
        expect(state.voidDeclaringPlayerId, isNull);
        // First turn is Host (Seat 0)
        expect(state.currentPlayerSeatIndex, equals(0));
      }
      expect(state.auctionTurnSeatIndex, equals(0));

      await provider.reset();
    });
  });
}
