// lib/providers/game_provider.dart
//
// Central state manager. Bridges networking layer ↔ UI.

import 'dart:async';
import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart' show rootBundle, AssetManifest;
import 'package:uuid/uuid.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../core/models/game_state.dart';
import '../core/models/card.dart';
import '../core/models/bid.dart';
import '../core/models/player.dart';
import '../networking/game_server.dart';
import '../networking/game_client.dart';
import '../networking/messages.dart';
import '../modes/ninety_nine/networking/ninety_nine_game_server.dart';
import '../modes/ninety_nine/networking/ninety_nine_game_client.dart';
import '../modes/ninety_nine/presentation/providers/ninety_nine_game_provider.dart';
import '../features/lobby/data/lobby_repository.dart';
import '../features/lobby/domain/models/game_room.dart';
import '../features/lobby/domain/models/room_player.dart';
import '../services/session_storage_service.dart';
import '../services/profile_service.dart';

import '../networking/local/local_game_server.dart';
import '../networking/local/local_game_client.dart';
import '../modes/ninety_nine/networking/local_ninety_nine_game_server.dart';
import '../modes/ninety_nine/networking/local_ninety_nine_game_client.dart';
import '../networking/local/local_discovery_service.dart';

enum ConnectionRole { none, host, client }

enum ConnectionStatus { idle, connecting, connected, error }

enum ConnectionTransport { online, local }

class GameProvider extends ChangeNotifier {
  final _uuid = const Uuid();
  final _lobbyRepo = LobbyRepository();
  final _sessionService = SessionStorageService();

  GameProvider() {
    _loadAvailableThemes();
  }

  GameState? _state;
  ConnectionRole _role = ConnectionRole.none;
  ConnectionStatus _status = ConnectionStatus.idle;
  String _errorMessage = '';

  GameServer? _server;
  GameClient? _client;
  NinetyNineGameServer? _nnServer;
  NinetyNineGameClient? _nnClient;
  NinetyNineGameProvider? nnProvider;

  String? _myPlayerId; // Supabase auth uid
  String _myName = '';
  bool _isSearching = false;
  bool _isTestMode = false;
  int _expectedPlayers = 4;

  ConnectionTransport _transport = ConnectionTransport.online;
  LocalGameServer? _localServer;
  LocalGameClient? _localClient;
  LocalNinetyNineGameServer? _localNnServer;
  LocalNinetyNineGameClient? _localNnClient;
  final LocalDiscoveryService _discoveryService = LocalDiscoveryService();
  String? _localHostIp;
  int _localPort = 7890;

  // Supabase Lobby State
  GameRoom? _currentRoom;
  List<RoomPlayer> _roomPlayers = [];
  StreamSubscription? _roomSub;
  StreamSubscription? _playersSub;

  // ── Getters ───────────────────────────────────────────────────

  GameState? get state => _state;
  ConnectionRole get role => _role;
  ConnectionStatus get status => _status;
  ConnectionTransport get transport => _transport;
  bool get isLocal => _transport == ConnectionTransport.local;
  String? get localHostIp => _localHostIp;
  int get localPort => _localPort;
  String get errorMessage => _errorMessage;
  String get myPlayerId => _myPlayerId ?? '';
  String get myName => _myName;
  bool get isHost => _role == ConnectionRole.host;
  bool get isSearching => _isSearching;
  bool get isTestMode => _isTestMode;
  int get expectedPlayers => _expectedPlayers;

  /// The room code to share with other players (host only).
  String? get gameCode => _currentRoom?.roomCode;

  GameRoom? get currentRoom => _currentRoom;
  List<RoomPlayer> get roomPlayers => _roomPlayers;

  NinetyNineGameClient? get nnClient => _nnClient;

  List<String> _availableThemes = ['theme_1', 'theme_2'];
  List<String> get availableThemes => _availableThemes;

  Future<void> _loadAvailableThemes() async {
    try {
      final manifest = await AssetManifest.loadFromAssetBundle(rootBundle);
      final assets = manifest.listAssets();
      
      final themes = <String>{};
      for (final path in assets) {
        if (path.startsWith('assets/theme_')) {
          final parts = path.split('/');
          if (parts.length >= 2) {
            themes.add(parts[1]);
          }
        }
      }
      
      if (themes.isNotEmpty) {
        _availableThemes = themes.toList()..sort();
        notifyListeners();
      }
    } catch (e) {
      debugPrint('Error loading themes: $e');
    }
  }

  Player? get me =>
      _state?.players.where((p) => p.id == myPlayerId).firstOrNull;

  GamePhase get phase => _state?.phase ?? GamePhase.lobby;

  bool get isMyTurn {
    if (_state == null || me == null) return false;
    switch (_state!.phase) {
      case GamePhase.auction:
        return _state!.auctionTurnSeatIndex == me!.seatIndex;
      case GamePhase.trickTaking:
        return _state!.currentPlayerSeatIndex == me!.seatIndex;
      case GamePhase.declarations:
        return _state!.currentPlayerSeatIndex == me!.seatIndex && me!.declared == null;
      case GamePhase.voidCheck:
        return !_state!.voidCheckPassed.contains(myPlayerId);
      default:
        return false;
    }
  }

  bool get amBidder => _state?.bidderPlayerId == myPlayerId;

  List<PlayingCard> get myHand => me?.hand ?? [];

  // ── Supabase Lobby Streams ─────────────────────────────────────

  /// Returns true when the game is actively in progress (past lobby).
  /// Used to distinguish transient mid-game network blips from fatal
  /// pre-game connection failures.
  bool get _isGameInProgress =>
      _state != null && _state!.phase != GamePhase.lobby;

  void _listenToRoom(String roomId) {
    _roomSub?.cancel();
    _roomSub = _lobbyRepo.watchRoom(roomId).listen(
      (room) {
        _currentRoom = room;
        _expectedPlayers = room.maxPlayers;
        // Automatically sync state if status changed to playing
        if (room.status == GameRoomStatus.playing) {
          if (_state == null && !isHost) {
            requestStateSync();
          }
        } else if (room.status == GameRoomStatus.cancelled) {
          _setError('تم إلغاء الغرفة من قبل المضيف');
        }
        notifyListeners();
      },
      onError: (err) {
        // Mid-game Supabase auth/network errors (e.g. token-refresh timeout)
        // are transient and must NOT terminate an in-progress game session.
        // Only treat them as fatal during the lobby phase.
        if (_isGameInProgress) {
          debugPrint('[GameProvider] Room stream error (non-fatal mid-game): $err');
        } else {
          _setError('حدث خطأ في الغرفة: $err');
        }
      },
    );

    _playersSub?.cancel();
    _playersSub = _lobbyRepo.watchRoomPlayers(roomId).listen(
      (players) {
        _roomPlayers = players;
        notifyListeners();
      },
      onError: (err) {
        // Same: player-list stream errors mid-game are non-fatal.
        if (_isGameInProgress) {
          debugPrint('[GameProvider] Players stream error (non-fatal mid-game): $err');
        } else {
          _setError('حدث خطأ في اللاعبين: $err');
        }
      },
    );
  }

  // ── Local (LAN / Hotspot) Hosting & Joining ──────────────────────────────

  Future<void> hostLocalGame(
    String name, {
    int expectedPlayers = 4,
    String gameType = 'kotchina',
    int port = 7890,
  }) async {
    await reset();
    _transport = ConnectionTransport.local;
    _myPlayerId = Supabase.instance.client.auth.currentUser?.id ?? _uuid.v4();
    nnProvider?.setPlayerId(_myPlayerId!);
    _myName = name;
    _role = ConnectionRole.host;
    _isTestMode = false;
    _expectedPlayers = expectedPlayers;
    _status = ConnectionStatus.connecting;
    notifyListeners();

    try {
      final ip = await LocalDiscoveryService.getLocalIpAddress();
      _localHostIp = ip ?? '127.0.0.1';
      _localPort = port;
      final roomCode = _generateRoomCode();

      _currentRoom = GameRoom(
        id: 'local_${_uuid.v4()}',
        roomCode: roomCode,
        hostId: _myPlayerId!,
        status: GameRoomStatus.waiting,
        maxPlayers: expectedPlayers,
        hostIp: _localHostIp!,
        wsPort: _localPort,
        gameType: gameType,
        createdAt: DateTime.now(),
      );

      final myPhoto = await ProfileService.getProfilePhoto();

      if (gameType == 'ninety_nine') {
        _localNnServer = LocalNinetyNineGameServer(
          onStateUpdate: (state) {
            nnProvider?.syncState(state);
          },
        );
        await _localNnServer!.start(
          name,
          _myPlayerId!,
          _currentRoom!.id,
          myPhoto,
          maxPlayers: expectedPlayers,
          port: port,
        );
        _localPort = _localNnServer!.boundPort;
      } else {
        _localServer = LocalGameServer(
          onStateUpdate: (state) {
            _state = state;
            notifyListeners();
          },
        );
        await _localServer!.start(
          name,
          _myPlayerId!,
          _currentRoom!.id,
          myPhoto,
          maxPlayers: expectedPlayers,
          port: port,
        );
        _localPort = _localServer!.boundPort;
      }

      await _discoveryService.startBroadcasting(
        hostName: name,
        port: _localPort,
        gameType: gameType,
        roomCode: roomCode,
        currentPlayers: 1,
        maxPlayers: expectedPlayers,
      );

      _status = ConnectionStatus.connected;
      notifyListeners();
    } catch (e) {
      _setError('فشل تشغيل الخادم المحلي: $e');
    }
  }

  Future<void> joinLocalGame(
    String name,
    String hostIp,
    int port, {
    String? expectedGameType,
  }) async {
    await reset();
    _transport = ConnectionTransport.local;
    _myPlayerId = Supabase.instance.client.auth.currentUser?.id ?? _uuid.v4();
    nnProvider?.setPlayerId(_myPlayerId!);
    _myName = name;
    _role = ConnectionRole.client;
    _isTestMode = false;
    _status = ConnectionStatus.connecting;
    notifyListeners();

    try {
      _currentRoom = GameRoom(
        id: 'local_client_${_uuid.v4()}',
        roomCode: 'LOCAL',
        hostId: 'host_local',
        status: GameRoomStatus.waiting,
        maxPlayers: 4,
        hostIp: hostIp,
        wsPort: port,
        gameType: expectedGameType ?? 'kotchina',
        createdAt: DateTime.now(),
      );

      final myPhoto = await ProfileService.getProfilePhoto();

      if (expectedGameType == 'ninety_nine') {
        _localNnClient = LocalNinetyNineGameClient(
          onError: (err) => _setError(err),
          onStateUpdate: (state) {
            nnProvider?.syncState(state);
          },
        );
        await _localNnClient!.connect(hostIp, port, myPlayerId, name, myPhoto);
      } else {
        _localClient = LocalGameClient(
          onStateUpdate: (state) {
            _state = state;
            notifyListeners();
          },
          onError: (err) => _setError(err),
        );
        await _localClient!.connect(hostIp, port, myPlayerId, name, myPhoto);
      }

      _status = ConnectionStatus.connected;
      notifyListeners();
    } catch (e) {
      _setError('فشل الانضمام للخادم المحلي: $e');
    }
  }

  // ── Host a game ───────────────────────────────────────────────

  Future<void> hostGame(String name, {int expectedPlayers = 4, String gameType = 'kotchina'}) async {
    await reset();
    _myPlayerId = Supabase.instance.client.auth.currentUser?.id ?? _uuid.v4();
    nnProvider?.setPlayerId(_myPlayerId!);
    _myName = name;
    _role = ConnectionRole.host;
    _isTestMode = false;
    _expectedPlayers = expectedPlayers;
    _status = ConnectionStatus.connecting;
    notifyListeners();

    try {
      // 1. Generate 6-char code and create Supabase room
      String roomCode = '';
      GameRoom? createdRoom;
      int retries = 3;
      while (retries > 0) {
        roomCode = _generateRoomCode();
        debugPrint('Attempting to create room with code: $roomCode');
        try {
          createdRoom = await _lobbyRepo.createRoom(
            playerName: name,
            roomCode: roomCode,
            hostIp: '127.0.0.1',
            wsPort: 0,
            gameType: gameType,
            expectedPlayers: expectedPlayers,
          ).timeout(const Duration(seconds: 25));
          _myPlayerId = Supabase.instance.client.auth.currentUser?.id ?? _myPlayerId;
          nnProvider?.setPlayerId(_myPlayerId!);
          debugPrint('Successfully created room: ${createdRoom.id} for player: $_myPlayerId');
          break;
          } catch (e) {
            debugPrint('Failed to create room (retries left: ${retries - 1}): $e');
            if (e is TimeoutException || e.toString().contains('TimeoutException') || e.toString().contains('SocketException')) {
              throw Exception('انتهى وقت الاتصال. يرجى التحقق من اتصالك بالإنترنت.');
            }
            if (e.toString().contains('ROOM_CODE_COLLISION')) {
              retries--;
            } else {
              rethrow;
            }
          }
        }

      if (_status != ConnectionStatus.connecting) {
        // User cancelled
        if (createdRoom != null) {
          _lobbyRepo.cancelRoom(createdRoom.id).catchError((_) {});
        }
        return;
      }

      if (createdRoom == null) throw Exception('فشل في إنشاء الغرفة');

      if (gameType == 'ninety_nine') {
        _nnServer = NinetyNineGameServer(
          onStateUpdate: (state) {
            nnProvider?.syncState(state);
          },
        );
        final myPhoto = await ProfileService.getProfilePhoto();
        await _nnServer!.start(name, myPlayerId, createdRoom.id, myPhoto, maxPlayers: expectedPlayers);
      } else {
        _server = GameServer(
          onStateUpdate: (state) {
            _state = state;
            notifyListeners();
          },
        );
        final myPhoto = await ProfileService.getProfilePhoto();
        await _server!.start(name, myPlayerId, createdRoom.id, myPhoto, maxPlayers: expectedPlayers);
      }

      _currentRoom = createdRoom;
      _listenToRoom(createdRoom.id);
      await _sessionService.saveActiveRoomSession(
        roomId:     createdRoom.id,
        roomCode:   roomCode,
        playerId:   myPlayerId,
        playerName: _myName,
        isHost:     true,
      );

      _status = ConnectionStatus.connected;
      notifyListeners();
    } catch (e) {
      if (_status == ConnectionStatus.connecting) {
        String msg = e.toString();
        if (msg.startsWith('Exception: ')) msg = msg.substring(11);
        _setError('فشل تشغيل الخادم: $msg');
      }
    }
  }

  String _generateRoomCode() {
    const chars = 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789';
    final random = Random.secure();
    return List.generate(6, (_) => chars[random.nextInt(chars.length)]).join();
  }

  // ── Test mode (3 bot players) ─────────────────────────────────

  Future<void> startTestGame(String name) async {
    await reset();
    _myPlayerId = Supabase.instance.client.auth.currentUser?.id ?? _uuid.v4();
    _myName = name;
    _role = ConnectionRole.host;
    _isTestMode = true;
    _status = ConnectionStatus.connecting;
    notifyListeners();

    try {
      _server = GameServer(
        onStateUpdate: (state) {
          _state = state;
          notifyListeners();
        },
      );
      final dummyRoomId = 'test_${_uuid.v4()}';
      final myPhoto = await ProfileService.getProfilePhoto();
      await _server!.start(name, myPlayerId, dummyRoomId, myPhoto);
      // Add 3 bot players to fill the remaining seats
      _server!.addBotPlayers(count: 3);
      _status = ConnectionStatus.connected;
      notifyListeners();
    } catch (e) {
      _setError('فشل تشغيل الخادم: $e');
    }
  }

  Future<void> startNinetyNineTestGame(String name, {int totalPlayers = 4}) async {
    await reset();
    _myPlayerId = Supabase.instance.client.auth.currentUser?.id ?? _uuid.v4();
    nnProvider?.setPlayerId(_myPlayerId!);
    _myName = name;
    _role = ConnectionRole.host;
    _isTestMode = true;
    _expectedPlayers = totalPlayers;
    _status = ConnectionStatus.connecting;
    notifyListeners();

    try {
      _nnServer = NinetyNineGameServer(
        onStateUpdate: (state) {
          nnProvider?.syncState(state);
        },
      );
      final dummyRoomId = 'test_99_${_uuid.v4()}';
      final myPhoto = await ProfileService.getProfilePhoto();
      await _nnServer!.start(name, myPlayerId, dummyRoomId, myPhoto, maxPlayers: totalPlayers);
      // Wait for dummy start
      _status = ConnectionStatus.connected;
      notifyListeners();
    } catch (e) {
      _setError('فشل تشغيل الخادم: $e');
    }
  }

  // ── Join a game ───────────────────────────────────────────────

  Future<void> joinGameWithCode(String name, String code, {String? expectedGameType}) async {
    await reset();
    _myPlayerId = Supabase.instance.client.auth.currentUser?.id ?? _uuid.v4();
    nnProvider?.setPlayerId(_myPlayerId!);
    _myName = name;
    _role = ConnectionRole.client;
    _isTestMode = false;
    _status = ConnectionStatus.connecting;
    _isSearching = true;
    notifyListeners();

    if (expectedGameType == 'ninety_nine') {
      _nnClient = NinetyNineGameClient(
        onError: (err) => _setError(err),
        onStateUpdate: (state) {
          nnProvider?.syncState(state);
        },
      );
    } else {
      _client = GameClient(
        onStateUpdate: (state) {
          _state = state;
          notifyListeners();
        },
        onError: (err) => _setError(err),
      );
    }

    try {
      // 1. Join Supabase room
      final normalizedCode = code.trim().toUpperCase();
      debugPrint('Attempting to join room with code: $normalizedCode');
      final room = await _lobbyRepo.joinRoom(
        roomCode: normalizedCode,
        playerName: name,
        expectedGameType: expectedGameType,
      ).timeout(const Duration(seconds: 25));
      _myPlayerId = Supabase.instance.client.auth.currentUser?.id ?? _myPlayerId;
      nnProvider?.setPlayerId(_myPlayerId!);

      if (_status != ConnectionStatus.connecting) {
        // User cancelled while we were joining, leave immediately
        _lobbyRepo.leaveRoom(room.id, myPlayerId).catchError((_) {});
        return;
      }

      _currentRoom = room;
      debugPrint('Successfully joined room: ${room.id}');

      // 2. Connect to Supabase Broadcast Channel
      _isSearching = false;
      final myPhoto = await ProfileService.getProfilePhoto();
      
      if (expectedGameType == 'ninety_nine') {
        await _nnClient!.connect(room.id, myPlayerId, name, myPhoto);
      } else {
        await _client!.connect(room.id, myPlayerId, name, myPhoto);
      }
      debugPrint('Connected to Supabase Broadcast for room: ${room.id}');

      // 3. Listen to Supabase room
      _listenToRoom(room.id);
      await _sessionService.saveActiveRoomSession(
        roomId:     room.id,
        roomCode:   normalizedCode,
        playerId:   myPlayerId,
        playerName: _myName,
        isHost:     false,
      );

      _status = ConnectionStatus.connected;
      notifyListeners();
    } catch (e, st) {
      if (_status == ConnectionStatus.connecting) {
        _isSearching = false;
        debugPrint('ERROR in joinGameWithCode: $e\nStacktrace: $st');
        _setError(_translateJoinError(e.toString()));
      }
    }
  }

  // ── Actions → Host ────────────────────────────────────────────

  void _sendAction(String action, [Map<String, dynamic> extra = const {}]) {
    // If a transient stream error flipped status to error while the game is
    // actively running, auto-heal the status so actions are not silently dropped.
    if (_status == ConnectionStatus.error && _isGameInProgress) {
      debugPrint('[GameProvider] Auto-healing status from error→connected for mid-game action "$action"');
      _status = ConnectionStatus.connected;
    }

    if (_status != ConnectionStatus.connected) {
      debugPrint('Cannot send action "$action": Not connected (status: $_status)');
      return;
    }

    if (_transport == ConnectionTransport.local) {
      if (_role == ConnectionRole.host) {
        if (_localServer != null) {
          _localServer!.sendHostAction(action, {'playerId': myPlayerId, ...extra});
        } else if (_localNnServer != null) {
          _localNnServer!.sendHostAction(action, {'playerId': myPlayerId, ...extra});
        }
      } else if (_role == ConnectionRole.client) {
        if (_localClient != null) {
          _localClient!.sendAction(action, myPlayerId, extra);
        } else if (_localNnClient != null) {
          _localNnClient!.sendAction(action, extra.isEmpty ? null : extra);
        }
      }
      return;
    }

    if (_role == ConnectionRole.host) {
      if (_server != null) {
        _server!.sendHostAction(action, {'playerId': myPlayerId, ...extra});
      } else if (_nnServer != null) {
        _nnServer!.sendHostAction(action, {'playerId': myPlayerId, ...extra});
      } else {
        debugPrint('Cannot send action "$action": Host server is null');
      }
    } else if (_role == ConnectionRole.client) {
      if (_client != null) {
        _client!.sendAction(action, myPlayerId, extra);
      } else if (_nnClient != null) {
        // 99-mode client — route through the NN client
        _nnClient!.sendAction(action, extra.isEmpty ? null : extra);
      } else {
        debugPrint('Cannot send action "$action": Client is null');
      }
    } else {
      debugPrint('Cannot send action "$action": Connection role is $_role');
    }
  }

  Future<void> startGame() async {
    if (_transport == ConnectionTransport.local) {
      if (isHost && _currentRoom != null) {
        _currentRoom = GameRoom(
          id: _currentRoom!.id,
          roomCode: _currentRoom!.roomCode,
          hostId: _currentRoom!.hostId,
          status: GameRoomStatus.playing,
          maxPlayers: _currentRoom!.maxPlayers,
          hostIp: _currentRoom!.hostIp,
          wsPort: _currentRoom!.wsPort,
          gameType: _currentRoom!.gameType,
          createdAt: _currentRoom!.createdAt,
          startedAt: DateTime.now(),
        );

        if (_localServer != null && _localServer!.playerCount < 4 && _currentRoom!.gameType == 'kotchina') {
          _localServer!.addBotPlayers(count: 4 - _localServer!.playerCount);
        }

        _sendAction(ActionType.startGame);
        notifyListeners();
      }
      return;
    }

    if (_currentRoom != null && isHost) {
      try {
        // Sync all Supabase room players into the local game server state
        // so dealCards has the correct player count, regardless of WebSocket timing.
        if (_server != null && _roomPlayers.isNotEmpty) {
          _server!.syncPlayersFromRoom(
            _roomPlayers.map((p) => (id: p.playerId, name: p.playerName)).toList(),
          );
          final is99 = _currentRoom?.gameType == 'ninety_nine';
          if (!is99 && _server!.playerCount < 4) {
            _server!.addBotPlayers(count: 4 - _server!.playerCount);
          }
        } else if (_nnServer != null && _roomPlayers.isNotEmpty) {
          // Sync room players into the 99-mode server before dealing cards.
          // Without this the server only has the host and deals to 1 player.
          _nnServer!.syncPlayersFromRoom(
            _roomPlayers.map((p) => (id: p.playerId, name: p.playerName)).toList(),
          );
        }
        _sendAction(ActionType.startGame);
        await _lobbyRepo.startGame(_currentRoom!.id);
      } catch (e) {
        _setError('فشل بدء اللعبة: $e');
      }
    } else {
      _sendAction(ActionType.startGame);
    }
  }

  void confirmNoVoid() => _sendAction(ActionType.confirmNoVoid);

  void changeTheme(String theme) {
    if (isHost) {
      _sendAction(ActionType.changeTheme, {'theme': theme});
    }
  }

  void unready() => _sendAction(ActionType.unready);


  void approveRedeal() {
    _sendAction(ActionType.approveRedeal);
  }

  void rejectRedeal() {
    _sendAction(ActionType.rejectRedeal);
  }

  void submitBid(Bid bid) =>
      _sendAction(ActionType.submitBid, {'bid': bid.toJson()});

  void passBid() => _sendAction(ActionType.passBid);

  void submitDeclaration(int declared) =>
      _sendAction(ActionType.submitDeclaration, {'declared': declared});

  void playCard(PlayingCard card) =>
      _sendAction(ActionType.playCard, {'card': card.toJson()});

  void requestStateSync() => _sendAction(ActionType.requestStateSync);


  void nextRound() => _sendAction(ActionType.nextRound);

  // ── Helpers ───────────────────────────────────────────────────

  /// Translates raw Supabase/network error strings into user-friendly Arabic.
  String _translateJoinError(String raw) {
    if (raw.contains('ROOM_NOT_FOUND')) {
      return 'الغرفة غير موجودة. تأكد من صحة الكود.';
    } else if (raw.contains('ROOM_ALREADY_STARTED')) {
      return 'اللعبة بدأت بالفعل، لا يمكن الانضمام.';
    } else if (raw.contains('ROOM_NOT_AVAILABLE')) {
      return 'الغرفة لم تعد متاحة (منتهية أو ملغاة).';
    } else if (raw.contains('ROOM_NOT_WAITING') || raw.contains('ROOM_FULL')) {
      return 'الغرفة ممتلئة أو لم تعد في وضع الانتظار.';
    } else if (raw.contains('NOT_AUTHENTICATED')) {
      return 'يجب تسجيل الدخول أولاً.';
    } else if (raw.contains('SocketException') || raw.contains('Connection refused') || raw.contains('TimeoutException')) {
      return 'استغرق الاتصال وقتًا أطول من المعتاد. يرجى التحقق من اتصالك بالإنترنت وإعادة المحاولة.';
    }
    return 'فشل الانضمام: $raw';
  }

  void _setError(String msg) {
    _errorMessage = msg;
    _status = ConnectionStatus.error;
    _isSearching = false;
    notifyListeners();
  }

  Future<void> reset() async {
    await _sessionService.clearSession();
    final myId = myPlayerId;
    if (_currentRoom != null && myId.isNotEmpty) {
      try {
        await _lobbyRepo.leaveRoom(_currentRoom!.id, myId);
        await _sessionService.clearSession();
      } catch (e) {
        debugPrint('Error leaving room: $e');
      }
    }

    _roomSub?.cancel();
    _roomSub = null;
    _playersSub?.cancel();
    _playersSub = null;

    await _discoveryService.stopBroadcasting();
    if (_localServer != null) {
      await _localServer!.stop();
      _localServer = null;
    }
    if (_localNnServer != null) {
      await _localNnServer!.stop();
      _localNnServer = null;
    }
    if (_localClient != null) {
      _localClient!.disconnect(myId);
      _localClient = null;
    }
    if (_localNnClient != null) {
      await _localNnClient!.disconnect();
      _localNnClient = null;
    }

    if (_server != null) {
      await _server!.stop();
      _server = null;
    }
    if (_nnServer != null) {
      await _nnServer!.stop();
      _nnServer = null;
    }
    if (_client != null) {
      _client!.disconnect(myId);
      _client = null;
    }
    if (_nnClient != null) {
      await _nnClient!.disconnect();
      _nnClient = null;
    }
    
    _state = null;
    _currentRoom = null;
    _roomPlayers = [];
    _role = ConnectionRole.none;
    _status = ConnectionStatus.idle;
    _transport = ConnectionTransport.online;
    _errorMessage = '';
    _isSearching = false;
    _isTestMode = false;
    notifyListeners();
  }

  // ── Session Recovery ──────────────────────────────────────────
  //
  // The _saveSession / _clearSession stubs have been replaced by
  // SessionStorageService. recoverSession() is now a thin wrapper kept
  // for backwards-compatibility with HomeScreen; full recovery logic
  // lives in ReconnectionManager (Phase 3).

  /// Lightweight recovery check called once on cold-start from HomeScreen.
  /// Returns true if a valid session was found AND a reconnect attempt succeeded.
  Future<bool> recoverSession() async {
    final session = await _sessionService.getActiveRoomSession();
    if (session == null) return false;

    _status = ConnectionStatus.connecting;
    notifyListeners();

    try {
      final room = await _lobbyRepo.getRoom(session.roomId);

      // Room is no longer active — wipe the stale session.
      if (room.status == GameRoomStatus.cancelled ||
          room.status == GameRoomStatus.finished) {
        await _sessionService.clearSession();
        _status = ConnectionStatus.idle;
        notifyListeners();
        return false;
      }

      // Attempt reconnect as client (Phase 3 will handle full host promotion).
      // Ensure myPlayerId and myName are restored from the session before
      // joinGameWithCode sets them again.
      _myPlayerId = session.playerId;
      _myName     = session.playerName;

      await joinGameWithCode(session.playerName, session.roomCode);
      return _status == ConnectionStatus.connected;
    } catch (e) {
      await _sessionService.clearSession();
      _status = ConnectionStatus.idle;
      notifyListeners();
      return false;
    }
  }

  /// Expose the session service so ReconnectionManager can update the
  /// isHost flag after a host-promotion event.
  SessionStorageService get sessionService => _sessionService;

  // ── Identity restoration (no network call) ────────────────────────────────

  /// Set player identity from a persisted session before making network calls.
  /// Must be called before [rehydrateGameState] so [myPlayerId] is populated.
  void restoreIdentity({
    required String playerId,
    required String playerName,
  }) {
    _myPlayerId = playerId;
    _myName     = playerName;
    nnProvider?.setPlayerId(playerId);
  }

  // ── State re-hydration (client reconnect) ─────────────────────────────────

  /// Fetch the persisted GameState snapshot, restore local state, recover
  /// the player's private hand, and re-subscribe to the Realtime channel.
  ///
  /// Returns true on success; false if the snapshot is missing or any
  /// network step fails.
  Future<bool> rehydrateGameState(String roomId) async {
    try {
      debugPrint('[Provider] Rehydrating state for room $roomId…');

      // 1. Fetch the phase-transition snapshot from Supabase.
      final snapshot = await _lobbyRepo.getGameStateSnapshot(roomId);
      if (snapshot == null) {
        debugPrint('[Provider] No snapshot found — cannot rehydrate');
        return false;
      }

      _state = GameState.fromJson(snapshot);

      // 2. Recover the player's own hand cards (private, per-player row).
      if (myPlayerId.isNotEmpty) {
        try {
          final myHand = await _lobbyRepo.getMyHandCards(roomId, myPlayerId);
          if (myHand.isNotEmpty) {
            final idx = _state!.players.indexWhere((p) => p.id == myPlayerId);
            if (idx != -1) _state!.players[idx].hand = myHand;
          }
        } catch (e) {
          // Non-fatal: the host's next broadcast will overwrite with full state.
          debugPrint('[Provider] Hand recovery skipped: $e');
        }
      }

      // 3. Clean up any stale client connection.
      _client?.disconnect(myPlayerId);

      // 4. Re-subscribe to the Realtime broadcast channel.
      _client = GameClient(
        onStateUpdate: (state) {
          _state = state;
          notifyListeners();
        },
        onError: (err) => _setError(err),
      );
      final myPhoto = await ProfileService.getProfilePhoto();
      await _client!.connect(roomId, myPlayerId, myName, myPhoto);

      // 5. Re-subscribe to Supabase room stream.
      _listenToRoom(roomId);
      _currentRoom = await _lobbyRepo.getRoom(roomId);

      _role   = ConnectionRole.client;
      _status = ConnectionStatus.connected;
      notifyListeners();

      debugPrint('[Provider] Rehydration complete — phase: ${_state!.phase.name}');
      return true;
    } catch (e) {
      debugPrint('[Provider] rehydrateGameState failed: $e');
      return false;
    }
  }

  // ── Host promotion ────────────────────────────────────────────────────────

  /// Called when the ReconnectionManager determines this client has been
  /// promoted to host (the previous host exceeded the grace window).
  ///
  /// Loads the persisted GameState, starts a [GameServer] with that state,
  /// and takes over broadcasting to all remaining clients.
  Future<bool> becomeHost(ActiveRoomSession session) async {
    try {
      debugPrint('[Provider] Taking over as host for room ${session.roomId}…');

      // 1. Fetch persisted state.
      final snapshot = await _lobbyRepo.getGameStateSnapshot(session.roomId);
      if (snapshot == null) {
        debugPrint('[Provider] No snapshot — cannot become host');
        return false;
      }
      final restoredState = GameState.fromJson(snapshot);

      // 2. Clean up any existing connections.
      _client?.disconnect(myPlayerId);
      await _server?.stop();
      _client = null;

      // 3. Start GameServer with the restored state.
      _server = GameServer(
        onStateUpdate: (state) {
          _state = state;
          notifyListeners();
        },
      );
      await _server!.restoreFromState(
        state:        restoredState,
        hostPlayerId: session.playerId,
        hostName:     session.playerName,
        roomId:       session.roomId,
      );

      // 4. Restore local identity & room reference.
      _myPlayerId  = session.playerId;
      nnProvider?.setPlayerId(_myPlayerId!);
      _myName      = session.playerName;
      _role        = ConnectionRole.host;
      _currentRoom = await _lobbyRepo.getRoom(session.roomId);
      _listenToRoom(session.roomId);

      _status = ConnectionStatus.connected;
      notifyListeners();

      debugPrint('[Provider] Host takeover complete');
      return true;
    } catch (e) {
      debugPrint('[Provider] becomeHost failed: $e');
      return false;
    }
  }

  @override
  void dispose() {
    _roomSub?.cancel();
    _playersSub?.cancel();
    _server?.stop();
    _client?.disconnect(myPlayerId);
    super.dispose();
  }
}

