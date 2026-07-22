// lib/features/lobby/domain/models/room_player.dart

class RoomPlayer {
  final String id;
  final String roomId;
  final String playerId;
  final String playerName;
  final bool isHost;
  final DateTime joinedAt;

  const RoomPlayer({
    required this.id,
    required this.roomId,
    required this.playerId,
    required this.playerName,
    required this.isHost,
    required this.joinedAt,
  });

  factory RoomPlayer.fromJson(Map<String, dynamic> json) {
    return RoomPlayer(
      id: json['id'] as String,
      roomId: json['room_id'] as String,
      playerId: json['player_id'] as String,
      playerName: json['player_name'] as String,
      isHost: json['is_host'] as bool,
      joinedAt: DateTime.parse(json['joined_at'] as String),
    );
  }
}
