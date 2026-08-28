// lib/features/lobby/domain/models/game_room.dart

enum GameRoomStatus {
  waiting,
  playing,
  finished,
  cancelled,
}

class GameRoom {
  final String id;
  final String roomCode;
  final String hostId;
  final GameRoomStatus status;
  final int maxPlayers;
  final String hostIp;
  final int wsPort;
  final String gameType;
  final String roomKind;
  final String matchmakingState;
  final int? totalRounds;
  final int botsToFill;
  final int botOfferVersion;
  final int botYesVotes;
  final DateTime? botOfferAfter;
  final DateTime createdAt;
  final DateTime? startedAt;

  const GameRoom({
    required this.id,
    required this.roomCode,
    required this.hostId,
    required this.status,
    required this.maxPlayers,
    required this.hostIp,
    required this.wsPort,
    this.gameType = 'kotchina',
    this.roomKind = 'private',
    this.matchmakingState = 'none',
    this.totalRounds,
    this.botsToFill = 0,
    this.botOfferVersion = 0,
    this.botYesVotes = 0,
    this.botOfferAfter,
    required this.createdAt,
    this.startedAt,
  });

  bool get isMatchmaking => roomKind == 'matchmaking';
  bool get isPrivateRoom => !isMatchmaking;
  bool get isBotVoteOpen => matchmakingState == 'voting';
  bool get isMatchmakingStarting => matchmakingState == 'starting';

  factory GameRoom.fromJson(Map<String, dynamic> json) {
    GameRoomStatus parseStatus(String status) {
      switch (status) {
        case 'waiting':
          return GameRoomStatus.waiting;
        case 'playing':
          return GameRoomStatus.playing;
        case 'finished':
          return GameRoomStatus.finished;
        case 'cancelled':
          return GameRoomStatus.cancelled;
        default:
          return GameRoomStatus.waiting;
      }
    }

    return GameRoom(
      id: json['id'] as String,
      roomCode: json['room_code'] as String,
      hostId: json['host_id'] as String,
      status: parseStatus(json['status'] as String),
      maxPlayers: json['max_players'] as int,
      hostIp: json['host_ip'] as String,
      wsPort: json['ws_port'] as int,
      gameType: (json['game_type'] as String?) ?? 'kotchina',
      roomKind: (json['room_kind'] as String?) ?? 'private',
      matchmakingState: (json['matchmaking_state'] as String?) ?? 'none',
      totalRounds: (json['total_rounds'] as num?)?.toInt(),
      botsToFill: (json['bots_to_fill'] as num?)?.toInt() ?? 0,
      botOfferVersion: (json['bot_offer_version'] as num?)?.toInt() ?? 0,
      botYesVotes: (json['bot_yes_votes'] as num?)?.toInt() ?? 0,
      botOfferAfter: json['bot_offer_after'] != null
          ? DateTime.tryParse(json['bot_offer_after'] as String)
          : null,
      createdAt: DateTime.parse(json['created_at'] as String),
      startedAt: json['started_at'] != null
          ? DateTime.parse(json['started_at'] as String)
          : null,
    );
  }
}
