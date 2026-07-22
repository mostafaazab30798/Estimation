// lib/features/lobby/data/lobby_repository.dart

import 'package:supabase_flutter/supabase_flutter.dart';
import '../domain/models/game_room.dart';
import '../domain/models/room_player.dart';

class LobbyRepository {
  final SupabaseClient _client = Supabase.instance.client;

  Future<GameRoom> createRoom({
    required String playerName,
    required String roomCode,
    required String hostIp,
    required int wsPort,
  }) async {
    final response = await _client.rpc('create_game_room', params: {
      'p_room_code': roomCode,
      'p_player_name': playerName,
      'p_host_ip': hostIp,
      'p_ws_port': wsPort,
    });

    final roomId = response['room_id'] as String;
    return getRoom(roomId);
  }

  Future<GameRoom> joinRoom({
    required String roomCode,
    required String playerName,
  }) async {
    final response = await _client.rpc('join_game_room', params: {
      'p_room_code': roomCode,
      'p_player_name': playerName,
    });

    final roomId = response['room_id'] as String;
    return getRoom(roomId);
  }

  Future<GameRoom> getRoom(String roomId) async {
    final response = await _client
        .from('game_rooms')
        .select()
        .eq('id', roomId)
        .single();
    return GameRoom.fromJson(response);
  }

  Stream<GameRoom> watchRoom(String roomId) {
    return _client
        .from('game_rooms')
        .stream(primaryKey: ['id'])
        .eq('id', roomId)
        .map((events) => GameRoom.fromJson(events.first));
  }

  Stream<List<RoomPlayer>> watchRoomPlayers(String roomId) {
    return _client
        .from('room_players')
        .stream(primaryKey: ['id'])
        .eq('room_id', roomId)
        .map((events) => events.map((e) => RoomPlayer.fromJson(e)).toList());
  }

  Future<void> startGame(String roomId) async {
    await _client.rpc('start_game_room', params: {
      'p_room_id': roomId,
    });
  }

  Future<void> leaveRoom(String roomId, [String? playerId]) async {
    final uid = playerId ?? _client.auth.currentUser?.id;
    if (uid != null) {
      await _client
          .from('room_players')
          .delete()
          .eq('room_id', roomId)
          .eq('player_id', uid);
    }
  }

  Future<void> cancelRoom(String roomId) async {
    await _client
        .from('game_rooms')
        .update({'status': 'cancelled'})
        .eq('id', roomId);
  }
}
