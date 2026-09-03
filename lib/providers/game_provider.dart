// lib/providers/game_provider.dart
//
// Central state manager. Bridges networking layer ↔ UI.

import 'dart:async';
import 'dart:io' show Platform;
import 'dart:math';
import 'dart:ui' show Offset, Size;

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart' show rootBundle, AssetManifest;
import 'package:uuid/uuid.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../core/constants.dart';
import '../core/models/game_state.dart';
import '../core/models/card.dart';
import '../core/models/game_reaction.dart';
import '../core/models/bid.dart';
import '../core/models/player.dart';
import '../core/game_engine.dart';
import '../core/events/estimation_event_bus.dart';
import '../core/events/estimation_event_dispatcher.dart';
import '../core/events/estimation_game_events.dart';
import '../networking/game_server.dart';
import '../networking/game_client.dart';
import '../networking/messages.dart';
import '../modes/ninety_nine/networking/ninety_nine_game_server.dart';
import '../modes/ninety_nine/networking/ninety_nine_game_client.dart';
import '../modes/ninety_nine/presentation/providers/ninety_nine_game_provider.dart';
import '../modes/basra/networking/basra_game_server.dart';
import '../modes/basra/networking/basra_game_client.dart';
import '../modes/basra/presentation/providers/basra_game_provider.dart';
import '../features/lobby/data/lobby_repository.dart';
import '../features/lobby/domain/models/game_room.dart';
import '../features/lobby/domain/models/room_player.dart';
import '../features/matchmaking/data/matchmaking_repository.dart';
import '../features/matchmaking/domain/models/bot_fill_vote_result.dart';
import '../features/matchmaking/domain/models/matchmaking_status.dart';
import '../services/session_storage_service.dart';
import '../services/profile_service.dart';
import '../services/game_action_service.dart';
import '../services/auth_service.dart';
import '../core/utils/google_online_auth.dart';

import '../networking/local/local_game_server.dart';
import '../networking/local/local_game_client.dart';
import '../modes/ninety_nine/networking/local_ninety_nine_game_server.dart';
import '../modes/ninety_nine/networking/local_ninety_nine_game_client.dart';
import '../modes/basra/networking/local_basra_game_server.dart';
import '../modes/basra/networking/local_basra_game_client.dart';
import '../networking/local/local_discovery_service.dart';

enum ConnectionRole { none, host, client }

enum ConnectionStatus { idle, connecting, connected, error }

enum ConnectionTransport { online, local }

class GameProvider extends ChangeNotifier {
  static const matchmakingBotOfferDelay = Duration(seconds: 8);

  final _uuid = const Uuid();
  final _lobbyRepo = LobbyRepository();
  final _matchmakingRepo = MatchmakingRepository();
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
  NinetyNineGameProvider? _nnProvider;
  NinetyNineGameProvider? get nnProvider => _nnProvider;
  set nnProvider(NinetyNineGameProvider? provider) {
    _nnProvider = provider;
    _bindNnProvider();
  }

  void _bindNnProvider() {
    _nnProvider?.onSendAction = (action, [data]) {
      _sendAction(action, data ?? {});
    };
  }

  BasraGameServer? _basraServer;
  BasraGameClient? _basraClient;
  BasraGameProvider? _basraProvider;
  BasraGameProvider? get basraProvider => _basraProvider;
  set basraProvider(BasraGameProvider? provider) {
    _basraProvider = provider;
    _bindBasraProvider();
  }

  void _bindBasraProvider() {
    _basraProvider?.onSendAction = (action, [data]) {
      _sendAction(action, data ?? {});
    };
  }

  String? _myPlayerId; // Supabase auth uid
  String _myName = '';
  bool _isSearching = false;
  bool _isTestMode = false;
  bool _isTemporarilyAway = false;
  int _expectedPlayers = 4;

  ConnectionTransport _transport = ConnectionTransport.online;
  LocalGameServer? _localServer;
  LocalGameClient? _localClient;
  LocalNinetyNineGameServer? _localNnServer;
  LocalNinetyNineGameClient? _localNnClient;
  LocalBasraGameServer? _localBasraServer;
  LocalBasraGameClient? _localBasraClient;
  final LocalDiscoveryService _discoveryService = LocalDiscoveryService();
  String? _localHostIp;
  int _localPort = 7890;

  // Supabase Lobby State
  GameRoom? _currentRoom;
  List<RoomPlayer> _roomPlayers = [];
  int _actionSeq = 0;
  int _receivedActionSeq = 0;
  int _expectedOwnHandCount = -1;
  List<PlayingCard> _lastKnownPrivateHand = [];
  Future<void>? _pendingAuthorityStateApply;
  bool _serverActionInFlight = false;
  String? _myAvatarRef;
  final Map<String, String> _lobbyAvatarRefs = {};
  StreamSubscription? _roomSub;
  StreamSubscription? _playersSub;

  /// Lobby-only actions stay on the local host path — no Edge Function needed.
  static const _lobbyLocalHostActions = {ActionType.changeTheme};

  MatchmakingStatus _matchmakingStatus = MatchmakingStatus.idle;
  Timer? _matchmakingBotOfferTimer;
  Timer? _matchmakingSyncTimer;
  int _matchmakingRosterFetchEpoch = 0;
  int? _lastPresentedBotOfferVersion;
  bool _isLeavingMatchmaking = false;
  bool _matchmakingStartInProgress = false;
  bool _matchmakingHostPromotionInProgress = false;
  bool _matchmakingSessionSaved = false;

  Timer? _autoPlayCardTimer;
  Timer? _authorityTimeoutTimer;

  Future<String> _loadMyAvatarRef() async {
    final raw = await ProfileService.getProfilePhoto();
    _myAvatarRef = ProfileService.publicAvatarRef(raw);
    return raw;
  }

  void _rememberLobbyAvatars(GameState state) {
    if (state.phase != GamePhase.lobby) return;
    for (final player in state.players) {
      final photo = player.photo;
      if (photo != null && photo.isNotEmpty) {
        _lobbyAvatarRefs[player.id] = ProfileService.publicAvatarRef(photo);
      }
    }
  }

  void _patchLobbyAvatars(GameState state) {
    if (state.phase != GamePhase.lobby) return;
    _rememberLobbyAvatars(state);
    for (var i = 0; i < state.players.length; i++) {
      final player = state.players[i];
      if (player.photo != null && player.photo!.isNotEmpty) continue;
      final cached = _lobbyAvatarRefs[player.id] ??
          (player.id == myPlayerId ? _myAvatarRef : null) ??
          ProfileService.presetForPlayerId(player.id);
      state.players[i] = player.copyWith(photo: cached);
    }
  }

  void _updateState(GameState newState) {
    _patchLobbyAvatars(newState);
    final oldState = _state;
    _state = newState;
    EstimationEventDispatcher.instance
        .dispatchStateTransition(oldState, newState);
    _checkAutoPlayCard();
    _scheduleAuthorityTurnTimeout();
    notifyListeners();
  }

  void _scheduleAuthorityTurnTimeout() {
    _authorityTimeoutTimer?.cancel();
    _authorityTimeoutTimer = null;
    if (!_usesServerAuthority() || _transport == ConnectionTransport.local) {
      return;
    }
    final deadline = _state?.turnDeadlineEpochMs;
    final phase = _state?.phase;
    if (deadline == null ||
        (phase != GamePhase.dashCall &&
            phase != GamePhase.auction &&
            phase != GamePhase.declarations &&
            phase != GamePhase.trickTaking)) {
      return;
    }
    final waitMs = max(
      0,
      deadline - DateTime.now().millisecondsSinceEpoch + 150,
    );
    _authorityTimeoutTimer = Timer(
      Duration(milliseconds: waitMs),
      () => _submitAuthorityTimeout(deadline),
    );
  }

  void _submitAuthorityTimeout(int expectedDeadline) {
    if (_state?.turnDeadlineEpochMs != expectedDeadline) return;
    if (_serverActionInFlight) {
      _authorityTimeoutTimer = Timer(
        const Duration(milliseconds: 300),
        () => _submitAuthorityTimeout(expectedDeadline),
      );
      return;
    }
    unawaited(_sendServerAction(ActionType.timeoutTurn, const {}));
  }

  void _applyOptimisticCardPlay(PlayingCard card) {
    final current = _state;
    if (current == null || me == null) return;
    final optimistic = GameState.fromJson(current.toJson());
    final playerIndex =
        optimistic.players.indexWhere((player) => player.id == myPlayerId);
    if (playerIndex < 0) return;
    final player = optimistic.players[playerIndex];
    final cardIndex = player.hand.indexWhere((held) => held == card);
    if (cardIndex < 0 || !GameEngine.canPlayCard(optimistic, player, card)) {
      return;
    }
    player.hand.removeAt(cardIndex);
    _lastKnownPrivateHand = List.from(player.hand);
    _expectedOwnHandCount = player.hand.length;
    optimistic.currentTrick.add(TrickCard(playerId: player.id, card: card));
    if (optimistic.currentTrick.length < optimistic.players.length) {
      optimistic.currentPlayerSeatIndex =
          (optimistic.currentPlayerSeatIndex + 1) % optimistic.players.length;
    }
    _updateState(optimistic);
  }

  /// Host GameServer callback — under server authority in-game state comes from
  /// the Edge Function; lobby join/leave still uses local host state.
  void _onEstimationHostState(GameState state) {
    if (_usesServerAuthority() && state.phase != GamePhase.lobby) {
      unawaited(_applyOnlineEstimationState(state));
      return;
    }
    _updateState(state);
  }

  void _onNnHostState(NinetyNineGameState state) {
    if (_usesServerAuthority() && state.phase != NinetyNinePhase.waiting) {
      unawaited(_applyOnlineNinetyNineState(state));
      return;
    }
    nnProvider?.syncState(state);
  }

  void _onBasraHostState(BasraGameState state) {
    if (_usesServerAuthority() && state.phase != BasraPhase.waiting) {
      unawaited(_applyOnlineBasraState(state));
      return;
    }
    _basraProvider?.syncState(state);
  }

  /// Online clients receive sanitized broadcasts; merge own hand via owner-only RPC.
  /// Under server authority the host uses the same path as clients.
  Future<void> _applyOnlineEstimationState(
    GameState incoming, {
    List<PlayingCard>? privateHand,
  }) async {
    if (_transport == ConnectionTransport.local) {
      _updateState(incoming);
      return;
    }
    if (isHost && !_usesServerAuthority()) {
      _updateState(incoming);
      return;
    }
    // A server-authoritative host keeps a lightweight lobby server for the
    // waiting room. A reconnect must not let that stale server replace a live
    // table with its empty lobby snapshot.
    if ((_currentRoom?.status == GameRoomStatus.playing ||
            (_state?.phase != null && _state!.phase != GamePhase.lobby)) &&
        incoming.phase == GamePhase.lobby) {
      debugPrint('[GameProvider] Ignored stale lobby state during live game');
      return;
    }
    final roomId = _currentRoom?.id;
    if (roomId == null || myPlayerId.isEmpty) {
      _updateState(incoming);
      return;
    }
    final incomingIndex =
        incoming.players.indexWhere((player) => player.id == myPlayerId);
    final expectedHandCount =
        incomingIndex >= 0 ? incoming.players[incomingIndex].hand.length : -1;
    _expectedOwnHandCount = expectedHandCount;
    if (privateHand != null && privateHand.length == expectedHandCount) {
      GameEngine.autoSort(privateHand);
      _lastKnownPrivateHand = List.from(privateHand);
    }
    if (incomingIndex >= 0) {
      if (_lastKnownPrivateHand.length == expectedHandCount) {
        incoming.players[incomingIndex].hand = List.from(_lastKnownPrivateHand);
      } else {
        // Repeated 2-spades are the server privacy mask, never a real hand.
        incoming.players[incomingIndex].hand = [];
      }
    }

    // Render public turn/card changes immediately. Waiting for the private-hand
    // RPC here added a complete network round trip to every online animation.
    _updateState(incoming);

    try {
      final myHand = await _lobbyRepo.getMyHandCards(roomId, myPlayerId);
      final current = _state;
      if (current == null) return;
      final currentIndex =
          current.players.indexWhere((player) => player.id == myPlayerId);
      if (currentIndex < 0 ||
          (_expectedOwnHandCount >= 0 &&
              myHand.length != _expectedOwnHandCount)) {
        return;
      }
      GameEngine.autoSort(myHand);
      _lastKnownPrivateHand = List.from(myHand);
      current.players[currentIndex].hand = List.from(myHand);
      notifyListeners();
    } catch (e) {
      debugPrint('[GameProvider] Estimation hand merge failed: $e');
    }
  }

  Future<void> _applyOnlineNinetyNineState(NinetyNineGameState incoming) async {
    if (_transport == ConnectionTransport.local) {
      nnProvider?.syncState(incoming);
      return;
    }
    if (isHost && !_usesServerAuthority()) {
      nnProvider?.syncState(incoming);
      return;
    }
    final roomId = _currentRoom?.id;
    if (roomId == null || myPlayerId.isEmpty) {
      nnProvider?.syncState(incoming);
      return;
    }
    try {
      final myHand = await _lobbyRepo.getMyHandCards(roomId, myPlayerId);
      if (myHand.isNotEmpty) {
        final idx = incoming.players.indexWhere((p) => p.id == myPlayerId);
        if (idx != -1) {
          incoming.players[idx] = incoming.players[idx].copyWith(hand: myHand);
        }
      }
    } catch (e) {
      debugPrint('[GameProvider] 99 hand merge failed: $e');
    }
    nnProvider?.syncState(incoming);
  }

  Future<void> _applyOnlineBasraState(BasraGameState incoming) async {
    if (_transport == ConnectionTransport.local) {
      _basraProvider?.syncState(incoming);
      return;
    }
    if (isHost && !_usesServerAuthority()) {
      _basraProvider?.syncState(incoming);
      return;
    }
    final roomId = _currentRoom?.id;
    if (roomId == null || myPlayerId.isEmpty) {
      _basraProvider?.syncState(incoming);
      return;
    }
    try {
      final myHand = await _lobbyRepo.getMyHandCards(roomId, myPlayerId);
      if (myHand.isNotEmpty) {
        final idx = incoming.players.indexWhere((p) => p.id == myPlayerId);
        if (idx != -1) {
          incoming.players[idx] = incoming.players[idx].copyWith(hand: myHand);
        }
      }
    } catch (e) {
      debugPrint('[GameProvider] Basra hand merge failed: $e');
    }
    _basraProvider?.syncState(incoming);
  }

  void _checkAutoPlayCard() {
    _autoPlayCardTimer?.cancel();
    _autoPlayCardTimer = null;
    _authorityTimeoutTimer?.cancel();
    _authorityTimeoutTimer = null;

    if (_isTemporarilyAway || _status != ConnectionStatus.connected) return;

    final st = _state;
    final localMe = me;
    if (st == null || localMe == null) return;
    if (st.phase != GamePhase.trickTaking) return;
    if (st.currentPlayerSeatIndex != localMe.seatIndex) return;

    // Find all legal playable cards for me
    final legalCards = localMe.hand
        .where((c) => GameEngine.canPlayCard(st, localMe, c))
        .toList();

    // If there is strictly only 1 legal card (either last card in hand or forced follow-suit)
    if (legalCards.length == 1) {
      final cardToPlay = legalCards.first;
      _autoPlayCardTimer = Timer(const Duration(milliseconds: 550), () {
        if (_isTemporarilyAway || _status != ConnectionStatus.connected) {
          return;
        }
        if (_state != null &&
            _state!.phase == GamePhase.trickTaking &&
            _state!.currentPlayerSeatIndex == me?.seatIndex &&
            me?.hand.contains(cardToPlay) == true) {
          playCard(cardToPlay);
        }
      });
    }
  }

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

  bool get usesServerAuthorityOnline => _usesServerAuthority();
  bool get isSearching => _isSearching;
  bool get isTestMode => _isTestMode;
  bool get isTemporarilyAway => _isTemporarilyAway;
  bool get canResumeTemporarilyLeftGame =>
      _isTemporarilyAway && _currentRoom != null && _state != null;
  int get expectedPlayers => _expectedPlayers;
  MatchmakingStatus get matchmakingStatus => _matchmakingStatus;
  bool get isMatchmaking => _currentRoom?.isMatchmaking == true;
  bool get isMatchmakingSearching =>
      isMatchmaking &&
      (_matchmakingStatus == MatchmakingStatus.searching ||
          _matchmakingStatus == MatchmakingStatus.votingForBots);
  int get matchmakingHumanCount => _roomPlayers.length;
  int get matchmakingBotsToFill => _currentRoom?.botsToFill ?? 0;
  int? get lastPresentedBotOfferVersion => _lastPresentedBotOfferVersion;

  bool claimBotOfferPresentation(int version) {
    if (_lastPresentedBotOfferVersion == version) return false;
    _lastPresentedBotOfferVersion = version;
    return true;
  }

  Future<bool> hasUnfinishedOnlineGame() async {
    final session = await _sessionService.getActiveRoomSession();
    if (session == null) return false;
    try {
      final room = await _lobbyRepo.getRoom(session.roomId);
      final active = room.status == GameRoomStatus.waiting ||
          room.status == GameRoomStatus.playing;
      if (!active) {
        await _sessionService.clearSession();
        return false;
      }
      final stillMember =
          await _lobbyRepo.isPlayerInRoom(session.roomId, session.playerId);
      if (!stillMember) {
        await _sessionService.clearSession();
        return false;
      }
      return true;
    } catch (error) {
      debugPrint('[Reconnection] Could not verify active session: $error');
      return true;
    }
  }

  Future<bool> _rejectNewGameWhileSessionActive() async {
    if (!await hasUnfinishedOnlineGame()) return false;
    _errorMessage =
        'لديك مباراة ما زالت جارية. يجب العودة إليها أو انتظار انتهائها قبل بدء مباراة جديدة.';
    _status = ConnectionStatus.error;
    notifyListeners();
    return true;
  }

  bool get isNinetyNine =>
      _currentRoom?.gameType == 'ninety_nine' ||
      _nnServer != null ||
      _nnClient != null ||
      _localNnServer != null ||
      _localNnClient != null;

  bool get isBasra =>
      _currentRoom?.gameType == 'basra' ||
      _basraServer != null ||
      _basraClient != null ||
      _localBasraServer != null ||
      _localBasraClient != null;

  bool _usesServerAuthority() {
    if (!GameActionService.useServerAuthority) return false;
    if (_isTestMode) return false;
    if (_transport == ConnectionTransport.local) return false;
    final type = _currentRoom?.gameType;
    if (type == null) return !isNinetyNine && !isBasra;
    return type == 'kotchina' ||
        type == 'estimation' ||
        type == 'ninety_nine' ||
        type == 'basra';
  }

  Future<void> _applyServerPublicState(
    Map<String, dynamic> publicState, {
    int? actionSeq,
    List<PlayingCard>? privateHand,
  }) async {
    if (isNinetyNine) {
      await _applyOnlineNinetyNineState(
          NinetyNineGameState.fromJson(publicState));
    } else if (isBasra) {
      await _applyOnlineBasraState(BasraGameState.fromJson(publicState));
    } else {
      await _applyOnlineEstimationState(
        GameState.fromJson(publicState),
        privateHand: privateHand,
      );
    }
    if (actionSeq != null && actionSeq > _actionSeq) {
      _actionSeq = actionSeq;
    }
  }

  Future<void> _syncFromRoomIfNewer(
    GameRoom room, {
    bool force = false,
  }) async {
    if (!_usesServerAuthority()) return;
    if (!force && room.actionSeq <= _receivedActionSeq) return;
    final snapshot = room.gameState;
    if (snapshot == null || snapshot['players'] == null) return;
    if (room.actionSeq > _receivedActionSeq) {
      _receivedActionSeq = room.actionSeq;
    }
    try {
      await _applyServerPublicState(snapshot, actionSeq: room.actionSeq);
    } catch (e) {
      debugPrint('[GameProvider] Room snapshot parse failed: $e');
    }
  }

  void _queueAuthorityRoomSync(GameRoom room) {
    late final Future<void> sync;
    sync = _syncFromRoomIfNewer(room);
    _pendingAuthorityStateApply = sync;
    unawaited(sync.whenComplete(() {
      if (identical(_pendingAuthorityStateApply, sync)) {
        _pendingAuthorityStateApply = null;
      }
    }));
  }

  Future<void> _refreshFromRoomSnapshot() async {
    final roomId = _currentRoom?.id;
    if (roomId == null) return;
    try {
      final view = await _lobbyRepo.getMyGameState(roomId);
      final rawState = view?['state'];
      if (rawState is Map) {
        await _applyServerPublicState(
          Map<String, dynamic>.from(rawState),
          actionSeq: (view?['actionSeq'] as num?)?.toInt(),
        );
      }
    } catch (e) {
      debugPrint('[GameProvider] refreshFromRoomSnapshot failed: $e');
    }
  }

  Future<void> _sendServerAction(
    String action,
    Map<String, dynamic> extra,
  ) async {
    final roomId = _currentRoom?.id;
    if (roomId == null) {
      debugPrint(
          '[GameProvider] Server action "$action" skipped: no current room');
      return;
    }

    final isEphemeralAction = action == ActionType.sendReaction ||
        action == ActionType.triggerEarthquake;

    if (_serverActionInFlight && !isEphemeralAction) {
      debugPrint('[GameProvider] Ignored duplicate in-flight action "$action"');
      return;
    }

    if (!isEphemeralAction) {
      final pendingApply = _pendingAuthorityStateApply;
      if (pendingApply != null) {
        await pendingApply;
      }
    }

    final payload = Map<String, dynamic>.from(extra)..remove('playerId');
    if (action == ActionType.playCard) {
      final rawCard = payload['card'];
      final currentState = _state;
      final currentPlayer = me;
      if (rawCard is! Map || currentState == null || currentPlayer == null) {
        return;
      }
      final selected = PlayingCard.fromJson(
        Map<String, dynamic>.from(rawCard),
      );
      if (!GameEngine.canPlayCard(currentState, currentPlayer, selected)) {
        debugPrint(
          '[GameProvider] Dropped stale card selection after state sync',
        );
        return;
      }
      _applyOptimisticCardPlay(selected);
    }

    if (!isEphemeralAction) {
      _serverActionInFlight = true;
    }
    try {
      final result = await GameActionService.submit(
        roomId: roomId,
        action: action,
        payload: payload,
        expectedSeq: _actionSeq,
      );

      if (!result.ok) {
        debugPrint(
            '[GameProvider] Server action "$action" failed: ${result.error}');
        if (result.error == 'SEQ_MISMATCH' || result.error == 'CARD_REJECTED') {
          await _refreshFromRoomSnapshot();
        }
        return;
      }

      if (action == ActionType.startGame) {
        _server?.markServerAuthorityGameStarted();
      }

      final resultSeq = result.seq;
      if (resultSeq != null && resultSeq > _receivedActionSeq) {
        _receivedActionSeq = resultSeq;
      }

      if (result.ephemeral) {
        final ephemeral = result.data['ephemeral'];
        if (ephemeral is Map) {
          final map = Map<String, dynamic>.from(ephemeral);
          if (map['type'] == ActionType.sendReaction) {
            handleIncomingReaction(map);
          } else if (map['type'] == ActionType.triggerEarthquake) {
            handleIncomingEarthquake(map);
          }
        }
        return;
      }

      final publicState = result.publicState;
      if (publicState != null) {
        final privateHand =
            result.privateHand?.map(PlayingCard.fromJson).toList();
        await _applyServerPublicState(
          publicState,
          actionSeq: resultSeq,
          privateHand: privateHand,
        );
      }
    } finally {
      if (!isEphemeralAction) {
        _serverActionInFlight = false;
      }
    }
  }

  void _configureServerAuthority(GameServer server) {
    server.serverAuthorityMode =
        GameActionService.useServerAuthority && !_isTestMode;
  }

  void _configureNnServerAuthority(NinetyNineGameServer server) {
    server.serverAuthorityMode =
        GameActionService.useServerAuthority && !_isTestMode;
  }

  void _configureBasraServerAuthority(BasraGameServer server) {
    server.serverAuthorityMode =
        GameActionService.useServerAuthority && !_isTestMode;
  }

  /// The room code to share with other players (host only).
  String? get gameCode => _currentRoom?.roomCode;

  GameRoom? get currentRoom => _currentRoom;
  List<RoomPlayer> get roomPlayers => _roomPlayers;

  NinetyNineGameClient? get nnClient => _nnClient;
  BasraGameClient? get basraClient => _basraClient;

  List<String> _availableThemes = ['theme_1', 'theme_2', 'theme_3', 'theme_4'];
  List<String> get availableThemes => _availableThemes;

  // ── Reactions State ───────────────────────────────────────────
  final Map<String, GameReaction> _activeReactions = {};
  Map<String, GameReaction> get activeReactions =>
      Map.unmodifiable(_activeReactions);
  final Map<String, Timer> _reactionTimers = {};

  Future<void> _loadAvailableThemes() async {
    try {
      if (!kIsWeb && Platform.environment.containsKey('FLUTTER_TEST')) {
        return;
      }
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
      case GamePhase.dashCall:
        return _state!.currentPlayerSeatIndex == me!.seatIndex &&
            !_state!.dashCallPassed.contains(myPlayerId);
      case GamePhase.auction:
        return _state!.auctionTurnSeatIndex == me!.seatIndex;
      case GamePhase.trickTaking:
        return _state!.currentPlayerSeatIndex == me!.seatIndex;
      case GamePhase.declarations:
        return _state!.currentPlayerSeatIndex == me!.seatIndex &&
            me!.declared == null;
      case GamePhase.voidCheck:
        if (_state!.voidDeclaringPlayerId != null) {
          return !_state!.voidRedealRejections.contains(myPlayerId);
        }
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
    unawaited(_refreshRoomPlayers(roomId));
    _roomSub = _lobbyRepo.watchRoom(roomId).listen(
      (room) {
        final previousHost = _currentRoom?.hostId;
        _currentRoom = room;
        _expectedPlayers = room.maxPlayers;
        _queueAuthorityRoomSync(room);
        if (isHost && _server != null && room.gameState != null) {
          _server!.applyBotPlayerIdsFromSnapshot(room.gameState);
        }
        // Automatically sync state if status changed to playing
        if (room.status == GameRoomStatus.playing) {
          if (_state == null && !isHost) {
            requestStateSync();
          }
        } else if (room.status == GameRoomStatus.cancelled) {
          if (_isTemporarilyAway) {
            unawaited(_sessionService.clearSession());
            _isTemporarilyAway = false;
          }
          if (room.isMatchmaking) {
            _matchmakingStatus = MatchmakingStatus.error;
            _setError('انتهت جلسة البحث. سنعيدك للصفحة الرئيسية.');
          } else {
            _setError('تم إلغاء الغرفة من قبل المضيف');
          }
        }
        if (room.isMatchmaking) {
          unawaited(_refreshRoomPlayers(room.id));
          _handleMatchmakingRoomUpdate(room, previousHost: previousHost);
        }
        notifyListeners();
      },
      onError: (err) {
        // Mid-game Supabase auth/network errors (e.g. token-refresh timeout)
        // are transient and must NOT terminate an in-progress game session.
        // Only treat them as fatal during the lobby phase.
        if (_isGameInProgress) {
          debugPrint(
              '[GameProvider] Room stream error (non-fatal mid-game): $err');
        } else {
          _setError('حدث خطأ في الغرفة: $err');
        }
      },
    );

    _playersSub?.cancel();
    _playersSub = _lobbyRepo.watchRoomPlayers(roomId).listen(
      (players) {
        _matchmakingRosterFetchEpoch++;
        _applyRoomPlayers(players, fromRealtime: true);
      },
      onError: (err) {
        // Same: player-list stream errors mid-game are non-fatal.
        if (_isGameInProgress) {
          debugPrint(
              '[GameProvider] Players stream error (non-fatal mid-game): $err');
        } else {
          _setError('حدث خطأ في اللاعبين: $err');
        }
      },
    );
    _startMatchmakingSyncIfNeeded();
  }

  Future<void> _refreshRoomPlayers(String roomId) async {
    final fetchEpoch = ++_matchmakingRosterFetchEpoch;
    try {
      final room = _currentRoom;
      final players = await _lobbyRepo.fetchRoomPlayers(
        roomId,
        activeOnly: room?.isMatchmakingWaiting ?? false,
      );
      if (fetchEpoch != _matchmakingRosterFetchEpoch ||
          _currentRoom?.id != roomId) {
        return;
      }
      _applyRoomPlayers(players);
    } catch (error) {
      debugPrint('[Matchmaking] Player roster refresh failed: $error');
    }
  }

  Future<void> _refreshMatchmakingState(String roomId) async {
    try {
      final room = await _matchmakingRepo.getRoom(roomId);
      if (_currentRoom?.id != roomId) return;
      final previousHost = _currentRoom?.hostId;
      _currentRoom = room;
      _expectedPlayers = room.maxPlayers;
      _queueAuthorityRoomSync(room);
      _handleMatchmakingRoomUpdate(room, previousHost: previousHost);
      await _refreshRoomPlayers(roomId);
      notifyListeners();
    } catch (error) {
      debugPrint('[Matchmaking] State refresh failed: $error');
    }
  }

  void _applyRoomPlayers(List<RoomPlayer> players,
      {bool fromRealtime = false}) {
    Iterable<RoomPlayer> resolved = players;
    final room = _currentRoom;
    if ((room?.isMatchmakingWaiting ?? false) && fromRealtime) {
      resolved = _filterActiveMatchmakingPlayers(players);
    }
    final ordered = RoomPlayer.stableSeatOrder(resolved);
    final previousIds = _roomPlayers.map((p) => p.playerId).toSet();
    final membershipChanged = !RoomPlayer.sameMembership(_roomPlayers, ordered);
    final presentationChanged =
        !RoomPlayer.sameSeatPresentation(_roomPlayers, ordered);
    _roomPlayers = ordered;
    if (membershipChanged && _isGameInProgress && isHost && _server != null) {
      final newIds = players.map((p) => p.playerId).toSet();
      for (final id in previousIds.difference(newIds)) {
        _server!.markPlayerPermanentlyAbsent(id);
      }
    }
    if (membershipChanged &&
        !_isTemporarilyAway &&
        room != null &&
        room.isMatchmakingWaiting) {
      if (isHost && _server != null) {
        _server!.syncPlayersFromRoom(_roomPlayers
            .map((p) => (id: p.playerId, name: p.playerName))
            .toList());
      }
      _handleMatchmakingPopulationChanged();
    }
    if (membershipChanged || presentationChanged) {
      notifyListeners();
    }
  }

  List<RoomPlayer> _filterActiveMatchmakingPlayers(List<RoomPlayer> players) {
    return players.where((p) => p.isActiveForMatchmaking).toList();
  }

  void _startMatchmakingSyncIfNeeded() {
    final room = _currentRoom;
    if (room == null || !room.isMatchmakingWaiting) {
      _stopMatchmakingSync();
      return;
    }
    _matchmakingSyncTimer ??= Timer.periodic(const Duration(seconds: 3), (_) {
      final activeRoom = _currentRoom;
      if (activeRoom == null || !activeRoom.isMatchmakingWaiting) {
        _stopMatchmakingSync();
        return;
      }
      unawaited(_refreshMatchmakingState(activeRoom.id));
    });
  }

  void _stopMatchmakingSync() {
    _matchmakingSyncTimer?.cancel();
    _matchmakingSyncTimer = null;
  }

  void _handleMatchmakingRoomUpdate(GameRoom room, {String? previousHost}) {
    if (room.isBotVoteOpen) {
      _matchmakingStatus = MatchmakingStatus.votingForBots;
      _cancelMatchmakingBotOfferTimer();
    } else if (room.isMatchmakingStarting ||
        room.status == GameRoomStatus.playing) {
      _matchmakingStatus = room.status == GameRoomStatus.playing
          ? MatchmakingStatus.playing
          : MatchmakingStatus.starting;
      _cancelMatchmakingBotOfferTimer();
      unawaited(_saveMatchmakingSessionIfNeeded(room));
      _stopMatchmakingSync();
      if (room.hostId == myPlayerId) {
        unawaited(_startApprovedMatchmakingGame());
      } else if (room.status == GameRoomStatus.playing && _state == null) {
        requestStateSync();
      }
    } else if (room.matchmakingState == 'waiting') {
      _matchmakingStatus = MatchmakingStatus.searching;
      _scheduleBotFillOfferIfNeeded();
    }

    if (room.hostId == myPlayerId && !isHost && previousHost != room.hostId) {
      unawaited(_becomeMatchmakingHost(room));
    }
  }

  Future<void> _saveMatchmakingSessionIfNeeded(GameRoom room) async {
    if (_matchmakingSessionSaved || myPlayerId.isEmpty) return;
    _matchmakingSessionSaved = true;
    await _sessionService.saveActiveRoomSession(
      roomId: room.id,
      roomCode: room.roomCode,
      playerId: myPlayerId,
      playerName: _myName,
      isHost: room.hostId == myPlayerId,
    );
  }

  void _handleMatchmakingPopulationChanged() {
    final room = _currentRoom;
    if (room == null || !room.isMatchmakingWaiting || _isTemporarilyAway) {
      return;
    }
    debugPrint('[Matchmaking] Population changed: ${_roomPlayers.length}/4');
    _cancelMatchmakingBotOfferTimer();
    if (room.isMatchmakingStarting && isHost) {
      unawaited(_startApprovedMatchmakingGame());
      return;
    }
    if (_roomPlayers.length < 4 && room.matchmakingState == 'waiting') {
      _matchmakingStatus = MatchmakingStatus.searching;
      _scheduleBotFillOfferIfNeeded();
    }
  }

  void _scheduleBotFillOfferIfNeeded() {
    final room = _currentRoom;
    if (!isHost ||
        room == null ||
        !room.isMatchmaking ||
        room.status != GameRoomStatus.waiting ||
        room.matchmakingState != 'waiting' ||
        !(_roomPlayers.length == 2 || _roomPlayers.length == 3) ||
        _matchmakingBotOfferTimer != null) {
      return;
    }
    final notBefore = room.botOfferAfter;
    final now = DateTime.now();
    final delay = notBefore == null
        ? matchmakingBotOfferDelay
        : notBefore.isAfter(now)
            ? notBefore.difference(now)
            : Duration.zero;
    _matchmakingBotOfferTimer = Timer(delay, () async {
      _matchmakingBotOfferTimer = null;
      final latest = _currentRoom;
      if (!isHost ||
          latest == null ||
          latest.matchmakingState != 'waiting' ||
          !(_roomPlayers.length == 2 || _roomPlayers.length == 3)) {
        return;
      }
      try {
        final offer = await _matchmakingRepo.openBotFillOffer(latest.id);
        if (offer != null) {
          debugPrint(
              '[Matchmaking] Bot offer opened: version=${offer.offerVersion} humans=${offer.humanCount}');
          await _refreshMatchmakingState(latest.id);
        }
      } catch (error) {
        debugPrint('[Matchmaking] Bot offer retry needed: $error');
      }
    });
  }

  void _cancelMatchmakingBotOfferTimer() {
    _matchmakingBotOfferTimer?.cancel();
    _matchmakingBotOfferTimer = null;
  }

  Future<void> startMatchmaking(
    String name, {
    String gameType = 'kotchina',
    required int totalRounds,
  }) async {
    if (!AuthService.instance.isAuthenticated) {
      _setError(kGoogleOnlineRequiredMessage);
      return;
    }
    if (await _rejectNewGameWhileSessionActive()) return;
    await reset();
    _roomPlayers = [];
    _myName = name.trim();
    _transport = ConnectionTransport.online;
    _expectedPlayers = 4;
    _status = ConnectionStatus.connecting;
    _matchmakingStatus = MatchmakingStatus.joiningQueue;
    _isSearching = true;
    notifyListeners();
    try {
      debugPrint(
          '[Matchmaking] Entering queue: game=$gameType rounds=$totalRounds');
      final result = await _matchmakingRepo
          .enterMatchmaking(
            playerName: _myName,
            gameType: gameType,
            totalRounds: totalRounds,
          )
          .timeout(const Duration(seconds: 25));
      _myPlayerId = Supabase.instance.client.auth.currentUser?.id;
      if (_myPlayerId == null || _status != ConnectionStatus.connecting) {
        unawaited(_matchmakingRepo.leaveMatchmaking(result.roomId));
        return;
      }
      final room = await _matchmakingRepo.getRoom(result.roomId);
      _currentRoom = room;
      _role = result.isHost ? ConnectionRole.host : ConnectionRole.client;
      await _refreshRoomPlayers(room.id);
      if (result.isHost) {
        await _initializeMatchmakingHost(room);
      } else {
        await _initializeMatchmakingClient(room);
      }
      _listenToRoom(room.id);
      _startMatchmakingSyncIfNeeded();
      _status = ConnectionStatus.connected;
      _isSearching = false;
      _matchmakingStatus = room.isMatchmakingStarting
          ? MatchmakingStatus.starting
          : MatchmakingStatus.searching;
      debugPrint(
        '[Matchmaking] Joined room ${room.id} code=${room.roomCode} '
        'host=${result.isHost} rpcPlayers=${result.playerCount} '
        'roster=${_roomPlayers.length}',
      );
      notifyListeners();
      if (room.isMatchmakingStarting && isHost) {
        unawaited(_startApprovedMatchmakingGame());
      }
    } catch (error, stackTrace) {
      debugPrint('[Matchmaking] Join failed: $error\n$stackTrace');
      if (_status == ConnectionStatus.connecting) {
        _matchmakingStatus = MatchmakingStatus.error;
        _isSearching = false;
        _setError(_matchmakingRepo.translateError(error));
      }
    }
  }

  Future<void> _initializeMatchmakingHost(GameRoom room) async {
    final photo = await ProfileService.getProfilePhoto();
    _server = GameServer(
      onStateUpdate: _onEstimationHostState,
      onReaction: handleIncomingReaction,
      onEarthquake: handleIncomingEarthquake,
    );
    _configureServerAuthority(_server!);
    await _server!.start(_myName, myPlayerId, room.id, photo,
        maxPlayers: 4, totalRounds: room.totalRounds ?? kBoulaTotalRounds);
  }

  Future<void> _initializeMatchmakingClient(GameRoom room) async {
    final photo = await ProfileService.getProfilePhoto();
    _client = GameClient(
      onStateUpdate: (state) => unawaited(_applyOnlineEstimationState(state)),
      onError: (error) => debugPrint('[Matchmaking] Client: $error'),
      onReaction: handleIncomingReaction,
      onEarthquake: handleIncomingEarthquake,
    );
    await _client!.connect(room.id, myPlayerId, _myName, photo);
  }

  Future<void> _becomeMatchmakingHost(GameRoom room) async {
    if (_matchmakingHostPromotionInProgress || isHost) return;
    _matchmakingHostPromotionInProgress = true;
    try {
      _client?.disconnect(myPlayerId);
      _client = null;
      _role = ConnectionRole.host;
      await _initializeMatchmakingHost(room);
      _server!.syncPlayersFromRoom(_roomPlayers
          .map((p) => (id: p.playerId, name: p.playerName))
          .toList());
      await _sessionService.updateIsHost(isHost: true);
      debugPrint('[Matchmaking] Host changed to ${room.hostId}');
      _scheduleBotFillOfferIfNeeded();
      if (room.isMatchmakingStarting) {
        unawaited(_startApprovedMatchmakingGame());
      }
      notifyListeners();
    } catch (error) {
      debugPrint('[Matchmaking] Host promotion failed: $error');
    } finally {
      _matchmakingHostPromotionInProgress = false;
    }
  }

  Future<BotFillVoteResult?> voteForBotFill({
    required int offerVersion,
    required bool accepted,
  }) async {
    final room = _currentRoom;
    if (room == null || !room.isMatchmaking) return null;
    try {
      final result = await _matchmakingRepo.castBotFillVote(
          roomId: room.id, offerVersion: offerVersion, accepted: accepted);
      await _refreshMatchmakingState(room.id);
      return result;
    } catch (error) {
      _errorMessage = _matchmakingRepo.translateError(error);
      notifyListeners();
      return null;
    }
  }

  Future<void> _startApprovedMatchmakingGame() async {
    if (_matchmakingStartInProgress) return;
    final room = _currentRoom;
    if (room == null ||
        !room.isMatchmaking ||
        !isHost ||
        room.status != GameRoomStatus.waiting ||
        !room.isMatchmakingStarting ||
        _server == null) {
      return;
    }
    final humans = _roomPlayers.length;
    final bots = room.botsToFill;
    final valid = (humans == 4 && bots == 0) ||
        (humans == 3 && bots == 1) ||
        (humans == 2 && bots == 2);
    if (!valid) {
      debugPrint(
          '[Matchmaking] Refusing invalid start: humans=$humans bots=$bots');
      return;
    }
    _matchmakingStartInProgress = true;
    _matchmakingStatus = MatchmakingStatus.starting;
    notifyListeners();
    try {
      await _matchmakingRepo.startApprovedMatch(room.id);
      _server!.syncPlayersFromRoom(_roomPlayers
          .map((p) => (id: p.playerId, name: p.playerName))
          .toList());
      if (_server!.playerCount != humans) {
        throw StateError('Human sync mismatch');
      }
      _server!.addBotPlayers(count: bots);
      if (_server!.playerCount != 4) {
        throw StateError('Invalid final seat count');
      }
      await _sessionService.saveActiveRoomSession(
          roomId: room.id,
          roomCode: room.roomCode,
          playerId: myPlayerId,
          playerName: _myName,
          isHost: true);
      debugPrint('[Matchmaking] Start approved with $bots bots');
      _sendAction(ActionType.startGame);
    } catch (error, stackTrace) {
      debugPrint('[Matchmaking] Approved start failed: $error\n$stackTrace');
      _matchmakingStartInProgress = false;
      _errorMessage = _matchmakingRepo.translateError(error);
      notifyListeners();
    }
  }

  Future<void> cancelMatchmaking() async {
    if (_isLeavingMatchmaking) return;
    _isLeavingMatchmaking = true;
    _matchmakingStatus = MatchmakingStatus.cancelling;
    _cancelMatchmakingBotOfferTimer();
    _stopMatchmakingSync();
    notifyListeners();
    final room = _currentRoom;
    final roomId = room?.id;
    try {
      if (room?.isMatchmaking == true &&
          room!.status == GameRoomStatus.waiting &&
          roomId != null) {
        await _matchmakingRepo.leaveMatchmaking(roomId);
      }
    } catch (error) {
      debugPrint('[Matchmaking] Leave failed: $error');
    } finally {
      _currentRoom = null;
      await reset();
      _isLeavingMatchmaking = false;
    }
  }

  // ── Local (LAN / Hotspot) Hosting & Joining ──────────────────────────────

  Future<void> hostLocalGame(
    String name, {
    int expectedPlayers = 4,
    String gameType = 'kotchina',
    int port = 7890,
    int totalRounds = kBoulaTotalRounds,
  }) async {
    if (await _rejectNewGameWhileSessionActive()) return;
    await reset();
    _transport = ConnectionTransport.local;
    _myPlayerId = Supabase.instance.client.auth.currentUser?.id ?? _uuid.v4();
    nnProvider?.setPlayerId(_myPlayerId!);
    _basraProvider?.setPlayerId(_myPlayerId!);
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
          onReaction: handleIncomingReaction,
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
      } else if (gameType == 'basra') {
        _localBasraServer = LocalBasraGameServer(
          onStateUpdate: (state) {
            _basraProvider?.syncState(state);
          },
          onReaction: handleIncomingReaction,
        );
        await _localBasraServer!.start(
          name,
          _myPlayerId!,
          _currentRoom!.id,
          myPhoto,
          maxPlayers: expectedPlayers,
          port: port,
        );
        _localPort = _localBasraServer!.boundPort;
      } else {
        _localServer = LocalGameServer(
          onStateUpdate: (state) {
            _updateState(state);
          },
          onReaction: handleIncomingReaction,
          onEarthquake: handleIncomingEarthquake,
        );
        await _localServer!.start(
          name,
          _myPlayerId!,
          _currentRoom!.id,
          myPhoto,
          maxPlayers: expectedPlayers,
          port: port,
          totalRounds: totalRounds,
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
    if (await _rejectNewGameWhileSessionActive()) return;
    await reset();
    _transport = ConnectionTransport.local;
    _myPlayerId = Supabase.instance.client.auth.currentUser?.id ?? _uuid.v4();
    nnProvider?.setPlayerId(_myPlayerId!);
    _basraProvider?.setPlayerId(_myPlayerId!);
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
          onReaction: handleIncomingReaction,
        );
        await _localNnClient!.connect(hostIp, port, myPlayerId, name, myPhoto);
      } else if (expectedGameType == 'basra') {
        _localBasraClient = LocalBasraGameClient(
          onError: (err) => _setError(err),
          onStateUpdate: (state) {
            _basraProvider?.syncState(state);
          },
          onReaction: handleIncomingReaction,
        );
        await _localBasraClient!
            .connect(hostIp, port, myPlayerId, name, myPhoto);
      } else {
        _localClient = LocalGameClient(
          onStateUpdate: (state) {
            _updateState(state);
          },
          onError: (err) => _setError(err),
          onReaction: handleIncomingReaction,
          onEarthquake: handleIncomingEarthquake,
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

  Future<void> hostGame(
    String name, {
    int expectedPlayers = 4,
    String gameType = 'kotchina',
    int totalRounds = kBoulaTotalRounds,
  }) async {
    if (!AuthService.instance.isAuthenticated) {
      _setError(kGoogleOnlineRequiredMessage);
      return;
    }
    if (await _rejectNewGameWhileSessionActive()) return;
    await reset();
    _myPlayerId = Supabase.instance.client.auth.currentUser?.id ?? _uuid.v4();
    nnProvider?.setPlayerId(_myPlayerId!);
    _basraProvider?.setPlayerId(_myPlayerId!);
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
          createdRoom = await _lobbyRepo
              .createRoom(
                playerName: name,
                roomCode: roomCode,
                hostIp: '127.0.0.1',
                wsPort: 0,
                gameType: gameType,
                expectedPlayers: expectedPlayers,
              )
              .timeout(const Duration(seconds: 25));
          _myPlayerId =
              Supabase.instance.client.auth.currentUser?.id ?? _myPlayerId;
          nnProvider?.setPlayerId(_myPlayerId!);
          _basraProvider?.setPlayerId(_myPlayerId!);
          debugPrint(
              'Successfully created room: ${createdRoom.id} for player: $_myPlayerId');
          break;
        } catch (e) {
          debugPrint(
              'Failed to create room (retries left: ${retries - 1}): $e');
          if (e is TimeoutException ||
              e.toString().contains('TimeoutException') ||
              e.toString().contains('SocketException')) {
            throw Exception(
                'انتهى وقت الاتصال. يرجى التحقق من اتصالك بالإنترنت.');
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
          onStateUpdate: (state) => _onNnHostState(state),
          onReaction: handleIncomingReaction,
        );
        _configureNnServerAuthority(_nnServer!);
        final myPhoto = await ProfileService.getProfilePhoto();
        await _nnServer!.start(name, myPlayerId, createdRoom.id, myPhoto,
            maxPlayers: expectedPlayers);
      } else if (gameType == 'basra') {
        _basraServer = BasraGameServer(
          onStateUpdate: (state) => _onBasraHostState(state),
          onReaction: handleIncomingReaction,
        );
        _configureBasraServerAuthority(_basraServer!);
        final myPhoto = await ProfileService.getProfilePhoto();
        await _basraServer!.start(name, myPlayerId, createdRoom.id, myPhoto,
            maxPlayers: expectedPlayers);
      } else {
        _server = GameServer(
          onStateUpdate: _onEstimationHostState,
          onReaction: handleIncomingReaction,
          onEarthquake: handleIncomingEarthquake,
        );
        _configureServerAuthority(_server!);
        final myPhoto = await _loadMyAvatarRef();
        await _server!.start(
          name,
          myPlayerId,
          createdRoom.id,
          myPhoto,
          maxPlayers: expectedPlayers,
          totalRounds: totalRounds,
        );
      }

      _currentRoom = createdRoom;
      _actionSeq = createdRoom.actionSeq;
      _receivedActionSeq = createdRoom.actionSeq;
      _listenToRoom(createdRoom.id);
      await _sessionService.saveActiveRoomSession(
        roomId: createdRoom.id,
        roomCode: roomCode,
        playerId: myPlayerId,
        playerName: _myName,
        isHost: true,
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

  Future<void> startTestGame(String name,
      {int totalRounds = kBoulaTotalRounds}) async {
    if (await _rejectNewGameWhileSessionActive()) return;
    await reset();
    _myPlayerId = Supabase.instance.client.auth.currentUser?.id ?? _uuid.v4();
    _myName = name;
    _role = ConnectionRole.host;
    _isTestMode = true;
    _expectedPlayers = 4;
    _status = ConnectionStatus.connecting;
    notifyListeners();

    try {
      _server = GameServer(
        onStateUpdate: (state) {
          _updateState(state);
        },
        onReaction: handleIncomingReaction,
        onEarthquake: handleIncomingEarthquake,
      );
      _configureServerAuthority(_server!);
      final dummyRoomId = 'test_${_uuid.v4()}';
      final myPhoto = await ProfileService.getProfilePhoto();
      await _server!.start(name, myPlayerId, dummyRoomId, myPhoto,
          totalRounds: totalRounds);
      // Add 3 bot players to fill the remaining seats
      _server!.addBotPlayers(count: 3);
      _status = ConnectionStatus.connected;
      notifyListeners();
    } catch (e) {
      _setError('فشل تشغيل الخادم: $e');
    }
  }

  Future<void> startNinetyNineTestGame(String name,
      {int totalPlayers = 4}) async {
    if (await _rejectNewGameWhileSessionActive()) return;
    await reset();
    _myPlayerId = Supabase.instance.client.auth.currentUser?.id ?? _uuid.v4();
    _bindNnProvider();
    nnProvider?.setPlayerId(_myPlayerId!);
    _basraProvider?.setPlayerId(_myPlayerId!);
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
        onReaction: handleIncomingReaction,
      );
      final dummyRoomId = 'test_99_${_uuid.v4()}';
      final myPhoto = await ProfileService.getProfilePhoto();
      await _nnServer!.start(name, myPlayerId, dummyRoomId, myPhoto,
          maxPlayers: totalPlayers);
      if (totalPlayers > 1) {
        _nnServer!.addBotPlayers(count: totalPlayers - 1);
      }
      _status = ConnectionStatus.connected;
      notifyListeners();
    } catch (e) {
      _setError('فشل تشغيل الخادم: $e');
    }
  }

  Future<void> startBasraTestGame(String name, {int totalPlayers = 4}) async {
    if (await _rejectNewGameWhileSessionActive()) return;
    await reset();
    _myPlayerId = Supabase.instance.client.auth.currentUser?.id ?? _uuid.v4();
    _bindBasraProvider();
    nnProvider?.setPlayerId(_myPlayerId!);
    _basraProvider?.setPlayerId(_myPlayerId!);
    _myName = name;
    _role = ConnectionRole.host;
    _isTestMode = true;
    _expectedPlayers = totalPlayers;
    _status = ConnectionStatus.connecting;
    notifyListeners();

    try {
      _basraServer = BasraGameServer(
        onStateUpdate: (state) {
          _basraProvider?.syncState(state);
        },
        onReaction: handleIncomingReaction,
      );
      final dummyRoomId = 'test_basra_${_uuid.v4()}';
      final myPhoto = await ProfileService.getProfilePhoto();
      await _basraServer!.start(name, myPlayerId, dummyRoomId, myPhoto,
          maxPlayers: totalPlayers);
      if (totalPlayers > 1) {
        _basraServer!.addBotPlayers(count: totalPlayers - 1);
      }
      _status = ConnectionStatus.connected;
      notifyListeners();
    } catch (e) {
      _setError('فشل تشغيل الخادم: $e');
    }
  }

  // ── Join a game ───────────────────────────────────────────────

  Future<void> joinGameWithCode(String name, String code,
      {String? expectedGameType}) async {
    if (!AuthService.instance.isAuthenticated) {
      _setError(kGoogleOnlineRequiredMessage);
      return;
    }
    if (await _rejectNewGameWhileSessionActive()) return;
    await reset();
    _myPlayerId = Supabase.instance.client.auth.currentUser?.id ?? _uuid.v4();
    nnProvider?.setPlayerId(_myPlayerId!);
    _basraProvider?.setPlayerId(_myPlayerId!);
    _myName = name;
    _role = ConnectionRole.client;
    _isTestMode = false;
    _status = ConnectionStatus.connecting;
    _isSearching = true;
    notifyListeners();

    try {
      // 1. Join Supabase room
      final normalizedCode = code.trim().toUpperCase();
      debugPrint('Attempting to join room with code: $normalizedCode');
      final room = await _lobbyRepo
          .joinRoom(
            roomCode: normalizedCode,
            playerName: name,
            expectedGameType: expectedGameType,
          )
          .timeout(const Duration(seconds: 25));
      _myPlayerId =
          Supabase.instance.client.auth.currentUser?.id ?? _myPlayerId;
      nnProvider?.setPlayerId(_myPlayerId!);
      _basraProvider?.setPlayerId(_myPlayerId!);

      if (_status != ConnectionStatus.connecting) {
        _lobbyRepo.leaveRoom(room.id, myPlayerId).catchError((_) {});
        return;
      }

      _currentRoom = room;
      _actionSeq = room.actionSeq;
      _receivedActionSeq = room.actionSeq;
      debugPrint('Successfully joined room: ${room.id}');

      // 2. Connect to the mode-specific broadcast channel
      _isSearching = false;
      final myPhoto = await _loadMyAvatarRef();
      final type = expectedGameType ?? room.gameType;

      if (type == 'ninety_nine') {
        _nnClient = NinetyNineGameClient(
          onError: (err) => _setError(err),
          onStateUpdate: (state) =>
              unawaited(_applyOnlineNinetyNineState(state)),
          onReaction: handleIncomingReaction,
        );
        await _nnClient!.connect(room.id, myPlayerId, name, myPhoto);
      } else if (type == 'basra') {
        _basraClient = BasraGameClient(
          onError: (err) => _setError(err),
          onStateUpdate: (state) => unawaited(_applyOnlineBasraState(state)),
          onReaction: handleIncomingReaction,
        );
        await _basraClient!.connect(room.id, myPlayerId, name, myPhoto);
      } else {
        _client = GameClient(
          onStateUpdate: (state) =>
              unawaited(_applyOnlineEstimationState(state)),
          onError: (err) => _setError(err),
          onReaction: handleIncomingReaction,
          onEarthquake: handleIncomingEarthquake,
        );
        await _client!.connect(room.id, myPlayerId, name, myPhoto);
      }
      debugPrint('Connected to Supabase Broadcast for room: ${room.id}');

      // 3. Listen to Supabase room
      _listenToRoom(room.id);
      await _sessionService.saveActiveRoomSession(
        roomId: room.id,
        roomCode: normalizedCode,
        playerId: myPlayerId,
        playerName: _myName,
        isHost: false,
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
      debugPrint(
          '[GameProvider] Auto-healing status from error→connected for mid-game action "$action"');
      _status = ConnectionStatus.connected;
    }

    if (_status != ConnectionStatus.connected) {
      debugPrint(
          'Cannot send action "$action": Not connected (status: $_status)');
      return;
    }

    if (_transport == ConnectionTransport.local) {
      if (_role == ConnectionRole.host) {
        if (_localServer != null) {
          _localServer!
              .sendHostAction(action, {'playerId': myPlayerId, ...extra});
        } else if (_localNnServer != null) {
          _localNnServer!
              .sendHostAction(action, {'playerId': myPlayerId, ...extra});
        } else if (_localBasraServer != null) {
          _localBasraServer!
              .sendHostAction(action, {'playerId': myPlayerId, ...extra});
        }
      } else if (_role == ConnectionRole.client) {
        if (_localClient != null) {
          _localClient!.sendAction(action, myPlayerId, extra);
        } else if (_localNnClient != null) {
          _localNnClient!.sendAction(action, extra.isEmpty ? null : extra);
        } else if (_localBasraClient != null) {
          _localBasraClient!.sendAction(action, extra.isEmpty ? null : extra);
        }
      }
      return;
    }

    if (_usesServerAuthority() && !_lobbyLocalHostActions.contains(action)) {
      if (action == ActionType.requestStateSync) {
        unawaited(_refreshFromRoomSnapshot());
        return;
      }
      unawaited(_sendServerAction(action, extra));
      return;
    }

    if (_role == ConnectionRole.host) {
      if (_server != null) {
        _server!.sendHostAction(action, {'playerId': myPlayerId, ...extra});
      } else if (_nnServer != null) {
        _nnServer!.sendHostAction(action, {'playerId': myPlayerId, ...extra});
      } else if (_basraServer != null) {
        _basraServer!
            .sendHostAction(action, {'playerId': myPlayerId, ...extra});
      } else {
        debugPrint('Cannot send action "$action": Host server is null');
      }
    } else if (_role == ConnectionRole.client) {
      if (_client != null) {
        _client!.sendAction(action, myPlayerId, extra);
      } else if (_nnClient != null) {
        _nnClient!.sendAction(action, extra.isEmpty ? null : extra);
      } else if (_basraClient != null) {
        _basraClient!.sendAction(action, extra.isEmpty ? null : extra);
      } else {
        debugPrint('Cannot send action "$action": Client is null');
      }
    } else {
      debugPrint('Cannot send action "$action": Connection role is $_role');
    }
  }

  Future<void> startGame() async {
    if (isMatchmaking) {
      if (_currentRoom?.matchmakingState != 'starting') {
        debugPrint('[Matchmaking] Ignored unauthorized manual start');
        return;
      }
      await _startApprovedMatchmakingGame();
      return;
    }
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

        if (_localServer != null &&
            _localServer!.playerCount < 4 &&
            _currentRoom!.gameType == 'kotchina') {
          _localServer!.addBotPlayers(count: 4 - _localServer!.playerCount);
        } else if (_localNnServer != null &&
            _localNnServer!.playerCount < _expectedPlayers) {
          _localNnServer!.addBotPlayers(
              count: _expectedPlayers - _localNnServer!.playerCount);
        } else if (_localBasraServer != null &&
            _localBasraServer!.playerCount < _expectedPlayers) {
          _localBasraServer!.addBotPlayers(
              count: _expectedPlayers - _localBasraServer!.playerCount);
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
            _roomPlayers
                .map((p) => (id: p.playerId, name: p.playerName))
                .toList(),
          );
          final is99 = _currentRoom?.gameType == 'ninety_nine';
          if (!is99 && _server!.playerCount < 4) {
            _server!.addBotPlayers(count: 4 - _server!.playerCount);
          }
        } else if (_nnServer != null) {
          if (_roomPlayers.isNotEmpty) {
            _nnServer!.syncPlayersFromRoom(
              _roomPlayers
                  .map((p) => (id: p.playerId, name: p.playerName))
                  .toList(),
            );
          }
          if (_nnServer!.playerCount < _expectedPlayers) {
            _nnServer!.addBotPlayers(
                count: _expectedPlayers - _nnServer!.playerCount);
          }
        } else if (_basraServer != null) {
          if (_roomPlayers.isNotEmpty) {
            _basraServer!.syncPlayersFromRoom(
              _roomPlayers
                  .map((p) => (id: p.playerId, name: p.playerName))
                  .toList(),
            );
          }
          if (_basraServer!.playerCount < _expectedPlayers) {
            _basraServer!.addBotPlayers(
                count: _expectedPlayers - _basraServer!.playerCount);
          }
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
    if (!isHost) return;

    // Immediate UI feedback for Estimation lobby while host applies locally.
    if (!isNinetyNine && !isBasra && _state?.phase == GamePhase.lobby) {
      _state!.cardTheme = theme;
      notifyListeners();
    }

    _sendAction(ActionType.changeTheme, {'theme': theme});
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

  void submitDashCall(bool wantsDashCall) =>
      _sendAction(ActionType.submitDashCall, {'wantsDashCall': wantsDashCall});

  void submitDeclaration(int declared) {
    if (_state != null && me != null) {
      final forbidden = GameEngine.getForbiddenDeclaration(_state!, myPlayerId);
      if (forbidden != null && declared == forbidden) {
        EstimationEventDispatcher.instance
            .notifyForbiddenDeclarationAttempt(me!, forbidden);
      }
    }
    _sendAction(ActionType.submitDeclaration, {'declared': declared});
  }

  void playCard(PlayingCard card) {
    _autoPlayCardTimer?.cancel();
    _autoPlayCardTimer = null;
    _authorityTimeoutTimer?.cancel();
    _authorityTimeoutTimer = null;
    _sendAction(ActionType.playCard, {'card': card.toJson()});
  }

  void requestStateSync() => _sendAction(ActionType.requestStateSync);

  Future<void> advanceServerBotsAfterTakeover() async {
    if (!_usesServerAuthority() || isNinetyNine || isBasra) return;
    for (var attempt = 0; attempt < 12 && _serverActionInFlight; attempt++) {
      await Future<void>.delayed(const Duration(milliseconds: 250));
    }
    if (_serverActionInFlight) {
      debugPrint('[GameProvider] Bot takeover wake-up deferred to next sync');
      return;
    }
    await _sendServerAction(ActionType.processBots, const {});
  }

  void nextRound() => _sendAction(ActionType.nextRound);

  // ── Reactions & Earthquakes ───────────────────────────────────

  final Set<String> _handledEarthquakeIds = {};

  void handleIncomingEarthquake(Map<String, dynamic> data) {
    try {
      final id =
          data['earthquakeId']?.toString() ?? data['id']?.toString() ?? '';
      if (id.isNotEmpty) {
        if (_handledEarthquakeIds.contains(id)) return;
        _handledEarthquakeIds.add(id);
        if (_handledEarthquakeIds.length > 60) {
          _handledEarthquakeIds.remove(_handledEarthquakeIds.first);
        }
      }

      final playerId = data['playerId'] as String? ?? '';
      if (playerId == myPlayerId && id.isEmpty) return;

      final playerName = data['playerName'] as String? ?? 'Player';
      final roundNumber =
          data['roundNumber'] as int? ?? _state?.roundNumber ?? 1;
      PlayingCard? card;
      if (data['card'] != null) {
        if (data['card'] is Map<String, dynamic>) {
          card = PlayingCard.fromJson(data['card'] as Map<String, dynamic>);
        }
      }
      card ??= PlayingCard(rank: Rank.ace, suit: Suit.spade);

      EstimationEventBus.instance.fire(
        EarthquakeStrikeUsed(
          playerId: playerId,
          playerName: playerName,
          card: card,
          roundNumber: roundNumber,
        ),
      );
    } catch (e) {
      debugPrint('[GameProvider] Error handling incoming earthquake: $e');
    }
  }

  void triggerEarthquakeStrike(
    PlayingCard card, {
    Offset? flightOrigin,
    Size? cardSize,
  }) {
    final earthquakeId = DateTime.now().microsecondsSinceEpoch.toString();
    _handledEarthquakeIds.add(earthquakeId);

    // Fire locally immediately on striker device for 0ms latency
    EstimationEventBus.instance.fire(
      EarthquakeStrikeUsed(
        playerId: myPlayerId,
        playerName: _myName,
        card: card,
        roundNumber: _state?.roundNumber ?? 1,
        flightOriginGlobal: flightOrigin,
        flightCardSize: cardSize,
      ),
    );

    // Broadcast action to all other players and server
    _sendAction(ActionType.triggerEarthquake, {
      'earthquakeId': earthquakeId,
      'card': card.toJson(),
      'roundNumber': _state?.roundNumber ?? 1,
      'playerName': _myName,
    });
  }

  void handleIncomingReaction(Map<String, dynamic> data) {
    try {
      final reaction = GameReaction.fromJson(data);
      _activeReactions[reaction.playerId] = reaction;
      _reactionTimers[reaction.playerId]?.cancel();
      _reactionTimers[reaction.playerId] =
          Timer(const Duration(milliseconds: 3200), () {
        _activeReactions.remove(reaction.playerId);
        notifyListeners();
      });
      notifyListeners();
    } catch (e) {
      debugPrint('[GameProvider] Error handling incoming reaction: $e');
    }
  }

  void sendReaction(String emoji, [String? text]) {
    final reaction = GameReaction(
      id: DateTime.now().microsecondsSinceEpoch.toString(),
      playerId: myPlayerId,
      playerName: _myName,
      emoji: emoji,
      text: text,
      timestamp: DateTime.now().millisecondsSinceEpoch,
    );
    handleIncomingReaction(reaction.toJson());
    _sendAction(ActionType.sendReaction, {
      'reactionId': reaction.id,
      'emoji': emoji,
      'text': text,
      'timestamp': reaction.timestamp,
    });
  }

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
    } else if (isGoogleOnlineAuthError(raw)) {
      return kGoogleOnlineRequiredMessage;
    } else if (raw.contains('ONGOING_GAME_REQUIRES_RETURN')) {
      return 'لديك مباراة ما زالت جارية. عد إليها قبل الانضمام إلى غرفة أخرى.';
    } else if (raw.contains('SocketException') ||
        raw.contains('Connection refused') ||
        raw.contains('TimeoutException')) {
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
    _matchmakingRosterFetchEpoch++;
    _authorityTimeoutTimer?.cancel();
    _authorityTimeoutTimer = null;
    _cancelMatchmakingBotOfferTimer();
    _stopMatchmakingSync();
    await _sessionService.clearSession();
    _nnProvider?.reset();
    _basraProvider?.reset();
    final myId = myPlayerId;
    if (_currentRoom != null && myId.isNotEmpty) {
      try {
        if (_currentRoom!.isMatchmaking &&
            _currentRoom!.status == GameRoomStatus.waiting) {
          await _matchmakingRepo.leaveMatchmaking(_currentRoom!.id);
        } else {
          await _lobbyRepo.leaveRoom(_currentRoom!.id, myId);
        }
        await _sessionService.clearSession();
      } catch (e) {
        debugPrint('Error leaving room: $e');
      }
    }

    _roomSub?.cancel();
    _roomSub = null;
    _playersSub?.cancel();
    _playersSub = null;

    _autoPlayCardTimer?.cancel();
    _autoPlayCardTimer = null;

    for (final t in _reactionTimers.values) {
      t.cancel();
    }
    _reactionTimers.clear();
    _activeReactions.clear();

    await _discoveryService.stopBroadcasting();
    if (_localServer != null) {
      await _localServer!.stop();
      _localServer = null;
    }
    if (_localNnServer != null) {
      await _localNnServer!.stop();
      _localNnServer = null;
    }
    if (_localBasraServer != null) {
      await _localBasraServer!.stop();
      _localBasraServer = null;
    }
    if (_localClient != null) {
      _localClient!.disconnect(myId);
      _localClient = null;
    }
    if (_localNnClient != null) {
      await _localNnClient!.disconnect();
      _localNnClient = null;
    }
    if (_localBasraClient != null) {
      await _localBasraClient!.disconnect();
      _localBasraClient = null;
    }

    if (_server != null) {
      await _server!.stop();
      _server = null;
    }
    if (_nnServer != null) {
      await _nnServer!.stop();
      _nnServer = null;
    }
    if (_basraServer != null) {
      await _basraServer!.stop();
      _basraServer = null;
    }
    if (_client != null) {
      _client!.disconnect(myId);
      _client = null;
    }
    if (_nnClient != null) {
      await _nnClient!.disconnect();
      _nnClient = null;
    }
    if (_basraClient != null) {
      await _basraClient!.disconnect();
      _basraClient = null;
    }

    _state = null;
    _currentRoom = null;
    _roomPlayers = [];
    _actionSeq = 0;
    _receivedActionSeq = 0;
    _expectedOwnHandCount = -1;
    _lastKnownPrivateHand = [];
    _pendingAuthorityStateApply = null;
    _serverActionInFlight = false;
    _myAvatarRef = null;
    _lobbyAvatarRefs.clear();
    _role = ConnectionRole.none;
    _status = ConnectionStatus.idle;
    _transport = ConnectionTransport.online;
    _errorMessage = '';
    _isSearching = false;
    _isTestMode = false;
    _isTemporarilyAway = false;
    _expectedPlayers = 4;
    _matchmakingStatus = MatchmakingStatus.idle;
    _lastPresentedBotOfferVersion = null;
    _matchmakingStartInProgress = false;
    _matchmakingHostPromotionInProgress = false;
    _matchmakingSessionSaved = false;
    EstimationEventBus.instance.clearHistory();
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
      _myName = session.playerName;

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

  /// Leave the game screen without forfeiting the active online seat.
  /// The session and room membership remain available for recovery.
  Future<void> temporarilyLeaveOngoingGame() async {
    final room = _currentRoom;
    if (room == null || room.status != GameRoomStatus.playing || isLocal) {
      await reset();
      return;
    }
    _isTemporarilyAway = true;
    _autoPlayCardTimer?.cancel();
    _autoPlayCardTimer = null;
    _authorityTimeoutTimer?.cancel();
    _authorityTimeoutTimer = null;
    _cancelMatchmakingBotOfferTimer();
    _roomSub?.cancel();
    _roomSub = null;
    _playersSub?.cancel();
    _playersSub = null;
    try {
      // Complete the ownership handoff before the home screen refreshes. This
      // makes the five-minute recovery state appear on both phones at once.
      await _lobbyRepo.markOffline(room.id);
    } catch (error) {
      debugPrint('[Reconnection] Could not mark temporary departure: $error');
    }
    if (isHost) {
      _server?.markHostTemporarilyAway();
    } else {
      _client?.disconnect(myPlayerId);
      _client = null;
    }
    _status = ConnectionStatus.idle;
    notifyListeners();
  }

  /// Stop this installation when the same Google account has claimed the seat
  /// from another device. This intentionally performs no server-side leave:
  /// deleting the shared membership would also kick out the new owner.
  Future<void> relinquishSeatToOtherDevice() async {
    _isTemporarilyAway = true;
    _autoPlayCardTimer?.cancel();
    _autoPlayCardTimer = null;
    _authorityTimeoutTimer?.cancel();
    _authorityTimeoutTimer = null;
    _cancelMatchmakingBotOfferTimer();
    _stopMatchmakingSync();
    await _roomSub?.cancel();
    _roomSub = null;
    await _playersSub?.cancel();
    _playersSub = null;
    if (isHost) {
      _server?.markHostTemporarilyAway();
    } else {
      _client?.disconnect(myPlayerId);
      _client = null;
    }
    _status = ConnectionStatus.idle;
    _errorMessage = 'تم فتح المباراة على جهاز آخر بهذا الحساب.';
    notifyListeners();
  }

  Future<bool> resumeTemporarilyLeftGame(ActiveRoomSession session) async {
    if (!canResumeTemporarilyLeftGame) return false;
    if (isHost && _server != null) {
      _server!.reclaimHostSeat();
      await _lobbyRepo.pingHeartbeat(session.roomId);
      _listenToRoom(session.roomId);
      _status = ConnectionStatus.connected;
      _isTemporarilyAway = false;
      notifyListeners();
      return true;
    }
    restoreIdentity(playerId: session.playerId, playerName: session.playerName);
    final success = await rehydrateGameState(session.roomId);
    if (success) _isTemporarilyAway = false;
    return success;
  }

  // ── Identity restoration (no network call) ────────────────────────────────

  /// Set player identity from a persisted session before making network calls.
  /// Must be called before [rehydrateGameState] so [myPlayerId] is populated.
  void restoreIdentity({
    required String playerId,
    required String playerName,
  }) {
    _myPlayerId = playerId;
    _myName = playerName;
    nnProvider?.setPlayerId(playerId);
    _basraProvider?.setPlayerId(playerId);
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

      // 1. Atomically fetch the public table plus only this device's real hand.
      final view = await _lobbyRepo.getMyGameState(roomId);
      final rawSnapshot = view?['state'];
      if (rawSnapshot is! Map) {
        debugPrint('[Provider] No snapshot found — cannot rehydrate');
        return false;
      }

      _state = GameState.fromJson(Map<String, dynamic>.from(rawSnapshot));
      _actionSeq = (view?['actionSeq'] as num?)?.toInt() ?? _actionSeq;
      _receivedActionSeq = _actionSeq;
      final ownIndex = _state!.players.indexWhere((p) => p.id == myPlayerId);
      if (ownIndex >= 0) {
        GameEngine.autoSort(_state!.players[ownIndex].hand);
        _lastKnownPrivateHand = List.from(_state!.players[ownIndex].hand);
        _expectedOwnHandCount = _lastKnownPrivateHand.length;
      }

      // 2. Clean up any stale client connection.
      _client?.disconnect(myPlayerId);

      // 3. Re-subscribe to the Realtime broadcast channel.
      _client = GameClient(
        onStateUpdate: (state) => unawaited(_applyOnlineEstimationState(state)),
        onError: (err) => _setError(err),
      );
      final myPhoto = await ProfileService.getProfilePhoto();
      await _client!.connect(roomId, myPlayerId, myName, myPhoto);

      // 4. Re-subscribe to Supabase room stream.
      _listenToRoom(roomId);
      _currentRoom = await _lobbyRepo.getRoom(roomId);

      _role = ConnectionRole.client;
      _status = ConnectionStatus.connected;
      notifyListeners();

      debugPrint(
          '[Provider] Rehydration complete — phase: ${_state!.phase.name}');
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
      final privateHands =
          await _lobbyRepo.getRoomPrivateHandsForHost(session.roomId);
      for (final entry in privateHands.entries) {
        final idx = restoredState.players.indexWhere((p) => p.id == entry.key);
        if (idx != -1) {
          final orderedHand = List<PlayingCard>.from(entry.value);
          GameEngine.autoSort(orderedHand);
          restoredState.players[idx].hand = orderedHand;
        }
      }

      // 2. Clean up any existing connections.
      _client?.disconnect(myPlayerId);
      await _server?.stop();
      _client = null;

      // 3. Start GameServer with the restored state.
      _server = GameServer(
        onStateUpdate: _onEstimationHostState,
      );
      _configureServerAuthority(_server!);
      await _server!.restoreFromState(
        state: restoredState,
        hostPlayerId: session.playerId,
        hostName: session.playerName,
        roomId: session.roomId,
      );

      // 4. Restore local identity & room reference.
      _myPlayerId = session.playerId;
      nnProvider?.setPlayerId(_myPlayerId!);
      _basraProvider?.setPlayerId(_myPlayerId!);
      _myName = session.playerName;
      _role = ConnectionRole.host;
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
    _autoPlayCardTimer?.cancel();
    _autoPlayCardTimer = null;
    _authorityTimeoutTimer?.cancel();
    _authorityTimeoutTimer = null;
    _roomSub?.cancel();
    _playersSub?.cancel();
    _server?.stop();
    _localServer?.stop();
    _nnServer?.stop();
    _localNnServer?.stop();
    _basraServer?.stop();
    _localBasraServer?.stop();
    _client?.disconnect(myPlayerId);
    _localClient?.disconnect(myPlayerId);
    _nnClient?.disconnect();
    _localNnClient?.disconnect();
    _basraClient?.disconnect();
    _localBasraClient?.disconnect();
    super.dispose();
  }
}
