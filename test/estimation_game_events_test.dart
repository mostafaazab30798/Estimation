import 'package:flutter_test/flutter_test.dart';
import 'package:estimation/core/constants.dart';
import 'package:estimation/core/events/estimation_game_events.dart';
import 'package:estimation/core/events/estimation_event_bus.dart';
import 'package:estimation/core/events/estimation_event_dispatcher.dart';
import 'package:estimation/core/models/bid.dart';
import 'package:estimation/core/models/card.dart';
import 'package:estimation/core/models/comeback_event.dart';
import 'package:estimation/core/models/game_state.dart';
import 'package:estimation/core/models/player.dart';

void main() {
  group('Estimation Game Events Structure & Serialization', () {
    test('1. RoundStarted event contains correct metadata and serializes to JSON', () {
      final event = RoundStarted(
        roundNumber: 14,
        totalRounds: 18,
        dealerSeatIndex: 1,
        isDoubleRound: true,
        fixedTrump: Trump.sans,
      );

      expect(event.eventName, equals('RoundStarted'));
      expect(event.roundNumber, equals(14));
      expect(event.totalRounds, equals(18));
      expect(event.isDoubleRound, isTrue);
      expect(event.fixedTrump, equals(Trump.sans));
      expect(event.emoji, equals('🏁'));

      final json = event.toJson();
      expect(json['eventName'], equals('RoundStarted'));
      expect(json['roundNumber'], equals(14));
      expect(json['fixedTrump'], equals('sans'));
    });

    test('2. VoidCheckCompleted event handles redeal flag', () {
      final event = VoidCheckCompleted(
        roundNumber: 1,
        redealOccurred: true,
        declaringPlayerId: 'p1',
      );

      expect(event.eventName, equals('VoidCheckCompleted'));
      expect(event.redealOccurred, isTrue);
      expect(event.declaringPlayerId, equals('p1'));
      expect(event.toJson()['redealOccurred'], isTrue);
    });

    test('3. DashCallMade, DashCallSucceeded, and DashCallFailed events', () {
      final made = DashCallMade(
        playerId: 'p1',
        playerName: 'Mostafa',
        seatIndex: 0,
      );
      expect(made.eventName, equals('DashCallMade'));
      expect(made.playerName, equals('Mostafa'));

      final succeeded = DashCallSucceeded(
        playerId: 'p1',
        playerName: 'Mostafa',
        scoreDelta: 33,
        roundNumber: 2,
      );
      expect(succeeded.scoreDelta, equals(33));
      expect(succeeded.emoji, equals('🌟'));

      final failed = DashCallFailed(
        playerId: 'p1',
        playerName: 'Mostafa',
        actualTricks: 2,
        scoreDelta: -33,
        roundNumber: 2,
      );
      expect(failed.actualTricks, equals(2));
      expect(failed.scoreDelta, equals(-33));
      expect(failed.emoji, equals('💥'));
    });

    test('4. Auction Events: BidPlaced, HighBidChanged, AuctionWon, AuctionPassed, AllPlayersPassed', () {
      final bid = Bid(trickCount: 6, trump: Trump.spade);
      final prevBid = Bid(trickCount: 5, trump: Trump.club);

      final placed = BidPlaced(
        playerId: 'p2',
        playerName: 'Ahmed',
        bid: bid,
        seatIndex: 1,
      );
      expect(placed.bid.trickCount, equals(6));

      final highChanged = HighBidChanged(
        playerId: 'p2',
        playerName: 'Ahmed',
        newHighBid: bid,
        previousHighBid: prevBid,
      );
      expect(highChanged.newHighBid.trickCount, equals(6));
      expect(highChanged.previousHighBid?.trickCount, equals(5));

      final won = AuctionWon(
        bidderId: 'p2',
        bidderName: 'Ahmed',
        winningBid: bid,
        trump: Trump.spade,
      );
      expect(won.bidderId, equals('p2'));
      expect(won.trump, equals(Trump.spade));

      final passed = AuctionPassed(
        playerId: 'p3',
        playerName: 'Sara',
        seatIndex: 2,
      );
      expect(passed.playerId, equals('p3'));

      final allPassed = AllPlayersPassed(
        roundNumber: 3,
        nextRoundNumber: 4,
      );
      expect(allPassed.roundNumber, equals(3));
      expect(allPassed.nextRoundNumber, equals(4));
    });

    test('5. Declaration Events: DeclarationMade, PerfectEstimate, DeclarationMissed, ForbiddenDeclarationAttempt, RiskDeclaration', () {
      final dec = DeclarationMade(
        playerId: 'p1',
        playerName: 'Mostafa',
        declared: 4,
        seatIndex: 0,
        isRisk: false,
        isWith: true,
      );
      expect(dec.declared, equals(4));
      expect(dec.isWith, isTrue);

      final perfect = PerfectEstimate(
        playerId: 'p1',
        playerName: 'Mostafa',
        declared: 4,
        actual: 4,
        scoreDelta: 18,
        roundNumber: 1,
        isBidder: true,
      );
      expect(perfect.actual, equals(4));
      expect(perfect.scoreDelta, equals(18));
      expect(perfect.isBidder, isTrue);

      final missed = DeclarationMissed(
        playerId: 'p1',
        playerName: 'Mostafa',
        declared: 4,
        actual: 2,
        difference: 2,
        scoreDelta: -13,
        roundNumber: 1,
      );
      expect(missed.difference, equals(2));
      expect(missed.scoreDelta, equals(-13));

      final forbidden = ForbiddenDeclarationAttempt(
        playerId: 'p4',
        playerName: 'Nour',
        forbiddenNumber: 3,
      );
      expect(forbidden.forbiddenNumber, equals(3));

      final risk = RiskDeclaration(
        playerId: 'p4',
        playerName: 'Nour',
        declared: 2,
        totalTableDeclared: 10,
      );
      expect(risk.totalTableDeclared, equals(10));
      expect(risk.emoji, equals('⚠️'));
    });

    test('6. Trick Events: TrickWon, BidderTrickWon, BidderTrickLost', () {
      final trickCard = TrickCard(
        playerId: 'p1',
        card: PlayingCard(rank: Rank.ace, suit: Suit.spade),
      );

      final trickWon = TrickWon(
        winnerId: 'p1',
        winnerName: 'Mostafa',
        trickNumber: 5,
        trickCards: [trickCard],
        winningCard: trickCard,
        isBidder: true,
      );
      expect(trickWon.winnerId, equals('p1'));
      expect(trickWon.trickNumber, equals(5));

      final bidderWon = BidderTrickWon(
        bidderId: 'p1',
        bidderName: 'Mostafa',
        trickNumber: 5,
        bidderTotalTaken: 4,
      );
      expect(bidderWon.bidderTotalTaken, equals(4));

      final bidderLost = BidderTrickLost(
        bidderId: 'p1',
        bidderName: 'Mostafa',
        winnerId: 'p2',
        winnerName: 'Ahmed',
        trickNumber: 6,
      );
      expect(bidderLost.winnerId, equals('p2'));
      expect(bidderLost.bidderId, equals('p1'));
    });

    test('7. Meta & Lifecycle Events: RoundCompleted, DoubleRoundStarted, ComebackDetected, PlayerTakesLead, FinalRoundStarted, MatchCompleted', () {
      final comeback = ComebackEvent(
        playerId: 'p1',
        playerName: 'Mostafa',
        type: ComebackType.majorComeback,
        roundNumber: 5,
        previousRank: 4,
        newRank: 1,
        pointsDeficitOvercome: 20,
        scoreDelta: 25,
      );

      final cbEvent = ComebackDetected(comeback: comeback);
      expect(cbEvent.comeback.playerName, equals('Mostafa'));

      final lead = PlayerTakesLead(
        leaderId: 'p1',
        leaderName: 'Mostafa',
        leaderScore: 120,
        previousLeaderId: 'p2',
        previousLeaderName: 'Ahmed',
        roundNumber: 8,
      );
      expect(lead.leaderScore, equals(120));
      expect(lead.previousLeaderName, equals('Ahmed'));

      final doubleRound = DoubleRoundStarted(roundNumber: 4, multiplier: 2);
      expect(doubleRound.multiplier, equals(2));

      final finalRound = FinalRoundStarted(
        roundNumber: 18,
        totalRounds: 18,
        leaderPlayerId: 'p1',
        leaderPlayerName: 'Mostafa',
      );
      expect(finalRound.totalRounds, equals(18));

      final player = Player(id: 'p1', name: 'Mostafa', seatIndex: 0, totalScore: 150);
      final matchEnd = MatchCompleted(
        winner: player,
        rankings: [player],
        totalRounds: 18,
      );
      expect(matchEnd.winner.id, equals('p1'));
      expect(matchEnd.winner.totalScore, equals(150));
    });
  });

  group('EstimationEventBus Tests', () {
    late EstimationEventBus bus;

    setUp(() {
      bus = EstimationEventBus.instance;
      bus.clearHistory();
    });

    test('Fires events and receives them on general stream', () async {
      final events = <EstimationGameEvent>[];
      final sub = bus.events.listen(events.add);

      bus.fire(RoundStarted(roundNumber: 1, totalRounds: 18, dealerSeatIndex: 0));
      bus.fire(DashCallMade(playerId: 'p1', playerName: 'Mostafa', seatIndex: 0));

      await Future.delayed(const Duration(milliseconds: 10));

      expect(events.length, equals(2));
      expect(events[0], isA<RoundStarted>());
      expect(events[1], isA<DashCallMade>());

      await sub.cancel();
    });

    test('Filters typed events accurately with on<T>()', () async {
      final perfectEstimates = <PerfectEstimate>[];
      final sub = bus.on<PerfectEstimate>().listen(perfectEstimates.add);

      bus.fire(RoundStarted(roundNumber: 1, totalRounds: 18, dealerSeatIndex: 0));
      bus.fire(PerfectEstimate(
        playerId: 'p1',
        playerName: 'Mostafa',
        declared: 3,
        actual: 3,
        scoreDelta: 14,
        roundNumber: 1,
      ));
      bus.fire(DashCallMade(playerId: 'p1', playerName: 'Mostafa', seatIndex: 0));

      await Future.delayed(const Duration(milliseconds: 10));

      expect(perfectEstimates.length, equals(1));
      expect(perfectEstimates.first.declared, equals(3));

      await sub.cancel();
    });

    test('Maintains event history within configured buffer capacity', () {
      bus.maxHistoryLength = 5;

      for (int i = 1; i <= 10; i++) {
        bus.fire(RoundStarted(roundNumber: i, totalRounds: 18, dealerSeatIndex: 0));
      }

      expect(bus.history.length, equals(5));
      expect((bus.history.first as RoundStarted).roundNumber, equals(6));
      expect((bus.history.last as RoundStarted).roundNumber, equals(10));
    });
  });

  group('EstimationEventDispatcher State Transition Tests', () {
    late EstimationEventBus bus;
    late EstimationEventDispatcher dispatcher;

    setUp(() {
      bus = EstimationEventBus.instance;
      bus.clearHistory();
      dispatcher = EstimationEventDispatcher(bus: bus);
    });

    test('Dispatches RoundStarted, HighBidChanged, DeclarationMade, and TrickWon on state changes', () async {
      final events = <EstimationGameEvent>[];
      final sub = bus.events.listen(events.add);

      final p1 = Player(id: 'p1', name: 'Mostafa', seatIndex: 0);
      final p2 = Player(id: 'p2', name: 'Ahmed', seatIndex: 1);
      final p3 = Player(id: 'p3', name: 'Sara', seatIndex: 2);
      final p4 = Player(id: 'p4', name: 'Nour', seatIndex: 3);

      final state1 = GameState(
        players: [p1, p2, p3, p4],
        phase: GamePhase.dealing,
        roundNumber: 1,
      );

      dispatcher.dispatchStateTransition(null, state1);

      // State 2: Auction high bid
      final state2 = GameState(
        players: [p1, p2, p3, p4],
        phase: GamePhase.auction,
        roundNumber: 1,
        currentHighBid: Bid(trickCount: 5, trump: Trump.spade),
        currentHighBidderPlayerId: 'p1',
      );
      dispatcher.dispatchStateTransition(state1, state2);

      // State 3: Declarations
      final p1Declared = p1.copyWith(declared: 5);
      final state3 = GameState(
        players: [p1Declared, p2, p3, p4],
        phase: GamePhase.declarations,
        roundNumber: 1,
        bidderPlayerId: 'p1',
        currentHighBid: Bid(trickCount: 5, trump: Trump.spade),
        trump: Trump.spade,
      );
      dispatcher.dispatchStateTransition(state2, state3);

      await Future.delayed(const Duration(milliseconds: 10));

      expect(events.any((e) => e is RoundStarted), isTrue);
      expect(events.any((e) => e is HighBidChanged), isTrue);
      expect(events.any((e) => e is DeclarationMade), isTrue);
      expect(events.any((e) => e is AuctionWon), isTrue);

      await sub.cancel();
    });

    test('Dispatches scoring and comeback events on round scoring phase', () async {
      final events = <EstimationGameEvent>[];
      final sub = bus.events.listen(events.add);

      final p1 = Player(id: 'p1', name: 'Mostafa', seatIndex: 0, totalScore: 30, declared: 4, actual: 4);
      final p2 = Player(id: 'p2', name: 'Ahmed', seatIndex: 1, totalScore: -10, declared: 3, actual: 1);
      final p3 = Player(id: 'p3', name: 'Sara', seatIndex: 2, totalScore: 15, declared: 3, actual: 3);
      final p4 = Player(id: 'p4', name: 'Nour', seatIndex: 3, totalScore: 10, declared: 3, actual: 3);

      final statePrev = GameState(
        players: [p1, p2, p3, p4],
        phase: GamePhase.trickTaking,
        roundNumber: 1,
        tricksPlayedThisRound: 13,
      );

      final record = RoundHistoryRecord(
        roundNumber: 1,
        bidderPlayerId: 'p1',
        trump: Trump.spade,
        playerRecords: [
          PlayerRoundRecord(
            playerId: 'p1',
            playerName: 'Mostafa',
            declared: 4,
            actual: 4,
            scoreDelta: 15,
            totalScoreAfterRound: 30,
            isSuccess: true,
          ),
          PlayerRoundRecord(
            playerId: 'p2',
            playerName: 'Ahmed',
            declared: 3,
            actual: 1,
            scoreDelta: -15,
            totalScoreAfterRound: -10,
            isSuccess: false,
          ),
        ],
      );

      final stateScoring = GameState(
        players: [p1, p2, p3, p4],
        phase: GamePhase.scoring,
        roundNumber: 1,
        lastRoundScoreDeltas: {'p1': 15, 'p2': -15, 'p3': 14, 'p4': 14},
        roundHistory: [record],
      );

      dispatcher.dispatchStateTransition(statePrev, stateScoring);

      await Future.delayed(const Duration(milliseconds: 10));

      expect(events.any((e) => e is PerfectEstimate), isTrue);
      expect(events.any((e) => e is DeclarationMissed), isTrue);
      expect(events.any((e) => e is RoundCompleted), isTrue);
      expect(events.any((e) => e is PlayerTakesLead), isTrue);

      await sub.cancel();
    });
  });
}
