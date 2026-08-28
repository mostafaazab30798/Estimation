import 'package:flutter_test/flutter_test.dart';
import 'package:estimation/features/lobby/domain/models/game_room.dart';
import 'package:estimation/features/matchmaking/domain/models/bot_fill_vote_result.dart';
import 'package:estimation/features/matchmaking/domain/models/matchmaking_join_result.dart';

void main() {
  group('GameRoom matchmaking metadata', () {
    Map<String, dynamic> baseJson() => {
          'id': 'room-id',
          'room_code': 'ABC123',
          'host_id': 'host-id',
          'status': 'waiting',
          'max_players': 4,
          'host_ip': '127.0.0.1',
          'ws_port': 0,
          'created_at': '2026-08-28T00:00:00Z',
        };

    test('legacy rooms remain private with safe defaults', () {
      final room = GameRoom.fromJson(baseJson());
      expect(room.isPrivateRoom, isTrue);
      expect(room.isMatchmaking, isFalse);
      expect(room.matchmakingState, 'none');
      expect(room.botsToFill, 0);
      expect(room.botOfferVersion, 0);
    });

    test('matchmaking state and vote aggregate are typed', () {
      final room = GameRoom.fromJson({
        ...baseJson(),
        'room_kind': 'matchmaking',
        'matchmaking_state': 'voting',
        'total_rounds': 18,
        'bots_to_fill': 0,
        'bot_offer_version': 7,
        'bot_yes_votes': 2,
        'bot_offer_after': '2026-08-28T00:00:08Z',
      });
      expect(room.isMatchmaking, isTrue);
      expect(room.isBotVoteOpen, isTrue);
      expect(room.totalRounds, 18);
      expect(room.botOfferVersion, 7);
      expect(room.botYesVotes, 2);
    });
  });

  test('join and vote RPC results parse numeric values safely', () {
    final join = MatchmakingJoinResult.fromJson({
      'room_id': 'room-id',
      'room_code': 'ABC123',
      'host_id': 'host-id',
      'is_host': false,
      'player_count': 3,
      'matchmaking_state': 'waiting',
      'bots_to_fill': 0,
      'bot_offer_version': 4,
    });
    final vote = BotFillVoteResult.fromJson({
      'result': 'starting',
      'should_start': true,
      'waiting_for_votes': false,
      'yes_votes': 3,
      'human_count': 3,
      'bots_to_fill': 1,
    });
    expect(join.playerCount, 3);
    expect(vote.shouldStart, isTrue);
    expect(vote.humanCount + vote.botsToFill, 4);
  });
}
