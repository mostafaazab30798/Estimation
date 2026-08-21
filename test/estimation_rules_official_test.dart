// test/estimation_rules_official_test.dart

import 'package:flutter_test/flutter_test.dart';
import 'package:estimation/core/game_engine.dart';
import 'package:estimation/core/models/card.dart';
import 'package:estimation/core/models/bid.dart';
import 'package:estimation/core/models/player.dart';
import 'package:estimation/core/models/game_state.dart';
import 'package:estimation/core/constants.dart';

void main() {
  List<Player> createTestPlayers() {
    return [
      Player(id: 'p1', name: 'Player 1', seatIndex: 0),
      Player(id: 'p2', name: 'Player 2', seatIndex: 1),
      Player(id: 'p3', name: 'Player 3', seatIndex: 2),
      Player(id: 'p4', name: 'Player 4', seatIndex: 3),
    ];
  }

  group('1. Trump Hierarchy & Sans (No Trump) Rules', () {
    test('Sans has highest priority in bidding over all suits', () {
      const bidSans = Bid(trickCount: 4, trump: Trump.sans);
      const bidSpade = Bid(trickCount: 4, trump: Trump.spade);
      const bidHeart = Bid(trickCount: 4, trump: Trump.heart);
      const bidDiamond = Bid(trickCount: 4, trump: Trump.diamond);
      const bidClub = Bid(trickCount: 4, trump: Trump.club);

      expect(bidSans.beats(bidSpade), isTrue);
      expect(bidSpade.beats(bidHeart), isTrue);
      expect(bidHeart.beats(bidDiamond), isTrue);
      expect(bidDiamond.beats(bidClub), isTrue);
      expect(bidClub.beats(bidSans), isFalse);
    });

    test('In Sans trick resolution, highest card of led suit wins, no trump cuts', () {
      final state = GameState(
        players: createTestPlayers(),
        phase: GamePhase.trickTaking,
        trump: Trump.sans,
      );

      // P1 leads 10 Hearts, P2 plays Ace Hearts, P3 plays King Spades (off-suit), P4 plays 2 Hearts
      state.currentTrick = [
        const TrickCard(playerId: 'p1', card: PlayingCard(suit: Suit.heart, rank: Rank.ten)),
        const TrickCard(playerId: 'p2', card: PlayingCard(suit: Suit.heart, rank: Rank.ace)),
        const TrickCard(playerId: 'p3', card: PlayingCard(suit: Suit.spade, rank: Rank.king)),
        const TrickCard(playerId: 'p4', card: PlayingCard(suit: Suit.heart, rank: Rank.two)),
      ];

      GameEngine.resolveTrick(state);
      expect(state.playerById('p2').actual, equals(1)); // Ace of led suit wins
    });
  });

  group('2. Preserved Void Suit Redeal Rule', () {
    test('Player with 0 cards in any suit is detected as having a void suit', () {
      final playerWithVoid = Player(
        id: 'p1',
        name: 'Player 1',
        seatIndex: 0,
        hand: [
          // 13 cards with no Diamonds
          const PlayingCard(suit: Suit.spade, rank: Rank.ace),
          const PlayingCard(suit: Suit.spade, rank: Rank.king),
          const PlayingCard(suit: Suit.spade, rank: Rank.queen),
          const PlayingCard(suit: Suit.spade, rank: Rank.jack),
          const PlayingCard(suit: Suit.heart, rank: Rank.ace),
          const PlayingCard(suit: Suit.heart, rank: Rank.king),
          const PlayingCard(suit: Suit.heart, rank: Rank.queen),
          const PlayingCard(suit: Suit.heart, rank: Rank.jack),
          const PlayingCard(suit: Suit.club, rank: Rank.ace),
          const PlayingCard(suit: Suit.club, rank: Rank.king),
          const PlayingCard(suit: Suit.club, rank: Rank.queen),
          const PlayingCard(suit: Suit.club, rank: Rank.jack),
          const PlayingCard(suit: Suit.club, rank: Rank.ten),
        ],
      );

      expect(GameEngine.hasVoidSuit(playerWithVoid), isTrue);
    });
  });

  group('3. Pre-Auction Dash Call Mechanics & Scoring', () {
    test('Calling Dash Call sets isDashCall=true, declared=0, and skips bidding', () {
      final state = GameState(
        players: createTestPlayers(),
        phase: GamePhase.dashCall,
        dealerSeatIndex: 3,
        currentPlayerSeatIndex: 0,
      );

      GameEngine.submitDashCall(state, 'p1', true);
      expect(state.playerById('p1').isDashCall, isTrue);
      expect(state.playerById('p1').declared, equals(0));
      expect(state.playerById('p1').hasPassed, isTrue);
    });

    test('4-player Dash Call sequential progression transitions to Auction phase', () {
      final state = GameState(
        players: createTestPlayers(),
        phase: GamePhase.dashCall,
        dealerSeatIndex: 0,
        currentPlayerSeatIndex: 1,
      );

      // P2 passes dash call
      GameEngine.submitDashCall(state, 'p2', false);
      expect(state.currentPlayerSeatIndex, equals(2));
      expect(state.phase, equals(GamePhase.dashCall));

      // P3 calls dash call
      GameEngine.submitDashCall(state, 'p3', true);
      expect(state.playerById('p3').isDashCall, isTrue);
      expect(state.currentPlayerSeatIndex, equals(3));
      expect(state.phase, equals(GamePhase.dashCall));

      // P4 passes dash call
      GameEngine.submitDashCall(state, 'p4', false);
      expect(state.currentPlayerSeatIndex, equals(0));
      expect(state.phase, equals(GamePhase.dashCall));

      // P1 (dealer/human) passes dash call
      GameEngine.submitDashCall(state, 'p1', false);

      // All 4 have answered -> Phase advances to Auction!
      expect(state.phase, equals(GamePhase.auction));
      expect(state.auctionTurnSeatIndex, equals(1)); // First bidder is seat after dealer
      expect(state.playerById('p3').hasPassed, isTrue); // P3 who dash called is skipped from auction
    });

    test('Dash Call win in Over yields +33, in Under yields +25', () {
      final state = GameState(
        players: createTestPlayers(),
        phase: GamePhase.scoring,
        roundNumber: 1,
      );

      final p1 = state.playerById('p1');
      p1.isDashCall = true;
      p1.declared = 0;
      p1.actual = 0; // Success

      // Other players declare enough to make Over (sum = 14)
      state.playerById('p2').declared = 5;
      state.playerById('p2').actual = 5;
      state.playerById('p3').declared = 5;
      state.playerById('p3').actual = 5;
      state.playerById('p4').declared = 4;
      state.playerById('p4').actual = 4;

      final deltasOver = GameEngine.computeAndApplyScores(state);
      expect(deltasOver['p1'], equals(33));

      // Reset for Under scenario (sum = 10)
      p1.totalScore = 0;
      state.playerById('p2').declared = 4;
      state.playerById('p2').actual = 4;
      state.playerById('p3').declared = 3;
      state.playerById('p3').actual = 3;
      state.playerById('p4').declared = 3;
      state.playerById('p4').actual = 3;

      final deltasUnder = GameEngine.computeAndApplyScores(state);
      expect(deltasUnder['p1'], equals(25));
    });
  });

  group('4. Declarations: Forbidden 13, Bidder Ceiling & Risk', () {
    test('4th player is forbidden from choosing sum=13', () {
      final state = GameState(
        players: createTestPlayers(),
        phase: GamePhase.declarations,
        bidderPlayerId: 'p1',
        currentPlayerSeatIndex: 3,
      );

      state.playerById('p1').declared = 5;
      state.playerById('p2').declared = 4;
      state.playerById('p3').declared = 2; // sum so far = 11

      final forbidden = GameEngine.getForbiddenDeclaration(state, 'p4');
      expect(forbidden, equals(2)); // 13 - 11 = 2 is forbidden

      // Trying to declare forbidden 2 fails
      final acceptedForbidden = GameEngine.submitDeclaration(state, 'p4', 2);
      expect(acceptedForbidden, isFalse);

      // Declaring 1 (sum = 12, Under) succeeds and activates Risk
      final acceptedLegal = GameEngine.submitDeclaration(state, 'p4', 0);
      expect(acceptedLegal, isTrue);
      expect(state.playerById('p4').isRisk, isTrue); // sum = 11 <= 11
    });

    test('Non-bidder cannot declare higher trick count than Bidder', () {
      final state = GameState(
        players: createTestPlayers(),
        phase: GamePhase.declarations,
        bidderPlayerId: 'p1',
        currentPlayerSeatIndex: 1,
      );

      state.playerById('p1').declared = 4;

      final maxAllowed = GameEngine.getMaxAllowedDeclaration(state, 'p2');
      expect(maxAllowed, equals(4));

      // Attempting to declare 5 fails
      final accepted = GameEngine.submitDeclaration(state, 'p2', 5);
      expect(accepted, isFalse);
    });
  });

  group('5. All-Pass Double Round Multiplier', () {
    test('When all 4 players pass auction, next round is doubled (Double x2)', () {
      final state = GameState(
        players: createTestPlayers(),
        phase: GamePhase.auction,
        dealerSeatIndex: 0,
        auctionTurnSeatIndex: 1,
      );

      GameEngine.passBid(state, 'p2');
      GameEngine.passBid(state, 'p3');
      GameEngine.passBid(state, 'p4');
      GameEngine.passBid(state, 'p1'); // All pass

      expect(state.isDoubleRound, isTrue);
      expect(state.roundNumber, equals(2));
    });
  });

  group('6. 18-Round Boula & Last 5 Fixed Rounds', () {
    test('Fixed trumps are enforced in rounds 14–18', () {
      expect(fixedTrumpForRound(14), equals(Trump.sans));
      expect(fixedTrumpForRound(15), equals(Trump.spade));
      expect(fixedTrumpForRound(16), equals(Trump.heart));
      expect(fixedTrumpForRound(17), equals(Trump.diamond));
      expect(fixedTrumpForRound(18), equals(Trump.club));
    });

    test('Overriding fixed trump requires 8 or more tricks', () {
      const fixed = Trump.spade;

      // Bid in different suit (Hearts) with 7 tricks -> invalid
      const bid7Hearts = Bid(trickCount: 7, trump: Trump.heart);
      expect(GameEngine.isValidBid(bid7Hearts, null, fixedTrump: fixed), isFalse);

      // Bid in different suit with 8 tricks -> valid override
      const bid8Hearts = Bid(trickCount: 8, trump: Trump.heart);
      expect(GameEngine.isValidBid(bid8Hearts, null, fixedTrump: fixed), isTrue);
    });
  });
}
