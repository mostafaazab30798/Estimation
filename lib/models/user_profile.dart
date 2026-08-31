// lib/models/user_profile.dart

import 'dart:math';
import '../core/utils/string_utils.dart';
import '../services/ugc_service.dart';
import 'rank_tier.dart';

class UserProfile {
  final String id;
  final String email;
  final String username;
  final String avatarUrl;
  final int xp;
  final int level;
  final int gamesPlayed;
  final int gamesWon;
  final DateTime? createdAt;
  final DateTime? updatedAt;
  final DateTime? termsAcceptedAt;
  final String? termsVersion;

  const UserProfile({
    required this.id,
    required this.email,
    required this.username,
    required this.avatarUrl,
    this.xp = 0,
    this.level = 1,
    this.gamesPlayed = 0,
    this.gamesWon = 0,
    this.createdAt,
    this.updatedAt,
    this.termsAcceptedAt,
    this.termsVersion,
  });

  bool get hasAcceptedCurrentTerms =>
      termsAcceptedAt != null && termsVersion == kCurrentTermsVersion;

  /// Factory from Supabase PostgREST JSON map
  factory UserProfile.fromMap(Map<String, dynamic> map) {
    return UserProfile(
      id: map['id']?.toString() ?? '',
      email: map['email']?.toString() ?? '',
      username: StringUtils.capitalizeWords(map['username']?.toString() ?? 'Player'),
      avatarUrl: map['avatar_url']?.toString() ?? 'preset:king',
      xp: (map['xp'] as num?)?.toInt() ?? 0,
      level: (map['level'] as num?)?.toInt() ?? 1,
      gamesPlayed: (map['games_played'] as num?)?.toInt() ?? 0,
      gamesWon: (map['games_won'] as num?)?.toInt() ?? 0,
      createdAt: map['created_at'] != null ? DateTime.tryParse(map['created_at'].toString()) : null,
      updatedAt: map['updated_at'] != null ? DateTime.tryParse(map['updated_at'].toString()) : null,
      termsAcceptedAt: map['terms_accepted_at'] != null
          ? DateTime.tryParse(map['terms_accepted_at'].toString())
          : null,
      termsVersion: map['terms_version']?.toString(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'email': email,
      'username': username,
      'avatar_url': avatarUrl,
      'xp': xp,
      'level': level,
      'games_played': gamesPlayed,
      'games_won': gamesWon,
      'updated_at': DateTime.now().toUtc().toIso8601String(),
    };
  }

  UserProfile copyWith({
    String? id,
    String? email,
    String? username,
    String? avatarUrl,
    int? xp,
    int? level,
    int? gamesPlayed,
    int? gamesWon,
    DateTime? createdAt,
    DateTime? updatedAt,
    DateTime? termsAcceptedAt,
    String? termsVersion,
  }) {
    return UserProfile(
      id: id ?? this.id,
      email: email ?? this.email,
      username: username ?? this.username,
      avatarUrl: avatarUrl ?? this.avatarUrl,
      xp: xp ?? this.xp,
      level: level ?? this.level,
      gamesPlayed: gamesPlayed ?? this.gamesPlayed,
      gamesWon: gamesWon ?? this.gamesWon,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      termsAcceptedAt: termsAcceptedAt ?? this.termsAcceptedAt,
      termsVersion: termsVersion ?? this.termsVersion,
    );
  }

  /// Win rate percentage (0.0 to 100.0)
  double get winRate => gamesPlayed > 0 ? (gamesWon / gamesPlayed) * 100 : 0.0;

  /// Player's competitive rank tier
  RankTier get rankTier => RankTier.fromLevel(level);

  /// Progress inside current rank tier towards next tier (0.0 to 1.0)
  double get tierProgress => rankTier.getTierProgress(level);

  /// Total XP threshold required to reach current level: 100 * (level - 1)^2
  int get currentLevelBaseXp => 100 * (level - 1) * (level - 1);

  /// Total XP threshold required to reach next level: 100 * level^2
  int get nextLevelTargetXp => 100 * level * level;

  /// Progress within current level from 0.0 to 1.0
  double get levelProgress {
    final range = nextLevelTargetXp - currentLevelBaseXp;
    if (range <= 0) return 0.0;
    final currentInLevel = xp - currentLevelBaseXp;
    return (currentInLevel / range).clamp(0.0, 1.0);
  }

  /// Calculates level based on XP: 1 + floor(sqrt(xp / 100))
  static int calculateLevel(int xp) {
    if (xp <= 0) return 1;
    return 1 + (sqrt(xp / 100)).floor();
  }
}
