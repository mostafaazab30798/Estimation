// lib/modes/basra/networking/basra_game_client.dart

import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:estimation/networking/messages.dart';
import '../domain/models/basra_game_state.dart';

class BasraGameClient {
  final SupabaseClient _supabase = Supabase.instance.client;
  RealtimeChannel? _channel;

  void Function(BasraGameState)? onStateUpdate;
  final void Function(String) onError;
  final void Function(Map<String, dynamic> reactionData)? onReaction;

  String _roomId = '';
  String _playerId = '';

  BasraGameClient({
    this.onStateUpdate,
    required this.onError,
    this.onReaction,
  });

  Future<void> connect(
    String roomId,
    String playerId,
    String playerName,
    String playerAvatarId,
  ) async {
    _roomId = roomId;
    _playerId = playerId;

    _channel = _supabase.channel('room_$_roomId');

    _channel!.onBroadcast(
      event: 'state',
      callback: (payload) {
        _handleStatePayload(payload);
      },
    );

    _channel!.onBroadcast(
      event: 'reaction',
      callback: (payload) {
        final data = (payload.containsKey('payload') &&
                payload['payload'] is Map<String, dynamic>)
            ? payload['payload'] as Map<String, dynamic>
            : payload;
        onReaction?.call(data);
      },
    );

    _channel!.onBroadcast(
      event: 'error',
      callback: (payload) {
        final data = (payload.containsKey('payload') &&
                payload['payload'] is Map<String, dynamic>)
            ? payload['payload'] as Map<String, dynamic>
            : payload;
        onError(data['error'] as String? ?? 'حدث خطأ غير معروف');
      },
    );

    try {
      _channel!.subscribe((status, [error]) async {
        if (status == RealtimeSubscribeStatus.subscribed) {
          await _channel!.track({
            'playerId': _playerId,
            'name': playerName,
          });

          _channel!.sendBroadcastMessage(
            event: 'joinRequest',
            payload: {
              'playerId': _playerId,
              'name': playerName,
              'avatarId': playerAvatarId,
            },
          );

          sendAction(ActionType.requestStateSync);
          debugPrint('[BasraClient] Subscribed, sent joinRequest');
        } else if (status == RealtimeSubscribeStatus.closed) {
          onError('انقطع الاتصال بالمضيف');
        } else if (status == RealtimeSubscribeStatus.channelError) {
          debugPrint('[BasraClient] Channel error (will auto-retry): $error');
        }
      });
    } catch (e) {
      onError('فشل الاتصال بالغرفة: $e');
    }
  }

  void _handleStatePayload(Map<String, dynamic> rawPayload) {
    try {
      final json = (rawPayload.containsKey('payload') &&
              rawPayload['payload'] is Map<String, dynamic>)
          ? rawPayload['payload'] as Map<String, dynamic>
          : rawPayload;

      if (!json.containsKey('players') || json['players'] == null) return;

      final state = BasraGameState.fromJson(json);
      onStateUpdate?.call(state);
    } catch (e, st) {
      debugPrint('[BasraClient] State parse error: $e\n$st');
    }
  }

  void sendAction(String action, [Map<String, dynamic>? data]) {
    if (_channel == null) return;

    _channel!.sendBroadcastMessage(
      event: 'action',
      payload: {
        'action': action,
        'playerId': _playerId,
        if (data != null) ...data,
      },
    );
  }

  Future<void> disconnect() async {
    if (_channel != null) {
      _channel!.sendBroadcastMessage(
        event: 'leaveRequest',
        payload: {'playerId': _playerId},
      );
      await _channel!.unsubscribe();
      _channel = null;
    }
  }
}
