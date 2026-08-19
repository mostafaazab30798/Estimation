// lib/modes/ninety_nine/networking/local_ninety_nine_game_server.dart

import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:shelf/shelf_io.dart' as shelf_io;
import 'package:shelf_web_socket/shelf_web_socket.dart';
import 'package:web_socket_channel/web_socket_channel.dart';

import 'package:estimation/networking/messages.dart';
import 'package:estimation/core/models/card.dart';
import '../domain/models/ninety_nine_game_state.dart';
import '../domain/ninety_nine_game_engine.dart';

class LocalNinetyNineGameServer {
  HttpServer? _server;
  final Map<String, WebSocketChannel> _clientSockets = {};
  final Set<WebSocketChannel> _unidentifiedSockets = {};

  late NinetyNineGameState _state;
  final void Function(NinetyNineGameState) onStateUpdate;
  String _hostId = '';
  String _hostName = '';
  int _maxPlayers = 2;
  int boundPort = 7890;

  LocalNinetyNineGameServer({required this.onStateUpdate});

  Future<void> start(
    String hostName,
    String hostId,
    String roomId,
    String hostAvatarId, {
    required int maxPlayers,
    int port = 7890,
  }) async {
    _hostId = hostId;
    _hostName = hostName;
    _maxPlayers = maxPlayers;

    _state = NinetyNineGameState(
      hostId: hostId,
      players: [
        NinetyNinePlayer(
          id: hostId,
          name: hostName,
          hand: [],
          isBot: false,
          avatarId: hostAvatarId,
        ),
      ],
      playerLosses: {hostId: 0},
    );

    final handler = webSocketHandler((WebSocketChannel webSocket) {
      _handleNewSocket(webSocket);
    });

    try {
      _server = await shelf_io.serve(handler, InternetAddress.anyIPv4, port);
      boundPort = _server!.port;
      debugPrint('[Local99Server] Bound to port $boundPort for host $_hostName');
    } catch (e) {
      _server = await shelf_io.serve(handler, InternetAddress.anyIPv4, 0);
      boundPort = _server!.port;
      debugPrint('[Local99Server] Fallback port $boundPort (error: $e)');
    }

    onStateUpdate(_state);
  }

  void _handleNewSocket(WebSocketChannel socket) {
    _unidentifiedSockets.add(socket);
    String? assocId;

    socket.stream.listen(
      (data) {
        if (data is String) {
          try {
            final msg = GameMessage.fromJsonString(data);
            assocId = _processMessage(socket, msg, assocId);
          } catch (e) {
            debugPrint('[Local99Server] Parse error: $e');
          }
        }
      },
      onDone: () => _handleSocketClosed(socket, assocId),
      onError: (err) => _handleSocketClosed(socket, assocId),
    );
  }

  String? _processMessage(WebSocketChannel socket, GameMessage msg, String? currentAssocId) {
    switch (msg.type) {
      case MessageType.joinRequest:
        final playerId = msg.payload['playerId'] as String?;
        if (playerId != null) {
          _unidentifiedSockets.remove(socket);
          _clientSockets[playerId] = socket;
          _handleJoinRequest(msg.payload);
          return playerId;
        }
        return currentAssocId;

      case MessageType.playerAction:
        _handlePlayerAction(msg.payload);
        return currentAssocId;

      case MessageType.heartbeat:
        socket.sink.add(GameMessage(type: MessageType.heartbeat, payload: {}).toJsonString());
        return currentAssocId;

      default:
        return currentAssocId;
    }
  }

  void _handleSocketClosed(WebSocketChannel socket, String? playerId) {
    _unidentifiedSockets.remove(socket);
    if (playerId != null && _clientSockets[playerId] == socket) {
      _clientSockets.remove(playerId);
      if (_state.phase == NinetyNinePhase.waiting) {
        _handleLeaveRequest({'playerId': playerId});
      }
    }
  }

  void _handleJoinRequest(Map<String, dynamic> payload) {
    final playerId = payload['playerId'] as String? ?? '';
    final playerName = payload['name'] as String? ?? 'لاعب';
    final avatarId = payload['avatarId'] as String? ?? 'avatar_1';

    if (playerId.isEmpty) return;

    final existingIdx = _state.players.indexWhere((p) => p.id == playerId);
    if (existingIdx == -1) {
      if (_state.phase != NinetyNinePhase.waiting || _state.players.length >= _maxPlayers) {
        return;
      }
      _state.players.add(NinetyNinePlayer(
        id: playerId,
        name: playerName,
        hand: [],
        isBot: false,
        avatarId: avatarId,
      ));
      _state.playerLosses[playerId] = 0;
    }

    _broadcastState();
  }

  void _handleLeaveRequest(Map<String, dynamic> payload) {
    final playerId = payload['playerId'] as String? ?? '';
    if (playerId.isEmpty || playerId == _hostId) return;
    if (_state.phase == NinetyNinePhase.waiting) {
      final before = _state.players.length;
      _state.players.removeWhere((p) => p.id == playerId);
      _state.playerLosses.remove(playerId);
      if (_state.players.length < before) _broadcastState();
    }
  }

  void _handlePlayerAction(Map<String, dynamic> payload) {
    final action = payload['action'] as String? ?? '';
    final playerId = payload['playerId'] as String? ?? '';

    switch (action) {
      case ActionType.requestStateSync:
        _broadcastState();

      case ActionType.startGame:
        if (playerId == _state.hostId && _state.phase == NinetyNinePhase.waiting) {
          NinetyNineGameEngine.dealCardsAndStartRound(_state, roundNumber: 1);
          _broadcastState();
        }

      case ActionType.playCardNinetyNine:
        final cardJson = payload['card'];
        if (cardJson == null) break;
        final card = PlayingCard.fromJson(cardJson as Map<String, dynamic>);
        final accepted = NinetyNineGameEngine.playCard(_state, playerId, card);
        if (accepted) _broadcastState();

      case ActionType.nextRound:
        if (playerId == _state.hostId && _state.phase == NinetyNinePhase.roundFinished) {
          NinetyNineGameEngine.advanceToNextRound(_state);
          _broadcastState();
        }

      case ActionType.changeTheme:
        if (playerId == _state.hostId) {
          final theme = payload['theme'] as String?;
          if (theme != null) {
            _state.cardTheme = theme;
            _broadcastState();
          }
        }
    }
  }

  void _broadcastState() {
    onStateUpdate(_state);
    final msg = GameMessage(
      type: MessageType.stateUpdate,
      payload: _state.toJson(),
    ).toJsonString();

    for (final socket in _clientSockets.values) {
      try {
        socket.sink.add(msg);
      } catch (_) {}
    }
  }

  void sendHostAction(String action, Map<String, dynamic> extra) {
    _handlePlayerAction({
      'action': action,
      'playerId': _hostId,
      ...extra,
    });
  }

  Future<void> stop() async {
    for (final socket in _clientSockets.values) {
      try {
        socket.sink.close();
      } catch (_) {}
    }
    _clientSockets.clear();
    await _server?.close(force: true);
    _server = null;
  }
}
