class MatchmakingJoinResult {
  final String roomId;
  final String roomCode;
  final String hostId;
  final bool isHost;
  final int playerCount;
  final int botsToFill;
  final int botOfferVersion;
  final String matchmakingState;

  const MatchmakingJoinResult({
    required this.roomId,
    required this.roomCode,
    required this.hostId,
    required this.isHost,
    required this.playerCount,
    required this.botsToFill,
    required this.botOfferVersion,
    required this.matchmakingState,
  });

  factory MatchmakingJoinResult.fromJson(Map<String, dynamic> json) =>
      MatchmakingJoinResult(
        roomId: json['room_id'] as String,
        roomCode: json['room_code'] as String,
        hostId: json['host_id'] as String,
        isHost: json['is_host'] as bool? ?? false,
        playerCount: (json['player_count'] as num?)?.toInt() ?? 1,
        botsToFill: (json['bots_to_fill'] as num?)?.toInt() ?? 0,
        botOfferVersion: (json['bot_offer_version'] as num?)?.toInt() ?? 0,
        matchmakingState: json['matchmaking_state'] as String? ?? 'waiting',
      );
}
