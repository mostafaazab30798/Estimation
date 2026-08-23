// lib/widgets/estimation_poster_card.dart
//
// Ultra-luxury emerald & gold poster card matching the template — 100% Arabic Edition.

import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../models/playstyle_models.dart';
import '../models/estimation_statistics.dart';
import '../services/achievement_service.dart';
import '../core/widgets/player_avatar.dart';

class EstimationPosterCard extends StatelessWidget {
  final String playerName;
  final String avatarUrl;
  final EstimationStatistics stats;
  final PlayerPersonalityProfile profile;
  final PlayerIdentityCardConfig config;
  final int level;
  final int currentXp;
  final int nextLevelTargetXp;

  const EstimationPosterCard({
    super.key,
    required this.playerName,
    required this.avatarUrl,
    required this.stats,
    required this.profile,
    required this.config,
    required this.level,
    this.currentXp = 1450,
    this.nextLevelTargetXp = 2000,
  });

  static const Color gold = Color(0xFFD4AF37);
  static const Color goldLight = Color(0xFFF7E7A9);
  static const Color goldDark = Color(0xFF8C6D1F);
  static const Color emeraldDark = Color(0xFF04120D);
  static const Color emeraldMid = Color(0xFF082218);
  static const Color emeraldLight = Color(0xFF0D3325);
  static const Color emeraldBorder = Color(0xFF1B4D3A);

  @override
  Widget build(BuildContext context) {
    final displayName = playerName.trim().isNotEmpty ? playerName.trim() : 'لاعب كوتشينة';
    final archetype = profile.primaryArchetype;
    final accuracy = stats.declarationAccuracy.toStringAsFixed(0);
    final winStreak = stats.longestWinningStreak;
    final bestScore = stats.highestScoreInOneRound > 0 ? '+${stats.highestScoreInOneRound}' : '+0';
    final title = config.selectedTitle.isNotEmpty ? config.selectedTitle : archetype.titleAr;
    final tagline = archetype.taglineAr.isNotEmpty ? '« ${archetype.taglineAr} »' : '« سيد التكتيك واللمّات الحاسمة »';

    // Calculate over/under bid percentages
    final totalRounds = stats.totalRounds > 0 ? stats.totalRounds : 1;
    final overRate = ((stats.failedDeclarations * 0.6) / totalRounds * 100).clamp(0, 100).toStringAsFixed(0);
    final underRate = ((stats.failedDeclarations * 0.4) / totalRounds * 100).clamp(0, 100).toStringAsFixed(0);

    return Directionality(
      textDirection: TextDirection.rtl,
      child: Container(
        width: 600,
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: emeraldDark,
          borderRadius: BorderRadius.circular(28),
          gradient: const RadialGradient(
            center: Alignment(0, -0.2),
            radius: 1.2,
            colors: [
              emeraldMid,
              emeraldDark,
              Color(0xFF020906),
            ],
          ),
          border: Border.all(color: gold, width: 3.0),
          boxShadow: [
            BoxShadow(
              color: gold.withValues(alpha: 0.35),
              blurRadius: 30,
              spreadRadius: 2,
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(22),
          child: Stack(
            children: [
              // Background Watermark Patterns
              Positioned.fill(
                child: CustomPaint(
                  painter: _PosterBackgroundWatermarkPainter(),
                ),
              ),

              // Inner Filigree Border Frame
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: gold.withValues(alpha: 0.45), width: 1.5),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // ── 1. Top Logo Header ───────────────────────────────────────
                    _buildHeaderLogo(),

                    const SizedBox(height: 12),

                    // ── 2. Player Identity Hero Section ──────────────────────────
                    _buildIdentityHero(displayName, title, tagline),

                    const SizedBox(height: 14),

                    // ── 3. 5-Metric Ribbon Bar ───────────────────────────────────
                    _buildFiveMetricsBar(accuracy, winStreak.toString(), bestScore),

                    const SizedBox(height: 14),

                    // ── 4. Middle Dual Panels: Radar Playstyle + Stats ───────────
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Left: Radar Play Style (5 vertices)
                        Expanded(
                          flex: 10,
                          child: _buildPlayStylePanel(),
                        ),
                        const SizedBox(width: 10),
                        // Right: Detailed Stats List
                        Expanded(
                          flex: 11,
                          child: _buildEstimationStatsPanel(overRate, underRate),
                        ),
                      ],
                    ),

                    const SizedBox(height: 14),

                    // ── 5. Bottom Dual Panels: Achievements + Favorite Mode ──────
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Left: Achievements (4 Shields)
                        Expanded(
                          flex: 11,
                          child: _buildAchievementsPanel(),
                        ),
                        const SizedBox(width: 10),
                        // Right: Favorite Mode
                        Expanded(
                          flex: 10,
                          child: _buildFavoriteModePanel(),
                        ),
                      ],
                    ),

                    const SizedBox(height: 14),

                    // ── 6. Bottom Ribbon & Footer ────────────────────────────────
                    _buildFooterSection(),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ── Header Logo ────────────────────────────────────────────────────────────

  Widget _buildHeaderLogo() {
    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.star_rounded, size: 10, color: gold),
            const SizedBox(width: 6),
            const Text('👑', style: TextStyle(fontSize: 16)),
            const SizedBox(width: 6),
            const Icon(Icons.star_rounded, size: 10, color: gold),
          ],
        ),
        const SizedBox(height: 2),
        Text(
          'كوتشينة • إستميشن',
          style: GoogleFonts.cairo(
            fontSize: 22,
            fontWeight: FontWeight.w900,
            color: goldLight,
            letterSpacing: 2.0,
            shadows: [
              const Shadow(color: Colors.black, blurRadius: 4, offset: Offset(0, 2)),
              Shadow(color: gold.withValues(alpha: 0.8), blurRadius: 10),
            ],
          ),
        ),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(width: 28, height: 1, color: gold.withValues(alpha: 0.6)),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8),
              child: Text(
                '♦ لعبة الذكاء والتكتيك ♦',
                style: GoogleFonts.cairo(
                  fontSize: 9.0,
                  fontWeight: FontWeight.bold,
                  color: gold,
                  letterSpacing: 1.5,
                ),
              ),
            ),
            Container(width: 28, height: 1, color: gold.withValues(alpha: 0.6)),
          ],
        ),
      ],
    );
  }

  // ── Player Identity Hero ───────────────────────────────────────────────────

  Widget _buildIdentityHero(String displayName, String title, String tagline) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        // Right in RTL: Avatar with Gold Ring & Ribbon
        Stack(
          alignment: Alignment.bottomCenter,
          clipBehavior: Clip.none,
          children: [
            Container(
              padding: const EdgeInsets.all(3),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(color: gold, width: 2.5),
                boxShadow: [
                  BoxShadow(
                    color: gold.withValues(alpha: 0.4),
                    blurRadius: 12,
                    spreadRadius: 1,
                  ),
                ],
              ),
              child: PlayerAvatar(
                photoData: avatarUrl,
                size: 72,
              ),
            ),
            Positioned(
              bottom: -6,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 2),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFFB8860B), Color(0xFFDAA520), Color(0xFFB8860B)],
                  ),
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(color: goldLight, width: 0.8),
                  boxShadow: const [
                    BoxShadow(color: Colors.black45, blurRadius: 4, offset: Offset(0, 2)),
                  ],
                ),
                child: Text(
                  'اللاعب',
                  style: GoogleFonts.cairo(
                    fontSize: 8.5,
                    fontWeight: FontWeight.w900,
                    color: Colors.black,
                  ),
                ),
              ),
            ),
          ],
        ),

        const SizedBox(width: 14),

        // Center: Name, Title Ribbon, Tagline
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                displayName,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: GoogleFonts.cairo(
                  fontSize: 20,
                  fontWeight: FontWeight.w900,
                  color: Colors.white,
                  letterSpacing: 0.5,
                  shadows: [
                    const Shadow(color: Colors.black87, blurRadius: 4, offset: Offset(0, 2)),
                  ],
                ),
              ),
              const SizedBox(height: 3),
              // Title ribbon pill
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 2),
                decoration: BoxDecoration(
                  color: gold.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: gold.withValues(alpha: 0.7), width: 1),
                ),
                child: Text(
                  title,
                  style: GoogleFonts.cairo(
                    fontSize: 10.5,
                    fontWeight: FontWeight.w900,
                    color: goldLight,
                  ),
                ),
              ),
              const SizedBox(height: 4),
              Text(
                tagline,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: GoogleFonts.cairo(
                  fontSize: 9.5,
                  fontWeight: FontWeight.w600,
                  fontStyle: FontStyle.italic,
                  color: const Color(0xFF6EE7B7), // Mint green
                ),
              ),
            ],
          ),
        ),

        const SizedBox(width: 10),

        // Left in RTL: Crowned Level Shield & EXP Bar
        Column(
          children: [
            // Level Shield
            Stack(
              alignment: Alignment.topCenter,
              children: [
                Container(
                  width: 58,
                  height: 64,
                  decoration: BoxDecoration(
                    color: emeraldMid,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: gold, width: 2),
                    boxShadow: [
                      BoxShadow(color: gold.withValues(alpha: 0.3), blurRadius: 8),
                    ],
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const SizedBox(height: 6),
                      Text(
                        'المستوى',
                        style: GoogleFonts.cairo(
                          fontSize: 8.0,
                          fontWeight: FontWeight.w900,
                          color: goldLight,
                        ),
                      ),
                      Text(
                        level.toString().padLeft(2, '0'),
                        style: GoogleFonts.cairo(
                          fontSize: 18,
                          fontWeight: FontWeight.w900,
                          color: Colors.white,
                          height: 1.0,
                        ),
                      ),
                    ],
                  ),
                ),
                Positioned(
                  top: -8,
                  child: const Text('👑', style: TextStyle(fontSize: 14)),
                ),
              ],
            ),
            const SizedBox(height: 5),
            // EXP Capsule
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: Colors.black.withValues(alpha: 0.5),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: gold.withValues(alpha: 0.4), width: 0.8),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 3, vertical: 0.5),
                    decoration: BoxDecoration(
                      color: gold,
                      borderRadius: BorderRadius.circular(3),
                    ),
                    child: Text(
                      'خبرة',
                      style: GoogleFonts.cairo(
                        fontSize: 7.0,
                        fontWeight: FontWeight.w900,
                        color: Colors.black,
                      ),
                    ),
                  ),
                  const SizedBox(width: 4),
                  Text(
                    '${currentXp.toString().padLeft(4, '0')} / ${nextLevelTargetXp.toString().padLeft(4, '0')}',
                    style: GoogleFonts.cairo(
                      fontSize: 7.5,
                      fontWeight: FontWeight.bold,
                      color: goldLight,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ],
    );
  }

  // ── 5 Metrics Bar ──────────────────────────────────────────────────────────

  Widget _buildFiveMetricsBar(String accuracy, String winStreak, String bestScore) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.45),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: gold.withValues(alpha: 0.4), width: 1.2),
      ),
      child: Row(
        children: [
          _buildMetricColumn('🏆', 'إجمالي الفوز', stats.gamesWon.toString().padLeft(3, '0')),
          _buildDivider(),
          _buildMetricColumn('🎴', 'المباريات', stats.gamesPlayed.toString().padLeft(3, '0')),
          _buildDivider(),
          _buildMetricColumn('🎯', 'دقة الكول', '$accuracy%'),
          _buildDivider(),
          _buildMetricColumn('🔥', 'أطول سلسلة', winStreak.padLeft(2, '0')),
          _buildDivider(),
          _buildMetricColumn('📈', 'أعلى سكور', bestScore),
        ],
      ),
    );
  }

  Widget _buildMetricColumn(String emoji, String title, String value) {
    return Expanded(
      child: Column(
        children: [
          Text(emoji, style: const TextStyle(fontSize: 14)),
          const SizedBox(height: 2),
          FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(
              title,
              style: GoogleFonts.cairo(
                fontSize: 8.0,
                fontWeight: FontWeight.bold,
                color: goldLight,
              ),
            ),
          ),
          FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(
              value,
              style: GoogleFonts.cairo(
                fontSize: 13.5,
                fontWeight: FontWeight.w900,
                color: Colors.white,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDivider() {
    return Container(
      width: 1,
      height: 28,
      color: gold.withValues(alpha: 0.25),
    );
  }

  // ── Play Style Radar Panel ─────────────────────────────────────────────────

  Widget _buildPlayStylePanel() {
    final metrics = profile.metrics;
    final strategic = (metrics.scoreAwareness + metrics.trumpConfidence) / 200.0;
    final aggressive = metrics.aggression / 100.0;
    final riskTaking = metrics.riskTaking / 100.0;
    final accurate = (metrics.declarationAccuracy + metrics.precision) / 200.0;
    final adaptive = (metrics.adaptability + metrics.comebackAbility) / 200.0;

    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.4),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: emeraldBorder, width: 1.2),
      ),
      child: Column(
        children: [
          _buildPanelHeader('أسلوب اللعب'),
          const SizedBox(height: 8),
          SizedBox(
            width: 210,
            height: 170,
            child: CustomPaint(
              painter: _RadarChartPainter(
                values: [strategic, aggressive, riskTaking, accurate, adaptive],
                labels: [
                  '🧠 استراتيجي\n${(strategic * 100).toInt()}%',
                  '🔥 هجومي\n${(aggressive * 100).toInt()}%',
                  '🎲 مجازف\n${(riskTaking * 100).toInt()}%',
                  '🎯 دقيق\n${(accurate * 100).toInt()}%',
                  '🔄 مرن\n${(adaptive * 100).toInt()}%',
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ── Estimation Stats Panel ─────────────────────────────────────────────────

  Widget _buildEstimationStatsPanel(String overRate, String underRate) {
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.4),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: emeraldBorder, width: 1.2),
      ),
      child: Column(
        children: [
          _buildPanelHeader('إحصائيات إستميشن'),
          const SizedBox(height: 6),
          _buildStatRow('🎴', 'متوسط المزايدة', stats.totalRounds > 0 ? stats.averageDeclaredTricks.toStringAsFixed(1) : '0.0'),
          _buildStatRow('📊', 'متوسط النتيجة', stats.totalRounds > 0 ? stats.averageActualTricks.toStringAsFixed(1) : '0.0'),
          _buildStatRow('🎯', 'كول مثالي', stats.perfectEstimates.toString().padLeft(2, '0')),
          _buildStatRow('⬆️', 'مزايدة زائدة', '$overRate%'),
          _buildStatRow('⬇️', 'مزايدة ناقصة', '$underRate%'),
          _buildStatRow('🚩', 'البولات المكتملة', stats.gamesPlayed.toString().padLeft(2, '0')),
          _buildStatRow('🔄', 'الريمونتادا', stats.majorComebacks.toString().padLeft(2, '0')),
        ],
      ),
    );
  }

  Widget _buildStatRow(String icon, String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2.2),
      child: Row(
        children: [
          Text(icon, style: const TextStyle(fontSize: 11)),
          const SizedBox(width: 5),
          Text(
            label,
            style: GoogleFonts.cairo(
              fontSize: 9.5,
              fontWeight: FontWeight.w600,
              color: const Color(0xFFD1D5DB),
            ),
          ),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4),
              child: Text(
                '....................................................................',
                maxLines: 1,
                overflow: TextOverflow.clip,
                style: TextStyle(
                  fontSize: 7,
                  color: Colors.white.withValues(alpha: 0.15),
                ),
              ),
            ),
          ),
          Text(
            value,
            style: GoogleFonts.cairo(
              fontSize: 10.5,
              fontWeight: FontWeight.w900,
              color: goldLight,
            ),
          ),
        ],
      ),
    );
  }

  // ── Achievements Panel ─────────────────────────────────────────────────────

  Widget _buildAchievementsPanel() {
    final topAchievements = AchievementService.instance.getTopDisplayAchievements(stats, limit: 4);

    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.4),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: emeraldBorder, width: 1.2),
      ),
      child: Column(
        children: [
          _buildPanelHeader('الإنجازات'),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: topAchievements.map((a) {
              final isUnlocked = a.isUnlocked(stats);
              final tierLabel = isUnlocked ? a.tier.nameAr : '${(a.getProgress(stats) * 100).toInt()}%';
              return _buildAchievementShield(
                a.emoji,
                a.titleAr,
                tierLabel,
                isUnlocked: isUnlocked,
              );
            }).toList(),
          ),
        ],
      ),
    );
  }

  Widget _buildAchievementShield(String emoji, String title, String tier, {bool isUnlocked = true}) {
    return Column(
      children: [
        Container(
          width: 44,
          height: 48,
          decoration: BoxDecoration(
            color: isUnlocked ? emeraldMid : Colors.black.withValues(alpha: 0.6),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: isUnlocked ? gold : Colors.white24,
              width: 1.2,
            ),
            boxShadow: isUnlocked
                ? [BoxShadow(color: gold.withValues(alpha: 0.25), blurRadius: 4)]
                : null,
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                emoji,
                style: TextStyle(
                  fontSize: 14,
                  color: isUnlocked ? null : Colors.grey,
                ),
              ),
              Text(
                tier,
                style: GoogleFonts.cairo(
                  fontSize: 7.0,
                  fontWeight: FontWeight.w900,
                  color: isUnlocked ? gold : Colors.white38,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 3),
        FittedBox(
          fit: BoxFit.scaleDown,
          child: Text(
            title,
            style: GoogleFonts.cairo(
              fontSize: 7.0,
              fontWeight: FontWeight.bold,
              color: isUnlocked ? Colors.white70 : Colors.white38,
            ),
          ),
        ),
      ],
    );
  }

  // ── Favorite Mode Panel ────────────────────────────────────────────────────

  Widget _buildFavoriteModePanel() {
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.4),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: emeraldBorder, width: 1.2),
      ),
      child: Column(
        children: [
          _buildPanelHeader('النمط المفضل'),
          const SizedBox(height: 10),
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: emeraldMid,
                  shape: BoxShape.circle,
                  border: Border.all(color: gold, width: 1.2),
                ),
                child: const Text('🎴', style: TextStyle(fontSize: 20)),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'بولة كاملة 18 جولة',
                      style: GoogleFonts.cairo(
                        fontSize: 10.5,
                        fontWeight: FontWeight.w900,
                        color: Colors.white,
                      ),
                    ),
                    Text(
                      '85% من المباريات',
                      style: GoogleFonts.cairo(
                        fontSize: 8.5,
                        fontWeight: FontWeight.bold,
                        color: const Color(0xFF34D399),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ── Panel Header Pill ──────────────────────────────────────────────────────

  Widget _buildPanelHeader(String title) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 3),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF1B4D3A), Color(0xFF0F3024), Color(0xFF1B4D3A)],
        ),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: gold.withValues(alpha: 0.6), width: 0.9),
      ),
      child: Text(
        title,
        style: GoogleFonts.cairo(
          fontSize: 9.0,
          fontWeight: FontWeight.w900,
          color: goldLight,
          letterSpacing: 1.0,
        ),
      ),
    );
  }

  // ── Footer Section ─────────────────────────────────────────────────────────

  Widget _buildFooterSection() {
    return Column(
      children: [
        // Ribbon Banner
        Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(vertical: 4),
          decoration: BoxDecoration(
            color: gold.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: gold.withValues(alpha: 0.4), width: 1),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Text('👑', style: TextStyle(fontSize: 10)),
              const SizedBox(width: 6),
              Text(
                'فخور بأنني لاعب إستميشن!',
                style: GoogleFonts.cairo(
                  fontSize: 10.0,
                  fontWeight: FontWeight.w900,
                  color: goldLight,
                  letterSpacing: 0.8,
                ),
              ),
              const SizedBox(width: 6),
              const Text('👑', style: TextStyle(fontSize: 10)),
            ],
          ),
        ),
        const SizedBox(height: 6),

        // Suit symbols
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Text('♠', style: TextStyle(fontSize: 13, color: gold)),
            const SizedBox(width: 8),
            const Text('♥', style: TextStyle(fontSize: 13, color: Color(0xFFEF4444))),
            const SizedBox(width: 8),
            const Text('♦', style: TextStyle(fontSize: 13, color: Color(0xFFEF4444))),
            const SizedBox(width: 8),
            const Text('♣', style: TextStyle(fontSize: 13, color: gold)),
          ],
        ),
        const SizedBox(height: 3),

        Text(
          'يلا نلعب سوا!  #كوتشينة_إستميشن',
          style: GoogleFonts.cairo(
            fontSize: 9.0,
            fontWeight: FontWeight.bold,
            color: Colors.white70,
            letterSpacing: 0.5,
          ),
        ),
      ],
    );
  }
}

// ── Custom Radar Chart Painter ───────────────────────────────────────────────

class _RadarChartPainter extends CustomPainter {
  final List<double> values;
  final List<String> labels;

  _RadarChartPainter({required this.values, required this.labels});

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = math.min(size.width, size.height) * 0.36;

    final gridPaint = Paint()
      ..color = const Color(0xFF1B4D3A)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.0;

    final axisPaint = Paint()
      ..color = const Color(0xFF1B4D3A).withValues(alpha: 0.7)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.0;

    const numSides = 5;
    const angleStep = (math.pi * 2) / numSides;
    const startAngle = -math.pi / 2; // Point top

    // 1. Draw concentric pentagon grids (0.2, 0.4, 0.6, 0.8, 1.0)
    for (int ring = 1; ring <= 4; ring++) {
      final r = radius * (ring / 4.0);
      final path = Path();
      for (int i = 0; i < numSides; i++) {
        final angle = startAngle + i * angleStep;
        final x = center.dx + r * math.cos(angle);
        final y = center.dy + r * math.sin(angle);
        if (i == 0) {
          path.moveTo(x, y);
        } else {
          path.lineTo(x, y);
        }
      }
      path.close();
      canvas.drawPath(path, gridPaint);
    }

    // 2. Draw axis lines from center to vertices
    for (int i = 0; i < numSides; i++) {
      final angle = startAngle + i * angleStep;
      final x = center.dx + radius * math.cos(angle);
      final y = center.dy + radius * math.sin(angle);
      canvas.drawLine(center, Offset(x, y), axisPaint);
    }

    // 3. Draw filled data polygon
    final dataPath = Path();
    final points = <Offset>[];

    for (int i = 0; i < numSides; i++) {
      final angle = startAngle + i * angleStep;
      final val = values[i].clamp(0.15, 1.0);
      final r = radius * val;
      final x = center.dx + r * math.cos(angle);
      final y = center.dy + r * math.sin(angle);
      points.add(Offset(x, y));

      if (i == 0) {
        dataPath.moveTo(x, y);
      } else {
        dataPath.lineTo(x, y);
      }
    }
    dataPath.close();

    final fillPaint = Paint()
      ..color = const Color(0xFF10B981).withValues(alpha: 0.35)
      ..style = PaintingStyle.fill;
    canvas.drawPath(dataPath, fillPaint);

    final borderPaint = Paint()
      ..color = const Color(0xFF34D399)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.0;
    canvas.drawPath(dataPath, borderPaint);

    // 4. Draw vertex dots
    final dotPaint = Paint()
      ..color = const Color(0xFFF7E7A9)
      ..style = PaintingStyle.fill;
    for (final p in points) {
      canvas.drawCircle(p, 3.5, dotPaint);
    }

    // 5. Draw Labels around the pentagon
    final textPainter = TextPainter(textDirection: TextDirection.rtl);
    for (int i = 0; i < numSides; i++) {
      final angle = startAngle + i * angleStep;
      final labelRadius = radius + 22;
      final x = center.dx + labelRadius * math.cos(angle);
      final y = center.dy + labelRadius * math.sin(angle);

      textPainter.text = TextSpan(
        text: labels[i],
        style: GoogleFonts.cairo(
          fontSize: 7.5,
          fontWeight: FontWeight.bold,
          color: const Color(0xFFD1D5DB),
          height: 1.1,
        ),
      );
      textPainter.layout();
      textPainter.paint(canvas, Offset(x - textPainter.width / 2, y - textPainter.height / 2));
    }
  }

  @override
  bool shouldRepaint(covariant _RadarChartPainter oldDelegate) => true;
}

// ── Poster Background Watermark Painter ──────────────────────────────────────

class _PosterBackgroundWatermarkPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.white.withValues(alpha: 0.02)
      ..style = PaintingStyle.fill;

    // Corner decorative flourishes
    canvas.drawCircle(const Offset(30, 30), 20, paint);
    canvas.drawCircle(Offset(size.width - 30, 30), 20, paint);
    canvas.drawCircle(Offset(30, size.height - 30), 20, paint);
    canvas.drawCircle(Offset(size.width - 30, size.height - 30), 20, paint);
  }

  @override
  bool shouldRepaint(covariant _PosterBackgroundWatermarkPainter oldDelegate) => false;
}
