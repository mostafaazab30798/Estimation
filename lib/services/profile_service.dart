// lib/services/profile_service.dart

import 'dart:convert';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../core/utils/string_utils.dart';
import 'history_service.dart';

import '../models/estimation_statistics.dart';
import 'estimation_stats_service.dart';

class PresetAvatar {
  final String id;
  final String label;
  final String assetPath;

  const PresetAvatar({
    required this.id,
    required this.label,
    required this.assetPath,
  });
}

class PlayerStats {
  final int totalMatches;
  final int wins;
  final double winRate;
  final int totalScore;
  final double avgScore;
  final int maxScore;
  final int kingCount;
  final int subKingCount;
  final int subKozCount;
  final int kozCount;
  final EstimationStatistics estimationStats;

  const PlayerStats({
    required this.totalMatches,
    required this.wins,
    required this.winRate,
    required this.totalScore,
    required this.avgScore,
    required this.maxScore,
    required this.kingCount,
    required this.subKingCount,
    required this.subKozCount,
    required this.kozCount,
    this.estimationStats = const EstimationStatistics(),
  });

  factory PlayerStats.empty() {
    return const PlayerStats(
      totalMatches: 0,
      wins: 0,
      winRate: 0.0,
      totalScore: 0,
      avgScore: 0.0,
      maxScore: 0,
      kingCount: 0,
      subKingCount: 0,
      subKozCount: 0,
      kozCount: 0,
      estimationStats: EstimationStatistics(),
    );
  }
}

class ProfileService {
  static const String _kNameKey = 'player_name';
  static const String _kPhotoKey = 'player_profile_photo';

  static const List<PresetAvatar> presetAvatars = [
    PresetAvatar(
      id: 'preset:bear',
      label: 'الدب',
      assetPath: 'assets/avatars/bear.png',
    ),
    PresetAvatar(
      id: 'preset:cat',
      label: 'القط',
      assetPath: 'assets/avatars/cat.png',
    ),
    PresetAvatar(
      id: 'preset:chicken',
      label: 'الدجاجة',
      assetPath: 'assets/avatars/chicken.png',
    ),
    PresetAvatar(
      id: 'preset:duck',
      label: 'البطة',
      assetPath: 'assets/avatars/duck.png',
    ),
    PresetAvatar(
      id: 'preset:meerkat',
      label: 'الميركات',
      assetPath: 'assets/avatars/meerkat.png',
    ),
    PresetAvatar(
      id: 'preset:panda',
      label: 'الباندا',
      assetPath: 'assets/avatars/panda.png',
    ),
    PresetAvatar(
      id: 'preset:penguin',
      label: 'البطريق',
      assetPath: 'assets/avatars/penguin.png',
    ),
    PresetAvatar(
      id: 'preset:rabbit',
      label: 'الأرنب',
      assetPath: 'assets/avatars/rabbit.png',
    ),
  ];

  static bool isKnownPreset(String photoData) =>
      presetAvatars.any((avatar) => avatar.id == photoData);

  /// Avatars a guest may keep: animal presets or a custom gallery photo.
  /// Network (Google) photos are excluded so guests always get a local avatar.
  static bool isGuestAssignableAvatar(String photoData) {
    if (photoData.isEmpty) return false;
    if (isKnownPreset(photoData)) return true;
    if (photoData.startsWith('ugc:')) return true;
    return isBase64Photo(photoData);
  }

  /// Avatars a signed-in player may keep, including a Google profile photo.
  static bool isAssignableAvatar(String photoData) {
    if (isGuestAssignableAvatar(photoData)) return true;
    return photoData.startsWith('http://') || photoData.startsWith('https://');
  }

  static String randomPresetId([Random? rng]) {
    final index = (rng ?? Random()).nextInt(presetAvatars.length);
    return presetAvatars[index].id;
  }

  /// Stable animal preset for a player when their profile photo is not yet synced.
  static String presetForPlayerId(String playerId) {
    if (playerId.isEmpty) return presetAvatars.first.id;
    final index = playerId.hashCode.abs() % presetAvatars.length;
    return presetAvatars[index].id;
  }

  /// Avatar ref for lobby display — keeps each player's chosen photo when known,
  /// otherwise assigns a distinct preset from the full set (not always the first).
  static String lobbyAvatarRef(String? photoData, String playerId) {
    if (photoData != null && photoData.isNotEmpty) {
      return publicAvatarRef(photoData);
    }
    return presetForPlayerId(playerId);
  }

  static Future<String?> getRawProfilePhoto() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_kPhotoKey);
  }

  /// Picks a random animal avatar for guests when none is saved, or when the
  /// saved value is a retired emoji preset / Google URL.
  static Future<String> ensureGuestAvatar() async {
    final saved = await getRawProfilePhoto();
    if (saved != null && isGuestAssignableAvatar(saved)) {
      return saved;
    }
    final id = randomPresetId();
    await saveProfilePhoto(id);
    return id;
  }

  static Future<String> assignRandomAvatar() async {
    final id = randomPresetId();
    await saveProfilePhoto(id);
    return id;
  }

  /// Loads saved player name from SharedPreferences
  static Future<String> getProfileName() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_kNameKey) ?? '';
    return StringUtils.capitalizeWords(raw);
  }

  /// Saves player name to SharedPreferences
  static Future<void> saveProfileName(String name) async {
    final formatted = StringUtils.capitalizeWords(name);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_kNameKey, formatted);
  }

  /// Reference sent to other players — never includes raw gallery bytes.
  static String publicAvatarRef(String? photoData) {
    if (photoData == null || photoData.isEmpty) {
      return presetAvatars.first.id;
    }
    if (photoData.startsWith('preset:')) {
      return isKnownPreset(photoData) ? photoData : presetAvatars.first.id;
    }
    if (photoData.startsWith('http://') ||
        photoData.startsWith('https://') ||
        photoData.startsWith('ugc:')) {
      return photoData;
    }
    if (isBase64Photo(photoData)) {
      return 'ugc:custom';
    }
    return presetAvatars.first.id;
  }

  /// Loads saved profile photo string from SharedPreferences.
  /// Defaults to the first preset avatar if not set.
  static Future<String> getProfilePhoto() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_kPhotoKey) ?? presetAvatars.first.id;
  }

  /// Saves profile photo string (Base64 string or preset id) to SharedPreferences
  static Future<void> saveProfilePhoto(String photoData) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_kPhotoKey, photoData);
  }

  /// Checks if photo data string is a Base64 encoded image
  static bool isBase64Photo(String photoData) {
    if (photoData.startsWith('http://') || photoData.startsWith('https://')) {
      return false;
    }
    return photoData.startsWith('data:image') ||
        (!photoData.startsWith('preset:') && photoData.length > 50);
  }

  static final Map<String, MemoryImage> _imageCache = {};

  /// Converts raw Base64 string or data URL to MemoryImage bytes
  static ImageProvider? parseBase64Image(String photoData) {
    if (_imageCache.containsKey(photoData)) {
      return _imageCache[photoData];
    }
    try {
      String cleanStr = photoData;
      if (photoData.contains(',')) {
        cleanStr = photoData.split(',').last;
      }
      final bytes = base64Decode(cleanStr);
      final image = MemoryImage(bytes);
      // Cache up to 20 images to prevent memory leaks while keeping active ones
      if (_imageCache.length > 20) {
        _imageCache.remove(_imageCache.keys.first);
      }
      _imageCache[photoData] = image;
      return image;
    } catch (e) {
      debugPrint('[ProfileService] Error decoding Base64 image: $e');
      return null;
    }
  }

  /// Computes statistics for a player given their name
  static Future<PlayerStats> getProfileStats(String playerName) async {
    if (playerName.trim().isEmpty) return PlayerStats.empty();
    final targetName = playerName.trim().toLowerCase();

    final allHistory = await HistoryService.getHistory();

    int totalMatches = 0;
    int wins = 0;
    int totalScore = 0;
    int maxScore = 0;
    int kingCount = 0;
    int subKingCount = 0;
    int subKozCount = 0;
    int kozCount = 0;

    for (final record in allHistory) {
      // Find player entry in this record
      final pResult = record.players.firstWhere(
        (p) => p.name.trim().toLowerCase() == targetName,
        orElse: () => PlayerResult(name: '', score: -999, rankTitle: ''),
      );

      if (pResult.name.isNotEmpty) {
        totalMatches++;
        totalScore += pResult.score;

        if (totalMatches == 1 || pResult.score > maxScore) {
          maxScore = pResult.score;
        }

        if (record.winnerName.trim().toLowerCase() == targetName) {
          wins++;
        }

        final rankStr = pResult.rankTitle;
        if (rankStr.contains('كينج') && !rankStr.contains('صب')) {
          kingCount++;
        } else if (rankStr.contains('صب كينج')) {
          subKingCount++;
        } else if (rankStr.contains('صب كوز')) {
          subKozCount++;
        } else if (rankStr.contains('كوز') && !rankStr.contains('صب')) {
          kozCount++;
        }
      }
    }

    if (totalMatches == 0) {
      final estStats = await EstimationStatsService.instance.getStats(playerName);
      return PlayerStats(
        totalMatches: estStats.gamesPlayed,
        wins: estStats.gamesWon,
        winRate: estStats.winRate,
        totalScore: 0,
        avgScore: 0.0,
        maxScore: 0,
        kingCount: estStats.gamesWon,
        subKingCount: 0,
        subKozCount: 0,
        kozCount: 0,
        estimationStats: estStats,
      );
    }

    final winRate = (wins / totalMatches) * 100;
    final avgScore = totalScore / totalMatches;
    var estStats = await EstimationStatsService.instance.getStats(playerName);

    // If local estimation stats are blank but matches exist in history, backfill gamesPlayed/won
    if (estStats.gamesPlayed == 0 && totalMatches > 0) {
      estStats = estStats.copyWith(
        gamesPlayed: totalMatches,
        gamesWon: wins,
      );
    }

    return PlayerStats(
      totalMatches: totalMatches,
      wins: wins,
      winRate: winRate,
      totalScore: totalScore,
      avgScore: avgScore,
      maxScore: maxScore,
      kingCount: kingCount,
      subKingCount: subKingCount,
      subKozCount: subKozCount,
      kozCount: kozCount,
      estimationStats: estStats,
    );
  }

  /// Filters history matches for a specific player
  static Future<List<MatchRecord>> getPlayerHistory(String playerName) async {
    if (playerName.trim().isEmpty) return [];
    final targetName = playerName.trim().toLowerCase();
    final allHistory = await HistoryService.getHistory();

    return allHistory.where((record) {
      return record.players.any(
        (p) => p.name.trim().toLowerCase() == targetName,
      );
    }).toList();
  }
}
