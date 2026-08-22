// lib/models/estimation_statistics.dart

class EstimationStatistics {
  final int gamesPlayed;
  final int gamesWon;
  final int totalRounds;
  final int totalTricks;
  final int totalDeclared;
  final int perfectEstimates; // rounds where actual == declared (or successful dash call)
  final int failedDeclarations; // rounds where actual != declared
  final int highestSuccessfulBid; // trick count of highest winning bid made
  final int highestSuccessfulDeclaration; // highest declared trick count made (actual == declared)
  final int highestScoreInOneRound;
  final int lowestScoreInOneRound;
  final int bestComeback; // max points behind when trailing mid-game that player overcame to win
  final int totalComebacks; // total comeback events achieved across games
  final int majorComebacks; // total major comebacks (4th to 1st)
  final int finalRoundComebacks; // total final-round clutch comebacks
  final int longestWinningStreak;
  final int currentWinningStreak;

  const EstimationStatistics({
    this.gamesPlayed = 0,
    this.gamesWon = 0,
    this.totalRounds = 0,
    this.totalTricks = 0,
    this.totalDeclared = 0,
    this.perfectEstimates = 0,
    this.failedDeclarations = 0,
    this.highestSuccessfulBid = 0,
    this.highestSuccessfulDeclaration = 0,
    this.highestScoreInOneRound = 0,
    this.lowestScoreInOneRound = 0,
    this.bestComeback = 0,
    this.totalComebacks = 0,
    this.majorComebacks = 0,
    this.finalRoundComebacks = 0,
    this.longestWinningStreak = 0,
    this.currentWinningStreak = 0,
  });

  /// Win rate percentage (0.0 to 100.0)
  double get winRate =>
      gamesPlayed > 0 ? (gamesWon / gamesPlayed) * 100.0 : 0.0;

  /// Total declarations made (perfect estimates + failed declarations)
  int get totalDeclarations => perfectEstimates + failedDeclarations;

  /// Successful declarations is an alias for perfect estimates
  int get successfulDeclarations => perfectEstimates;

  /// Declaration accuracy: (Perfect estimates / Total declarations) * 100
  double get declarationAccuracy =>
      totalDeclarations > 0 ? (perfectEstimates / totalDeclarations) * 100.0 : 0.0;

  /// Average declared tricks per round
  double get averageDeclaredTricks =>
      totalRounds > 0 ? totalDeclared / totalRounds : 0.0;

  /// Average actual tricks won per round
  double get averageActualTricks =>
      totalRounds > 0 ? totalTricks / totalRounds : 0.0;

  factory EstimationStatistics.empty() => const EstimationStatistics();

  Map<String, dynamic> toJson() => {
        'gamesPlayed': gamesPlayed,
        'gamesWon': gamesWon,
        'totalRounds': totalRounds,
        'totalTricks': totalTricks,
        'totalDeclared': totalDeclared,
        'perfectEstimates': perfectEstimates,
        'failedDeclarations': failedDeclarations,
        'highestSuccessfulBid': highestSuccessfulBid,
        'highestSuccessfulDeclaration': highestSuccessfulDeclaration,
        'highestScoreInOneRound': highestScoreInOneRound,
        'lowestScoreInOneRound': lowestScoreInOneRound,
        'bestComeback': bestComeback,
        'totalComebacks': totalComebacks,
        'majorComebacks': majorComebacks,
        'finalRoundComebacks': finalRoundComebacks,
        'longestWinningStreak': longestWinningStreak,
        'currentWinningStreak': currentWinningStreak,
      };

  factory EstimationStatistics.fromJson(Map<String, dynamic> json) {
    return EstimationStatistics(
      gamesPlayed: (json['gamesPlayed'] as num?)?.toInt() ?? 0,
      gamesWon: (json['gamesWon'] as num?)?.toInt() ?? 0,
      totalRounds: (json['totalRounds'] as num?)?.toInt() ?? 0,
      totalTricks: (json['totalTricks'] as num?)?.toInt() ?? 0,
      totalDeclared: (json['totalDeclared'] as num?)?.toInt() ?? 0,
      perfectEstimates: (json['perfectEstimates'] as num?)?.toInt() ?? 0,
      failedDeclarations: (json['failedDeclarations'] as num?)?.toInt() ?? 0,
      highestSuccessfulBid: (json['highestSuccessfulBid'] as num?)?.toInt() ?? 0,
      highestSuccessfulDeclaration:
          (json['highestSuccessfulDeclaration'] as num?)?.toInt() ?? 0,
      highestScoreInOneRound:
          (json['highestScoreInOneRound'] as num?)?.toInt() ?? 0,
      lowestScoreInOneRound:
          (json['lowestScoreInOneRound'] as num?)?.toInt() ?? 0,
      bestComeback: (json['bestComeback'] as num?)?.toInt() ?? 0,
      totalComebacks: (json['totalComebacks'] as num?)?.toInt() ?? 0,
      majorComebacks: (json['majorComebacks'] as num?)?.toInt() ?? 0,
      finalRoundComebacks: (json['finalRoundComebacks'] as num?)?.toInt() ?? 0,
      longestWinningStreak:
          (json['longestWinningStreak'] as num?)?.toInt() ?? 0,
      currentWinningStreak:
          (json['currentWinningStreak'] as num?)?.toInt() ?? 0,
    );
  }

  EstimationStatistics copyWith({
    int? gamesPlayed,
    int? gamesWon,
    int? totalRounds,
    int? totalTricks,
    int? totalDeclared,
    int? perfectEstimates,
    int? failedDeclarations,
    int? highestSuccessfulBid,
    int? highestSuccessfulDeclaration,
    int? highestScoreInOneRound,
    int? lowestScoreInOneRound,
    int? bestComeback,
    int? totalComebacks,
    int? majorComebacks,
    int? finalRoundComebacks,
    int? longestWinningStreak,
    int? currentWinningStreak,
  }) {
    return EstimationStatistics(
      gamesPlayed: gamesPlayed ?? this.gamesPlayed,
      gamesWon: gamesWon ?? this.gamesWon,
      totalRounds: totalRounds ?? this.totalRounds,
      totalTricks: totalTricks ?? this.totalTricks,
      totalDeclared: totalDeclared ?? this.totalDeclared,
      perfectEstimates: perfectEstimates ?? this.perfectEstimates,
      failedDeclarations: failedDeclarations ?? this.failedDeclarations,
      highestSuccessfulBid:
          highestSuccessfulBid ?? this.highestSuccessfulBid,
      highestSuccessfulDeclaration:
          highestSuccessfulDeclaration ?? this.highestSuccessfulDeclaration,
      highestScoreInOneRound:
          highestScoreInOneRound ?? this.highestScoreInOneRound,
      lowestScoreInOneRound:
          lowestScoreInOneRound ?? this.lowestScoreInOneRound,
      bestComeback: bestComeback ?? this.bestComeback,
      totalComebacks: totalComebacks ?? this.totalComebacks,
      majorComebacks: majorComebacks ?? this.majorComebacks,
      finalRoundComebacks: finalRoundComebacks ?? this.finalRoundComebacks,
      longestWinningStreak:
          longestWinningStreak ?? this.longestWinningStreak,
      currentWinningStreak:
          currentWinningStreak ?? this.currentWinningStreak,
    );
  }
}
