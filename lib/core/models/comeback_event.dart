// lib/core/models/comeback_event.dart

import 'game_state.dart';

enum ComebackType {
  /// Moved from 4th (or large deficit >= 15 pts) to 1st place
  majorComeback,

  /// Seized 1st place / victory in the final round of the Boula
  finalRoundComeback,

  /// Jumped 2 or more positions upward in a single round (e.g. 4th -> 2nd)
  rankSurge,
}

class ComebackEvent {
  final String playerId;
  final String playerName;
  final ComebackType type;
  final int roundNumber;
  final int previousRank; // 1 to 4
  final int newRank;      // 1 to 4
  final int pointsDeficitOvercome;
  final int scoreDelta;

  const ComebackEvent({
    required this.playerId,
    required this.playerName,
    required this.type,
    required this.roundNumber,
    required this.previousRank,
    required this.newRank,
    this.pointsDeficitOvercome = 0,
    this.scoreDelta = 0,
  });

  String get titleEn {
    switch (type) {
      case ComebackType.majorComeback:
        return 'MAJOR COMEBACK!';
      case ComebackType.finalRoundComeback:
        return 'LAST ROUND COMEBACK!';
      case ComebackType.rankSurge:
        return 'RANK SURGE!';
    }
  }

  String get titleAr {
    switch (type) {
      case ComebackType.majorComeback:
        return 'ريمونتادا كبرى!';
      case ComebackType.finalRoundComeback:
        return 'ريمونتادا الجولة الأخيرة!';
      case ComebackType.rankSurge:
        return 'قفزة في الترتيب!';
    }
  }

  String get subtitleEn {
    switch (type) {
      case ComebackType.majorComeback:
        return 'You moved from ${_rankSuffix(previousRank)} → 1st place!';
      case ComebackType.finalRoundComeback:
        return 'You took the Boula lead in the final round!';
      case ComebackType.rankSurge:
        return 'You climbed from ${_rankSuffix(previousRank)} → ${_rankSuffix(newRank)}!';
    }
  }

  String get subtitleAr {
    switch (type) {
      case ComebackType.majorComeback:
        return 'قفزت من المركز ${_rankAr(previousRank)} إلى الصدارة!';
      case ComebackType.finalRoundComeback:
        return 'انتزعت صدارة البولة في الجولة الحاسمة!';
      case ComebackType.rankSurge:
        return 'تقدمت من المركز ${_rankAr(previousRank)} إلى المركز ${_rankAr(newRank)}!';
    }
  }

  String get iconEmoji {
    switch (type) {
      case ComebackType.majorComeback:
        return '🔥';
      case ComebackType.finalRoundComeback:
        return '👑';
      case ComebackType.rankSurge:
        return '⚡';
    }
  }

  static String _rankSuffix(int rank) {
    switch (rank) {
      case 1:
        return '1st';
      case 2:
        return '2nd';
      case 3:
        return '3rd';
      case 4:
        return '4th';
      default:
        return '${rank}th';
    }
  }

  static String _rankAr(int rank) {
    switch (rank) {
      case 1:
        return 'الأول';
      case 2:
        return 'الثاني';
      case 3:
        return 'الثالث';
      case 4:
        return 'الرابع';
      default:
        return '$rank';
    }
  }

  Map<String, dynamic> toJson() => {
        'playerId': playerId,
        'playerName': playerName,
        'type': type.name,
        'roundNumber': roundNumber,
        'previousRank': previousRank,
        'newRank': newRank,
        'pointsDeficitOvercome': pointsDeficitOvercome,
        'scoreDelta': scoreDelta,
      };

  factory ComebackEvent.fromJson(Map<String, dynamic> json) {
    return ComebackEvent(
      playerId: json['playerId'] as String? ?? '',
      playerName: json['playerName'] as String? ?? '',
      type: ComebackType.values.firstWhere(
        (t) => t.name == json['type'],
        orElse: () => ComebackType.rankSurge,
      ),
      roundNumber: json['roundNumber'] as int? ?? 1,
      previousRank: json['previousRank'] as int? ?? 4,
      newRank: json['newRank'] as int? ?? 1,
      pointsDeficitOvercome: json['pointsDeficitOvercome'] as int? ?? 0,
      scoreDelta: json['scoreDelta'] as int? ?? 0,
    );
  }
}

class ComebackDetector {
  const ComebackDetector();

  /// Evaluates comebacks that occurred specifically at the end of [roundNumber]
  static List<ComebackEvent> detectRoundComebacks({
    required GameState state,
    required int roundNumber,
  }) {
    if (roundNumber < 1 || state.roundHistory.isEmpty) return [];

    int roundIndex = state.roundHistory.indexWhere((r) => r.roundNumber == roundNumber);
    if (roundIndex < 0) {
      roundIndex = roundNumber - 1;
    }
    if (roundIndex < 0 || roundIndex >= state.roundHistory.length) return [];

    // Calculate scores before this round
    final Map<String, int> scoresBefore = {};
    final Map<String, String> playerNames = {};

    for (final player in state.players) {
      scoresBefore[player.id] = 0;
      playerNames[player.id] = player.name;
    }

    if (roundIndex > 0) {
      final prevRound = state.roundHistory[roundIndex - 1];
      for (final pRec in prevRound.playerRecords) {
        scoresBefore[pRec.playerId] = pRec.totalScoreAfterRound;
        if (pRec.playerName.isNotEmpty) {
          playerNames[pRec.playerId] = pRec.playerName;
        }
      }
    }

    // Calculate scores after this round
    final curRound = state.roundHistory[roundIndex];
    final Map<String, int> scoresAfter = {};
    final Map<String, int> deltas = {};

    for (final pRec in curRound.playerRecords) {
      scoresAfter[pRec.playerId] = pRec.totalScoreAfterRound;
      deltas[pRec.playerId] = pRec.scoreDelta;
      if (pRec.playerName.isNotEmpty) {
        playerNames[pRec.playerId] = pRec.playerName;
      }
    }

    // Ranks before (sorted by score descending)
    final sortedBefore = scoresBefore.keys.toList()
      ..sort((a, b) => (scoresBefore[b] ?? 0).compareTo(scoresBefore[a] ?? 0));
    final Map<String, int> ranksBefore = {};
    for (int i = 0; i < sortedBefore.length; i++) {
      ranksBefore[sortedBefore[i]] = i + 1;
    }
    final int leaderScoreBefore = sortedBefore.isNotEmpty ? (scoresBefore[sortedBefore.first] ?? 0) : 0;

    // Ranks after (sorted by score descending)
    final sortedAfter = scoresAfter.keys.toList()
      ..sort((a, b) => (scoresAfter[b] ?? 0).compareTo(scoresAfter[a] ?? 0));
    final Map<String, int> ranksAfter = {};
    for (int i = 0; i < sortedAfter.length; i++) {
      ranksAfter[sortedAfter[i]] = i + 1;
    }

    final isFinalRound = roundNumber >= state.totalRounds || state.isMatchOver;
    final List<ComebackEvent> events = [];

    for (final playerId in scoresAfter.keys) {
      final prevRank = ranksBefore[playerId] ?? 4;
      final newRank = ranksAfter[playerId] ?? 4;
      final prevScore = scoresBefore[playerId] ?? 0;
      final deficit = leaderScoreBefore - prevScore;
      final delta = deltas[playerId] ?? 0;
      final name = playerNames[playerId] ?? 'Player';

      // 1. Final-Round Comeback
      if (isFinalRound && prevRank > 1 && newRank == 1) {
        events.add(ComebackEvent(
          playerId: playerId,
          playerName: name,
          type: ComebackType.finalRoundComeback,
          roundNumber: roundNumber,
          previousRank: prevRank,
          newRank: newRank,
          pointsDeficitOvercome: deficit > 0 ? deficit : 0,
          scoreDelta: delta,
        ));
      }
      // 2. Major Comeback: 4th to 1st OR overcame >= 15 deficit to become 1st
      else if ((prevRank == 4 || deficit >= 15) && newRank == 1 && prevRank > 1) {
        events.add(ComebackEvent(
          playerId: playerId,
          playerName: name,
          type: ComebackType.majorComeback,
          roundNumber: roundNumber,
          previousRank: prevRank,
          newRank: newRank,
          pointsDeficitOvercome: deficit > 0 ? deficit : 0,
          scoreDelta: delta,
        ));
      }
      // 3. Rank Surge: Climbed 2+ positions (e.g. 4th -> 2nd, 3rd -> 1st)
      else if (prevRank - newRank >= 2) {
        events.add(ComebackEvent(
          playerId: playerId,
          playerName: name,
          type: ComebackType.rankSurge,
          roundNumber: roundNumber,
          previousRank: prevRank,
          newRank: newRank,
          pointsDeficitOvercome: deficit > 0 ? deficit : 0,
          scoreDelta: delta,
        ));
      }
    }

    return events;
  }

  /// Scans the entire match history to retrieve all comeback events achieved by a specific player
  static List<ComebackEvent> detectMatchComebacks({
    required GameState state,
    required String playerId,
    String? playerName,
  }) {
    final List<ComebackEvent> allEvents = [];

    for (int r = 1; r <= state.roundHistory.length; r++) {
      final roundEvents = detectRoundComebacks(state: state, roundNumber: r);
      for (final event in roundEvents) {
        if (event.playerId == playerId ||
            (playerName != null &&
                event.playerName.trim().toLowerCase() ==
                    playerName.trim().toLowerCase())) {
          allEvents.add(event);
        }
      }
    }

    return allEvents;
  }
}
