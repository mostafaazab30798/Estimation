// lib/modes/ninety_nine/networking/local_ninety_nine_game_client.dart

import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:web_socket_channel/web_socket_channel.dart';

import 'package:estimation/networking/messages.dart';
import '../domain/models/ninety_nine_game_state.dart';

class LocalNinetyNineGameClient {
  WebSocketChannel? _channel;
  StreamSubscription? _sub;

  void Function(NinetyNineGameState)? onStateUpdate;
  final void Function(String) onError;

  String? _lastHostIp;
  int? _lastPort;
  String _playerId = '';
  String _playerName = '';
  String _playerAvatarId = '';

  bool _isReconnecting = false;
  int _reconnectAttempts = 0;
  static const int _maxReconnectAttempts = 3;

  LocalNinetyNineGameClient({
    this.onStateUpdate,
    required this.onError,
  });

  Future<void> connect(
    String hostIp,
    int port,
    String playerId,
    String playerName,
    String playerAvatarId,
  ) async {
    _lastHostIp = hostIp;
    _lastPort = port;
    _playerId = playerId;
    _playerName = playerName;
    _playerAvatarId = playerAvatarId;
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

      _sendJoinRequest();
      _isReconnecting = false;
      _reconnectAttempts = 0;
    } catch (e) {
      if (_isReconnecting) {
        _attemptReconnect();
      } else {
        onError('فشل الاتصال بغرفة الـ99 المحلية: $e');
      }
    }
  }

  void _sendJoinRequest() {
    if (_channel == null) return;
    final msg = GameMessage(
      type: MessageType.joinRequest,
      payload: {
        'playerId': _playerId,
        'name': _playerName,
        'avatarId': _playerAvatarId,
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
          final state = NinetyNineGameState.fromJson(msg.payload);
          onStateUpdate?.call(state);

        case MessageType.error:
          final err = msg.payload['error'] as String? ?? 'حدث خطأ غير معروف';
          onError(err);

        default:
          break;
      }
    } catch (e, st) {
      debugPrint('[Local99Client] State parse error: $e\n$st');
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
      onError('انقطع الاتصال بالمضيف المحلى');
    }
  }

  Future<void> _attemptReconnect() async {
    _reconnectAttempts++;
    debugPrint('[Local99Client] Reconnect attempt $_reconnectAttempts/$_maxReconnectAttempts…');
    await Future.delayed(Duration(milliseconds: 1500 * _reconnectAttempts));
    if (_lastHostIp != null) {
      await _initSocket();
    }
  }

  void sendAction(String action, [Map<String, dynamic>? data]) {
    if (_channel == null) return;
    final msg = GameMessage(
      type: MessageType.playerAction,
      payload: {
        'action': action,
        'playerId': _playerId,
        if (data != null) ...data,
      },
    );
    try {
      _channel!.sink.add(msg.toJsonString());
    } catch (e) {
      debugPrint('[Local99Client] Send action error: $e');
    }
  }

  Future<void> disconnect() async {
    if (_channel != null) {
      try {
        final msg = GameMessage(
          type: MessageType.playerAction,
          payload: {
            'action': 'leaveRequest',
            'playerId': _playerId,
          },
        );
        _channel!.sink.add(msg.toJsonString());
      } catch (_) {}
      _sub?.cancel();
      _sub = null;
      await _channel!.sink.close();
      _channel = null;
    }
    _lastHostIp = null;
  }
}
