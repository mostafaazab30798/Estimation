import 'package:flutter_test/flutter_test.dart';
import 'package:estimation/features/lobby/domain/models/game_room.dart';
import 'package:estimation/features/lobby/domain/models/online_play_status.dart';
import 'package:estimation/features/lobby/domain/models/room_player.dart';
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

    test('playing matchmaking rooms are not treated as waiting', () {
      final room = GameRoom.fromJson({
        ...baseJson(),
        'room_kind': 'matchmaking',
        'matchmaking_state': 'starting',
        'status': 'playing',
      });
      expect(room.isMatchmaking, isTrue);
      expect(room.isMatchmakingWaiting, isFalse);
    });

    test('waiting matchmaking rooms expose isMatchmakingWaiting', () {
      final room = GameRoom.fromJson({
        ...baseJson(),
        'room_kind': 'matchmaking',
        'matchmaking_state': 'waiting',
      });
      expect(room.isMatchmakingWaiting, isTrue);
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

  group('RoomPlayer membership', () {
    test('same roster is unchanged even when row metadata would differ', () {
      final first = [_player('a'), _player('b')];
      final replay = [_player('b'), _player('a')];
      expect(RoomPlayer.sameMembership(first, replay), isTrue);
    });

    test('joining or leaving a seat is a membership change', () {
      expect(
        RoomPlayer.sameMembership([_player('a')], [_player('a'), _player('b')]),
        isFalse,
      );
      expect(
        RoomPlayer.sameMembership([_player('a'), _player('b')], [_player('a')]),
        isFalse,
      );
    });

    test('stable seat order keeps host first and breaks timestamp ties by id', () {
      final joined = DateTime.utc(2026, 8, 28);
      final guestB = _player('b', joinedAt: joined);
      final guestA = _player('a', joinedAt: joined);
      final host = _player('host', joinedAt: joined, isHost: true);

      final first = RoomPlayer.stableSeatOrder([guestB, host, guestA]);
      final replay = RoomPlayer.stableSeatOrder([guestA, guestB, host]);

      expect(first.map((p) => p.playerId), ['host', 'a', 'b']);
      expect(replay.map((p) => p.playerId), ['host', 'a', 'b']);
      expect(RoomPlayer.sameSeatPresentation(first, replay), isTrue);
    });
  });

  group('device-scoped online gate', () {
    test('active seat on another phone has no timer or recovery action', () {
      final status = OnlinePlayStatus.fromJson({
        'can_join_new_online': false,
        'has_active_membership': true,
        'active_on_another_device': true,
        'recovery_available': false,
        'room_id': 'room-id',
        'room_status': 'playing',
      });

      expect(status.activeOnAnotherDevice, isTrue);
      expect(status.canReturnToOngoingGame, isFalse);
      expect(status.remainingBlock(), Duration.zero);
      expect(status.isStaleBlock, isFalse);
    });

    test('offline seat exposes the shared recovery countdown', () {
      final status = OnlinePlayStatus.fromJson({
        'can_join_new_online': false,
        'has_active_membership': true,
        'active_on_another_device': false,
        'recovery_available': true,
        'grace_ends_at':
            DateTime.now().toUtc().add(const Duration(minutes: 4)).toIso8601String(),
        'room_id': 'room-id',
        'room_status': 'playing',
      });

      expect(status.canReturnToOngoingGame, isTrue);
      expect(status.remainingBlock().inMinutes, greaterThanOrEqualTo(3));
    });
  });
}

RoomPlayer _player(
  String playerId, {
  DateTime? joinedAt,
  bool isHost = false,
}) =>
    RoomPlayer(
      id: 'row-$playerId',
      roomId: 'room-id',
      playerId: playerId,
      playerName: playerId,
      isHost: isHost,
      joinedAt: joinedAt ?? DateTime.utc(2026, 8, 28),
      lastSeen: joinedAt ?? DateTime.utc(2026, 8, 28),
    );
