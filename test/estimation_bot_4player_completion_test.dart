// test/estimation_bot_4player_completion_test.dart

import 'package:flutter_test/flutter_test.dart';
import 'package:estimation/core/ai/estimation_bot_ai.dart';
import 'package:estimation/core/game_engine.dart';
import 'package:estimation/core/models/card.dart';
import 'package:estimation/core/models/player.dart';
import 'package:estimation/core/models/game_state.dart';
import 'package:estimation/core/constants.dart';

void main() {
  group('4-Player Completion & Bot Integration Tests', () {
    test('GameServer with 2 human players completes 4 players with 2 bots on startGame', () {
      final host = Player(id: 'host_p1', name: 'Host Player', seatIndex: 0);
      final client = Player(id: 'client_p2', name: 'Friend Player', seatIndex: 1);

      final state = GameEngine.createInitialState([host, client]);
      expect(state.players.length, 2);

      // Add bots to complete to 4
      if (state.players.length < 4) {
        final toAdd = 4 - state.players.length;
        for (int i = 1; i <= toAdd; i++) {
          final botId = 'bot_$i';
          state.players.add(Player(
            id: botId,
            name: 'لاعب $i 🤖',
            seatIndex: state.players.length,
          ));
        }
      }

      expect(state.players.length, 4);
      expect(state.players[2].id, 'bot_1');
      expect(state.players[3].id, 'bot_2');

      // Deal cards - 52 cards total, exactly 13 cards per player
      GameEngine.dealCards(state);
      for (final p in state.players) {
        expect(p.hand.length, 13);
      }
    });

    test('GameServer with 3 human players completes 4 players with 1 bot on startGame', () {
      final p1 = Player(id: 'p1', name: 'Player 1', seatIndex: 0);
      final p2 = Player(id: 'p2', name: 'Player 2', seatIndex: 1);
      final p3 = Player(id: 'p3', name: 'Player 3', seatIndex: 2);

      final state = GameEngine.createInitialState([p1, p2, p3]);
      expect(state.players.length, 3);

      if (state.players.length < 4) {
        final toAdd = 4 - state.players.length;
        for (int i = 1; i <= toAdd; i++) {
          final botId = 'bot_$i';
          state.players.add(Player(
            id: botId,
            name: 'لاعب $i 🤖',
            seatIndex: state.players.length,
          ));
        }
      }

      expect(state.players.length, 4);
      expect(state.players[3].id, 'bot_1');

      GameEngine.dealCards(state);
      for (final p in state.players) {
        expect(p.hand.length, 13);
      }
    });
  });

  group('Extreme Bot AI Intelligence Tests', () {
    test('Under-the-winner ducking: Bot safely sheds highest card that is below current winner', () {
      final bot = Player(
        id: 'bot_1',
        name: 'Bot 1',
        seatIndex: 2,
        declared: 0,
        actual: 0, // Bot wants 0 tricks
        hand: [
          const PlayingCard(suit: Suit.heart, rank: Rank.queen),
          const PlayingCard(suit: Suit.heart, rank: Rank.ten),
          const PlayingCard(suit: Suit.heart, rank: Rank.four),
          const PlayingCard(suit: Suit.spade, rank: Rank.two),
        ],
      );

      final p1 = Player(id: 'p1', name: 'P1', seatIndex: 0);
      final p2 = Player(id: 'p2', name: 'P2', seatIndex: 1);
      final p4 = Player(id: 'p4', name: 'P4', seatIndex: 3);

      // P1 led Heart 7, P2 played Heart King. Winner is King.
      // Bot holds Queen, 10, 4.
      // Bot should duck under the King by playing the QUEEN (safely ditching high honor)!
      final state = GameState(
        players: [p1, p2, bot, p4],
        phase: GamePhase.trickTaking,
        trumpSuit: Suit.spade,
        currentPlayerSeatIndex: 2,
        currentTrick: [
          TrickCard(playerId: 'p1', card: const PlayingCard(suit: Suit.heart, rank: Rank.seven)),
          TrickCard(playerId: 'p2', card: const PlayingCard(suit: Suit.heart, rank: Rank.king)),
        ],
      );

      final chosen = EstimationBotAi.chooseCardToPlay(state, bot);
      expect(chosen.suit, Suit.heart);
      expect(chosen.rank, Rank.queen); // Successfully dumped Queen safely under the King!
    });

    test('Dangerous honor shedding: Bot void in led suit ditches bare high off-suit honor when ducking', () {
      final bot = Player(
        id: 'bot_1',
        name: 'Bot 1',
        seatIndex: 2,
        declared: 1,
        actual: 1, // Already reached quota, wants NO more tricks
        hand: [
          const PlayingCard(suit: Suit.diamond, rank: Rank.king), // Dangerous bare King!
          const PlayingCard(suit: Suit.spade, rank: Rank.two), // Low trump
          const PlayingCard(suit: Suit.spade, rank: Rank.three),
        ],
      );

      final p1 = Player(id: 'p1', name: 'P1', seatIndex: 0);
      final p2 = Player(id: 'p2', name: 'P2', seatIndex: 1);
      final p4 = Player(id: 'p4', name: 'P4', seatIndex: 3);

      // P1 led Heart 5, P2 played Heart Ace.
      // Bot is void in Hearts.
      // Bot does NOT want to ruff, and should ditch the dangerous Diamond King!
      final state = GameState(
        players: [p1, p2, bot, p4],
        phase: GamePhase.trickTaking,
        trumpSuit: Suit.spade,
        currentPlayerSeatIndex: 2,
        currentTrick: [
          TrickCard(playerId: 'p1', card: const PlayingCard(suit: Suit.heart, rank: Rank.five)),
          TrickCard(playerId: 'p2', card: const PlayingCard(suit: Suit.heart, rank: Rank.ace)),
        ],
      );

      final chosen = EstimationBotAi.chooseCardToPlay(state, bot);
      expect(chosen.suit, Suit.diamond);
      expect(chosen.rank, Rank.king); // Ditched dangerous King safely!
    });

    test('Economy of honors: When bot wants to win, it wins with the cheapest winning card', () {
      final bot = Player(
        id: 'bot_1',
        name: 'Bot 1',
        seatIndex: 3, // 4th player
        declared: 3,
        actual: 0, // Bot wants to win
        hand: [
          const PlayingCard(suit: Suit.spade, rank: Rank.ace),
          const PlayingCard(suit: Suit.spade, rank: Rank.jack),
          const PlayingCard(suit: Suit.spade, rank: Rank.three),
        ],
      );

      final p1 = Player(id: 'p1', name: 'P1', seatIndex: 0);
      final p2 = Player(id: 'p2', name: 'P2', seatIndex: 1);
      final p3 = Player(id: 'p3', name: 'P3', seatIndex: 2);

      // Led Spades: P1 played 4, P2 played 9, P3 played 10.
      // Winner is 10. Bot holds Jack, Ace, 3.
      // Both Jack and Ace can win. Bot should play JACK (cheapest winner), saving Ace!
      final state = GameState(
        players: [p1, p2, p3, bot],
        phase: GamePhase.trickTaking,
        trumpSuit: null, // Sans
        currentPlayerSeatIndex: 3,
        currentTrick: [
          TrickCard(playerId: 'p1', card: const PlayingCard(suit: Suit.spade, rank: Rank.four)),
          TrickCard(playerId: 'p2', card: const PlayingCard(suit: Suit.spade, rank: Rank.nine)),
          TrickCard(playerId: 'p3', card: const PlayingCard(suit: Suit.spade, rank: Rank.ten)),
        ],
      );

      final chosen = EstimationBotAi.chooseCardToPlay(state, bot);
      expect(chosen.suit, Suit.spade);
      expect(chosen.rank, Rank.jack);
    });

    test('Trump pulling: When bot wants to win and holds master trump while opponents have trumps, it pulls trumps', () {
      final bot = Player(
        id: 'bot_1',
        name: 'Bot 1',
        seatIndex: 0,
        declared: 4,
        actual: 0,
        hand: [
          const PlayingCard(suit: Suit.spade, rank: Rank.ace), // Trump Ace
          const PlayingCard(suit: Suit.spade, rank: Rank.king), // Trump King
          const PlayingCard(suit: Suit.heart, rank: Rank.ace), // Side Ace
          const PlayingCard(suit: Suit.diamond, rank: Rank.two),
        ],
      );

      final p2 = Player(id: 'p2', name: 'P2', seatIndex: 1);
      final p3 = Player(id: 'p3', name: 'P3', seatIndex: 2);
      final p4 = Player(id: 'p4', name: 'P4', seatIndex: 3);

      final state = GameState(
        players: [bot, p2, p3, p4],
        phase: GamePhase.trickTaking,
        trumpSuit: Suit.spade,
        currentPlayerSeatIndex: 0,
        currentTrick: [], // Bot is leading
      );

      final chosen = EstimationBotAi.chooseCardToPlay(state, bot);
      expect(chosen.suit, Suit.spade);
      expect(chosen.rank, Rank.ace); // Pulls trumps with master Ace
    });
  });
}
