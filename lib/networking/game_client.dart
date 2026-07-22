// lib/networking/game_client.dart
//
// Client-side: Connects to the host's room via Supabase Realtime Broadcast.

import 'dart:async';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../core/models/game_state.dart';

typedef StateUpdateCallback = void Function(GameState state);
typedef ErrorCallback = void Function(String error);

class GameClient {
  RealtimeChannel? _channel;

  final StateUpdateCallback onStateUpdate;
  final ErrorCallback onError;

  GameClient({required this.onStateUpdate, required this.onError});

  // ── Connection ────────────────────────────────────────────────

  Future<void> connect(String roomId, String playerId, String playerName) async {
    _channel = Supabase.instance.client.channel('room_$roomId');

    _channel!.onBroadcast(
      event: 'state',
      callback: (payload) {
        _handleStateUpdate(payload);
      },
    );

    _channel!.onBroadcast(
      event: 'error',
      callback: (payload) {
        if (payload['error'] != null) {
          onError(payload['error'] as String);
        }
      },
    );

    try {
      _channel!.subscribe((status, [error]) async {
        if (status == RealtimeSubscribeStatus.subscribed) {
          // Track presence
          await _channel!.track({
            'playerId': playerId,
            'name': playerName,
          });

          // Send join request via broadcast ONLY after successfully connecting
          _channel!.sendBroadcastMessage(
            event: 'joinRequest',
            payload: {
              'playerId': playerId,
              'name': playerName,
            },
          );
        } else if (status == RealtimeSubscribeStatus.closed) {
          onError('انقطع الاتصال بالمضيف');
        } else if (status == RealtimeSubscribeStatus.channelError) {
          // Supabase Realtime auto-reconnects on channelError.
          // By not calling onError, the user stays on the game screen and 
          // transparently recovers the session once the connection is restored.
        }
      });
    } catch (e) {
      onError('فشل الاتصال بالغرفة: $e');
    }
  }

  void disconnect(String playerId) {
    if (_channel != null) {
      _channel!.sendBroadcastMessage(
        event: 'leaveRequest',
        payload: {'playerId': playerId},
      );
      _channel!.unsubscribe();
      _channel = null;
    }
  }

  // ── Incoming messages ─────────────────────────────────────────

  void _handleStateUpdate(Map<String, dynamic> payload) {
    try {
      final state = GameState.fromJson(payload);
      onStateUpdate(state);
    } catch (e) {
      onError('خطأ في مزامنة حالة اللعبة: $e');
    }
  }

  // ── Send actions ──────────────────────────────────────────────

  void sendAction(String action, String playerId, [Map<String, dynamic> extra = const {}]) {
    if (_channel == null) return;
    
    _channel!.sendBroadcastMessage(
      event: 'action',
      payload: {
        'action': action,
        'playerId': playerId,
        ...extra,
      },
    );
  }
}
