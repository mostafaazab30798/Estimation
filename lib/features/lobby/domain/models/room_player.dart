// lib/features/lobby/domain/models/room_player.dart

class RoomPlayer {
  final String id;
  final String roomId;
  final String playerId;
  final String playerName;
  final bool isHost;
  final DateTime joinedAt;
  final bool isOnline;
  final DateTime lastSeen;

  const RoomPlayer({
    required this.id,
    required this.roomId,
    required this.playerId,
    required this.playerName,
    required this.isHost,
    required this.joinedAt,
    this.isOnline = true,
    required this.lastSeen,
  });

  factory RoomPlayer.fromJson(Map<String, dynamic> json) {
    return RoomPlayer(
      id: json['id'] as String,
      roomId: json['room_id'] as String,
      playerId: json['player_id'] as String,
      playerName: json['player_name'] as String,
      isHost: json['is_host'] as bool,
      joinedAt: DateTime.parse(json['joined_at'] as String),
      isOnline: json['is_online'] as bool? ?? true,
      lastSeen: DateTime.tryParse(json['last_seen'] as String? ?? '')?.toUtc() ??
          DateTime.parse(json['joined_at'] as String).toUtc(),
    );
  }

  bool get isActiveForMatchmaking {
    if (isOnline) return true;
    return lastSeen.isAfter(
      DateTime.now().toUtc().subtract(const Duration(seconds: 45)),
    );
  }

  /// True when both lists contain the same player ids, ignoring row metadata
  /// such as `last_seen` or `hand_cards` that change on every heartbeat/save.
  static bool sameMembership(List<RoomPlayer> a, List<RoomPlayer> b) {
    if (identical(a, b)) return true;
    if (a.length != b.length) return false;
    final ids = <String>{for (final player in a) player.playerId};
    return b.every((player) => ids.contains(player.playerId));
  }

  /// Stable table order shared by Realtime and one-shot roster fetches.
  /// Supabase Realtime does not guarantee row order, so rendering its raw list
  /// makes occupied seats (including the local "You" badge) jump around.
  static List<RoomPlayer> stableSeatOrder(Iterable<RoomPlayer> players) {
    final ordered = List<RoomPlayer>.of(players);
    ordered.sort((a, b) {
      if (a.isHost != b.isHost) return a.isHost ? -1 : 1;
      final joined = a.joinedAt.compareTo(b.joinedAt);
      if (joined != 0) return joined;
      return a.playerId.compareTo(b.playerId);
    });
    return ordered;
  }

  /// Whether rebuilding the visible matchmaking seats would change anything.
  static bool sameSeatPresentation(List<RoomPlayer> a, List<RoomPlayer> b) {
    if (a.length != b.length) return false;
    for (var index = 0; index < a.length; index++) {
      if (a[index].playerId != b[index].playerId ||
          a[index].playerName != b[index].playerName ||
          a[index].isHost != b[index].isHost) {
        return false;
      }
    }
    return true;
  }
}
