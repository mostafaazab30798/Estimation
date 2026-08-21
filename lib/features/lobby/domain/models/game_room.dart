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
    required this.createdAt,
    this.startedAt,
  });

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
      createdAt: DateTime.parse(json['created_at'] as String),
      startedAt: json['started_at'] != null
          ? DateTime.parse(json['started_at'] as String)
          : null,
    );
  }
}
