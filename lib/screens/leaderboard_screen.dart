// lib/screens/leaderboard_screen.dart

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../core/widgets/player_avatar.dart';
import '../services/auth_service.dart';
import '../services/ranking_service.dart';
import '../theme/app_theme.dart';
import '../widgets/rank_tier_badge.dart';

class LeaderboardView extends StatefulWidget {
  final bool isStandalone;
  const LeaderboardView({super.key, this.isStandalone = false});

  @override
  State<LeaderboardView> createState() => _LeaderboardViewState();
}

class _LeaderboardViewState extends State<LeaderboardView> {
  LeaderboardSort _currentSort = LeaderboardSort.xp;
  bool _isLoading = true;
  List<LeaderboardPlayer> _players = [];
  int? _myRank;

  @override
  void initState() {
    super.initState();
    _loadLeaderboard();
  }

  Future<void> _loadLeaderboard() async {
    setState(() => _isLoading = true);
    final players = await RankingService.instance.fetchLeaderboard(
      limit: 50,
      sort: _currentSort,
    );

    final auth = AuthService.instance;
    int? myRank;
    if (auth.isAuthenticated && auth.currentUser != null) {
      myRank = await RankingService.instance.fetchUserLeaderboardRank(
        auth.currentUser!.id,
        sort: _currentSort,
      );
    }

    if (mounted) {
      setState(() {
        _players = players;
        _myRank = myRank;
        _isLoading = false;
      });
    }
  }

  void _onSortChanged(LeaderboardSort sort) {
    if (_currentSort == sort) return;
    setState(() {
      _currentSort = sort;
    });
    _loadLeaderboard();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // Sort Filter Header
        _buildFilterBar(),

        // Content Area
        Expanded(
          child: _isLoading
              ? const Center(
                  child: CircularProgressIndicator(color: AppTheme.gold),
                )
              : _players.isEmpty
                  ? _buildEmptyState()
                  : RefreshIndicator(
                      color: AppTheme.gold,
                      onRefresh: _loadLeaderboard,
                      child: SingleChildScrollView(
                        physics: const AlwaysScrollableScrollPhysics(
                          parent: BouncingScrollPhysics(),
                        ),
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                        child: Column(
                          children: [
                            // Podium Top 3
                            if (_players.length >= 3) ...[
                              _buildPodium(_players.sublist(0, 3)),
                              const SizedBox(height: 16),
                            ],

                            // Ranked List (4th+)
                            ..._buildPlayerList(
                              _players.length >= 3 ? _players.sublist(3) : _players,
                            ),

                            const SizedBox(height: 80),
                          ],
                        ),
                      ),
                    ),
        ),

        // Bottom Sticky User Standing Bar
        _buildMyStandingBar(),
      ],
    );
  }

  Widget _buildFilterBar() {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 8, 16, 8),
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: AppTheme.navyDark.withValues(alpha: 0.6),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.white12),
      ),
      child: Row(
        children: [
          _buildFilterTab(
            title: 'الأعلى خبرة (XP)',
            icon: Icons.auto_awesome_rounded,
            sort: LeaderboardSort.xp,
          ),
          _buildFilterTab(
            title: 'الأكثر فوزاً 🏆',
            icon: Icons.emoji_events_rounded,
            sort: LeaderboardSort.wins,
          ),
          _buildFilterTab(
            title: 'المستوى ⭐',
            icon: Icons.military_tech_rounded,
            sort: LeaderboardSort.level,
          ),
        ],
      ),
    );
  }

  Widget _buildFilterTab({
    required String title,
    required IconData icon,
    required LeaderboardSort sort,
  }) {
    final isSelected = _currentSort == sort;
    return Expanded(
      child: GestureDetector(
        onTap: () => _onSortChanged(sort),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          padding: const EdgeInsets.symmetric(vertical: 8),
          decoration: BoxDecoration(
            color: isSelected
                ? AppTheme.gold.withValues(alpha: 0.22)
                : Colors.transparent,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: isSelected ? AppTheme.gold.withValues(alpha: 0.6) : Colors.transparent,
            ),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                icon,
                size: 14,
                color: isSelected ? AppTheme.gold : Colors.white60,
              ),
              const SizedBox(width: 4),
              Text(
                title,
                style: GoogleFonts.cairo(
                  fontSize: 11,
                  fontWeight: isSelected ? FontWeight.w900 : FontWeight.w600,
                  color: isSelected ? AppTheme.goldLight : Colors.white70,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPodium(List<LeaderboardPlayer> top3) {
    final first = top3[0];
    final second = top3[1];
    final third = top3[2];

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            AppTheme.navyDark.withValues(alpha: 0.7),
            AppTheme.deepNavy.withValues(alpha: 0.9),
          ],
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
        ),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: AppTheme.gold.withValues(alpha: 0.3)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          // 2nd Place (Silver)
          Expanded(
            child: _buildPodiumItem(
              player: second,
              place: 2,
              color: const Color(0xFFC0C0C0),
              crown: '🥈',
              height: 120,
            ),
          ),

          // 1st Place (Gold)
          Expanded(
            child: _buildPodiumItem(
              player: first,
              place: 1,
              color: AppTheme.gold,
              crown: '👑',
              height: 150,
              isFirst: true,
            ),
          ),

          // 3rd Place (Bronze)
          Expanded(
            child: _buildPodiumItem(
              player: third,
              place: 3,
              color: const Color(0xFFCD7F32),
              crown: '🥉',
              height: 100,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPodiumItem({
    required LeaderboardPlayer player,
    required int place,
    required Color color,
    required String crown,
    required double height,
    bool isFirst = false,
  }) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Crown / Medal Icon
        Text(crown, style: TextStyle(fontSize: isFirst ? 28 : 22)),
        const SizedBox(height: 2),

        // Avatar
        Container(
          padding: const EdgeInsets.all(3),
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(color: color, width: isFirst ? 2.5 : 1.8),
            boxShadow: [
              BoxShadow(
                color: color.withValues(alpha: 0.4),
                blurRadius: isFirst ? 14 : 8,
              ),
            ],
          ),
          child: PlayerAvatar(
            photoData: player.avatarUrl,
            size: isFirst ? 58 : 46,
          ),
        ),

        const SizedBox(height: 6),

        // Name
        Text(
          player.username,
          overflow: TextOverflow.ellipsis,
          style: GoogleFonts.cairo(
            fontSize: isFirst ? 13 : 11,
            fontWeight: FontWeight.w900,
            color: isFirst ? AppTheme.cream : Colors.white70,
          ),
        ),

        // Tier / XP Info
        Text(
          _currentSort == LeaderboardSort.wins
              ? '${player.gamesWon} فوز'
              : '${player.xp} XP',
          style: GoogleFonts.cairo(
            fontSize: 10,
            fontWeight: FontWeight.bold,
            color: color,
          ),
        ),

        const SizedBox(height: 6),

        // Pedestal Box
        Container(
          height: height * 0.45,
          width: double.infinity,
          margin: const EdgeInsets.symmetric(horizontal: 4),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                color.withValues(alpha: 0.4),
                color.withValues(alpha: 0.1),
              ],
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
            ),
            borderRadius: const BorderRadius.vertical(top: Radius.circular(12)),
            border: Border.all(color: color.withValues(alpha: 0.5)),
          ),
          child: Center(
            child: Text(
              '#$place',
              style: GoogleFonts.cairo(
                fontSize: 16,
                fontWeight: FontWeight.w900,
                color: color,
              ),
            ),
          ),
        ),
      ],
    );
  }

  List<Widget> _buildPlayerList(List<LeaderboardPlayer> players) {
    return players.map((player) {
      final isTop10 = player.rankPosition <= 10;
      final auth = AuthService.instance;
      final isMe = auth.isAuthenticated && auth.currentUser?.id == player.id;

      return Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: isMe
              ? AppTheme.gold.withValues(alpha: 0.18)
              : AppTheme.navyDark.withValues(alpha: 0.65),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isMe
                ? AppTheme.gold
                : isTop10
                    ? Colors.white24
                    : Colors.white10,
            width: isMe ? 1.8 : 1.0,
          ),
        ),
        child: Row(
          children: [
            // Rank Number
            SizedBox(
              width: 34,
              child: Text(
                '#${player.rankPosition}',
                style: GoogleFonts.cairo(
                  fontSize: 13,
                  fontWeight: FontWeight.w900,
                  color: isTop10 ? AppTheme.gold : Colors.white60,
                ),
              ),
            ),

            // Avatar
            PlayerAvatar(
              photoData: player.avatarUrl,
              size: 40,
            ),
            const SizedBox(width: 12),

            // Name & Tier
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Flexible(
                        child: Text(
                          player.username,
                          overflow: TextOverflow.ellipsis,
                          style: GoogleFonts.cairo(
                            fontSize: 13,
                            fontWeight: FontWeight.bold,
                            color: isMe ? AppTheme.goldLight : AppTheme.cream,
                          ),
                        ),
                      ),
                      if (isMe) ...[
                        const SizedBox(width: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                          decoration: BoxDecoration(
                            color: AppTheme.gold,
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            'أنت',
                            style: GoogleFonts.cairo(
                              fontSize: 9,
                              fontWeight: FontWeight.w900,
                              color: AppTheme.navyDark,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 2),
                  Row(
                    children: [
                      RankTierBadge(
                        tier: player.rankTier,
                        level: player.level,
                        compact: true,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        'نسبة الفوز: ${player.winRate.toStringAsFixed(0)}%',
                        style: GoogleFonts.cairo(
                          fontSize: 10,
                          color: AppTheme.steelBlue,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),

            // XP / Score Column
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  _currentSort == LeaderboardSort.wins
                      ? '${player.gamesWon} فوز'
                      : '${player.xp} XP',
                  style: GoogleFonts.cairo(
                    fontSize: 13,
                    fontWeight: FontWeight.w900,
                    color: AppTheme.gold,
                  ),
                ),
                Text(
                  '${player.gamesPlayed} مباراة',
                  style: GoogleFonts.cairo(
                    fontSize: 10,
                    color: Colors.white54,
                  ),
                ),
              ],
            ),
          ],
        ),
      );
    }).toList();
  }

  Widget _buildMyStandingBar() {
    return Consumer<AuthService>(
      builder: (context, auth, _) {
        final profile = auth.currentProfile;

        if (!auth.isAuthenticated || profile == null) {
          return Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            decoration: BoxDecoration(
              color: AppTheme.navyDark,
              border: Border(top: BorderSide(color: Colors.white12)),
            ),
            child: Row(
              children: [
                const Icon(Icons.info_outline_rounded, color: AppTheme.gold, size: 18),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'سجّل الدخول بحساب Google للظهور في لوحة الصدارة والتنافس!',
                    style: GoogleFonts.cairo(fontSize: 11, color: Colors.white70),
                  ),
                ),
              ],
            ),
          );
        }

        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            color: AppTheme.navyDark,
            border: Border(
              top: BorderSide(color: AppTheme.gold.withValues(alpha: 0.5), width: 1.5),
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.5),
                blurRadius: 10,
                offset: const Offset(0, -4),
              ),
            ],
          ),
          child: Row(
            children: [
              // My Rank Badge
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: AppTheme.gold.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: AppTheme.gold),
                ),
                child: Text(
                  _myRank != null ? '#$_myRank' : 'غير مصنف',
                  style: GoogleFonts.cairo(
                    fontSize: 13,
                    fontWeight: FontWeight.w900,
                    color: AppTheme.gold,
                  ),
                ),
              ),
              const SizedBox(width: 12),

              // Avatar
              PlayerAvatar(photoData: profile.avatarUrl, size: 36),
              const SizedBox(width: 10),

              // Info
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      'ترتيبك الحالي: ${profile.username}',
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.cairo(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: AppTheme.cream,
                      ),
                    ),
                    Text(
                      'المستوى ${profile.level} • ${profile.rankTier.titleAr}',
                      style: GoogleFonts.cairo(
                        fontSize: 10,
                        color: profile.rankTier.primaryColor,
                      ),
                    ),
                  ],
                ),
              ),

              // Total XP
              Text(
                '${profile.xp} XP',
                style: GoogleFonts.cairo(
                  fontSize: 14,
                  fontWeight: FontWeight.w900,
                  color: AppTheme.goldLight,
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.leaderboard_rounded, size: 54, color: Colors.white24),
          const SizedBox(height: 12),
          Text(
            'لا يوجد لاعبون مسجلون في لوحة المتصدرين بعد',
            style: GoogleFonts.cairo(fontSize: 14, color: Colors.white60),
          ),
          const SizedBox(height: 12),
          OutlinedButton.icon(
            onPressed: _loadLeaderboard,
            icon: const Icon(Icons.refresh_rounded, color: AppTheme.gold, size: 18),
            label: Text('تحديث', style: GoogleFonts.cairo(color: AppTheme.gold)),
            style: OutlinedButton.styleFrom(
              side: const BorderSide(color: AppTheme.gold),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
          ),
        ],
      ),
    );
  }
}

class LeaderboardScreen extends StatelessWidget {
  const LeaderboardScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.deepNavy,
      appBar: AppBar(
        backgroundColor: AppTheme.navyDark,
        title: Text(
          'لوحة المتصدرين العالمية',
          style: GoogleFonts.cairo(fontWeight: FontWeight.bold, color: AppTheme.cream),
        ),
        centerTitle: true,
        elevation: 0,
      ),
      body: const SafeArea(
        child: LeaderboardView(isStandalone: true),
      ),
    );
  }
}
