// lib/modes/ninety_nine/networking/ninety_nine_game_client.dart

import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:estimation/networking/messages.dart';
import '../domain/models/ninety_nine_game_state.dart';

class NinetyNineGameClient {
  final SupabaseClient _supabase = Supabase.instance.client;
  RealtimeChannel? _channel;

  void Function(NinetyNineGameState)? onStateUpdate;
  final void Function(String) onError;
  final void Function(Map<String, dynamic> reactionData)? onReaction;

  String _roomId = '';
  String _playerId = '';

  NinetyNineGameClient({
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

    // Same channel name convention as Kotchina: 'room_{roomId}'
    _channel = _supabase.channel('room_$_roomId');

    // ── Listen for state broadcasts from the server ──
    _channel!.onBroadcast(
      event: 'state',
      callback: (payload) {
        _handleStatePayload(payload);
      },
    );

    // ── Listen for reaction broadcasts ──
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

    // ── Listen for error broadcasts ──
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
          // Track presence so host can detect us
          await _channel!.track({
            'playerId': _playerId,
            'name': playerName,
          });

          // Send join request so host adds us to its state and broadcasts back
          _channel!.sendBroadcastMessage(
            event: 'joinRequest',
            payload: {
              'playerId': _playerId,
              'name': playerName,
              'avatarId': playerAvatarId,
            },
          );

          // Also request full state sync as a safety net
          sendAction(ActionType.requestStateSync);
          debugPrint('[99Client] Subscribed, sent joinRequest & requestStateSync');
        } else if (status == RealtimeSubscribeStatus.closed) {
          onError('انقطع الاتصال بالمضيف');
        } else if (status == RealtimeSubscribeStatus.channelError) {
          // Supabase Realtime auto-reconnects on channelError — do not treat as fatal
          debugPrint('[99Client] Channel error (will auto-retry): $error');
        }
      });
    } catch (e) {
      onError('فشل الاتصال بالغرفة: $e');
    }
  }

  void _handleStatePayload(Map<String, dynamic> rawPayload) {
    try {
      // The server sends raw _state.toJson() as the payload.
      // Handle both wrapped ({payload: {...}}) and unwrapped forms.
      final json = (rawPayload.containsKey('payload') &&
              rawPayload['payload'] is Map<String, dynamic>)
          ? rawPayload['payload'] as Map<String, dynamic>
          : rawPayload;

      if (!json.containsKey('players') || json['players'] == null) return;

      final state = NinetyNineGameState.fromJson(json);
      onStateUpdate?.call(state);
    } catch (e, st) {
      debugPrint('[99Client] State parse error: $e\n$st');
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
      // Inform the host we are leaving intentionally
      _channel!.sendBroadcastMessage(
        event: 'leaveRequest',
        payload: {'playerId': _playerId},
      );
      await _channel!.unsubscribe();
      _channel = null;
    }
  }
}
