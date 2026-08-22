// lib/services/estimation_stats_service.dart

import 'dart:convert';
import 'dart:math';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../core/models/game_state.dart';
import '../core/models/comeback_event.dart';
import '../models/estimation_statistics.dart';

class EstimationStatsService {
  static const String _kStatsPrefix = 'estimation_stats_v1_';

  EstimationStatsService._internal();
  static final EstimationStatsService instance = EstimationStatsService._internal();

  String _getStorageKey(String playerName) {
    final sanitized = playerName.trim().toLowerCase().replaceAll(' ', '_');
    return '$_kStatsPrefix$sanitized';
  }

  /// Loads the saved EstimationStatistics for a player
  Future<EstimationStatistics> getStats(String playerName) async {
    if (playerName.trim().isEmpty) return EstimationStatistics.empty();

    try {
      final prefs = await SharedPreferences.getInstance();
      final key = _getStorageKey(playerName);
      final jsonStr = prefs.getString(key);

      if (jsonStr != null && jsonStr.isNotEmpty) {
        final Map<String, dynamic> data = jsonDecode(jsonStr);
        return EstimationStatistics.fromJson(data);
      }
    } catch (e) {
      debugPrint('[EstimationStatsService] Error loading stats: $e');
    }

    return EstimationStatistics.empty();
  }

  /// Saves EstimationStatistics for a player
  Future<void> saveStats(String playerName, EstimationStatistics stats) async {
    if (playerName.trim().isEmpty) return;

    try {
      final prefs = await SharedPreferences.getInstance();
      final key = _getStorageKey(playerName);
      await prefs.setString(key, jsonEncode(stats.toJson()));
    } catch (e) {
      debugPrint('[EstimationStatsService] Error saving stats: $e');
    }
  }

  /// Updates player's statistics from a completed match
  Future<EstimationStatistics> recordMatch({
    required GameState state,
    required String playerName,
    required String playerId,
  }) async {
    final currentStats = await getStats(playerName);

    final sortedPlayers = [...state.players]
      ..sort((a, b) => b.totalScore.compareTo(a.totalScore));

    final isWinner = sortedPlayers.isNotEmpty &&
        (sortedPlayers.first.id == playerId ||
            sortedPlayers.first.name.trim().toLowerCase() ==
                playerName.trim().toLowerCase());

    final newGamesPlayed = currentStats.gamesPlayed + 1;
    final newGamesWon = currentStats.gamesWon + (isWinner ? 1 : 0);

    final newCurrentStreak = isWinner ? currentStats.currentWinningStreak + 1 : 0;
    final newLongestStreak =
        max(currentStats.longestWinningStreak, newCurrentStreak);

    int newRounds = currentStats.totalRounds;
    int newTricks = currentStats.totalTricks;
    int newDeclared = currentStats.totalDeclared;
    int newPerfect = currentStats.perfectEstimates;
    int newFailed = currentStats.failedDeclarations;
    int newHighestBid = currentStats.highestSuccessfulBid;
    int newHighestDec = currentStats.highestSuccessfulDeclaration;
    int newHighestScore = currentStats.highestScoreInOneRound;
    int newLowestScore = currentStats.lowestScoreInOneRound;
    bool hasRoundScoreRecorded = currentStats.totalRounds > 0;

    // Track round progression to compute best comeback if winner
    int matchMaxDeficit = 0;

    for (final round in state.roundHistory) {
      PlayerRoundRecord? myRecord;
      int leaderScoreInRound = -99999;

      for (final pRec in round.playerRecords) {
        if (pRec.playerId == playerId ||
            pRec.playerName.trim().toLowerCase() ==
                playerName.trim().toLowerCase()) {
          myRecord = pRec;
        }
        if (pRec.totalScoreAfterRound > leaderScoreInRound) {
          leaderScoreInRound = pRec.totalScoreAfterRound;
        }
      }

      if (myRecord != null) {
        newRounds++;
        newTricks += myRecord.actual;
        newDeclared += myRecord.declared;

        if (myRecord.isSuccess) {
          newPerfect++;
          if (myRecord.declared > newHighestDec) {
            newHighestDec = myRecord.declared;
          }
          if (myRecord.isBidder && round.winningBid != null) {
            if (round.winningBid!.trickCount > newHighestBid) {
              newHighestBid = round.winningBid!.trickCount;
            }
          }
        } else {
          newFailed++;
        }

        if (!hasRoundScoreRecorded) {
          newHighestScore = myRecord.scoreDelta;
          newLowestScore = myRecord.scoreDelta;
          hasRoundScoreRecorded = true;
        } else {
          if (myRecord.scoreDelta > newHighestScore) {
            newHighestScore = myRecord.scoreDelta;
          }
          if (myRecord.scoreDelta < newLowestScore) {
            newLowestScore = myRecord.scoreDelta;
          }
        }

        // Calculate deficit from leader after this round
        final deficit = leaderScoreInRound - myRecord.totalScoreAfterRound;
        if (deficit > matchMaxDeficit) {
          matchMaxDeficit = deficit;
        }
      }
    }

    // Track comeback moments using ComebackDetector
    final matchComebacks = ComebackDetector.detectMatchComebacks(
      state: state,
      playerId: playerId,
      playerName: playerName,
    );

    final newTotalComebacks = currentStats.totalComebacks + matchComebacks.length;
    final newMajorComebacks = currentStats.majorComebacks +
        matchComebacks.where((c) => c.type == ComebackType.majorComeback).length;
    final newFinalRoundComebacks = currentStats.finalRoundComebacks +
        matchComebacks.where((c) => c.type == ComebackType.finalRoundComeback).length;

    // Best comeback applies if the player won after trailing
    final newBestComeback = isWinner
        ? max(currentStats.bestComeback, matchMaxDeficit)
        : currentStats.bestComeback;

    final updated = currentStats.copyWith(
      gamesPlayed: newGamesPlayed,
      gamesWon: newGamesWon,
      totalRounds: newRounds,
      totalTricks: newTricks,
      totalDeclared: newDeclared,
      perfectEstimates: newPerfect,
      failedDeclarations: newFailed,
      highestSuccessfulBid: newHighestBid,
      highestSuccessfulDeclaration: newHighestDec,
      highestScoreInOneRound: newHighestScore,
      lowestScoreInOneRound: newLowestScore,
      bestComeback: newBestComeback,
      totalComebacks: newTotalComebacks,
      majorComebacks: newMajorComebacks,
      finalRoundComebacks: newFinalRoundComebacks,
      longestWinningStreak: newLongestStreak,
      currentWinningStreak: newCurrentStreak,
    );

    await saveStats(playerName, updated);
    return updated;
  }

  /// Clears statistics for a player
  Future<void> resetStats(String playerName) async {
    if (playerName.trim().isEmpty) return;
    final prefs = await SharedPreferences.getInstance();
    final key = _getStorageKey(playerName);
    await prefs.remove(key);
  }
}
