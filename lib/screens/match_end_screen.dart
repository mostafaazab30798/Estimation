// lib/screens/match_end_screen.dart
//
// Final match results screen with XP awards, level progression, and ranking tiers.

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../core/models/game_state.dart';
import '../core/models/comeback_event.dart';
import '../models/rank_tier.dart';
import '../providers/game_provider.dart';
import '../services/auth_service.dart';
import '../services/history_service.dart';
import '../services/audio_service.dart';
import '../services/estimation_stats_service.dart';
import '../services/ranking_service.dart';
import '../theme/app_theme.dart';
import '../widgets/level_up_dialog.dart';
import '../widgets/rank_tier_badge.dart';
import '../widgets/share_my_estimation_dialog.dart';

class MatchEndScreen extends StatefulWidget {
  final GameState state;
  final GameProvider provider;

  const MatchEndScreen({
    super.key,
    required this.state,
    required this.provider,
  });

  @override
  State<MatchEndScreen> createState() => _MatchEndScreenState();
}

class _MatchEndScreenState extends State<MatchEndScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<double> _scale;
  bool _hasSaved = false;
  XpRewardBreakdown? _rewardBreakdown;
  MatchXpResult? _xpResult;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );
    _scale = CurvedAnimation(parent: _ctrl, curve: Curves.elasticOut);
    _ctrl.forward();

    final winner = widget.state.matchWinner;
    final isMeWinner = winner != null && winner.id == widget.provider.myPlayerId;
    if (isMeWinner) {
      AudioService.instance.playWin();
    } else {
      AudioService.instance.playDefeat();
    }

    if (!_hasSaved) {
      _hasSaved = true;
      _calculateAndAwardXp();
      EstimationStatsService.instance.recordMatch(
        state: widget.state,
        playerName: widget.provider.myName,
        playerId: widget.provider.myPlayerId,
      );
      // Only the host (or offline player) saves match to prevent duplicate records from all 4 clients
      if (widget.provider.role != ConnectionRole.client) {
        HistoryService.saveMatch(widget.state);
      }
    }
  }

  Future<void> _calculateAndAwardXp() async {
    final breakdown = RankingService.instance.calculateKotshinaReward(
      state: widget.state,
      myPlayerId: widget.provider.myPlayerId,
      myPlayerName: widget.provider.myName,
    );

    setState(() {
      _rewardBreakdown = breakdown;
    });

    final result = await RankingService.instance.processMatchReward(breakdown);
    if (mounted && result != null) {
      setState(() {
        _xpResult = result;
      });

      if (result.didLevelUp) {
        Future.delayed(const Duration(milliseconds: 900), () {
          if (mounted) {
            LevelUpDialog.show(
              context,
              oldLevel: result.oldLevel,
              newLevel: result.newLevel,
              oldTier: result.oldTier,
              newTier: result.newTier,
            );
          }
        });
      }
    }
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final winner = widget.state.matchWinner;
    final sortedPlayers = [...widget.state.players]
      ..sort((a, b) => b.totalScore.compareTo(a.totalScore));

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {
        if (didPop) return;
        widget.provider.reset();
        Navigator.of(context, rootNavigator: true)
            .pushNamedAndRemoveUntil('/', (r) => false);
      },
      child: Scaffold(
        body: Container(
          decoration: const BoxDecoration(
            gradient: RadialGradient(
              colors: [Color(0xFF2E4730), AppTheme.feltGreenDark],
              radius: 1.5,
            ),
          ),
          child: SafeArea(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
              child: SingleChildScrollView(
                physics: const BouncingScrollPhysics(),
                child: Column(
                  children: [
                    const SizedBox(height: 8),
                    // Trophy animation
                    ScaleTransition(
                      scale: _scale,
                      child: const Text('🏆', style: TextStyle(fontSize: 64)),
                    ),
                    const SizedBox(height: 8),
                    if (winner != null) ...[
                      ShaderMask(
                        shaderCallback: (bounds) => const LinearGradient(
                          colors: [AppTheme.gold, Color(0xFFFFF9C4)],
                        ).createShader(bounds),
                        child: Text(
                          'الفائز: ${winner.name}!',
                          style: GoogleFonts.cairo(
                            fontSize: 26,
                            fontWeight: FontWeight.w900,
                            color: Colors.white,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '${winner.totalScore} نقطة',
                        style: GoogleFonts.cairo(
                          color: AppTheme.gold,
                          fontSize: 17,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],

                    const SizedBox(height: 18),

                    // XP & Ranking Progression Card
                    if (_rewardBreakdown != null) ...[
                      _buildXpProgressionCard(),
                      const SizedBox(height: 18),
                    ],

                    // Match Highlights / Comeback Moments
                    _buildMatchHighlightsSection(),

                    // Final standings
                    Text(
                      'الترتيب النهائي',
                      style: GoogleFonts.cairo(
                        fontSize: 18,
                        fontWeight: FontWeight.w900,
                        color: AppTheme.cream,
                      ),
                    ),
                    const SizedBox(height: 10),
                    ...sortedPlayers.asMap().entries.map((e) {
                      final rankIndex = e.key.clamp(0, 3);
                      final player = e.value;
                      final ranks = ['كينج 👑', 'صب كينج 🥈', 'صب كوز 🥉', 'كوز 🤡'];
                      final rankName = ranks[rankIndex];
                      final rankColor = AppTheme.rankColors[rankIndex];
                      final isMe = player.id == widget.provider.myPlayerId;

                      return Container(
                        margin: const EdgeInsets.only(bottom: 8),
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                        decoration: BoxDecoration(
                          color: rankColor.withValues(alpha: isMe ? 0.25 : 0.15),
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(
                            color: isMe ? AppTheme.gold : rankColor.withValues(alpha: 0.5),
                            width: isMe ? 2.0 : 1.0,
                          ),
                          boxShadow: rankIndex == 0 ? AppTheme.neumorphicTurnGlow(rankColor) : [],
                        ),
                        child: Row(
                          children: [
                            SizedBox(
                              width: 95,
                              child: Text(
                                rankName,
                                style: GoogleFonts.cairo(
                                  fontSize: 14,
                                  fontWeight: FontWeight.bold,
                                  color: rankColor,
                                ),
                              ),
                            ),
                            Expanded(
                              child: Row(
                                children: [
                                  Flexible(
                                    child: Text(
                                      player.name,
                                      overflow: TextOverflow.ellipsis,
                                      style: GoogleFonts.cairo(
                                        fontSize: 14,
                                        fontWeight: FontWeight.bold,
                                        color: isMe ? AppTheme.goldLight : rankColor,
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
                            ),
                            Text(
                              '${player.totalScore} نقطة',
                              style: GoogleFonts.cairo(
                                fontSize: 14,
                                fontWeight: FontWeight.bold,
                                color: rankColor,
                              ),
                            ),
                          ],
                        ),
                      );
                    }),
                    const SizedBox(height: 20),

                    // Share Victory Card Action
                    SizedBox(
                      width: double.infinity,
                      child: Container(
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(
                            colors: [Color(0xFF8B5CF6), Color(0xFF6D28D9)],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                          borderRadius: BorderRadius.circular(16),
                          boxShadow: [
                            BoxShadow(
                              color: const Color(0xFF7C3AED).withValues(alpha: 0.35),
                              blurRadius: 10,
                              offset: const Offset(0, 3),
                            ),
                          ],
                        ),
                        child: Material(
                          color: Colors.transparent,
                          child: InkWell(
                            onTap: () {
                              final auth = AuthService.instance;
                              int matchComebacks = 0;
                              int perfectCount = 0;
                              final winnerId = winner?.id;

                              for (int r = 1; r <= widget.state.roundHistory.length; r++) {
                                final cbs = ComebackDetector.detectRoundComebacks(state: widget.state, roundNumber: r);
                                matchComebacks += cbs.length;
                              }

                              for (final roundRecord in widget.state.roundHistory) {
                                for (final pr in roundRecord.playerRecords) {
                                  if (pr.playerId == winnerId && pr.isSuccess) {
                                    perfectCount++;
                                  }
                                }
                              }

                              ShareMyEstimationDialog.show(
                                context,
                                type: ShareCardType.matchVictory,
                                playerName: winner?.name ?? 'البطل',
                                avatarUrl: auth.currentProfile?.avatarUrl ?? '',
                                matchFinalScore: winner?.totalScore ?? 0,
                                matchPerfectEstimates: perfectCount,
                                matchComebacks: matchComebacks,
                                matchBestRound: 28,
                                matchRankTitle: 'الكينج 👑',
                              );
                            },
                            borderRadius: BorderRadius.circular(16),
                            child: Padding(
                              padding: const EdgeInsets.symmetric(vertical: 13, horizontal: 16),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  const Icon(Icons.share_rounded, color: Colors.white, size: 20),
                                  const SizedBox(width: 8),
                                  Text(
                                    'مشاركة نتيجة الانتصار 🏆',
                                    style: GoogleFonts.cairo(
                                      fontSize: 14,
                                      fontWeight: FontWeight.w900,
                                      color: Colors.white,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),

                    const SizedBox(height: 12),

                    // Back to home
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppTheme.gold,
                          foregroundColor: AppTheme.navyDark,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                          elevation: 3,
                        ),
                        onPressed: () {
                          widget.provider.reset();
                          Navigator.of(context, rootNavigator: true)
                              .pushNamedAndRemoveUntil('/', (r) => false);
                        },
                        child: Text(
                          'العودة للقائمة الرئيسية',
                          style: GoogleFonts.cairo(
                            fontSize: 15,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildXpProgressionCard() {
    final breakdown = _rewardBreakdown!;
    final auth = AuthService.instance;
    final profile = auth.currentProfile;
    final tier = profile?.rankTier ?? RankTier.bronze;
    final currentLevel = _xpResult?.newLevel ?? profile?.level ?? 1;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.navyDark.withValues(alpha: 0.85),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppTheme.gold.withValues(alpha: 0.4)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.4),
            blurRadius: 14,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          // Header: Total XP Gain & Tier Badge
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  const Icon(Icons.auto_awesome_rounded, color: AppTheme.gold, size: 20),
                  const SizedBox(width: 8),
                  Text(
                    '+${breakdown.totalXp} XP مكافأة الجولة',
                    style: GoogleFonts.cairo(
                      fontSize: 15,
                      fontWeight: FontWeight.w900,
                      color: AppTheme.gold,
                    ),
                  ),
                ],
              ),
              RankTierBadge(
                tier: tier,
                level: currentLevel,
                compact: true,
              ),
            ],
          ),

          const SizedBox(height: 12),
          const Divider(color: Colors.white10, height: 1),
          const SizedBox(height: 10),

          // Detailed XP Pills
          Wrap(
            spacing: 8,
            runSpacing: 6,
            alignment: WrapAlignment.center,
            children: [
              _buildXpPill(
                label: breakdown.rankTitle,
                xp: breakdown.placementXp,
                color: AppTheme.rankColors[breakdown.rankIndex],
              ),
              if (breakdown.winBonus > 0)
                _buildXpPill(
                  label: 'مكافأة الفوز 🏆',
                  xp: breakdown.winBonus,
                  color: AppTheme.gold,
                ),
              if (breakdown.accuracyBonus > 0)
                _buildXpPill(
                  label: 'دقة التوقع 🎯',
                  xp: breakdown.accuracyBonus,
                  color: AppTheme.mintSoft,
                ),
              if (breakdown.dashBonus > 0)
                _buildXpPill(
                  label: 'نداء داش ناجح ⚡',
                  xp: breakdown.dashBonus,
                  color: const Color(0xFFFF4081),
                ),
              if (breakdown.highScorerBonus > 0)
                _buildXpPill(
                  label: 'سكور عالي 🚀',
                  xp: breakdown.highScorerBonus,
                  color: const Color(0xFF00E5FF),
                ),
              if (breakdown.comebackBonus > 0)
                _buildXpPill(
                  label: 'ريمونتادا أسطورية 🔥',
                  xp: breakdown.comebackBonus,
                  color: const Color(0xFFFF5722),
                ),
            ],
          ),

          // Progress Bar if user profile exists
          if (profile != null) ...[
            const SizedBox(height: 12),
            ClipRRect(
              borderRadius: BorderRadius.circular(6),
              child: LinearProgressIndicator(
                value: profile.levelProgress,
                minHeight: 7,
                backgroundColor: Colors.white12,
                valueColor: AlwaysStoppedAnimation<Color>(tier.primaryColor),
              ),
            ),
            const SizedBox(height: 4),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'المستوى $currentLevel',
                  style: GoogleFonts.cairo(
                    fontSize: 10.5,
                    fontWeight: FontWeight.bold,
                    color: Colors.white70,
                  ),
                ),
                Text(
                  '${profile.xp} / ${profile.nextLevelTargetXp} XP',
                  style: GoogleFonts.cairo(
                    fontSize: 10.5,
                    fontWeight: FontWeight.bold,
                    color: AppTheme.goldLight,
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildXpPill({
    required String label,
    required int xp,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withValues(alpha: 0.4)),
      ),
      child: Text(
        '$label (+$xp XP)',
        style: GoogleFonts.cairo(
          fontSize: 10,
          fontWeight: FontWeight.bold,
          color: color,
        ),
      ),
    );
  }

  Widget _buildMatchHighlightsSection() {
    final List<ComebackEvent> allHighlights = [];
    for (int r = 1; r <= widget.state.roundHistory.length; r++) {
      allHighlights.addAll(
        ComebackDetector.detectRoundComebacks(state: widget.state, roundNumber: r),
      );
    }

    if (allHighlights.isEmpty) return const SizedBox.shrink();

    return Column(
      children: [
        Container(
          margin: const EdgeInsets.only(bottom: 18),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: const Color(0xFF1E2838).withValues(alpha: 0.85),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: const Color(0xFFFF7043).withValues(alpha: 0.45),
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.35),
                blurRadius: 12,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Text('🔥', style: TextStyle(fontSize: 20)),
                  const SizedBox(width: 8),
                  Text(
                    'أبرز أحداث وريمونتادات المباراة',
                    style: GoogleFonts.cairo(
                      fontSize: 15,
                      fontWeight: FontWeight.w900,
                      color: const Color(0xFFFFAB91),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              ...allHighlights.map((event) {
                final isMe = event.playerId == widget.provider.myPlayerId;
                Color accentColor;
                switch (event.type) {
                  case ComebackType.majorComeback:
                    accentColor = const Color(0xFFFF5722);
                    break;
                  case ComebackType.finalRoundComeback:
                    accentColor = AppTheme.gold;
                    break;
                  case ComebackType.rankSurge:
                    accentColor = const Color(0xFF00E676);
                    break;
                }

                return Container(
                  margin: const EdgeInsets.only(bottom: 8),
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  decoration: BoxDecoration(
                    color: accentColor.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: accentColor.withValues(alpha: 0.35),
                    ),
                  ),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 7,
                          vertical: 3,
                        ),
                        decoration: BoxDecoration(
                          color: accentColor.withValues(alpha: 0.25),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          'ج ${event.roundNumber}',
                          style: GoogleFonts.cairo(
                            fontSize: 11,
                            fontWeight: FontWeight.w900,
                            color: accentColor,
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Text(event.iconEmoji, style: const TextStyle(fontSize: 18)),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Text(
                                  event.playerName,
                                  style: GoogleFonts.cairo(
                                    fontSize: 13,
                                    fontWeight: FontWeight.bold,
                                    color: isMe ? AppTheme.goldLight : Colors.white,
                                  ),
                                ),
                                if (isMe) ...[
                                  const SizedBox(width: 5),
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                                    decoration: BoxDecoration(
                                      color: AppTheme.gold,
                                      borderRadius: BorderRadius.circular(4),
                                    ),
                                    child: Text(
                                      'أنت',
                                      style: GoogleFonts.cairo(
                                        fontSize: 8,
                                        fontWeight: FontWeight.w900,
                                        color: AppTheme.navyDark,
                                      ),
                                    ),
                                  ),
                                ],
                              ],
                            ),
                            Text(
                              event.subtitleAr,
                              style: GoogleFonts.cairo(
                                fontSize: 11.5,
                                color: Colors.white70,
                              ),
                            ),
                          ],
                        ),
                      ),
                      if (event.pointsDeficitOvercome > 0)
                        Text(
                          '+${event.pointsDeficitOvercome} نقطة',
                          style: GoogleFonts.cairo(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            color: accentColor,
                          ),
                        ),
                    ],
                  ),
                );
              }),
            ],
          ),
        ),
      ],
    );
  }
}
