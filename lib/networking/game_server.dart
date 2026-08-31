// lib/networking/game_server.dart
//
// Host-side server: Runs the GameEngine and broadcasts state via Supabase Realtime.

import 'dart:async';
import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../core/ai/estimation_bot_ai.dart';
import '../core/constants.dart';
import '../core/game_engine.dart';
import '../core/models/bid.dart';
import '../core/models/card.dart';
import '../core/models/game_state.dart';
import '../core/models/player.dart';
import '../services/profile_service.dart';
import 'messages.dart';

typedef StateUpdateCallback = void Function(GameState state);

class GameServer {
  static final Random _rng = Random();
  static const disconnectedPlayerGracePeriod = Duration(seconds: 60);

  final StateUpdateCallback onStateUpdate;
  final void Function(Map<String, dynamic> reactionData)? onReaction;
  final void Function(Map<String, dynamic> earthquakeData)? onEarthquake;

  String? hostPlayerId;
  String? hostName;
  late String roomId;
  int maxHumanPlayers = 4;
  int maxPlayers = 4;

  late GameState _state;
  RealtimeChannel? _channel;

  // Tracks the last phase we saved to DB; we only persist on transitions.
  GamePhase? _lastPersistedPhase;

  // ── Turn & Bot Timers ───────────────────────────────────────────
  bool _isStopped = false;
  Timer? _turnTimer;
  Timer? _botTimer;
  Timer? _trickTimer;

  // ── Bot support ──────────────────────────────────────────────
  final Set<String> _botPlayerIds = {};
  final Set<String> _temporaryBotPlayerIds = {};
  final Map<String, Timer> _disconnectedPlayerTimers = {};
  bool _botProcessing = false;

  GameServer({required this.onStateUpdate, this.onReaction, this.onEarthquake});

  // ── Lifecycle ────────────────────────────────────────────────

  Future<void> start(
    String hostName,
    String hostPlayerId,
    String roomId,
    String hostPhoto, {
    int maxPlayers = 4,
    int totalRounds = kBoulaTotalRounds,
  }) async {
    _isStopped = false;
    this.hostName = hostName;
    this.hostPlayerId = hostPlayerId;
    this.roomId = roomId;
    maxHumanPlayers = maxPlayers;
    this.maxPlayers = 4; // Estimation table is always 4 players

    // Add host as the first player immediately
    final hostPlayer = Player(
      id: hostPlayerId,
      name: hostName,
      seatIndex: 0,
      photo: hostPhoto,
    );
    _state =
        GameEngine.createInitialState([hostPlayer], totalRounds: totalRounds);

    // Initialize Supabase Broadcast Channel
    _channel = Supabase.instance.client.channel('room_$roomId');

    // Listen for actions from clients
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

    // Listen for join requests from clients
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

    // Listen for leave requests from clients
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

    // Listen for presence leave to automatically remove disconnected players
    _channel!.onPresenceLeave(_handlePresenceLeave);

    _channel!.subscribe((status, [error]) async {
      if (status == RealtimeSubscribeStatus.subscribed) {
        await _channel!.track({
          'playerId': hostPlayerId,
          'name': hostName,
        });
      }
    });

    // Immediately notify host UI so they appear in the lobby
    onStateUpdate(_state);
  }

  Future<void> stop() async {
    _isStopped = true;
    _turnTimer?.cancel();
    _turnTimer = null;
    _botTimer?.cancel();
    _botTimer = null;
    _trickTimer?.cancel();
    _trickTimer = null;
    for (final timer in _disconnectedPlayerTimers.values) {
      timer.cancel();
    }
    _disconnectedPlayerTimers.clear();
    _temporaryBotPlayerIds.clear();
    await _channel?.unsubscribe();
    _channel = null;
  }

  int get playerCount => _state.players.length;

  // ── Bot players ──────────────────────────────────────────────

  /// Add [count] bot players filling remaining seats up to 4.
  void addBotPlayers({int count = 3}) {
    final toAdd = count.clamp(0, 4 - _state.players.length);
    for (int i = 0; i < toAdd; i++) {
      var next = 1;
      while (_state.players.any((player) => player.id == 'bot_$next')) {
        next++;
      }
      final botId = 'bot_$next';
      final seatIndex = _state.players.length;
      _botPlayerIds.add(botId);
      _state.players.add(Player(
        id: botId,
        name: 'لاعب $next 🤖',
        seatIndex: seatIndex,
      ));
    }
    onStateUpdate(_state);
  }

  /// Sync players from Supabase into the local game state.
  /// Called just before startGame so all 4 seats are filled
  /// regardless of broadcast join timing.
  void syncPlayersFromRoom(List<({String id, String name})> players) {
    // Remove ghosts (players in state but not in the Supabase room)
    _state.players.removeWhere((sp) => !players.any((p) => p.id == sp.id));

    // Add new players
    for (final p in players) {
      final alreadyIn = _state.players.any((sp) => sp.id == p.id);
      if (!alreadyIn) {
        final seat = _state.players.length;
        _state.players.add(Player(id: p.id, name: p.name, seatIndex: seat));
      }
    }

    // Reassign seat indexes to ensure sequential seats
    for (int i = 0; i < _state.players.length; i++) {
      _state.players[i] = _state.players[i].copyWith(seatIndex: i);
    }
  }

  // ── Network handling ───────────────────────────────────────

  void _handleJoinRequest(Map<String, dynamic> payload) {
    final playerId = payload['playerId'] as String;
    final playerName = payload['name'] as String;
    final playerPhoto = ProfileService.publicAvatarRef(
      payload['photo'] as String?,
    );

    // Check if player is already in the state
    final existingIndex = _state.players.indexWhere((p) => p.id == playerId);

    if (existingIndex == -1) {
      // New player joining
      if (_state.phase != GamePhase.lobby) {
        // Cannot join a game in progress if not already in it
        _sendError('اللعبة بدأت بالفعل');
        return;
      }
      if (_state.players.length >= maxHumanPlayers) {
        _sendError('الغرفة ممتلئة');
        return;
      }
      final seat = _state.players.length;
      _state.players.add(Player(
          id: playerId, name: playerName, seatIndex: seat, photo: playerPhoto));
    } else if (_state.players[existingIndex].photo != playerPhoto) {
      // Update photo if changed during reconnection
      _state.players[existingIndex] =
          _state.players[existingIndex].copyWith(photo: playerPhoto);
    }

    _reclaimHumanSeat(playerId);

    // Always broadcast to give the newly connected client the current state
    _broadcastState();
  }

  void _sendError(String errorMsg) {
    _channel?.sendBroadcastMessage(
      event: 'error',
      payload: {'error': errorMsg},
    );
  }

  void _handleLeaveRequest(Map<String, dynamic> payload) {
    final playerId = payload['playerId'] as String;
    if (_state.phase == GamePhase.lobby) {
      _state.players.removeWhere((p) => p.id == playerId);
      // Reassign seat indexes
      for (int i = 0; i < _state.players.length; i++) {
        _state.players[i] = _state.players[i].copyWith(seatIndex: i);
      }
      _broadcastState();
    } else {
      _scheduleDisconnectedPlayerTakeover(playerId);
    }
  }

  void _handlePresenceLeave(dynamic payload) {
    for (final presence in payload.leftPresences) {
      final playerId = presence.payload['playerId'] as String?;
      if (playerId == null || playerId == hostPlayerId) continue;
      if (_state.phase == GamePhase.lobby) {
        _state.players.removeWhere((player) => player.id == playerId);
        for (var index = 0; index < _state.players.length; index++) {
          _state.players[index] =
              _state.players[index].copyWith(seatIndex: index);
        }
        _broadcastState();
      } else {
        _scheduleDisconnectedPlayerTakeover(playerId);
      }
    }
  }

  void _scheduleDisconnectedPlayerTakeover(String playerId) {
    if (_isStopped ||
        playerId.startsWith('bot_') ||
        !_state.players.any((player) => player.id == playerId) ||
        _temporaryBotPlayerIds.contains(playerId) ||
        _disconnectedPlayerTimers.containsKey(playerId)) {
      return;
    }
    debugPrint('[Reconnection] Reserving seat for $playerId for 60 seconds');
    _disconnectedPlayerTimers[playerId] = Timer(
      disconnectedPlayerGracePeriod,
      () {
        _disconnectedPlayerTimers.remove(playerId);
        if (_isStopped ||
            !_state.players.any((player) => player.id == playerId)) {
          return;
        }
        _temporaryBotPlayerIds.add(playerId);
        _botPlayerIds.add(playerId);
        debugPrint('[Reconnection] Bot took temporary control of $playerId');
        _broadcastState();
      },
    );
  }

  void markHostTemporarilyAway() {
    final id = hostPlayerId;
    if (id != null && _state.phase != GamePhase.lobby) {
      _scheduleDisconnectedPlayerTakeover(id);
    }
  }

  void reclaimHostSeat() {
    final id = hostPlayerId;
    if (id != null) _reclaimHumanSeat(id);
  }

  void _reclaimHumanSeat(String playerId) {
    _disconnectedPlayerTimers.remove(playerId)?.cancel();
    if (_temporaryBotPlayerIds.remove(playerId)) {
      _botPlayerIds.remove(playerId);
      _botTimer?.cancel();
      _botTimer = null;
      _botProcessing = false;
      debugPrint('[Reconnection] Human reclaimed seat $playerId');
      _broadcastState();
    }
  }

  // ── Action handler ───────────────────────────────────────────

  void _handlePlayerAction(Map<String, dynamic> payload) {
    if (_isStopped) return;
    final action = payload['action'] as String;
    final playerId = payload['playerId'] as String;

    switch (action) {
      case ActionType.requestStateSync:
        _broadcastState();

      case ActionType.startGame:
        // Only the host can start. Complete remaining seats with bots so table always has 4 players.
        if (playerId == hostPlayerId && _state.phase == GamePhase.lobby) {
          if (_state.players.length < 4) {
            addBotPlayers(count: 4 - _state.players.length);
          }
          _state.phase = GamePhase.dealing;
          _doDeal(); // _doDeal calls _broadcastState internally
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
          event: 'reaction',
          payload: reactionData,
        );
        onReaction?.call(reactionData);

      case ActionType.triggerEarthquake:
        final earthquakeData = {
          'id': payload['earthquakeId'] ??
              payload['id'] ??
              DateTime.now().microsecondsSinceEpoch.toString(),
          'playerId': playerId,
          'playerName':
              _state.players.where((p) => p.id == playerId).firstOrNull?.name ??
                  payload['playerName'] ??
                  'Player',
          'card': payload['card'],
          'roundNumber': payload['roundNumber'] ?? _state.roundNumber,
          'timestamp':
              payload['timestamp'] ?? DateTime.now().millisecondsSinceEpoch,
        };
        _channel?.sendBroadcastMessage(
          event: 'earthquake',
          payload: earthquakeData,
        );
        onEarthquake?.call(earthquakeData);

      case ActionType.changeTheme:
        if (playerId == hostPlayerId && _state.phase == GamePhase.lobby) {
          final newTheme = payload['theme'] as String;
          _state.cardTheme = newTheme;
          _broadcastState();
        }

      case ActionType.approveRedeal:
        // Any single approve while a void suit was detected → redeal immediately.
        if (_state.phase == GamePhase.voidCheck &&
            _state.voidDeclaringPlayerId != null) {
          _triggerRedeal();
        }

      case ActionType.rejectRedeal:
        if (_state.phase == GamePhase.voidCheck &&
            _state.voidDeclaringPlayerId != null) {
          _state.voidRedealRejections.add(playerId);
          if (_state.voidRedealRejections.length >= maxPlayers) {
            // Everyone chose continue — proceed to dash call / declarations.
            GameEngine.proceedAfterVoidCheck(_state);
          }
          _broadcastState();
        }

      case ActionType.confirmNoVoid:
        if (_state.phase == GamePhase.voidCheck) {
          GameEngine.passVoidCheck(_state, playerId);
          _broadcastState();
        }

      case ActionType.unready:
        if (_state.phase == GamePhase.voidCheck) {
          _state.voidCheckPassed.remove(playerId);
          _broadcastState();
        }

      case ActionType.submitDashCall:
        if (_state.phase == GamePhase.dashCall) {
          final wantsDash = payload['wantsDashCall'] as bool? ?? false;
          GameEngine.submitDashCall(_state, playerId, wantsDash);
          _broadcastState();
        } else {
          _broadcastState();
        }

      case ActionType.submitBid:
        if (_state.phase == GamePhase.auction) {
          final bid = Bid.fromJson(payload['bid'] as Map<String, dynamic>);
          final accepted = GameEngine.submitBid(_state, playerId, bid);
          if (accepted) {
            if (_state.phase == GamePhase.declarations) {
              _maybeSkipDeclarations();
            }
            _broadcastState();
          } else {
            // Action rejected (e.g. out of turn) — resync caller
            _broadcastState();
          }
        } else {
          _broadcastState();
        }

      case ActionType.passBid:
        if (_state.phase == GamePhase.auction) {
          GameEngine.passBid(_state, playerId);
          if (_state.phase == GamePhase.dealing) {
            _doDeal();
          } else {
            if (_state.phase == GamePhase.declarations) {
              _maybeSkipDeclarations();
            }
            _broadcastState();
          }
        } else {
          _broadcastState();
        }

      case ActionType.submitDeclaration:
        if (_state.phase == GamePhase.declarations) {
          final player = _state.playerById(playerId);
          if (player.seatIndex != _state.currentPlayerSeatIndex) {
            _broadcastState(); // Out of turn — resync caller
            return;
          }

          final declared = payload['declared'] as int;
          final decls = _state.players
              .map((p) => p.declared)
              .where((d) => d != null)
              .toList();
          if (decls.length == 3) {
            final sum = decls.fold<int>(0, (a, b) => a + b!);
            if (sum + declared == 13) {
              _broadcastState(); // Invalid declaration — resync caller
              return;
            }
          }
          GameEngine.submitDeclaration(_state, playerId, declared);
          _broadcastState();
        } else {
          _broadcastState();
        }

      case ActionType.playCard:
        if (_state.phase == GamePhase.trickTaking) {
          if (_state.currentTrick.length == maxPlayers) {
            _broadcastState(); // Ignore input while waiting to clear trick — resync
            return;
          }
          final card =
              PlayingCard.fromJson(payload['card'] as Map<String, dynamic>);
          final player = _state.playerById(playerId);
          if (GameEngine.canPlayCard(_state, player, card)) {
            final finished = GameEngine.playCard(_state, playerId, card);
            if (finished) {
              _broadcastState(); // Broadcast immediately to show the 4th card
              _persistSnapshotAndHands();
              _trickTimer?.cancel();
              _trickTimer = Timer(const Duration(seconds: 2), () {
                if (_isStopped) return;
                GameEngine.resolveTrick(_state);
                if (_state.phase == GamePhase.scoring) {
                  GameEngine.computeAndApplyScores(_state);
                }
                _broadcastState();
                _persistSnapshotAndHands();
              });
            } else {
              _broadcastState();
              _persistSnapshotAndHands();
            }
          } else {
            // Action rejected (illegal card or stale turn) — resync caller
            _broadcastState();
          }
        } else {
          _broadcastState();
        }

      case ActionType.nextRound:
        if (_state.phase == GamePhase.scoring && playerId == hostPlayerId) {
          if (_state.isMatchOver) {
            _state.phase = GamePhase.matchEnd;
          } else {
            GameEngine.startNextRound(_state);
            _doDeal();
            return; // _doDeal calls _broadcastState
          }
          _broadcastState();
        }
    }
  }

  void _maybeSkipDeclarations() {
    final nonBidders =
        _state.players.where((p) => p.id != _state.bidderPlayerId);
    if (nonBidders.every((p) => p.declared != null)) {
      _state.phase = GamePhase.trickTaking;
    }
  }

  void _doDeal() {
    if (_isStopped) return;
    // Determine dealer and first bidder for this round
    final firstBidder = (_state.roundNumber - 1) % maxPlayers;
    _state.dealerSeatIndex = (firstBidder - 1 + maxPlayers) % maxPlayers;
    _state.auctionTurnSeatIndex = firstBidder;
    _state.trump = _state.fixedTrump;

    GameEngine.dealCards(_state);

    // Persist each real player's private hand for reconnection recovery.
    _saveHandCards();

    // If anyone has an empty suit, pause for a redistribute/continue vote.
    GameEngine.enterPostDealPhase(_state);

    _broadcastState();
  }

  void _triggerRedeal() {
    if (_isStopped) return;
    for (final p in _state.players) {
      p.resetForRound();
    }
    _state.currentHighBid = null;
    _state.currentHighBidderPlayerId = null;
    _state.bidderPlayerId = null;
    _state.trump = _state.fixedTrump;
    _state.currentTrick = [];
    _state.tricksPlayedThisRound = 0;
    _state.voidCheckPassed = {};
    _state.voidDeclaringPlayerId = null;
    _state.voidRedealRejections.clear();
    _doDeal();
  }

  // ── Broadcast ────────────────────────────────────────────────

  void _broadcastState() {
    if (_isStopped) return;
    _prepareTurnTimer();

    // Online Realtime broadcast is room-wide — never send real opponent hands.
    final payload = Map<String, dynamic>.from(_state.toSanitizedJson());
    final players = payload['players'];
    if (players is List) {
      payload['players'] = players.map((raw) {
        final player = Map<String, dynamic>.from(raw as Map);
        player['photo'] =
            ProfileService.publicAvatarRef(player['photo'] as String?);
        return player;
      }).toList();
    }

    _channel?.sendBroadcastMessage(
      event: 'state',
      payload: payload,
    );
    onStateUpdate(_state);
    _scheduleBotTurn();
    _startTurnTimer();

    // Keep owner-only hand rows fresh for client RPC recovery.
    if (_state.players.any((p) =>
        p.hand.isNotEmpty && !p.id.startsWith('bot_'))) {
      _saveHandCards();
    }

    // Persist a snapshot on phase change or phase snapshot updates
    if (_state.phase != _lastPersistedPhase) {
      _lastPersistedPhase = _state.phase;
      _persistSnapshotAndHands();
    }
  }

  void _persistSnapshotAndHands() {
    if (_isStopped) return;
    _persistPhaseSnapshot();
    _saveHandCards();
  }

  // ── Turn Timeout Handling ─────────────────────────────────────

  void _prepareTurnTimer() {
    _turnTimer?.cancel();
    _turnTimer = null;
    if (_isStopped) {
      _state.turnDeadlineEpochMs = null;
      return;
    }

    Duration? timeout;
    if (_state.phase == GamePhase.dashCall) {
      timeout = kDashCallTurnTimeout;
    } else if (_state.phase == GamePhase.auction) {
      timeout = kAuctionTurnTimeout;
    } else if (_state.phase == GamePhase.declarations) {
      final activePlayer = _state.playerBySeat(_state.currentPlayerSeatIndex);
      if (activePlayer.declared == null) {
        timeout = kDeclarationTurnTimeout;
      }
    } else if (_state.phase == GamePhase.trickTaking) {
      if (_state.currentTrick.length < maxPlayers) {
        timeout = kTrickTurnTimeout;
      }
    }

    if (timeout != null) {
      _state.turnDurationSeconds = timeout.inSeconds;
      _state.turnDeadlineEpochMs =
          DateTime.now().millisecondsSinceEpoch + timeout.inMilliseconds;
    } else {
      _state.turnDeadlineEpochMs = null;
    }
  }

  void _startTurnTimer() {
    _turnTimer?.cancel();
    _turnTimer = null;
    if (_isStopped) return;

    if (_state.phase == GamePhase.dashCall) {
      final activePlayer = _state.playerBySeat(_state.currentPlayerSeatIndex);
      if (!_botPlayerIds.contains(activePlayer.id)) {
        _turnTimer = Timer(kDashCallTurnTimeout, _handleTurnTimeout);
      }
    } else if (_state.phase == GamePhase.auction) {
      final activePlayer = _state.playerBySeat(_state.auctionTurnSeatIndex);
      if (!_botPlayerIds.contains(activePlayer.id)) {
        _turnTimer = Timer(kAuctionTurnTimeout, _handleTurnTimeout);
      }
    } else if (_state.phase == GamePhase.declarations) {
      final activePlayer = _state.playerBySeat(_state.currentPlayerSeatIndex);
      if (activePlayer.declared == null &&
          !_botPlayerIds.contains(activePlayer.id)) {
        _turnTimer = Timer(kDeclarationTurnTimeout, _handleTurnTimeout);
      }
    } else if (_state.phase == GamePhase.trickTaking) {
      if (_state.currentTrick.length < maxPlayers) {
        final activePlayer = _state.playerBySeat(_state.currentPlayerSeatIndex);
        if (!_botPlayerIds.contains(activePlayer.id)) {
          _turnTimer = Timer(kTrickTurnTimeout, _handleTurnTimeout);
        }
      }
    }
  }

  void _handleTurnTimeout() {
    if (_isStopped) return;
    debugPrint(
        '[Server] Turn timeout triggered for phase: ${_state.phase.name}');
    switch (_state.phase) {
      case GamePhase.dashCall:
        final activePlayer = _state.playerBySeat(_state.currentPlayerSeatIndex);
        debugPrint(
            '[Server] Timing out dash call turn for ${activePlayer.name}');
        _handlePlayerAction({
          'action': ActionType.submitDashCall,
          'playerId': activePlayer.id,
          'wantsDashCall': false,
        });

      case GamePhase.auction:
        final activePlayer = _state.playerBySeat(_state.auctionTurnSeatIndex);
        debugPrint('[Server] Timing out auction turn for ${activePlayer.name}');
        _handlePlayerAction(
            {'action': ActionType.passBid, 'playerId': activePlayer.id});

      case GamePhase.declarations:
        final activePlayer = _state.playerBySeat(_state.currentPlayerSeatIndex);
        debugPrint(
            '[Server] Timing out declaration turn for ${activePlayer.name}');
        int minDecl = 0;
        if (activePlayer.id == _state.bidderPlayerId &&
            _state.currentHighBid != null) {
          minDecl = _state.currentHighBid!.trickCount;
        }
        final decls = _state.players
            .map((p) => p.declared)
            .where((d) => d != null)
            .toList();
        int? forbidden;
        if (decls.length == 3) {
          final sum = decls.fold<int>(0, (a, b) => a + b!);
          forbidden = 13 - sum;
        }
        int chosenDecl = minDecl.clamp(0, 13);
        if (chosenDecl == forbidden) {
          chosenDecl = (chosenDecl < 13) ? chosenDecl + 1 : chosenDecl - 1;
        }
        _handlePlayerAction({
          'action': ActionType.submitDeclaration,
          'playerId': activePlayer.id,
          'declared': chosenDecl,
        });

      case GamePhase.trickTaking:
        final activePlayer = _state.playerBySeat(_state.currentPlayerSeatIndex);
        debugPrint(
            '[Server] Timing out trickTaking turn for ${activePlayer.name}');
        _autoPlayCardForPlayer(activePlayer);

      default:
        break;
    }
  }

  void _autoPlayCardForPlayer(Player player) {
    if (player.hand.isEmpty) return;
    final chosen = EstimationBotAi.chooseCardToPlay(_state, player);

    _handlePlayerAction({
      'action': ActionType.playCard,
      'playerId': player.id,
      'card': chosen.toJson(),
    });
  }

  /// Fire-and-forget: save the current GameState to Supabase on phase transitions.
  void _persistPhaseSnapshot() {
    if (roomId.startsWith('test_')) return;
    Supabase.instance.client.rpc('save_game_state', params: {
      'p_room_id': roomId,
      'p_state': _state.toSanitizedJson(),
    }).catchError(
      (e) => debugPrint('[Server] Phase snapshot persist failed: $e'),
    );
  }

  /// Fire-and-forget: save every real player's hand after a deal.
  /// Bots are skipped — their hands are never private.
  void _saveHandCards() {
    if (roomId.startsWith('test_')) return;
    for (final player in _state.players) {
      if (player.id.startsWith('bot_')) continue;
      Supabase.instance.client.rpc('save_player_hand', params: {
        'p_room_id': roomId,
        'p_player_id': player.id,
        'p_hand_cards': player.hand.map((c) => c.toJson()).toList(),
      }).catchError(
        (e) => debugPrint('[Server] Hand save failed for ${player.id}: $e'),
      );
    }
  }

  // ── Host direct action ───────────────────────────────────────

  void sendHostAction(String action, Map<String, dynamic> extra) {
    _handlePlayerAction({
      'action': action,
      'playerId': hostPlayerId,
      ...extra,
    });
  }

  // ── Host promotion: restore from persisted state ──────────────────────────

  /// Called when this client has been elected as the new host.
  /// Re-creates the Realtime channel with the same room_id so existing clients
  /// continue to receive broadcasts without re-connecting.
  ///
  /// After [subscribe] confirms, the new host immediately re-broadcasts
  /// the current state so all clients are in sync.
  Future<void> restoreFromState({
    required GameState state,
    required String hostPlayerId,
    required String hostName,
    required String roomId,
  }) async {
    _isStopped = false;
    this.hostPlayerId = hostPlayerId;
    this.hostName = hostName;
    this.roomId = roomId;
    maxPlayers = 4;
    _state = state;
    _lastPersistedPhase = state.phase; // Avoid re-persisting the same phase

    _botPlayerIds.clear();
    for (final p in state.players) {
      if (p.id.startsWith('bot_')) {
        _botPlayerIds.add(p.id);
      }
    }

    _channel = Supabase.instance.client.channel('room_$roomId');

    _channel!.onBroadcast(
      event: 'action',
      callback: _handlePlayerAction,
    );
    _channel!.onBroadcast(
      event: 'joinRequest',
      callback: _handleJoinRequest,
    );
    _channel!.onBroadcast(
      event: 'leaveRequest',
      callback: _handleLeaveRequest,
    );

    _channel!.onPresenceLeave(_handlePresenceLeave);

    _channel!.subscribe((status, [error]) async {
      if (status == RealtimeSubscribeStatus.subscribed) {
        await _channel!.track({'playerId': hostPlayerId, 'name': hostName});
        // Re-announce state immediately so clients don't wait for next action.
        _broadcastState();
      }
    });

    onStateUpdate(_state);
    debugPrint(
        '[Server] Restored from persisted state — phase: ${_state.phase.name}');
  }

  // ── Bot AI ───────────────────────────────────────────────────

  void _scheduleBotTurn() {
    if (_isStopped || _botProcessing || _botPlayerIds.isEmpty) return;
    if (!_isBotTurnNeeded()) return;

    _botProcessing = true;
    final delay = 600 + _rng.nextInt(600);
    _botTimer?.cancel();
    _botTimer = Timer(Duration(milliseconds: delay), () {
      _botProcessing = false;
      if (_isStopped) return;
      _executeBotAction();
    });
  }

  bool _isBotTurnNeeded() {
    if (_isStopped) return false;
    switch (_state.phase) {
      case GamePhase.voidCheck:
        if (_state.voidDeclaringPlayerId != null) {
          return _botPlayerIds
              .any((id) => !_state.voidRedealRejections.contains(id));
        }
        return _botPlayerIds.any((id) => !_state.voidCheckPassed.contains(id));

      case GamePhase.dashCall:
        final seat = _state.currentPlayerSeatIndex;
        final players = _state.players.where((p) => p.seatIndex == seat);
        return players.isNotEmpty && _botPlayerIds.contains(players.first.id);

      case GamePhase.auction:
        final seat = _state.auctionTurnSeatIndex;
        final players = _state.players.where((p) => p.seatIndex == seat);
        return players.isNotEmpty && _botPlayerIds.contains(players.first.id);

      case GamePhase.declarations:
        final seat = _state.currentPlayerSeatIndex;
        final players = _state.players.where((p) => p.seatIndex == seat);
        return players.isNotEmpty && _botPlayerIds.contains(players.first.id);

      case GamePhase.trickTaking:
        if (_state.currentTrick.length == 4) {
          return false; // Waiting to clear trick
        }
        final seat = _state.currentPlayerSeatIndex;
        final players = _state.players.where((p) => p.seatIndex == seat);
        return players.isNotEmpty && _botPlayerIds.contains(players.first.id);

      default:
        return false;
    }
  }

  void _executeBotAction() {
    if (_isStopped) return;
    switch (_state.phase) {
      case GamePhase.voidCheck:
        if (_state.voidDeclaringPlayerId != null) {
          for (final id in _botPlayerIds) {
            if (!_state.voidRedealRejections.contains(id)) {
              final bot = _state.players.where((p) => p.id == id).firstOrNull;
              if (bot == null) continue;
              // Void holders lean toward redeal; others use hand-strength heuristic.
              final approve = id == _state.voidDeclaringPlayerId ||
                  GameEngine.hasVoidSuit(bot) ||
                  EstimationBotAi.shouldApproveRedeal(bot, _state);
              _handlePlayerAction({
                'action': approve
                    ? ActionType.approveRedeal
                    : ActionType.rejectRedeal,
                'playerId': id,
              });
              return;
            }
          }
        } else {
          for (final id in _botPlayerIds) {
            if (!_state.voidCheckPassed.contains(id)) {
              _handlePlayerAction(
                  {'action': ActionType.confirmNoVoid, 'playerId': id});
              return;
            }
          }
        }

      case GamePhase.dashCall:
        final seat = _state.currentPlayerSeatIndex;
        final playerList =
            _state.players.where((p) => p.seatIndex == seat).toList();
        if (playerList.isEmpty) return;
        final bot = playerList.first;
        if (!_botPlayerIds.contains(bot.id)) return;

        final wantsDash = EstimationBotAi.shouldCallDash(bot);
        _handlePlayerAction({
          'action': ActionType.submitDashCall,
          'playerId': bot.id,
          'wantsDashCall': wantsDash,
        });

      case GamePhase.auction:
        final seat = _state.auctionTurnSeatIndex;
        final playerList =
            _state.players.where((p) => p.seatIndex == seat).toList();
        if (playerList.isEmpty) return;
        final bot = playerList.first;
        if (!_botPlayerIds.contains(bot.id)) return;

        final bid = EstimationBotAi.decideAuctionBid(_state, bot);
        if (bid != null) {
          _handlePlayerAction({
            'action': ActionType.submitBid,
            'playerId': bot.id,
            'bid': bid.toJson(),
          });
        } else {
          _handlePlayerAction(
              {'action': ActionType.passBid, 'playerId': bot.id});
        }

      case GamePhase.declarations:
        final seat = _state.currentPlayerSeatIndex;
        final playerList =
            _state.players.where((p) => p.seatIndex == seat).toList();
        if (playerList.isEmpty) return;
        final bot = playerList.first;
        if (!_botPlayerIds.contains(bot.id)) return;

        final decl = EstimationBotAi.decideDeclaration(_state, bot);
        _handlePlayerAction({
          'action': ActionType.submitDeclaration,
          'playerId': bot.id,
          'declared': decl,
        });

      case GamePhase.trickTaking:
        final seat = _state.currentPlayerSeatIndex;
        final playerList =
            _state.players.where((p) => p.seatIndex == seat).toList();
        if (playerList.isEmpty) return;
        final bot = playerList.first;
        if (!_botPlayerIds.contains(bot.id)) return;

        final chosen = EstimationBotAi.chooseCardToPlay(_state, bot);
        _handlePlayerAction({
          'action': ActionType.playCard,
          'playerId': bot.id,
          'card': chosen.toJson(),
        });

      default:
        break;
    }
  }
}
