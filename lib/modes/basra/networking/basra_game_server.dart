// lib/modes/basra/networking/basra_game_server.dart

import 'dart:async';
import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:estimation/core/models/card.dart';
import 'package:estimation/features/lobby/data/lobby_repository.dart';
import 'package:estimation/networking/messages.dart';
import '../domain/basra_bot_ai.dart';
import '../domain/basra_game_engine.dart';
import '../domain/models/basra_game_state.dart';

class BasraGameServer {
  final SupabaseClient _supabase = Supabase.instance.client;
  RealtimeChannel? _channel;
  StreamSubscription? _roomPlayersSub;
  final LobbyRepository _lobbyRepo = LobbyRepository();

  late BasraGameState _state;
  final void Function(BasraGameState) onStateUpdate;
  final void Function(Map<String, dynamic> reactionData)? onReaction;
  String _hostId = '';
  String _hostName = '';
  late String _roomId;
  int _maxPlayers = 2;
  Timer? _botTimer;
  bool _botProcessing = false;
  final Random _random = Random();
  bool _isStopped = false;

  /// When true, in-game actions go through server authority (Edge Function).
  bool serverAuthorityMode = false;

  BasraGameServer({required this.onStateUpdate, this.onReaction});

  Future<void> start(
    String hostName,
    String hostId,
    String roomId,
    String hostAvatarId, {
    required int maxPlayers,
  }) async {
    _isStopped = false;
    _hostId = hostId;
    _hostName = hostName;
    _roomId = roomId;
    _maxPlayers = maxPlayers;

    _state = BasraGameState(
      hostId: hostId,
      players: [
        BasraPlayer(
          id: hostId,
          name: hostName,
          hand: [],
          isBot: false,
          avatarId: hostAvatarId,
        ),
      ],
    );

    if (!roomId.startsWith('test_')) {
      _roomPlayersSub = _lobbyRepo.watchRoomPlayers(roomId).listen((players) {
        var changed = false;
        for (final p in players) {
          if (!_state.players.any((sp) => sp.id == p.playerId)) {
            _state.players.add(BasraPlayer(
              id: p.playerId,
              name: p.playerName,
              hand: [],
              isBot: false,
              avatarId: 'avatar_1',
            ));
            changed = true;
          }
        }
        if (changed) _broadcastState();
      });

      _channel = _supabase.channel('room_$roomId');

      _channel!.onBroadcast(
        event: 'joinRequest',
        callback: (payload) {
          final data = (payload.containsKey('payload') &&
                  payload['payload'] is Map<String, dynamic>)
              ? payload['payload'] as Map<String, dynamic>
              : payload;
          _handleJoinRequest(data);
        },
      );

      _channel!.onBroadcast(
        event: 'action',
        callback: (payload) {
          final data = (payload.containsKey('payload') &&
                  payload['payload'] is Map<String, dynamic>)
              ? payload['payload'] as Map<String, dynamic>
              : payload;
          _handlePlayerAction(data);
        },
      );

      _channel!.onBroadcast(
        event: 'leaveRequest',
        callback: (payload) {
          final data = (payload.containsKey('payload') &&
                  payload['payload'] is Map<String, dynamic>)
              ? payload['payload'] as Map<String, dynamic>
              : payload;
          _handleLeaveRequest(data);
        },
      );

      _channel!.onPresenceLeave((payload) {
        if (_state.phase == BasraPhase.waiting) {
          var changed = false;
          for (final presence in payload.leftPresences) {
            final pId = presence.payload['playerId'] as String?;
            if (pId != null && pId != _hostId) {
              final idx = _state.players.indexWhere((p) => p.id == pId);
              if (idx != -1) {
                _state.players.removeAt(idx);
                changed = true;
              }
            }
          }
          if (changed) _broadcastState();
        }
      });

      _channel!.subscribe((status, [error]) async {
        if (status == RealtimeSubscribeStatus.subscribed) {
          await _channel!.track({
            'playerId': _hostId,
            'name': _hostName,
          });
          onStateUpdate(_state);
        } else if (status == RealtimeSubscribeStatus.channelError) {
          debugPrint('[BasraServer] Channel error: $error');
        }
      });
    } else {
      onStateUpdate(_state);
    }
  }

  void _handleJoinRequest(Map<String, dynamic> payload) {
    final playerId = payload['playerId'] as String? ?? '';
    final playerName = payload['name'] as String? ?? 'لاعب';
    final avatarId = payload['avatarId'] as String? ?? 'avatar_1';
    if (playerId.isEmpty) return;

    final existingIdx = _state.players.indexWhere((p) => p.id == playerId);
    if (existingIdx == -1) {
      if (_state.phase != BasraPhase.waiting) return;
      if (_state.players.length >= _maxPlayers) return;
      _state.players.add(BasraPlayer(
        id: playerId,
        name: playerName,
        hand: [],
        isBot: false,
        avatarId: avatarId,
      ));
    }
    _broadcastState();
  }

  void _handleLeaveRequest(Map<String, dynamic> payload) {
    final playerId = payload['playerId'] as String? ?? '';
    if (playerId.isEmpty || playerId == _hostId) return;
    if (_state.phase == BasraPhase.waiting) {
      final before = _state.players.length;
      _state.players.removeWhere((p) => p.id == playerId);
      if (_state.players.length < before) _broadcastState();
    }
  }

  int get playerCount => _state.players.length;

  void addBotPlayers({int count = 3}) {
    final toAdd = count.clamp(0, _maxPlayers - _state.players.length);
    for (var i = 1; i <= toAdd; i++) {
      final botIndex = _state.players.length + 1;
      _state.players.add(BasraPlayer(
        id: 'bot_$botIndex',
        name: 'بوت $i 🤖',
        hand: [],
        isBot: true,
        avatarId: 'avatar_${(i % 6) + 1}',
      ));
    }
    _broadcastState();
  }

  void _handlePlayerAction(Map<String, dynamic> payload) {
    final action = payload['action'] as String? ?? '';
    if (serverAuthorityMode &&
        _state.phase != BasraPhase.waiting &&
        action != ActionType.requestStateSync) {
      return;
    }
    final playerId = payload['playerId'] as String? ?? '';

    switch (action) {
      case ActionType.requestStateSync:
        _broadcastState();
      case ActionType.startGame:
        if (playerId == _state.hostId && _state.phase == BasraPhase.waiting) {
          if (_state.players.length < _maxPlayers) {
            addBotPlayers(count: _maxPlayers - _state.players.length);
          }
          BasraGameEngine.startMatch(_state);
          _broadcastState();
        }
      case ActionType.playCardBasra:
        final cardJson = payload['card'];
        if (cardJson == null) break;
        final card = PlayingCard.fromJson(cardJson as Map<String, dynamic>);
        final accepted = BasraGameEngine.playCard(_state, playerId, card);
        if (accepted) _broadcastState();
      case ActionType.nextRound:
        if (playerId == _state.hostId &&
            _state.phase == BasraPhase.roundFinished) {
          BasraGameEngine.advanceToNextRound(_state);
          _broadcastState();
        }
      case ActionType.sendReaction:
        final reactionData = {
          'id': payload['reactionId'] ??
              payload['id'] ??
              DateTime.now().microsecondsSinceEpoch.toString(),
          'playerId': playerId,
          'playerName':
              _state.players.where((p) => p.id == playerId).firstOrNull?.name ??
                  payload['playerName'],
          'emoji': payload['emoji'] ?? '🔥',
          'text': payload['text'],
          'timestamp':
              payload['timestamp'] ?? DateTime.now().millisecondsSinceEpoch,
        };
        _channel?.sendBroadcastMessage(
            event: 'reaction', payload: reactionData);
        onReaction?.call(reactionData);
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
    if (_isStopped) return;
    if (serverAuthorityMode && _state.phase != BasraPhase.waiting) return;
    onStateUpdate(_state);
    final payload = Map<String, dynamic>.from(_state.toSanitizedJson());
    _channel?.sendBroadcastMessage(event: 'state', payload: payload);

    if (!_roomId.startsWith('test_') &&
        _state.players.any((p) => p.hand.isNotEmpty && !p.isBot)) {
      _saveHandCards();
    }

    _scheduleBotTurnIfNeeded();
  }

  void _saveHandCards() {
    for (final player in _state.players) {
      if (player.isBot) continue;
      _lobbyRepo
          .savePlayerHand(_roomId, player.id, player.hand)
          .catchError((e) => debugPrint('[BasraServer] Hand save failed: $e'));
    }
  }

  void _scheduleBotTurnIfNeeded() {
    if (serverAuthorityMode) return;
    if (_isStopped || _state.phase != BasraPhase.playing) return;
    final currentP = _state.currentPlayer;
    if (currentP == null || !currentP.isBot) return;
    if (_botProcessing) return;

    _botProcessing = true;
    final captured = _state.lastTurnResult?.wasCapture == true;
    final delay =
        captured ? 1550 + _random.nextInt(350) : 750 + _random.nextInt(450);
    _botTimer?.cancel();
    _botTimer = Timer(Duration(milliseconds: delay), () {
      _botProcessing = false;
      if (_isStopped) return;
      _executeBotTurn();
    });
  }

  void _executeBotTurn() {
    if (_isStopped || _state.phase != BasraPhase.playing) return;
    final bot = _state.currentPlayer;
    if (bot == null || !bot.isBot || bot.hand.isEmpty) return;

    final chosenCard = BasraBotAi.chooseCard(
      hand: bot.hand,
      tableCards: _state.tableCards,
    );
    final accepted = BasraGameEngine.playCard(_state, bot.id, chosenCard);
    if (accepted) _broadcastState();
  }

  void sendHostAction(String action, Map<String, dynamic> extra) {
    if (_isStopped) return;
    _handlePlayerAction({
      'action': action,
      'playerId': _hostId,
      ...extra,
    });
  }

  void syncPlayersFromRoom(List<({String id, String name})> roomPlayers) {
    if (_isStopped) return;
    _state.players.removeWhere(
      (sp) => sp.id != _hostId && !roomPlayers.any((p) => p.id == sp.id),
    );
    for (final rp in roomPlayers) {
      if (!_state.players.any((sp) => sp.id == rp.id)) {
        _state.players.add(BasraPlayer(
          id: rp.id,
          name: rp.name,
          hand: [],
          isBot: false,
          avatarId: 'avatar_1',
        ));
      }
    }
  }

  Future<void> stop() async {
    _isStopped = true;
    _botTimer?.cancel();
    _botTimer = null;
    await _roomPlayersSub?.cancel();
    _roomPlayersSub = null;
    if (_channel != null) {
      await _supabase.removeChannel(_channel!);
      _channel = null;
    }
  }
}
