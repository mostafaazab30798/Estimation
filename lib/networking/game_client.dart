// lib/networking/game_client.dart
//
// Client-side: Connects to the host's room via Supabase Realtime Broadcast.

import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../core/models/game_state.dart';
import 'messages.dart';

typedef StateUpdateCallback = void Function(GameState state);
typedef ErrorCallback = void Function(String error);

class GameClient {
  RealtimeChannel? _channel;

  final StateUpdateCallback onStateUpdate;
  final ErrorCallback onError;
  final void Function(Map<String, dynamic> reactionData)? onReaction;

  GameClient({required this.onStateUpdate, required this.onError, this.onReaction});

  // ── Connection ────────────────────────────────────────────────

  Future<void> connect(String roomId, String playerId, String playerName, String playerPhoto) async {
    _channel = Supabase.instance.client.channel('room_$roomId');

    _channel!.onBroadcast(
      event: 'state',
      callback: (payload) {
        _handleStateUpdate(payload);
      },
    );

    _channel!.onBroadcast(
      event: 'reaction',
      callback: (payload) {
        final data = (payload.containsKey('payload') && payload['payload'] is Map<String, dynamic>)
            ? payload['payload'] as Map<String, dynamic>
            : payload;
        onReaction?.call(data);
      },
    );

    _channel!.onBroadcast(
      event: 'error',
      callback: (payload) {
        final data = (payload.containsKey('payload') && payload['payload'] is Map<String, dynamic>)
            ? payload['payload'] as Map<String, dynamic>
            : payload;
        if (data['error'] != null) {
          onError(data['error'] as String);
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
              'photo': playerPhoto,
            },
          );

          // Request live state sync immediately from host
          sendAction(ActionType.requestStateSync, playerId);
        } else if (status == RealtimeSubscribeStatus.closed) {
          // Supabase Realtime will attempt to auto-reconnect.
          // Do NOT call onError here — that would terminate the game session.
          // The GameProvider's _isGameInProgress guard is an additional safety net,
          // but avoiding the error event entirely is cleaner.
          debugPrint('[GameClient] Channel closed — waiting for Supabase auto-reconnect');
        } else if (status == RealtimeSubscribeStatus.channelError) {
          // Supabase Realtime auto-reconnects on channelError.
          debugPrint('[GameClient] Channel error — Supabase will auto-reconnect');
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

  void _handleStateUpdate(Map<String, dynamic> rawPayload) {
    try {
      final json = (rawPayload.containsKey('payload') && rawPayload['payload'] is Map<String, dynamic>)
          ? rawPayload['payload'] as Map<String, dynamic>
          : rawPayload;

      if (!json.containsKey('players') || json['players'] == null) {
        return;
      }

      final state = GameState.fromJson(json);
      onStateUpdate(state);
    } catch (e, st) {
      debugPrint('[GameClient] Parsing state error: $e\n$st');
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
