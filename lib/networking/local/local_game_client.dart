// lib/networking/local/local_game_client.dart

import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:web_socket_channel/web_socket_channel.dart';

import '../../core/models/game_state.dart';
import '../../services/profile_service.dart';
import '../messages.dart';

typedef StateUpdateCallback = void Function(GameState state);
typedef ErrorCallback = void Function(String error);

class LocalGameClient {
  WebSocketChannel? _channel;
  StreamSubscription? _sub;

  final StateUpdateCallback onStateUpdate;
  final ErrorCallback onError;
  final void Function(Map<String, dynamic> reactionData)? onReaction;
  final void Function(Map<String, dynamic> earthquakeData)? onEarthquake;

  String? _lastHostIp;
  int? _lastPort;
  String? _lastPlayerId;
  String? _lastPlayerName;
  String? _lastPlayerPhoto;

  bool _isReconnecting = false;
  int _reconnectAttempts = 0;
  static const int _maxReconnectAttempts = 3;

  LocalGameClient({required this.onStateUpdate, required this.onError, this.onReaction, this.onEarthquake});

  Future<void> connect(
    String hostIp,
    int port,
    String playerId,
    String playerName,
    String playerPhoto,
  ) async {
    _lastHostIp = hostIp;
    _lastPort = port;
    _lastPlayerId = playerId;
    _lastPlayerName = playerName;
    _lastPlayerPhoto = playerPhoto;
    _reconnectAttempts = 0;

    await _initSocket();
  }

  Future<void> _initSocket() async {
    final uri = Uri.parse('ws://$_lastHostIp:$_lastPort');
    try {
      _channel = WebSocketChannel.connect(uri);
      await _channel!.ready;

      _sub = _channel!.stream.listen(
        (data) {
          _handleMessage(data);
        },
        onDone: () {
          _handleSocketDisconnect();
        },
        onError: (err) {
          _handleSocketDisconnect();
        },
      );

      // Send join request immediately after open
      _sendJoinRequest();
      _isReconnecting = false;
      _reconnectAttempts = 0;
    } catch (e) {
      if (_isReconnecting) {
        _attemptReconnect();
      } else {
        onError('فشل الاتصال بالخادم المحلي: $e');
      }
    }
  }

  void _sendJoinRequest() {
    if (_channel == null || _lastPlayerId == null) return;
    final msg = GameMessage(
      type: MessageType.joinRequest,
      payload: {
        'playerId': _lastPlayerId,
        'name': _lastPlayerName,
        'photo': ProfileService.publicAvatarRef(_lastPlayerPhoto),
      },
    );
    _channel!.sink.add(msg.toJsonString());
  }

  void _handleMessage(dynamic data) {
    if (data is! String) return;
    try {
      final msg = GameMessage.fromJsonString(data);
      switch (msg.type) {
        case MessageType.stateUpdate:
          final state = GameState.fromJson(msg.payload);
          onStateUpdate(state);

        case MessageType.error:
          final err = msg.payload['error'] as String? ?? 'خطأ في اللعبة';
          onError(err);

        case MessageType.reaction:
          final data = msg.payload;
          onReaction?.call(data);

        case MessageType.earthquake:
          final data = msg.payload;
          onEarthquake?.call(data);

        case MessageType.heartbeat:
          break;

        default:
          break;
      }
    } catch (e, st) {
      debugPrint('[LocalGameClient] Frame parse error: $e\n$st');
    }
  }

  void _handleSocketDisconnect() {
    _sub?.cancel();
    _sub = null;
    _channel = null;

    if (_lastHostIp != null && _reconnectAttempts < _maxReconnectAttempts) {
      _isReconnecting = true;
      _attemptReconnect();
    } else {
      onError('انقطع الاتصال بالخادم المحلي');
    }
  }

  Future<void> _attemptReconnect() async {
    _reconnectAttempts++;
    debugPrint('[LocalGameClient] Reconnecting attempt $_reconnectAttempts/$_maxReconnectAttempts…');
    await Future.delayed(Duration(milliseconds: 1500 * _reconnectAttempts));
    if (_lastHostIp != null) {
      await _initSocket();
    }
  }

  void sendAction(String action, String playerId, [Map<String, dynamic> extra = const {}]) {
    if (_channel == null) return;
    final msg = GameMessage(
      type: MessageType.playerAction,
      payload: {
        'action': action,
        'playerId': playerId,
        ...extra,
      },
    );
    try {
      _channel!.sink.add(msg.toJsonString());
    } catch (e) {
      debugPrint('[LocalGameClient] Error sending action frame: $e');
    }
  }

  void disconnect(String playerId) {
    if (_channel != null) {
      try {
        final msg = GameMessage(
          type: MessageType.playerAction,
          payload: {
            'action': 'leaveRequest',
            'playerId': playerId,
          },
        );
        _channel!.sink.add(msg.toJsonString());
      } catch (_) {}
      _sub?.cancel();
      _sub = null;
      _channel!.sink.close();
      _channel = null;
    }
    _lastHostIp = null;
  }
}
