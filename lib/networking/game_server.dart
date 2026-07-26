// lib/networking/game_server.dart
//
// Host-side server: Runs the GameEngine and broadcasts state via Supabase Realtime.

import 'dart:async';
import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../core/constants.dart';
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

  Future<void> start(String hostName, String hostPlayerId, String roomId, String hostPhoto) async {
    this.hostName = hostName;
    this.hostPlayerId = hostPlayerId;
    this.roomId = roomId;

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
        _handlePlayerAction(payload);
      },
    );

    // Listen for join requests from clients
    _channel!.onBroadcast(
      event: 'joinRequest',
      callback: (payload) {
        _handleJoinRequest(payload);
      },
    );

    // Listen for leave requests from clients
    _channel!.onBroadcast(
      event: 'leaveRequest',
      callback: (payload) {
        _handleLeaveRequest(payload);
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

  // ── Bot players ──────────────────────────────────────────────

  /// Add [count] bot players filling remaining seats (max 3).
  void addBotPlayers({int count = 3}) {
    final toAdd = count.clamp(0, kPlayerCount - _state.players.length);
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
      if (_state.players.length >= kPlayerCount) {
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
        // Only the host can start. The player-count check is done in the UI
        // (via roomPlayers from Supabase), so we trust it here.
        if (playerId == hostPlayerId && _state.phase == GamePhase.lobby) {
          // Ensure all joined players are in _state; if some are
          // missing (race condition), we still proceed – the deal fills hands.
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
          if (_state.voidRedealRejections.length >= kPlayerCount) {
            // Everyone rejected the redeal. Resume voidCheck.
            _state.voidDeclaringPlayerId = null;
            _state.voidRedealRejections.clear();
          }
          _broadcastState();
        }

      case ActionType.confirmNoVoid:
        if (_state.phase == GamePhase.voidCheck) {
          _state.voidCheckPassed.add(playerId);
          if (_state.voidCheckPassed.length == kPlayerCount) {
            _state.phase = GamePhase.auction;
            if (_state.voidCheckPassed.isNotEmpty) {
              final firstReadyId = _state.voidCheckPassed.first;
              _state.auctionTurnSeatIndex =
                  _state.playerById(firstReadyId).seatIndex;
            }
          }
          _broadcastState();
        }

      case ActionType.unready:
        if (_state.phase == GamePhase.voidCheck) {
          _state.voidCheckPassed.remove(playerId);
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
          if (_state.currentTrick.length == kPlayerCount) {
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
    _state.dealerSeatIndex = (_state.roundNumber - 1) % kPlayerCount;

    // The player to the right of the dealer acts first in the auction
    _state.auctionTurnSeatIndex =
        (_state.dealerSeatIndex + 1) % kPlayerCount;

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

    if (_state.phase == GamePhase.auction) {
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
      if (_state.currentTrick.length < kPlayerCount) {
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
    final validCards = player.hand
        .where((card) => GameEngine.canPlayCard(_state, player, card))
        .toList();
    if (validCards.isEmpty) return;

    // Play lowest legal card to minimize impact on player
    validCards.sort((a, b) => a.rank.sortIndex.compareTo(b.rank.sortIndex));
    final chosen = validCards.first;

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
    _state = state;
    _lastPersistedPhase = state.phase; // Avoid re-persisting the same phase

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
              if (id == _state.voidDeclaringPlayerId) {
                _handlePlayerAction({'action': ActionType.approveRedeal, 'playerId': id});
              } else {
                _handlePlayerAction({'action': ActionType.rejectRedeal, 'playerId': id});
              }
              return;
            }
          }
        } else {
          // First bot that hasn't confirmed
          for (final id in _botPlayerIds) {
            if (!_state.voidCheckPassed.contains(id)) {
              _handlePlayerAction(
                  {'action': ActionType.confirmNoVoid, 'playerId': id});
              return;
            }
          }
        }

      case GamePhase.auction:
        final seat = _state.auctionTurnSeatIndex;
        final playerList =
            _state.players.where((p) => p.seatIndex == seat).toList();
        if (playerList.isEmpty) return;
        final botId = playerList.first.id;
        if (!_botPlayerIds.contains(botId)) return;
        _botMakeBid(botId);

      case GamePhase.declarations:
        final seat = _state.currentPlayerSeatIndex;
        final playerList = _state.players.where((p) => p.seatIndex == seat).toList();
        if (playerList.isEmpty) return;
        
        final botId = playerList.first.id;
        if (!_botPlayerIds.contains(botId)) return;
        
        final decls = _state.players.map((p) => p.declared).where((d) => d != null).toList();
        int? forbidden;
        if (decls.length == 3) {
          final sum = decls.fold<int>(0, (a, b) => a + b!);
          forbidden = 13 - sum;
        }
        
        int decl;
        do {
          decl = _rng.nextInt(5); // 0–4
        } while (decl == forbidden);

        _handlePlayerAction({
          'action': ActionType.submitDeclaration,
          'playerId': botId,
          'declared': decl,
        });
        return;

      case GamePhase.trickTaking:
        final seat = _state.currentPlayerSeatIndex;
        final playerList =
            _state.players.where((p) => p.seatIndex == seat).toList();
        if (playerList.isEmpty) return;
        final bot = playerList.first;
        if (!_botPlayerIds.contains(bot.id)) return;
        _botPlayCard(bot);

      default:
        break;
    }
  }

  void _botMakeBid(String botId) {
    final current = _state.currentHighBid;

    // For testing, only force pass if current bid is high (>= 5 tricks)
    if (current != null && current.trickCount >= 5) {
      _handlePlayerAction({'action': ActionType.passBid, 'playerId': botId});
      return;
    }

    // Small chance to pass randomly (20%) so the auction ends organically
    if (current != null && _rng.nextDouble() < 0.20) {
      _handlePlayerAction({'action': ActionType.passBid, 'playerId': botId});
      return;
    }

    // Find a valid bid
    final suits = Suit.values.toList()
      ..sort((a, b) => b.priority.compareTo(a.priority)); // Highest priority first
      
    // Start searching from current trick count or 4
    final startTc = (current?.trickCount ?? 4);
    
    for (int tc = startTc; tc <= 5; tc++) {
      // Reverse suits so we search from lowest to highest priority to increment gradually
      for (final suit in suits.reversed) {
        final bid = Bid(trickCount: tc, trumpSuit: suit);
        if (GameEngine.isValidBid(bid, current)) {
          // Found the lowest possible valid bid to increment the auction gradually!
          _handlePlayerAction({
            'action': ActionType.submitBid,
            'playerId': botId,
            'bid': bid.toJson(),
          });
          return;
        }
      }
    }
    
    // Fall back to pass if we couldn't find a valid bid under 6
    _handlePlayerAction({'action': ActionType.passBid, 'playerId': botId});
  }

  void _botPlayCard(Player bot) {
    // Collect valid cards
    final validCards = bot.hand
        .where((card) => GameEngine.canPlayCard(_state, bot, card))
        .toList();
    if (validCards.isEmpty) return;

    // Prefer winning the trick if possible, otherwise play lowest
    PlayingCard chosen;
    if (_state.currentTrick.isEmpty) {
      // Lead: play highest card
      validCards.sort(
          (a, b) => b.rank.sortIndex.compareTo(a.rank.sortIndex));
      chosen = validCards.first;
    } else {
      // Try to win; if can't, play lowest
      final ledSuit = _state.currentTrick.first.card.suit;
      final trump = _state.trumpSuit;
      final ledCards = validCards.where((c) => c.suit == ledSuit).toList();
      final trumpCards = validCards.where((c) => c.suit == trump).toList();

      if (ledCards.isNotEmpty) {
        ledCards.sort(
            (a, b) => b.rank.sortIndex.compareTo(a.rank.sortIndex));
        chosen = ledCards.first;
      } else if (trumpCards.isNotEmpty) {
        trumpCards.sort(
            (a, b) => a.rank.sortIndex.compareTo(b.rank.sortIndex));
        chosen = trumpCards.first; // play lowest trump
      } else {
        validCards.sort(
            (a, b) => a.rank.sortIndex.compareTo(b.rank.sortIndex));
        chosen = validCards.first; // play lowest off-suit
      }
    }

    _handlePlayerAction({
      'action': ActionType.playCard,
      'playerId': bot.id,
      'card': chosen.toJson(),
    });
  }
}
