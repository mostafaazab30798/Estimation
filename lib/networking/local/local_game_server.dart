// lib/networking/local/local_game_server.dart

import 'dart:async';
import 'dart:io';
import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:shelf/shelf_io.dart' as shelf_io;
import 'package:shelf_web_socket/shelf_web_socket.dart';
import 'package:web_socket_channel/web_socket_channel.dart';

import '../../core/ai/estimation_bot_ai.dart';
import '../../core/game_engine.dart';
import '../../core/models/bid.dart';
import '../../core/models/card.dart';
import '../../core/models/game_state.dart';
import '../../core/models/player.dart';
import '../messages.dart';

typedef StateUpdateCallback = void Function(GameState state);

class LocalGameServer {
  static final Random _rng = Random();

  final StateUpdateCallback onStateUpdate;

  String? hostPlayerId;
  String? hostName;
  late String roomId;
  int maxPlayers = 4;
  int boundPort = 7890;

  late GameState _state;
  HttpServer? _server;
  final Map<String, WebSocketChannel> _clientSockets = {}; // playerId -> socket
  final Set<WebSocketChannel> _unidentifiedSockets = {};

  // ── Turn Timer Support ─────────────────────────────────────────
  Timer? _turnTimer;
  static const Duration _kTurnTimeout = Duration(seconds: 45);

  // ── Bot support ──────────────────────────────────────────────
  final Set<String> _botPlayerIds = {};
  bool _botProcessing = false;

  LocalGameServer({required this.onStateUpdate});

  // ── Lifecycle ────────────────────────────────────────────────

  Future<void> start(
    String hostName,
    String hostPlayerId,
    String roomId,
    String hostPhoto, {
    int maxPlayers = 4,
    int port = 7890,
  }) async {
    this.hostName = hostName;
    this.hostPlayerId = hostPlayerId;
    this.roomId = roomId;
    this.maxPlayers = maxPlayers;

    final hostPlayer = Player(
      id: hostPlayerId,
      name: hostName,
      seatIndex: 0,
      photo: hostPhoto,
    );
    _state = GameEngine.createInitialState([hostPlayer]);

    // Start Shelf WebSocket HTTP server
    final handler = webSocketHandler((WebSocketChannel webSocket) {
      _handleNewSocket(webSocket);
    });

    try {
      _server = await shelf_io.serve(handler, InternetAddress.anyIPv4, port);
      boundPort = _server!.port;
      debugPrint('[LocalGameServer] Bound WebSocket server to port $boundPort');
    } catch (e) {
      // If requested port fails, bind to any available port (0)
      _server = await shelf_io.serve(handler, InternetAddress.anyIPv4, 0);
      boundPort = _server!.port;
      debugPrint('[LocalGameServer] Fallback bind to port $boundPort (error: $e)');
    }

    onStateUpdate(_state);
  }

  Future<void> stop() async {
    _turnTimer?.cancel();
    _turnTimer = null;

    for (final socket in _clientSockets.values) {
      try {
        socket.sink.close();
      } catch (_) {}
    }
    _clientSockets.clear();

    for (final socket in _unidentifiedSockets) {
      try {
        socket.sink.close();
      } catch (_) {}
    }
    _unidentifiedSockets.clear();

    await _server?.close(force: true);
    _server = null;
    debugPrint('[LocalGameServer] Server stopped');
  }

  int get playerCount => _state.players.length;

  void addBotPlayers({int count = 3}) {
    final toAdd = count.clamp(0, maxPlayers - _state.players.length);
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

  // ── Socket & Connection handling ────────────────────────────────

  void _handleNewSocket(WebSocketChannel socket) {
    _unidentifiedSockets.add(socket);
    String? associatedPlayerId;

    socket.stream.listen(
      (data) {
        if (data is String) {
          try {
            final msg = GameMessage.fromJsonString(data);
            associatedPlayerId = _processMessage(socket, msg, associatedPlayerId);
          } catch (e) {
            debugPrint('[LocalGameServer] Error parsing frame: $e');
          }
        }
      },
      onDone: () {
        _handleSocketClosed(socket, associatedPlayerId);
      },
      onError: (err) {
        _handleSocketClosed(socket, associatedPlayerId);
      },
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
      debugPrint('[LocalGameServer] Socket closed for player: $playerId');
      if (_state.phase == GamePhase.lobby) {
        _handleLeaveRequest({'playerId': playerId});
      } else {
        debugPrint('[LocalGameServer] Mid-game disconnect for $playerId — keeping seat intact');
      }
    }
  }

  void _handleJoinRequest(Map<String, dynamic> payload) {
    final playerId = payload['playerId'] as String;
    final playerName = payload['name'] as String;
    final playerPhoto = payload['photo'] as String?;

    final existingIndex = _state.players.indexWhere((p) => p.id == playerId);

    if (existingIndex == -1) {
      if (_state.phase != GamePhase.lobby) {
        _sendErrorToPlayer(playerId, 'اللعبة بدأت بالفعل');
        return;
      }
      if (_state.players.length >= maxPlayers) {
        _sendErrorToPlayer(playerId, 'الغرفة ممتلئة');
        return;
      }
      final seat = _state.players.length;
      _state.players.add(Player(id: playerId, name: playerName, seatIndex: seat, photo: playerPhoto));
    } else if (playerPhoto != null && _state.players[existingIndex].photo != playerPhoto) {
      _state.players[existingIndex] = _state.players[existingIndex].copyWith(photo: playerPhoto);
    }

    _broadcastState();
  }

  void _sendErrorToPlayer(String playerId, String errorMsg) {
    final socket = _clientSockets[playerId];
    if (socket != null) {
      socket.sink.add(GameMessage(
        type: MessageType.error,
        payload: {'error': errorMsg},
      ).toJsonString());
    }
  }

  void _handleLeaveRequest(Map<String, dynamic> payload) {
    final playerId = payload['playerId'] as String;
    if (_state.phase == GamePhase.lobby) {
      _state.players.removeWhere((p) => p.id == playerId);
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
        if (playerId == hostPlayerId && _state.phase == GamePhase.lobby) {
          _state.phase = GamePhase.dealing;
          _doDeal();
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
            _state.voidDeclaringPlayerId = null;
            _state.voidRedealRejections.clear();
          }
          _broadcastState();
        }

      case ActionType.confirmNoVoid:
        if (_state.phase == GamePhase.voidCheck) {
          _state.voidCheckPassed.add(playerId);
          if (_state.voidCheckPassed.length == maxPlayers) {
            _state.phase = GamePhase.auction;
            if (_state.voidCheckPassed.isNotEmpty) {
              final firstReadyId = _state.voidCheckPassed.first;
              _state.auctionTurnSeatIndex = _state.playerById(firstReadyId).seatIndex;
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
            _broadcastState();
            return;
          }
          final declared = payload['declared'] as int;
          final decls = _state.players.map((p) => p.declared).where((d) => d != null).toList();
          if (decls.length == 3) {
            final sum = decls.fold<int>(0, (a, b) => a + b!);
            if (sum + declared == 13) {
              _broadcastState();
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
            _broadcastState();
            return;
          }
          final card = PlayingCard.fromJson(payload['card'] as Map<String, dynamic>);
          final player = _state.playerById(playerId);
          if (GameEngine.canPlayCard(_state, player, card)) {
            final finished = GameEngine.playCard(_state, playerId, card);
            if (finished) {
              _broadcastState();
              Future.delayed(const Duration(seconds: 2), () {
                GameEngine.resolveTrick(_state);
                if (_state.phase == GamePhase.scoring) {
                  GameEngine.computeAndApplyScores(_state);
                }
                _broadcastState();
              });
            } else {
              _broadcastState();
            }
          } else {
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
            return;
          }
          _broadcastState();
        }
    }
  }

  void _maybeSkipDeclarations() {
    final nonBidders = _state.players.where((p) => p.id != _state.bidderPlayerId);
    if (nonBidders.every((p) => p.declared != null)) {
      _state.phase = GamePhase.trickTaking;
    }
  }

  void _doDeal() {
    _state.dealerSeatIndex = (_state.roundNumber - 1) % maxPlayers;
    _state.auctionTurnSeatIndex = (_state.dealerSeatIndex + 1) % maxPlayers;

    _state.voidCheckPassed.clear();
    _state.voidDeclaringPlayerId = null;
    _state.voidRedealRejections.clear();
    GameEngine.dealCards(_state);

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
    final msg = GameMessage(
      type: MessageType.stateUpdate,
      payload: _state.toJson(),
    ).toJsonString();

    for (final socket in _clientSockets.values) {
      try {
        socket.sink.add(msg);
      } catch (e) {
        debugPrint('[LocalGameServer] Broadcast frame error: $e');
      }
    }

    onStateUpdate(_state);
    _scheduleBotTurn();
    _resetTurnTimer();
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
      if (_state.currentTrick.length < maxPlayers) {
        final activePlayer = _state.playerBySeat(_state.currentPlayerSeatIndex);
        if (!_botPlayerIds.contains(activePlayer.id)) {
          _turnTimer = Timer(_kTurnTimeout, _handleTurnTimeout);
        }
      }
    }
  }

  void _handleTurnTimeout() {
    switch (_state.phase) {
      case GamePhase.auction:
        final activePlayer = _state.playerBySeat(_state.auctionTurnSeatIndex);
        _handlePlayerAction({'action': ActionType.passBid, 'playerId': activePlayer.id});

      case GamePhase.declarations:
        final activePlayer = _state.playerBySeat(_state.currentPlayerSeatIndex);
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

  void sendHostAction(String action, Map<String, dynamic> extra) {
    _handlePlayerAction({
      'action': action,
      'playerId': hostPlayerId,
      ...extra,
    });
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
        return players.isNotEmpty && _botPlayerIds.contains(players.first.id);

      case GamePhase.declarations:
        final seat = _state.currentPlayerSeatIndex;
        final players = _state.players.where((p) => p.seatIndex == seat);
        return players.isNotEmpty && _botPlayerIds.contains(players.first.id);

      case GamePhase.trickTaking:
        if (_state.currentTrick.length == 4) return false;
        final seat = _state.currentPlayerSeatIndex;
        final players = _state.players.where((p) => p.seatIndex == seat);
        return players.isNotEmpty && _botPlayerIds.contains(players.first.id);

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

      case GamePhase.auction:
        final seat = _state.auctionTurnSeatIndex;
        final playerList = _state.players.where((p) => p.seatIndex == seat).toList();
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
        final playerList = _state.players.where((p) => p.seatIndex == seat).toList();
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
