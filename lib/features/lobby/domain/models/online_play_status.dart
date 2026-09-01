class OnlinePlayStatus {
  final bool canJoinNewOnline;
  final bool hasActiveMembership;
  final DateTime? onlineBanUntil;
  final DateTime? graceEndsAt;
  final String? roomId;
  final String? roomStatus;

  const OnlinePlayStatus({
    required this.canJoinNewOnline,
    this.hasActiveMembership = false,
    this.onlineBanUntil,
    this.graceEndsAt,
    this.roomId,
    this.roomStatus,
  });

  factory OnlinePlayStatus.fromJson(Map<String, dynamic> json) {
    DateTime? parseTime(dynamic value) {
      if (value == null) return null;
      return DateTime.tryParse(value.toString())?.toUtc();
    }

    return OnlinePlayStatus(
      canJoinNewOnline: json['can_join_new_online'] as bool? ?? true,
      hasActiveMembership: json['has_active_membership'] as bool? ?? false,
      onlineBanUntil: parseTime(json['online_ban_until']),
      graceEndsAt: parseTime(json['grace_ends_at']),
      roomId: json['room_id'] as String?,
      roomStatus: json['room_status'] as String?,
    );
  }

  /// When the user may tap "play online" again.
  DateTime? get blockedUntil {
    if (canJoinNewOnline) return null;
    final now = DateTime.now().toUtc();
    final candidates = <DateTime>[];
    if (hasActiveMembership &&
        graceEndsAt != null &&
        graceEndsAt!.isAfter(now)) {
      candidates.add(graceEndsAt!);
    }
    if (onlineBanUntil != null && onlineBanUntil!.isAfter(now)) {
      candidates.add(onlineBanUntil!);
    }
    if (candidates.isEmpty) return null;
    candidates.sort();
    return candidates.last;
  }

  /// True when every block timer has expired but the server still reports blocked.
  bool get isStaleBlock => !canJoinNewOnline && remainingBlock().inSeconds <= 0;

  bool get canReturnToOngoingGame {
    if (!hasActiveMembership || roomId == null) return false;
    final ends = graceEndsAt;
    if (ends == null) return true;
    return ends.isAfter(DateTime.now().toUtc());
  }

  Duration remainingBlock([DateTime? now]) {
    final at = (now ?? DateTime.now()).toUtc();
    final until = blockedUntil;
    if (until == null) return Duration.zero;
    final diff = until.difference(at);
    return diff.isNegative ? Duration.zero : diff;
  }
}
