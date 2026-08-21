// lib/modes/ninety_nine/networking/ninety_nine_game_server.dart

import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:estimation/networking/messages.dart';
import 'package:estimation/core/models/card.dart';
import '../domain/models/ninety_nine_game_state.dart';
import '../domain/ninety_nine_game_engine.dart';
import 'package:estimation/features/lobby/data/lobby_repository.dart';

import 'dart:math';
import '../domain/ninety_nine_bot_ai.dart';

class NinetyNineGameServer {
  final SupabaseClient _supabase = Supabase.instance.client;
  RealtimeChannel? _channel;
  StreamSubscription? _roomPlayersSub;
  final LobbyRepository _lobbyRepo = LobbyRepository();

  late NinetyNineGameState _state;
  final void Function(NinetyNineGameState) onStateUpdate;
  String _hostId = '';
  String _hostName = '';
  int _maxPlayers = 2;
  Timer? _botTimer;
  bool _botProcessing = false;
  final Random _random = Random();


  NinetyNineGameServer({required this.onStateUpdate});

  Future<void> start(
    String hostName,
    String hostId,
    String roomId,
    String hostAvatarId, {
    required int maxPlayers,
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

    // Watch Supabase room_players for real-time joins (secondary sync).
    // The primary join path is via the broadcast joinRequest handler below.
    _roomPlayersSub = _lobbyRepo.watchRoomPlayers(roomId).listen((players) {
      bool changed = false;
      for (final p in players) {
        if (!_state.players.any((sp) => sp.id == p.playerId)) {
          _state.players.add(NinetyNinePlayer(
            id: p.playerId,
            name: p.playerName,
            hand: [],
            isBot: false,
            avatarId: 'avatar_1',
          ));
          _state.playerLosses[p.playerId] = 0;
          changed = true;
          debugPrint('[99Server] Player joined via DB watch: ${p.playerName}');
        }
      }
      if (changed) _broadcastState();
    });

    // Use the same channel naming convention as Kotchina: 'room_{roomId}'
    _channel = _supabase.channel('room_$roomId');

    // ── Listen for join requests (client sends when they subscribe) ──
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

    // ── Listen for actions from clients ──
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

    // ── Listen for leave requests ──
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

    // ── Presence: auto-remove players who disconnect in lobby ──
    _channel!.onPresenceLeave((payload) {
      if (_state.phase == NinetyNinePhase.waiting) {
        bool changed = false;
        for (final presence in payload.leftPresences) {
          final pId = presence.payload['playerId'] as String?;
          if (pId != null && pId != _hostId) {
            final idx = _state.players.indexWhere((p) => p.id == pId);
            if (idx != -1) {
              _state.players.removeAt(idx);
              _state.playerLosses.remove(pId);
              changed = true;
              debugPrint('[99Server] Player left presence: $pId');
            }
          }
        }
        if (changed) _broadcastState();
      }
    });

    // ── Subscribe: only broadcast AFTER the channel is confirmed open ──
    _channel!.subscribe((status, [error]) async {
      if (status == RealtimeSubscribeStatus.subscribed) {
        // Track presence so clients can detect host availability
        await _channel!.track({
          'playerId': _hostId,
          'name': _hostName,
        });
        // Notify local UI immediately (no network needed)
        onStateUpdate(_state);
        debugPrint('[99Server] Channel open, host tracked');
      } else if (status == RealtimeSubscribeStatus.channelError) {
        debugPrint('[99Server] Channel error: $error');
      }
    });
  }

  // ── Join / Leave handlers ─────────────────────────────────────────────────

  void _handleJoinRequest(Map<String, dynamic> payload) {
    final playerId = payload['playerId'] as String? ?? '';
    final playerName = payload['name'] as String? ?? 'لاعب';
    final avatarId = payload['avatarId'] as String? ?? 'avatar_1';

    if (playerId.isEmpty) return;

    final existingIdx = _state.players.indexWhere((p) => p.id == playerId);
    if (existingIdx == -1) {
      // New player joining
      if (_state.phase != NinetyNinePhase.waiting) {
        debugPrint('[99Server] Join rejected — game already started');
        return;
      }
      if (_state.players.length >= _maxPlayers) {
        debugPrint('[99Server] Join rejected — room full');
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
      debugPrint('[99Server] New player joined: $playerName ($playerId)');
    } else {
      // Reconnecting player — update their avatarId if changed
      debugPrint('[99Server] Player reconnected: $playerName ($playerId)');
    }

    // Always broadcast full state so the joining client gets current snapshot
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

  int get playerCount => _state.players.length;

  /// Add [count] bot players to fill the game up to [_maxPlayers].
  void addBotPlayers({int count = 3}) {
    final toAdd = count.clamp(0, _maxPlayers - _state.players.length);
    for (int i = 1; i <= toAdd; i++) {
      final botIndex = _state.players.length + 1;
      final botId = 'bot_$botIndex';
      _state.players.add(NinetyNinePlayer(
        id: botId,
        name: 'بوت $i 🤖',
        hand: [],
        isBot: true,
        avatarId: 'avatar_${(i % 6) + 1}',
      ));
      _state.playerLosses[botId] = 0;
    }
    _broadcastState();
  }

  // ── Player action handler ─────────────────────────────────────────────────

  void _handlePlayerAction(Map<String, dynamic> payload) {
    final action = payload['action'] as String? ?? '';
    final playerId = payload['playerId'] as String? ?? '';

    switch (action) {
      case ActionType.requestStateSync:
        _broadcastState();
        break;

      case ActionType.startGame:
        if (playerId == _state.hostId &&
            _state.phase == NinetyNinePhase.waiting) {
          if (_state.players.length < _maxPlayers) {
            addBotPlayers(count: _maxPlayers - _state.players.length);
          }
          NinetyNineGameEngine.dealCardsAndStartRound(_state, roundNumber: 1);
          _broadcastState();
        }
        break;

      case ActionType.playCardNinetyNine:
        final cardJson = payload['card'];
        if (cardJson == null) break;
        final card = PlayingCard.fromJson(cardJson as Map<String, dynamic>);
        final accepted = NinetyNineGameEngine.playCard(_state, playerId, card);
        if (accepted) _broadcastState();
        break;

      case ActionType.nextRound:
        if (playerId == _state.hostId &&
            _state.phase == NinetyNinePhase.roundFinished) {
          NinetyNineGameEngine.advanceToNextRound(_state);
          _broadcastState();
        }
        break;

      case ActionType.changeTheme:
        if (playerId == _state.hostId) {
          final theme = payload['theme'] as String?;
          if (theme != null) {
            _state.cardTheme = theme;
            _broadcastState();
          }
        }
        break;
    }
  }

  // ── Broadcast ─────────────────────────────────────────────────────────────

  void _broadcastState() {
    // Always notify the local host UI first
    onStateUpdate(_state);

    // Then broadcast raw state JSON to all clients (same pattern as Kotchina)
    _channel?.sendBroadcastMessage(
      event: 'state',
      payload: _state.toJson(),
    );

    // Check if next turn belongs to a bot
    _scheduleBotTurnIfNeeded();
  }

  // ── Bot AI Automation ────────────────────────────────────────────────────

  void _scheduleBotTurnIfNeeded() {
    if (_state.phase != NinetyNinePhase.playing) return;
    final currentP = _state.currentPlayer;
    if (currentP == null || !currentP.isBot) return;
    if (_botProcessing) return;

    _botProcessing = true;
    final delay = 750 + _random.nextInt(450);
    _botTimer?.cancel();
    _botTimer = Timer(Duration(milliseconds: delay), () {
      _botProcessing = false;
      _executeBotTurn();
    });
  }

  void _executeBotTurn() {
    if (_state.phase != NinetyNinePhase.playing) return;
    final bot = _state.currentPlayer;
    if (bot == null || !bot.isBot || bot.hand.isEmpty) return;

    final chosenCard = NinetyNineBotAi.chooseCard(
      hand: bot.hand,
      groundTotal: _state.groundTotal,
    );

    final accepted = NinetyNineGameEngine.playCard(_state, bot.id, chosenCard);
    if (accepted) {
      _broadcastState();
    }
  }

  // ── Host direct action (called by GameProvider for host actions) ──────────

  void sendHostAction(String action, Map<String, dynamic> extra) {
    _handlePlayerAction({
      'action': action,
      'playerId': _hostId,
      ...extra,
    });
  }

  /// Sync the authoritative player list from Supabase room_players into the
  /// server state before starting the game. This guarantees the correct
  /// player count is used when dealing cards, regardless of Realtime timing.
  void syncPlayersFromRoom(List<({String id, String name})> roomPlayers) {
    // Remove ghosts (players no longer in Supabase room)
    _state.players.removeWhere(
      (sp) => sp.id != _hostId && !roomPlayers.any((p) => p.id == sp.id),
    );
    _state.playerLosses.removeWhere(
      (id, _) => id != _hostId && !roomPlayers.any((p) => p.id == id),
    );

    // Add any missing players
    for (final rp in roomPlayers) {
      if (!_state.players.any((sp) => sp.id == rp.id)) {
        _state.players.add(NinetyNinePlayer(
          id: rp.id,
          name: rp.name,
          hand: [],
          isBot: false,
          avatarId: 'avatar_1',
        ));
        _state.playerLosses[rp.id] = 0;
      }
    }
    debugPrint(
        '[99Server] syncPlayersFromRoom: ${_state.players.length} players total');
  }

  Future<void> stop() async {
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

