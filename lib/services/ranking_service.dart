// lib/services/ranking_service.dart

import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../core/models/game_state.dart';
import '../core/models/comeback_event.dart';
import '../models/rank_tier.dart';
import '../models/match_rank.dart';
import '../models/user_profile.dart';
import 'auth_service.dart';
import 'game_action_service.dart';
import 'ugc_service.dart';

enum LeaderboardSort {
  xp,
  wins,
  level,
}

class XpRewardBreakdown {
  final int placementXp;
  final int winBonus;
  final int accuracyBonus;
  final int dashBonus;
  final int highScorerBonus;
  final int comebackBonus;
  final String rankTitle;
  final int rankIndex; // 0 = King, 1 = Sub-King, 2 = Sub-Kooz, 3 = Kooz
  final bool won;

  const XpRewardBreakdown({
    required this.placementXp,
    this.winBonus = 0,
    this.accuracyBonus = 0,
    this.dashBonus = 0,
    this.highScorerBonus = 0,
    this.comebackBonus = 0,
    required this.rankTitle,
    required this.rankIndex,
    required this.won,
  });

  int get totalXp =>
      placementXp +
      winBonus +
      accuracyBonus +
      dashBonus +
      highScorerBonus +
      comebackBonus;
}

class MatchXpResult {
  final XpRewardBreakdown breakdown;
  final int oldXp;
  final int newXp;
  final int oldLevel;
  final int newLevel;
  final bool didLevelUp;
  final RankTier oldTier;
  final RankTier newTier;
  final bool didTierUp;

  const MatchXpResult({
    required this.breakdown,
    required this.oldXp,
    required this.newXp,
    required this.oldLevel,
    required this.newLevel,
    required this.didLevelUp,
    required this.oldTier,
    required this.newTier,
    required this.didTierUp,
  });
}

class LeaderboardPlayer {
  final String id;
  final String username;
  final String avatarUrl;
  final int xp;
  final int level;
  final int gamesPlayed;
  final int gamesWon;
  final int rankPosition;
  final RankTier rankTier;

  const LeaderboardPlayer({
    required this.id,
    required this.username,
    required this.avatarUrl,
    required this.xp,
    required this.level,
    required this.gamesPlayed,
    required this.gamesWon,
    required this.rankPosition,
    required this.rankTier,
  });

  double get winRate =>
      gamesPlayed > 0 ? (gamesWon / gamesPlayed) * 100 : 0.0;

  factory LeaderboardPlayer.fromProfile(UserProfile profile, int rankPosition) {
    return LeaderboardPlayer(
      id: profile.id,
      username: profile.username,
      avatarUrl: profile.avatarUrl,
      xp: profile.xp,
      level: profile.level,
      gamesPlayed: profile.gamesPlayed,
      gamesWon: profile.gamesWon,
      rankPosition: rankPosition,
      rankTier: profile.rankTier,
    );
  }

  factory LeaderboardPlayer.fromMap(Map<String, dynamic> map, int rankPosition) {
    final profile = UserProfile.fromMap(map);
    return LeaderboardPlayer.fromProfile(profile, rankPosition);
  }
}

class RankingService {
  RankingService._internal();
  static final RankingService instance = RankingService._internal();

  /// Calculates the XP reward breakdown for an Estimation (Kotshina) match
  XpRewardBreakdown calculateKotshinaReward({
    required GameState state,
    required String myPlayerId,
    required String myPlayerName,
  }) {
    final sortedPlayers = [...state.players]
      ..sort((a, b) => b.totalScore.compareTo(a.totalScore));

    int myRankIndex = sortedPlayers.indexWhere(
      (p) => p.id == myPlayerId || p.name.trim().toLowerCase() == myPlayerName.trim().toLowerCase(),
    );

    if (myRankIndex < 0) myRankIndex = 3;

    final rankTitles = MatchRank.all.map((r) => r.titleAr).toList();
    final rankTitle = myRankIndex < rankTitles.length ? rankTitles[myRankIndex] : 'لاعب';

    // 1. Base Placement XP
    int placementXp;
    switch (myRankIndex) {
      case 0:
        placementXp = 100;
        break;
      case 1:
        placementXp = 65;
        break;
      case 2:
        placementXp = 35;
        break;
      default:
        placementXp = 15;
    }

    // 2. Win Bonus
    final won = myRankIndex == 0;
    final winBonus = won ? 50 : 0;

    // 3. Accuracy & Comeback Bonuses
    int accuracyBonus = 0;
    int dashBonus = 0;
    int highScorerBonus = 0;
    int comebackBonus = 0;

    final myPlayer = sortedPlayers.firstWhere(
      (p) => p.id == myPlayerId || p.name.trim().toLowerCase() == myPlayerName.trim().toLowerCase(),
      orElse: () => sortedPlayers.first,
    );

    // High Score bonus
    if (myPlayer.totalScore >= 50) {
      highScorerBonus = 25;
    } else if (myPlayer.totalScore >= 30) {
      highScorerBonus = 15;
    }

    if (myPlayer.declared != null && myPlayer.declared == myPlayer.actual) {
      accuracyBonus = 20;
    }
    if (myPlayer.isDashCall && myPlayer.actual == 0) {
      dashBonus = 30;
    }

    // Comeback Bonus
    final comebacks = ComebackDetector.detectMatchComebacks(
      state: state,
      playerId: myPlayerId,
      playerName: myPlayerName,
    );

    if (comebacks.isNotEmpty) {
      for (final event in comebacks) {
        switch (event.type) {
          case ComebackType.finalRoundComeback:
            comebackBonus += 50;
            break;
          case ComebackType.majorComeback:
            comebackBonus += 35;
            break;
          case ComebackType.rankSurge:
            comebackBonus += 15;
            break;
        }
      }
    }

    return XpRewardBreakdown(
      placementXp: placementXp,
      winBonus: winBonus,
      accuracyBonus: accuracyBonus,
      dashBonus: dashBonus,
      highScorerBonus: highScorerBonus,
      comebackBonus: comebackBonus,
      rankTitle: rankTitle,
      rankIndex: myRankIndex,
      won: won,
    );
  }

  /// Calculates the XP reward breakdown for a Ninety-Nine match
  XpRewardBreakdown calculateNinetyNineReward({
    required bool won,
    required int roundsSurvived,
  }) {
    final placementXp = won ? 80 : 30;
    final winBonus = won ? 40 : 0;
    final accuracyBonus = roundsSurvived * 5;

    return XpRewardBreakdown(
      placementXp: placementXp,
      winBonus: winBonus,
      accuracyBonus: accuracyBonus,
      rankTitle: won ? 'الفائز 👑' : 'مشارك 🃏',
      rankIndex: won ? 0 : 2,
      won: won,
    );
  }

  /// XP reward for a completed Basra match.
  XpRewardBreakdown calculateBasraReward({
    required bool won,
    required int roundsPlayed,
  }) {
    final placementXp = won ? 90 : 35;
    final winBonus = won ? 45 : 0;
    final accuracyBonus = roundsPlayed * 4;

    return XpRewardBreakdown(
      placementXp: placementXp,
      winBonus: winBonus,
      accuracyBonus: accuracyBonus,
      rankTitle: won ? 'الفائز 👑' : 'مشارك 🃏',
      rankIndex: won ? 0 : 2,
      won: won,
    );
  }

  /// Awards XP for a completed match. Uses server awards when authority mode is on.
  Future<MatchXpResult?> awardOnlineMatchXp({
    required XpRewardBreakdown breakdown,
    String? roomId,
  }) async {
    if (GameActionService.useServerAuthority &&
        roomId != null &&
        !roomId.startsWith('test_') &&
        !roomId.startsWith('local_')) {
      return processAuthorityMatchReward(
        roomId: roomId,
        fallbackBreakdown: breakdown,
      );
    }
    return processMatchReward(breakdown);
  }

  /// Reads server-recorded XP for an authority match and refreshes the profile.
  Future<MatchXpResult?> processAuthorityMatchReward({
    required String roomId,
    XpRewardBreakdown? fallbackBreakdown,
  }) async {
    final auth = AuthService.instance;
    final profile = auth.currentProfile;
    if (profile == null || !auth.isAuthenticated) return null;

    final oldXp = profile.xp;
    final oldLevel = profile.level;
    final oldTier = profile.rankTier;

    Map<String, dynamic>? award;
    for (var attempt = 0; attempt < 6; attempt++) {
      award = await _fetchServerMatchXpAward(roomId);
      if (award != null) break;
      await Future<void>.delayed(const Duration(milliseconds: 350));
    }

    if (award == null) {
      debugPrint('[RankingService] No server match XP award for room $roomId');
      return null;
    }

    await auth.refreshProfile();
    final updatedProfile = auth.currentProfile;
    final newXp = updatedProfile?.xp ?? oldXp;
    final newLevel =
        updatedProfile?.level ?? UserProfile.calculateLevel(newXp);
    final newTier = RankTier.fromLevel(newLevel);

    final rankIndex = (award['rank_index'] as num?)?.toInt() ?? 0;
    final rankTitles = MatchRank.all.map((r) => r.titleAr).toList();
    final breakdown = XpRewardBreakdown(
      placementXp: (award['placement_xp'] as num?)?.toInt() ??
          fallbackBreakdown?.placementXp ??
          0,
      winBonus: (award['win_bonus'] as num?)?.toInt() ??
          fallbackBreakdown?.winBonus ??
          0,
      accuracyBonus: (award['accuracy_bonus'] as num?)?.toInt() ??
          fallbackBreakdown?.accuracyBonus ??
          0,
      dashBonus: fallbackBreakdown?.dashBonus ?? 0,
      highScorerBonus: fallbackBreakdown?.highScorerBonus ?? 0,
      comebackBonus: fallbackBreakdown?.comebackBonus ?? 0,
      rankTitle: rankIndex < rankTitles.length
          ? rankTitles[rankIndex]
          : (fallbackBreakdown?.rankTitle ?? 'لاعب'),
      rankIndex: rankIndex,
      won: award['won'] as bool? ?? fallbackBreakdown?.won ?? false,
    );

    return MatchXpResult(
      breakdown: breakdown,
      oldXp: oldXp,
      newXp: newXp,
      oldLevel: oldLevel,
      newLevel: newLevel,
      didLevelUp: newLevel > oldLevel,
      oldTier: oldTier,
      newTier: newTier,
      didTierUp: newTier.type != oldTier.type,
    );
  }

  Future<Map<String, dynamic>?> _fetchServerMatchXpAward(String roomId) async {
    try {
      final raw = await Supabase.instance.client.rpc(
        'get_my_match_xp_award',
        params: {'p_room_id': roomId},
      );
      if (raw is Map<String, dynamic>) return raw;
      if (raw is Map) return Map<String, dynamic>.from(raw);
    } catch (e) {
      debugPrint('[RankingService] get_my_match_xp_award failed: $e');
    }
    return null;
  }

  /// Awards the XP and updates Supabase, returning Level-Up / Tier-Up details
  Future<MatchXpResult?> processMatchReward(XpRewardBreakdown breakdown) async {
    final auth = AuthService.instance;
    final profile = auth.currentProfile;
    if (profile == null || !auth.isAuthenticated) return null;

    final oldXp = profile.xp;
    final oldLevel = profile.level;
    final oldTier = profile.rankTier;

    final xpGain = breakdown.totalXp;
    await auth.recordGameResult(won: breakdown.won, xpGain: xpGain);

    final updatedProfile = auth.currentProfile;
    final newXp = updatedProfile?.xp ?? (oldXp + xpGain);
    final newLevel = updatedProfile?.level ?? UserProfile.calculateLevel(newXp);
    final newTier = RankTier.fromLevel(newLevel);

    return MatchXpResult(
      breakdown: breakdown,
      oldXp: oldXp,
      newXp: newXp,
      oldLevel: oldLevel,
      newLevel: newLevel,
      didLevelUp: newLevel > oldLevel,
      oldTier: oldTier,
      newTier: newTier,
      didTierUp: newTier.type != oldTier.type,
    );
  }

  /// Fetches global leaderboard players from Supabase (only signed-in players)
  Future<List<LeaderboardPlayer>> fetchLeaderboard({
    int limit = 50,
    LeaderboardSort sort = LeaderboardSort.xp,
  }) async {
    try {
      final client = Supabase.instance.client;
      String orderColumn = 'xp';
      if (sort == LeaderboardSort.wins) {
        orderColumn = 'games_won';
      } else if (sort == LeaderboardSort.level) {
        orderColumn = 'level';
      }

      final response = await client
          .from('public_profiles')
          .select()
          .order(orderColumn, ascending: false)
          .order('xp', ascending: false)
          .limit(limit)
          .timeout(const Duration(seconds: 4));

      final blocked = await UgcService.instance.fetchBlockedUserIds();

      final List<LeaderboardPlayer> players = [];
      int rank = 1;
      for (final item in response as List<dynamic>) {
        final map = item as Map<String, dynamic>;
        final id = map['id']?.toString() ?? '';
        if (blocked.contains(id)) continue;
        players.add(LeaderboardPlayer.fromMap(map, rank));
        rank++;
      }
      return players;
    } catch (e) {
      debugPrint('[RankingService] fetchLeaderboard error: $e');
      return [];
    }
  }

  /// Fetches the user's specific leaderboard rank position among signed-in players
  Future<int?> fetchUserLeaderboardRank(String userId, {LeaderboardSort sort = LeaderboardSort.xp}) async {
    try {
      final auth = AuthService.instance;
      if (!auth.isAuthenticated) return null;

      final client = Supabase.instance.client;
      final myProfileRes = await client
          .from('public_profiles')
          .select()
          .eq('id', userId)
          .maybeSingle();
      if (myProfileRes == null) return null;

      final myXp = (myProfileRes['xp'] as num?)?.toInt() ?? 0;
      final myWins = (myProfileRes['games_won'] as num?)?.toInt() ?? 0;

      var query = client
          .from('public_profiles')
          .select('id');

      if (sort == LeaderboardSort.wins) {
        query = query.gt('games_won', myWins);
      } else {
        query = query.gt('xp', myXp);
      }

      final higherPlayers = await query.timeout(const Duration(seconds: 3));
      final count = (higherPlayers as List<dynamic>).length;
      return count + 1;
    } catch (e) {
      debugPrint('[RankingService] fetchUserLeaderboardRank error: $e');
      return null;
    }
  }
}
