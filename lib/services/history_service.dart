import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../core/models/game_state.dart';

class MatchRecord {
  final String? id;
  final String date;
  final String winnerName;
  final int winnerScore;
  final String gameType; // 'kotchina' or 'ninety_nine'
  final List<PlayerResult> players;

  MatchRecord({
    this.id,
    required this.date,
    required this.winnerName,
    required this.winnerScore,
    this.gameType = 'kotchina',
    required this.players,
  });

  Map<String, dynamic> toJson() => {
        if (id != null) 'id': id,
        'date': date,
        'winnerName': winnerName,
        'winnerScore': winnerScore,
        'gameType': gameType,
        'players': players.map((p) => p.toJson()).toList(),
      };

  factory MatchRecord.fromJson(Map<String, dynamic> json, {String? id}) {
    return MatchRecord(
      id: id ?? json['id'] as String?,
      date: json['date'] as String,
      winnerName: json['winnerName'] as String,
      winnerScore: json['winnerScore'] as int,
      gameType: (json['gameType'] as String?) ?? 'kotchina',
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
  static const String _legacyKey = 'match_history';
  static const String _migratedKey = 'history_migrated';
  static const String _tableName = 'game_history';

  /// One-time migration of existing SharedPreferences history to Supabase.
  static Future<void> migrateFromSharedPreferences() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final isMigrated = prefs.getBool(_migratedKey) ?? false;
      if (isMigrated) return;

      final user = Supabase.instance.client.auth.currentUser;
      if (user == null || user.isAnonymous) {
        debugPrint('[HistoryService] Migration deferred: No authenticated non-anonymous user.');
        return;
      }
      final userId = user.id;

      final historyStrs = prefs.getStringList(_legacyKey) ?? [];
      if (historyStrs.isNotEmpty) {
        debugPrint('[HistoryService] Migrating ${historyStrs.length} local history records to Supabase...');
        for (final str in historyStrs) {
          try {
            final Map<String, dynamic> jsonMap = jsonDecode(str);
            await Supabase.instance.client.from(_tableName).insert({
              'user_id': userId,
              'game_data': jsonMap,
            });
          } catch (e) {
            debugPrint('[HistoryService] Migration failed for individual record: $e');
          }
        }
      }

      await prefs.remove(_legacyKey);
      await prefs.setBool(_migratedKey, true);
      debugPrint('[HistoryService] SharedPreferences migration completed successfully.');
    } catch (e) {
      debugPrint('[HistoryService] Error during SharedPreferences migration: $e');
    }
  }

  /// Saves a finished game state to Supabase for the authenticated user.
  static Future<void> saveMatch(GameState state) async {
    try {
      final user = Supabase.instance.client.auth.currentUser;
      if (user == null || user.isAnonymous) {
        debugPrint('[HistoryService] Cannot save match: No authenticated non-anonymous user.');
        return;
      }
      final userId = user.id;

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

      await Supabase.instance.client.from(_tableName).insert({
        'user_id': userId,
        'game_data': record.toJson(),
      });
      debugPrint('[HistoryService] Match saved successfully to Supabase.');
    } catch (e) {
      debugPrint('[HistoryService] Error saving match to Supabase: $e');
    }
  }

  /// Saves a finished MatchRecord directly to Supabase
  static Future<void> saveMatchRecordDirect(MatchRecord record) async {
    try {
      final user = Supabase.instance.client.auth.currentUser;
      if (user == null || user.isAnonymous) {
        debugPrint('[HistoryService] Cannot save match: No authenticated non-anonymous user.');
        return;
      }
      final userId = user.id;
      await Supabase.instance.client.from(_tableName).insert({
        'user_id': userId,
        'game_data': record.toJson(),
      });
      debugPrint('[HistoryService] Direct match record saved successfully (${record.gameType}).');
    } catch (e) {
      debugPrint('[HistoryService] Error saving direct match record: $e');
    }
  }

  /// Fetches history records for the authenticated user from Supabase.
  static Future<List<MatchRecord>> getHistory() async {
    try {
      final user = Supabase.instance.client.auth.currentUser;
      if (user == null || user.isAnonymous) {
        debugPrint('[HistoryService] Cannot fetch history: No authenticated non-anonymous user.');
        return [];
      }
      final userId = user.id;

      await migrateFromSharedPreferences().timeout(const Duration(seconds: 2), onTimeout: () {});

      final response = await Supabase.instance.client
          .from(_tableName)
          .select('id, game_data, created_at')
          .eq('user_id', userId)
          .order('created_at', ascending: false)
          .timeout(const Duration(seconds: 3));

      final List<MatchRecord> records = [];
      for (final row in response as List<dynamic>) {
        final rowMap = row as Map<String, dynamic>;
        final id = rowMap['id'] as String?;
        final gameData = rowMap['game_data'] as Map<String, dynamic>;
        records.add(MatchRecord.fromJson(gameData, id: id));
      }
      return _deduplicateRecords(records);
    } catch (e) {
      debugPrint('[HistoryService] Error fetching history from Supabase: $e');
      return [];
    }
  }

  /// Deduplicates match records that represent the same game saved multiple times
  /// (e.g. by multiple player clients simultaneously within a short timeframe).
  static List<MatchRecord> _deduplicateRecords(List<MatchRecord> records) {
    final List<MatchRecord> unique = [];

    for (final record in records) {
      final isDuplicate = unique.any((existing) => _isSameMatch(existing, record));
      if (!isDuplicate) {
        unique.add(record);
      }
    }

    return unique;
  }

  static bool _isSameMatch(MatchRecord a, MatchRecord b) {
    if (a.winnerName != b.winnerName || a.winnerScore != b.winnerScore) {
      return false;
    }

    if (a.players.length != b.players.length) {
      return false;
    }

    for (int i = 0; i < a.players.length; i++) {
      if (a.players[i].name != b.players[i].name ||
          a.players[i].score != b.players[i].score) {
        return false;
      }
    }

    try {
      final dtA = DateTime.parse(a.date);
      final dtB = DateTime.parse(b.date);
      final diffSeconds = dtA.difference(dtB).inSeconds.abs();
      return diffSeconds <= 180;
    } catch (_) {
      return true;
    }
  }

  /// Clears all match history for the authenticated user from Supabase.
  static Future<void> clearHistory() async {
    try {
      final user = Supabase.instance.client.auth.currentUser;
      if (user == null || user.isAnonymous) {
        debugPrint('[HistoryService] Cannot clear history: No authenticated non-anonymous user.');
        return;
      }
      final userId = user.id;

      await Supabase.instance.client
          .from(_tableName)
          .delete()
          .eq('user_id', userId);
      debugPrint('[HistoryService] All match history cleared from Supabase.');
    } catch (e) {
      debugPrint('[HistoryService] Error clearing history from Supabase: $e');
    }
  }

  /// Deletes a single match history item by ID from Supabase.
  static Future<void> deleteMatch(String id) async {
    try {
      final user = Supabase.instance.client.auth.currentUser;
      if (user == null || user.isAnonymous) {
        debugPrint('[HistoryService] Cannot delete match record: No authenticated non-anonymous user.');
        return;
      }
      final userId = user.id;

      await Supabase.instance.client
          .from(_tableName)
          .delete()
          .eq('id', id)
          .eq('user_id', userId);
      debugPrint('[HistoryService] Deleted match record $id from Supabase.');
    } catch (e) {
      debugPrint('[HistoryService] Error deleting match record $id from Supabase: $e');
    }
  }
}
