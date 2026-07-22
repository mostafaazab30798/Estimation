import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../core/models/game_state.dart';

class MatchRecord {
  final String date;
  final String winnerName;
  final int winnerScore;
  final List<PlayerResult> players;

  MatchRecord({
    required this.date,
    required this.winnerName,
    required this.winnerScore,
    required this.players,
  });

  Map<String, dynamic> toJson() => {
        'date': date,
        'winnerName': winnerName,
        'winnerScore': winnerScore,
        'players': players.map((p) => p.toJson()).toList(),
      };

  factory MatchRecord.fromJson(Map<String, dynamic> json) {
    return MatchRecord(
      date: json['date'] as String,
      winnerName: json['winnerName'] as String,
      winnerScore: json['winnerScore'] as int,
      players: (json['players'] as List<dynamic>)
          .map((p) => PlayerResult.fromJson(p as Map<String, dynamic>))
          .toList(),
    );
  }
}

class PlayerResult {
  final String name;
  final int score;
  final String rankTitle;

  PlayerResult({
    required this.name,
    required this.score,
    required this.rankTitle,
  });

  Map<String, dynamic> toJson() => {
        'name': name,
        'score': score,
        'rankTitle': rankTitle,
      };

  factory PlayerResult.fromJson(Map<String, dynamic> json) {
    return PlayerResult(
      name: json['name'] as String,
      score: json['score'] as int,
      rankTitle: json['rankTitle'] as String,
    );
  }
}

class HistoryService {
  static const String _key = 'match_history';

  static Future<void> saveMatch(GameState state) async {
    final prefs = await SharedPreferences.getInstance();
    
    // Sort players by score
    final sortedPlayers = [...state.players]
      ..sort((a, b) => b.totalScore.compareTo(a.totalScore));
      
    final winner = sortedPlayers.isNotEmpty ? sortedPlayers.first : null;
    if (winner == null) return;
    
    final rankTitles = ['كينج 👑', 'صب كينج 🥈', 'صب كوز 🥉', 'كوز 🤡'];

    final record = MatchRecord(
      date: DateTime.now().toIso8601String(),
      winnerName: winner.name,
      winnerScore: winner.totalScore,
      players: sortedPlayers.asMap().entries.map((e) {
        final rank = e.key < 4 ? rankTitles[e.key] : '';
        return PlayerResult(
          name: e.value.name,
          score: e.value.totalScore,
          rankTitle: rank,
        );
      }).toList(),
    );

    final historyStrs = prefs.getStringList(_key) ?? [];
    historyStrs.add(jsonEncode(record.toJson()));
    await prefs.setStringList(_key, historyStrs);
  }

  static Future<List<MatchRecord>> getHistory() async {
    final prefs = await SharedPreferences.getInstance();
    final historyStrs = prefs.getStringList(_key) ?? [];
    return historyStrs.map((s) => MatchRecord.fromJson(jsonDecode(s))).toList().reversed.toList(); // Newest first
  }
  
  static Future<void> clearHistory() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_key);
  }
}
