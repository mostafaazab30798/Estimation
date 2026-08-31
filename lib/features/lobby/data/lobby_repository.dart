// lib/features/lobby/data/lobby_repository.dart

import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../domain/models/game_room.dart';
import '../domain/models/room_player.dart';
import '../../../core/models/card.dart';

class LobbyRepository {
  final SupabaseClient _client = Supabase.instance.client;

  Future<void> _ensureAuth() async {
    final session = _client.auth.currentSession;
    if (session != null) {
      final expiresAt = session.expiresAt;
      if (expiresAt != null) {
        final expirationDate =
            DateTime.fromMillisecondsSinceEpoch(expiresAt * 1000);
        if (DateTime.now()
            .isAfter(expirationDate.subtract(const Duration(seconds: 30)))) {
          debugPrint(
              '[LobbyRepo] Session expired. Signing out to refresh anonymously.');
          try {
            await _client.auth.signOut().timeout(const Duration(seconds: 2));
          } catch (_) {}
        }
      }
    }

    if (_client.auth.currentUser == null) {
      try {
        await _client.auth
            .signInAnonymously()
            .timeout(const Duration(seconds: 8));
      } catch (e) {
        debugPrint('[LobbyRepo] signInAnonymously failed: $e');
      }
    }
    if (_client.auth.currentUser == null) {
      throw Exception(
          'تعذّر تسجيل الدخول. يرجى التحقق من اتصالك بالإنترنت والمحاولة مجدداً.');
    }
  }

  Future<GameRoom> createRoom({
    required String playerName,
    required String roomCode,
    required String hostIp,
    required int wsPort,
    String gameType = 'kotchina',
    int expectedPlayers = 4,
  }) async {
    await _ensureAuth();
    final response = await _client.rpc('create_game_room', params: {
      'p_room_code': roomCode,
      'p_player_name': playerName,
      'p_host_ip': hostIp,
      'p_ws_port': wsPort,
      'p_game_type': gameType,
    });

    final roomId = response['room_id'] as String;

    if (expectedPlayers != 4) {
      await _client.rpc('set_private_room_max_players', params: {
        'p_room_id': roomId,
        'p_max_players': expectedPlayers,
      });
    }

    return getRoom(roomId);
  }

  Future<GameRoom> joinRoom({
    required String roomCode,
    required String playerName,
    String? expectedGameType,
  }) async {
    await _ensureAuth();
    final response = await _client.rpc('join_game_room', params: {
      'p_room_code': roomCode,
      'p_player_name': playerName,
    });

    final roomId = response['room_id'] as String;
    final room = await getRoom(roomId);

    if (expectedGameType != null && room.gameType != expectedGameType) {
      // User entered code for wrong game mode
      final targetModeLabel = switch (room.gameType) {
        'kotchina' => 'كوتشينة',
        'ninety_nine' => 'الـ99',
        'basra' => 'باصرة',
        _ => room.gameType,
      };
      throw Exception('هذا الكود مخصص لروم $targetModeLabel');
    }

    return room;
  }

  Future<GameRoom> getRoom(String roomId) async {
    final response =
        await _client.from('game_rooms').select().eq('id', roomId).single();
    return GameRoom.fromJson(response);
  }

  Stream<GameRoom> watchRoom(String roomId) {
    if (roomId.startsWith('test_') || roomId.startsWith('local_')) {
      return const Stream.empty();
    }
    return _client
        .from('game_rooms')
        .stream(primaryKey: ['id'])
        .eq('id', roomId)
        .map((events) => GameRoom.fromJson(events.first));
  }

  Stream<List<RoomPlayer>> watchRoomPlayers(String roomId) {
    if (roomId.startsWith('test_') || roomId.startsWith('local_')) {
      return Stream.value([]);
    }
    return _client
        .from('room_players')
        .stream(primaryKey: ['id'])
        .eq('room_id', roomId)
        .map((events) => events.map((e) => RoomPlayer.fromJson(e)).toList());
  }

  Future<void> startGame(String roomId) async {
    if (roomId.startsWith('test_') || roomId.startsWith('local_')) return;
    await _client.rpc('start_game_room', params: {
      'p_room_id': roomId,
    });
  }

  Future<void> leaveRoom(String roomId, [String? playerId]) async {
    if (roomId.startsWith('test_') || roomId.startsWith('local_')) return;
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
    if (roomId.startsWith('test_') || roomId.startsWith('local_')) return;
    await _client.rpc('cancel_private_room', params: {'p_room_id': roomId});
  }

  // ── Reconnection & heartbeat ──────────────────────────────────────────

  /// Mark the current user online and refresh last_seen.
  Future<void> pingHeartbeat(String roomId) async {
    if (roomId.startsWith('test_') || roomId.startsWith('local_')) return;
    try {
      await _client.rpc('player_heartbeat', params: {'p_room_id': roomId});
    } catch (e) {
      final errorStr = e.toString();
      if (!errorStr.contains('SocketException') &&
          !errorStr.contains('AuthRetryableFetchException')) {
        debugPrint('[Lobby] pingHeartbeat failed: $e');
      }
    }
  }

  /// Mark the current user offline (called on app pause / background).
  Future<void> markOffline(String roomId) async {
    try {
      await _client.rpc('player_go_offline', params: {'p_room_id': roomId});
    } catch (e) {
      final errorStr = e.toString();
      if (!errorStr.contains('SocketException') &&
          !errorStr.contains('AuthRetryableFetchException')) {
        debugPrint('[Lobby] markOffline failed: $e');
      }
    }
  }

  // ── State snapshot ────────────────────────────────────────────────────

  /// Fetch the latest persisted GameState JSONB snapshot for a room.
  /// Returns null if no snapshot has been saved yet.
  Future<Map<String, dynamic>?> getGameStateSnapshot(String roomId) async {
    try {
      final response = await _client
          .from('game_rooms')
          .select('game_state')
          .eq('id', roomId)
          .single();
      return response['game_state'] as Map<String, dynamic>?;
    } catch (e) {
      debugPrint('[Lobby] getGameStateSnapshot failed: $e');
      return null;
    }
  }

  /// Persist a full GameState snapshot (called by host on phase transitions).
  Future<void> saveGameStateSnapshot(
    String roomId,
    Map<String, dynamic> state,
  ) async {
    try {
      await _client.rpc('save_game_state', params: {
        'p_room_id': roomId,
        'p_state': state,
      });
    } catch (e) {
      debugPrint('[Lobby] saveGameStateSnapshot failed: $e');
    }
  }

  // ── Hand cards ────────────────────────────────────────────────────────

  /// Fetch the calling player's private hand via owner-only RPC.
  /// Returns an empty list if no hand has been persisted yet.
  Future<List<PlayingCard>> getMyHandCards(
    String roomId,
    String playerId,
  ) async {
    if (roomId.startsWith('test_') || roomId.startsWith('local_')) {
      return [];
    }
    try {
      final handJson = await _client.rpc(
        'get_my_hand_cards',
        params: {'p_room_id': roomId},
      );
      if (handJson == null) return [];
      return (handJson as List<dynamic>)
          .map((c) => PlayingCard.fromJson(c as Map<String, dynamic>))
          .toList();
    } catch (e) {
      debugPrint('[Lobby] getMyHandCards failed: $e');
      return [];
    }
  }

  /// Host-only: all private hands in a room (for host promotion / recovery).
  Future<Map<String, List<PlayingCard>>> getRoomPrivateHandsForHost(
    String roomId,
  ) async {
    if (roomId.startsWith('test_') || roomId.startsWith('local_')) {
      return {};
    }
    try {
      final raw = await _client.rpc(
        'get_room_private_hands_for_host',
        params: {'p_room_id': roomId},
      );
      if (raw is! Map) return {};
      final result = <String, List<PlayingCard>>{};
      raw.forEach((playerId, handJson) {
        if (handJson is List) {
          result[playerId.toString()] = handJson
              .map((c) => PlayingCard.fromJson(c as Map<String, dynamic>))
              .toList();
        }
      });
      return result;
    } catch (e) {
      debugPrint('[Lobby] getRoomPrivateHandsForHost failed: $e');
      return {};
    }
  }

  /// Persist a player's private hand (called by host after each deal).
  Future<void> savePlayerHand(
    String roomId,
    String playerId,
    List<PlayingCard> hand,
  ) async {
    try {
      await _client.rpc('save_player_hand', params: {
        'p_room_id': roomId,
        'p_player_id': playerId,
        'p_hand_cards': hand.map((c) => c.toJson()).toList(),
      });
    } catch (e) {
      debugPrint('[Lobby] savePlayerHand failed for $playerId: $e');
    }
  }

  // ── Host promotion ─────────────────────────────────────────────────

  /// Atomically try to elect a new host if the current one has been offline
  /// beyond the 60-second grace window defined in the DB function.
  ///
  /// Returns the new host's player_id as a UUID string, or null if no
  /// promotion was needed / possible.
  Future<String?> promoteNewHost(String roomId) async {
    try {
      final result = await _client.rpc(
        'promote_new_host',
        params: {'p_room_id': roomId},
      );
      return result as String?;
    } catch (e) {
      debugPrint('[Lobby] promoteNewHost failed: $e');
      return null;
    }
  }
}
