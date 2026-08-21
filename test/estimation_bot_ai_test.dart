// test/estimation_bot_ai_test.dart

import 'package:flutter_test/flutter_test.dart';
import 'package:estimation/core/ai/estimation_bot_ai.dart';
import 'package:estimation/core/models/card.dart';
import 'package:estimation/core/models/bid.dart';
import 'package:estimation/core/models/player.dart';
import 'package:estimation/core/models/game_state.dart';
import 'package:estimation/core/constants.dart';

void main() {
  group('EstimationBotAi Hand Evaluation & Dash Tests', () {
    test('Strong hand with high honors and trumps evaluates with high expected tricks', () {
      final hand = [
        const PlayingCard(suit: Suit.spade, rank: Rank.ace),
        const PlayingCard(suit: Suit.spade, rank: Rank.king),
        const PlayingCard(suit: Suit.spade, rank: Rank.queen),
        const PlayingCard(suit: Suit.spade, rank: Rank.ten),
        const PlayingCard(suit: Suit.spade, rank: Rank.eight),
        const PlayingCard(suit: Suit.heart, rank: Rank.ace),
        const PlayingCard(suit: Suit.heart, rank: Rank.king),
        const PlayingCard(suit: Suit.heart, rank: Rank.three),
        const PlayingCard(suit: Suit.diamond, rank: Rank.ace),
        const PlayingCard(suit: Suit.diamond, rank: Rank.seven),
        const PlayingCard(suit: Suit.club, rank: Rank.five),
        const PlayingCard(suit: Suit.club, rank: Rank.three),
        const PlayingCard(suit: Suit.club, rank: Rank.two),
      ];

      final eval = EstimationBotAi.evaluateHand(hand, Suit.spade);
      expect(eval.bestSuit, Suit.spade);
      expect(eval.expectedTricks, greaterThanOrEqualTo(6.0));
      expect(eval.isStrongDashCandidate, isFalse);
    });

    test('Weak hand with no Aces, Kings, or high trumps is identified as Dash candidate', () {
      final hand = [
        const PlayingCard(suit: Suit.spade, rank: Rank.two),
        const PlayingCard(suit: Suit.spade, rank: Rank.four),
        const PlayingCard(suit: Suit.heart, rank: Rank.three),
        const PlayingCard(suit: Suit.heart, rank: Rank.five),
        const PlayingCard(suit: Suit.heart, rank: Rank.seven),
        const PlayingCard(suit: Suit.diamond, rank: Rank.two),
        const PlayingCard(suit: Suit.diamond, rank: Rank.three),
        const PlayingCard(suit: Suit.diamond, rank: Rank.six),
        const PlayingCard(suit: Suit.club, rank: Rank.two),
        const PlayingCard(suit: Suit.club, rank: Rank.four),
        const PlayingCard(suit: Suit.club, rank: Rank.six),
        const PlayingCard(suit: Suit.club, rank: Rank.eight),
        const PlayingCard(suit: Suit.club, rank: Rank.nine),
      ];

      final eval = EstimationBotAi.evaluateHand(hand, Suit.spade);
      expect(eval.expectedTricks, lessThan(1.0));
      expect(eval.isStrongDashCandidate, isTrue);
    });
  });

  group('EstimationBotAi Auction Bidding Tests', () {
    test('Bot with strong hand makes opening bid in its strongest suit', () {
      final bot = Player(
        id: 'bot_1',
        name: 'Bot 1',
        seatIndex: 0,
        hand: [
          const PlayingCard(suit: Suit.spade, rank: Rank.ace),
          const PlayingCard(suit: Suit.spade, rank: Rank.king),
          const PlayingCard(suit: Suit.spade, rank: Rank.queen),
          const PlayingCard(suit: Suit.spade, rank: Rank.jack),
          const PlayingCard(suit: Suit.spade, rank: Rank.ten),
          const PlayingCard(suit: Suit.heart, rank: Rank.ace),
          const PlayingCard(suit: Suit.heart, rank: Rank.king),
          const PlayingCard(suit: Suit.diamond, rank: Rank.two),
          const PlayingCard(suit: Suit.diamond, rank: Rank.four),
          const PlayingCard(suit: Suit.diamond, rank: Rank.five),
          const PlayingCard(suit: Suit.club, rank: Rank.three),
          const PlayingCard(suit: Suit.club, rank: Rank.six),
          const PlayingCard(suit: Suit.club, rank: Rank.eight),
        ],
      );

      final state = GameState(
        players: [bot],
        phase: GamePhase.auction,
        currentHighBid: null,
      );

      final bid = EstimationBotAi.decideAuctionBid(state, bot);
      expect(bid, isNotNull);
      expect(bid!.trump, Trump.spade);
      expect(bid.trickCount, greaterThanOrEqualTo(4));
    });

    test('Bot passes when hand is weak', () {
      final bot = Player(
        id: 'bot_1',
        name: 'Bot 1',
        seatIndex: 0,
        hand: [
          const PlayingCard(suit: Suit.spade, rank: Rank.two),
          const PlayingCard(suit: Suit.spade, rank: Rank.three),
          const PlayingCard(suit: Suit.heart, rank: Rank.four),
          const PlayingCard(suit: Suit.heart, rank: Rank.five),
          const PlayingCard(suit: Suit.diamond, rank: Rank.six),
          const PlayingCard(suit: Suit.diamond, rank: Rank.seven),
          const PlayingCard(suit: Suit.club, rank: Rank.eight),
          const PlayingCard(suit: Suit.club, rank: Rank.nine),
          const PlayingCard(suit: Suit.club, rank: Rank.two),
          const PlayingCard(suit: Suit.club, rank: Rank.three),
          const PlayingCard(suit: Suit.club, rank: Rank.four),
          const PlayingCard(suit: Suit.club, rank: Rank.five),
          const PlayingCard(suit: Suit.club, rank: Rank.six),
        ],
      );

      final state = GameState(
        players: [bot],
        phase: GamePhase.auction,
        currentHighBid: const Bid(trickCount: 4, trump: Trump.club),
      );

      final bid = EstimationBotAi.decideAuctionBid(state, bot);
      expect(bid, isNull); // Must pass
    });
  });

  group('EstimationBotAi Declarations Tests', () {
    test('Bidder declares at least the winning bid amount', () {
      final bot = Player(
        id: 'bot_1',
        name: 'Bot 1',
        seatIndex: 0,
        hand: [
          const PlayingCard(suit: Suit.spade, rank: Rank.ace),
          const PlayingCard(suit: Suit.spade, rank: Rank.king),
          const PlayingCard(suit: Suit.spade, rank: Rank.queen),
          const PlayingCard(suit: Suit.spade, rank: Rank.jack),
          const PlayingCard(suit: Suit.spade, rank: Rank.nine),
          const PlayingCard(suit: Suit.heart, rank: Rank.ace),
          const PlayingCard(suit: Suit.heart, rank: Rank.two),
          const PlayingCard(suit: Suit.diamond, rank: Rank.three),
          const PlayingCard(suit: Suit.diamond, rank: Rank.four),
          const PlayingCard(suit: Suit.diamond, rank: Rank.five),
          const PlayingCard(suit: Suit.club, rank: Rank.six),
          const PlayingCard(suit: Suit.club, rank: Rank.seven),
          const PlayingCard(suit: Suit.club, rank: Rank.eight),
        ],
      );

      final state = GameState(
        players: [bot],
        phase: GamePhase.declarations,
        bidderPlayerId: bot.id,
        trump: Trump.spade,
        currentHighBid: const Bid(trickCount: 5, trump: Trump.spade),
      );

      final decl = EstimationBotAi.decideDeclaration(state, bot);
      expect(decl, greaterThanOrEqualTo(5));
    });

    test('4th player respects forbidden 13 sum rule', () {
      final p1 = Player(id: 'p1', name: 'P1', seatIndex: 0, declared: 4);
      final p2 = Player(id: 'p2', name: 'P2', seatIndex: 1, declared: 3);
      final p3 = Player(id: 'p3', name: 'P3', seatIndex: 2, declared: 3);
      // sum so far = 10, forbidden for p4 is 3!
      final bot = Player(
        id: 'bot_4',
        name: 'Bot 4',
        seatIndex: 3,
        hand: [
          const PlayingCard(suit: Suit.spade, rank: Rank.ace),
          const PlayingCard(suit: Suit.heart, rank: Rank.ace),
          const PlayingCard(suit: Suit.diamond, rank: Rank.ace),
          const PlayingCard(suit: Suit.spade, rank: Rank.two),
          const PlayingCard(suit: Suit.spade, rank: Rank.three),
          const PlayingCard(suit: Suit.heart, rank: Rank.four),
          const PlayingCard(suit: Suit.heart, rank: Rank.five),
          const PlayingCard(suit: Suit.diamond, rank: Rank.six),
          const PlayingCard(suit: Suit.diamond, rank: Rank.seven),
          const PlayingCard(suit: Suit.club, rank: Rank.two),
          const PlayingCard(suit: Suit.club, rank: Rank.three),
          const PlayingCard(suit: Suit.club, rank: Rank.four),
          const PlayingCard(suit: Suit.club, rank: Rank.five),
        ],
      );

      final state = GameState(
        players: [p1, p2, p3, bot],
        phase: GamePhase.declarations,
        trumpSuit: Suit.spade,
      );

      final decl = EstimationBotAi.decideDeclaration(state, bot);
      expect(decl, isNot(equals(3))); // 3 is forbidden!
    });
  });

  group('EstimationBotAi Trick Play Tests', () {
    test('When bot wants to win, it plays lowest winning card if 4th player', () {
      final bot = Player(
        id: 'bot_1',
        name: 'Bot 1',
        seatIndex: 3,
        declared: 3,
        actual: 0, // needs tricks!
        hand: [
          const PlayingCard(suit: Suit.heart, rank: Rank.ten),
          const PlayingCard(suit: Suit.heart, rank: Rank.ace),
        ],
      );

      final state = GameState(
        players: [
          Player(id: 'p0', name: 'P0', seatIndex: 0),
          Player(id: 'p1', name: 'P1', seatIndex: 1),
          Player(id: 'p2', name: 'P2', seatIndex: 2),
          bot,
        ],
        phase: GamePhase.trickTaking,
        trumpSuit: Suit.spade,
        currentPlayerSeatIndex: 3,
        currentTrick: [
          const TrickCard(playerId: 'p0', card: PlayingCard(suit: Suit.heart, rank: Rank.eight)),
          const TrickCard(playerId: 'p1', card: PlayingCard(suit: Suit.heart, rank: Rank.four)),
          const TrickCard(playerId: 'p2', card: PlayingCard(suit: Suit.heart, rank: Rank.nine)),
        ],
      );

      final chosen = EstimationBotAi.chooseCardToPlay(state, bot);
      // Winner is 9 of hearts; bot has 10 and Ace; bot should play 10 to win efficiently!
      expect(chosen, const PlayingCard(suit: Suit.heart, rank: Rank.ten));
    });

    test('When bot reached its declaration, it avoids winning by playing lower card', () {
      final bot = Player(
        id: 'bot_1',
        name: 'Bot 1',
        seatIndex: 3,
        declared: 2,
        actual: 2, // Already reached target! Must duck!
        hand: [
          const PlayingCard(suit: Suit.heart, rank: Rank.six),
          const PlayingCard(suit: Suit.heart, rank: Rank.ace),
        ],
      );

      final state = GameState(
        players: [
          Player(id: 'p0', name: 'P0', seatIndex: 0),
          Player(id: 'p1', name: 'P1', seatIndex: 1),
          Player(id: 'p2', name: 'P2', seatIndex: 2),
          bot,
        ],
        phase: GamePhase.trickTaking,
        trumpSuit: Suit.spade,
        currentPlayerSeatIndex: 3,
        currentTrick: [
          const TrickCard(playerId: 'p0', card: PlayingCard(suit: Suit.heart, rank: Rank.ten)),
        ],
      );

      final chosen = EstimationBotAi.chooseCardToPlay(state, bot);
      // Trick is led with 10 of hearts; bot wants to duck; bot plays 6 of hearts!
      expect(chosen, const PlayingCard(suit: Suit.heart, rank: Rank.six));
    });

    test('When bot wants to duck and is void in led suit, it discards high non-trump honors', () {
      final bot = Player(
        id: 'bot_1',
        name: 'Bot 1',
        seatIndex: 1,
        declared: 0, // Dash!
        actual: 0,
        hand: [
          const PlayingCard(suit: Suit.diamond, rank: Rank.ace), // dangerous off-suit Ace!
          const PlayingCard(suit: Suit.club, rank: Rank.two),
          const PlayingCard(suit: Suit.spade, rank: Rank.two), // trump 2
        ],
      );

      final state = GameState(
        players: [
          Player(id: 'p0', name: 'P0', seatIndex: 0),
          bot,
        ],
        phase: GamePhase.trickTaking,
        trumpSuit: Suit.spade,
        currentPlayerSeatIndex: 1,
        currentTrick: [
          const TrickCard(playerId: 'p0', card: PlayingCard(suit: Suit.heart, rank: Rank.five)),
        ],
      );

      final chosen = EstimationBotAi.chooseCardToPlay(state, bot);
      // Bot is void in hearts; wants to duck; it should NOT trump, but sluff high Ace of diamonds!
      expect(chosen, const PlayingCard(suit: Suit.diamond, rank: Rank.ace));
    });

    test('When bot needs tricks and is void in led suit, it trumps to win', () {
      final bot = Player(
        id: 'bot_1',
        name: 'Bot 1',
        seatIndex: 1,
        declared: 3,
        actual: 0, // needs tricks!
        hand: [
          const PlayingCard(suit: Suit.diamond, rank: Rank.two),
          const PlayingCard(suit: Suit.spade, rank: Rank.four), // trump 4
          const PlayingCard(suit: Suit.spade, rank: Rank.king), // trump K
        ],
      );

      final state = GameState(
        players: [
          Player(id: 'p0', name: 'P0', seatIndex: 0),
          bot,
        ],
        phase: GamePhase.trickTaking,
        trumpSuit: Suit.spade,
        currentPlayerSeatIndex: 1,
        currentTrick: [
          const TrickCard(playerId: 'p0', card: PlayingCard(suit: Suit.heart, rank: Rank.ace)),
        ],
      );

      final chosen = EstimationBotAi.chooseCardToPlay(state, bot);
      // Led suit is hearts (bot is void); trick led by Ace; bot trumps with lowest trump (4 of spades)!
      expect(chosen, const PlayingCard(suit: Suit.spade, rank: Rank.four));
    });
  });
}
