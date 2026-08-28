class BotFillOfferResult {
  final int offerVersion;
  final int humanCount;

  const BotFillOfferResult({
    required this.offerVersion,
    required this.humanCount,
  });

  factory BotFillOfferResult.fromJson(Map<String, dynamic> json) =>
      BotFillOfferResult(
        offerVersion: (json['offer_version'] as num).toInt(),
        humanCount: (json['human_count'] as num).toInt(),
      );
}

class BotFillVoteResult {
  final String result;
  final bool shouldStart;
  final bool waitingForVotes;
  final int yesVotes;
  final int humanCount;
  final int botsToFill;

  const BotFillVoteResult({
    required this.result,
    required this.shouldStart,
    required this.waitingForVotes,
    required this.yesVotes,
    required this.humanCount,
    required this.botsToFill,
  });

  factory BotFillVoteResult.fromJson(Map<String, dynamic> json) =>
      BotFillVoteResult(
        result: json['result'] as String? ?? 'waiting',
        shouldStart: json['should_start'] as bool? ?? false,
        waitingForVotes: json['waiting_for_votes'] as bool? ?? false,
        yesVotes: (json['yes_votes'] as num?)?.toInt() ?? 0,
        humanCount: (json['human_count'] as num?)?.toInt() ?? 0,
        botsToFill: (json['bots_to_fill'] as num?)?.toInt() ?? 0,
      );
}
