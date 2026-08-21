// lib/networking/game_server.dart
//
// Host-side server: Runs the GameEngine and broadcasts state via Supabase Realtime.

import 'dart:async';
import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../core/ai/estimation_bot_ai.dart';
import '../core/game_engine.dart';
import '../core/models/bid.dart';
import '../core/models/card.dart';
import '../core/models/game_state.dart';
import '../core/models/player.dart';
import 'messages.dart';

typedef StateUpdateCallback = void Function(GameState state);

class GameServer {
  static final Random _rng = Random();

  final StateUpdateCallback onStateUpdate;
  
  String? hostPlayerId;
  String? hostName;
  late String roomId;
  int maxHumanPlayers = 4;
  int maxPlayers = 4;
  
  late GameState _state;
  RealtimeChannel? _channel;

  // Tracks the last phase we saved to DB; we only persist on transitions.
  GamePhase? _lastPersistedPhase;

  // ── Turn Timer Support ─────────────────────────────────────────
  Timer? _turnTimer;
  static const Duration _kTurnTimeout = Duration(seconds: 45);

  // ── Bot support ──────────────────────────────────────────────
  final Set<String> _botPlayerIds = {};
  bool _botProcessing = false;

  GameServer({required this.onStateUpdate});


  // ── Lifecycle ────────────────────────────────────────────────

  Future<void> start(String hostName, String hostPlayerId, String roomId, String hostPhoto, {int maxPlayers = 4}) async {
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
    _state = GameEngine.createInitialState([hostPlayer]);

    // Initialize Supabase Broadcast Channel
    _channel = Supabase.instance.client.channel('room_$roomId');
    
    // Listen for actions from clients
    _channel!.onBroadcast(
      event: 'action',
      callback: (payload) {
        final data = (payload.containsKey('payload') && payload['payload'] is Map<String, dynamic>)
            ? payload['payload'] as Map<String, dynamic>
            : payload;
        _handlePlayerAction(data);
      },
    );

    // Listen for join requests from clients
    _channel!.onBroadcast(
      event: 'joinRequest',
      callback: (payload) {
        final data = (payload.containsKey('payload') && payload['payload'] is Map<String, dynamic>)
            ? payload['payload'] as Map<String, dynamic>
            : payload;
        _handleJoinRequest(data);
      },
    );

    // Listen for leave requests from clients
    _channel!.onBroadcast(
      event: 'leaveRequest',
      callback: (payload) {
        final data = (payload.containsKey('payload') && payload['payload'] is Map<String, dynamic>)
            ? payload['payload'] as Map<String, dynamic>
            : payload;
        _handleLeaveRequest(data);
      },
    );

    // Listen for presence leave to automatically remove disconnected players
    _channel!.onPresenceLeave((payload) {
      if (_state.phase == GamePhase.lobby) {
        bool changed = false;
        for (final presence in payload.leftPresences) {
          final pId = presence.payload['playerId'] as String?;
          if (pId != null && pId != hostPlayerId) {
            final idx = _state.players.indexWhere((p) => p.id == pId);
            if (idx != -1) {
              _state.players.removeAt(idx);
              changed = true;
            }
          }
        }
        if (changed) {
          // Reassign seat indexes
          for (int i = 0; i < _state.players.length; i++) {
            _state.players[i] = _state.players[i].copyWith(seatIndex: i);
          }
          _broadcastState();
        }
      }
    });

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
    _turnTimer?.cancel();
    _turnTimer = null;
    await _channel?.unsubscribe();
    _channel = null;
  }

  int get playerCount => _state.players.length;

  // ── Bot players ──────────────────────────────────────────────

  /// Add [count] bot players filling remaining seats up to 4.
  void addBotPlayers({int count = 3}) {
    final toAdd = count.clamp(0, 4 - _state.players.length);
    for (int i = 1; i <= toAdd; i++) {
      final botId = 'bot_$i';
      final seatIndex = _state.players.length;
      _botPlayerIds.add(botId);
      _state.players.add(Player(
        id: botId,
        name: 'لاعب $i 🤖',
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
    final playerPhoto = payload['photo'] as String?;
    
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
      _state.players.add(Player(id: playerId, name: playerName, seatIndex: seat, photo: playerPhoto));
    } else if (playerPhoto != null && _state.players[existingIndex].photo != playerPhoto) {
      // Update photo if changed during reconnection
      _state.players[existingIndex] = _state.players[existingIndex].copyWith(photo: playerPhoto);
    }

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
    }
  }

  // ── Action handler ───────────────────────────────────────────

  void _handlePlayerAction(Map<String, dynamic> payload) {
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

      case ActionType.changeTheme:
        if (playerId == hostPlayerId && _state.phase == GamePhase.lobby) {
          final newTheme = payload['theme'] as String;
          _state.cardTheme = newTheme;
          _broadcastState();
        }

      case ActionType.approveRedeal:
        if (_state.phase == GamePhase.voidCheck && _state.voidDeclaringPlayerId != null) {
          _triggerRedeal();
        }

      case ActionType.rejectRedeal:
        if (_state.phase == GamePhase.voidCheck && _state.voidDeclaringPlayerId != null) {
          _state.voidRedealRejections.add(playerId);
          if (_state.voidRedealRejections.length >= maxPlayers) {
            // Everyone rejected the redeal. Resume voidCheck.
            _state.voidDeclaringPlayerId = null;
            _state.voidRedealRejections.clear();
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
          final decls = _state.players.map((p) => p.declared).where((d) => d != null).toList();
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
               Future.delayed(const Duration(seconds: 2), () {
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
    // Determine dealer for this round
    _state.dealerSeatIndex = (_state.roundNumber - 1) % maxPlayers;

    // The player to the right of the dealer acts first in the auction
    _state.auctionTurnSeatIndex =
        (_state.dealerSeatIndex + 1) % maxPlayers;

    _state.voidCheckPassed.clear();
    _state.voidDeclaringPlayerId = null;
    _state.voidRedealRejections.clear();
    GameEngine.dealCards(_state);

    // Persist each real player's private hand for reconnection recovery.
    _saveHandCards();

    // Automatically declare void if any player has an empty suit
    final playerWithVoid = _state.players
        .where((p) => p.hand.map((c) => c.suit).toSet().length < 4)
        .firstOrNull;
    if (playerWithVoid != null) {
      _state.voidDeclaringPlayerId = playerWithVoid.id;
    }

    _state.phase = GamePhase.voidCheck;
    _broadcastState();
  }

  void _triggerRedeal() {
    for (final p in _state.players) {
      p.resetForRound();
    }
    _state.currentHighBid = null;
    _state.currentHighBidderPlayerId = null;
    _state.bidderPlayerId = null;
    _state.trumpSuit = null;
    _state.currentTrick = [];
    _state.tricksPlayedThisRound = 0;
    _state.voidCheckPassed = {};
    _state.voidDeclaringPlayerId = null;
    _state.voidRedealRejections.clear();
    _doDeal();
  }

  // ── Broadcast ────────────────────────────────────────────────

  void _broadcastState() {
    final payload = _state.toJson();
    _channel?.sendBroadcastMessage(
      event: 'state',
      payload: payload,
    );
    onStateUpdate(_state);
    _scheduleBotTurn();
    _resetTurnTimer();

    // Persist a snapshot on phase change or phase snapshot updates
    if (_state.phase != _lastPersistedPhase) {
      _lastPersistedPhase = _state.phase;
      _persistSnapshotAndHands();
    }
  }

  void _persistSnapshotAndHands() {
    _persistPhaseSnapshot();
    _saveHandCards();
  }

  // ── Turn Timeout Handling ─────────────────────────────────────

  void _resetTurnTimer() {
    _turnTimer?.cancel();
    _turnTimer = null;

    if (_state.phase == GamePhase.dashCall) {
      final activePlayer = _state.playerBySeat(_state.currentPlayerSeatIndex);
      if (!_botPlayerIds.contains(activePlayer.id)) {
        _turnTimer = Timer(_kTurnTimeout, _handleTurnTimeout);
      }
    } else if (_state.phase == GamePhase.auction) {
      final activePlayer = _state.playerBySeat(_state.auctionTurnSeatIndex);
      if (!_botPlayerIds.contains(activePlayer.id)) {
        _turnTimer = Timer(_kTurnTimeout, _handleTurnTimeout);
      }
    } else if (_state.phase == GamePhase.declarations) {
      final activePlayer = _state.playerBySeat(_state.currentPlayerSeatIndex);
      if (activePlayer.declared == null && !_botPlayerIds.contains(activePlayer.id)) {
        _turnTimer = Timer(_kTurnTimeout, _handleTurnTimeout);
      }
    } else if (_state.phase == GamePhase.trickTaking) {
      if (_state.currentTrick.length < maxPlayers) {
        final activePlayer = _state.playerBySeat(_state.currentPlayerSeatIndex);
        if (!_botPlayerIds.contains(activePlayer.id)) {
          _turnTimer = Timer(_kTurnTimeout, _handleTurnTimeout);
        }
      }
    }
  }

  void _handleTurnTimeout() {
    debugPrint('[Server] Turn timeout triggered for phase: ${_state.phase.name}');
    switch (_state.phase) {
      case GamePhase.dashCall:
        final activePlayer = _state.playerBySeat(_state.currentPlayerSeatIndex);
        debugPrint('[Server] Timing out dash call turn for ${activePlayer.name}');
        _handlePlayerAction({
          'action': ActionType.submitDashCall,
          'playerId': activePlayer.id,
          'wantsDashCall': false,
        });

      case GamePhase.auction:
        final activePlayer = _state.playerBySeat(_state.auctionTurnSeatIndex);
        debugPrint('[Server] Timing out auction turn for ${activePlayer.name}');
        _handlePlayerAction({'action': ActionType.passBid, 'playerId': activePlayer.id});

      case GamePhase.declarations:
        final activePlayer = _state.playerBySeat(_state.currentPlayerSeatIndex);
        debugPrint('[Server] Timing out declaration turn for ${activePlayer.name}');
        int minDecl = 0;
        if (activePlayer.id == _state.bidderPlayerId && _state.currentHighBid != null) {
          minDecl = _state.currentHighBid!.trickCount;
        }
        final decls = _state.players.map((p) => p.declared).where((d) => d != null).toList();
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
        debugPrint('[Server] Timing out trickTaking turn for ${activePlayer.name}');
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
    Supabase.instance.client
        .rpc('save_game_state', params: {
          'p_room_id': roomId,
          'p_state':   _state.toJson(),
        })
        .catchError(
          (e) => debugPrint('[Server] Phase snapshot persist failed: $e'),
        );
  }

  /// Fire-and-forget: save every real player's hand after a deal.
  /// Bots are skipped — their hands are never private.
  void _saveHandCards() {
    if (roomId.startsWith('test_')) return;
    for (final player in _state.players) {
      if (player.id.startsWith('bot_')) continue;
      Supabase.instance.client
          .rpc('save_player_hand', params: {
            'p_room_id':    roomId,
            'p_player_id':  player.id,
            'p_hand_cards': player.hand.map((c) => c.toJson()).toList(),
          })
          .catchError(
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

    _channel!.onPresenceLeave((payload) {
      // During lobby: remove players who disconnected and never came back.
      if (_state.phase == GamePhase.lobby) {
        bool changed = false;
        for (final presence in payload.leftPresences) {
          final pId = presence.payload['playerId'] as String?;
          if (pId != null && pId != hostPlayerId) {
            final idx = _state.players.indexWhere((p) => p.id == pId);
            if (idx != -1) {
              _state.players.removeAt(idx);
              changed = true;
            }
          }
        }
        if (changed) {
          for (int i = 0; i < _state.players.length; i++) {
            _state.players[i] = _state.players[i].copyWith(seatIndex: i);
          }
          _broadcastState();
        }
      }
    });

    _channel!.subscribe((status, [error]) async {
      if (status == RealtimeSubscribeStatus.subscribed) {
        await _channel!.track({'playerId': hostPlayerId, 'name': hostName});
        // Re-announce state immediately so clients don't wait for next action.
        _broadcastState();
      }
    });

    onStateUpdate(_state);
    debugPrint('[Server] Restored from persisted state — phase: ${_state.phase.name}');
  }

  // ── Bot AI ───────────────────────────────────────────────────

  void _scheduleBotTurn() {
    if (_botProcessing || _botPlayerIds.isEmpty) return;
    if (!_isBotTurnNeeded()) return;

    _botProcessing = true;
    final delay = 600 + _rng.nextInt(600);
    Future.delayed(Duration(milliseconds: delay), () {
      _botProcessing = false;
      _executeBotAction();
    });
  }

  bool _isBotTurnNeeded() {
    switch (_state.phase) {
      case GamePhase.voidCheck:
        if (_state.voidDeclaringPlayerId != null) {
          return _botPlayerIds.any((id) => !_state.voidRedealRejections.contains(id));
        }
        return _botPlayerIds.any((id) => !_state.voidCheckPassed.contains(id));

      case GamePhase.dashCall:
        final seat = _state.currentPlayerSeatIndex;
        final players = _state.players.where((p) => p.seatIndex == seat);
        return players.isNotEmpty &&
            _botPlayerIds.contains(players.first.id);

      case GamePhase.auction:
        final seat = _state.auctionTurnSeatIndex;
        final players = _state.players.where((p) => p.seatIndex == seat);
        return players.isNotEmpty &&
            _botPlayerIds.contains(players.first.id);

      case GamePhase.declarations:
        final seat = _state.currentPlayerSeatIndex;
        final players = _state.players.where((p) => p.seatIndex == seat);
        return players.isNotEmpty && _botPlayerIds.contains(players.first.id);

      case GamePhase.trickTaking:
        if (_state.currentTrick.length == 4) return false; // Waiting to clear trick
        final seat = _state.currentPlayerSeatIndex;
        final players = _state.players.where((p) => p.seatIndex == seat);
        return players.isNotEmpty &&
            _botPlayerIds.contains(players.first.id);

      default:
        return false;
    }
  }

  void _executeBotAction() {
    switch (_state.phase) {
      case GamePhase.voidCheck:
        if (_state.voidDeclaringPlayerId != null) {
          for (final id in _botPlayerIds) {
            if (!_state.voidRedealRejections.contains(id)) {
              final bot = _state.players.where((p) => p.id == id).firstOrNull;
              if (bot == null) continue;
              if (id == _state.voidDeclaringPlayerId) {
                _handlePlayerAction({'action': ActionType.approveRedeal, 'playerId': id});
              } else {
                final approve = EstimationBotAi.shouldApproveRedeal(bot, _state);
                _handlePlayerAction({
                  'action': approve ? ActionType.approveRedeal : ActionType.rejectRedeal,
                  'playerId': id,
                });
              }
              return;
            }
          }
        } else {
          for (final id in _botPlayerIds) {
            if (!_state.voidCheckPassed.contains(id)) {
              _handlePlayerAction({'action': ActionType.confirmNoVoid, 'playerId': id});
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
          _handlePlayerAction({'action': ActionType.passBid, 'playerId': bot.id});
        }

      case GamePhase.declarations:
        final seat = _state.currentPlayerSeatIndex;
        final playerList = _state.players.where((p) => p.seatIndex == seat).toList();
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
