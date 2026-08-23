// lib/widgets/share_my_estimation_dialog.dart

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';

import '../models/playstyle_models.dart';
import '../models/estimation_statistics.dart';
import '../models/rank_tier.dart';
import '../services/auth_service.dart';
import '../services/audio_service.dart';
import '../services/share_card_service.dart';
import '../theme/app_theme.dart';
import '../core/widgets/player_avatar.dart';
import '../core/utils/snackbar_helper.dart';

enum ShareCardType {
  identityProfile,
  matchVictory,
}

class ShareMyEstimationDialog extends StatefulWidget {
  final ShareCardType type;
  final String playerName;
  final String avatarUrl;
  final PlayerPersonalityProfile? profile;
  final PlayerIdentityCardConfig? config;
  final EstimationStatistics? stats;

  // Match victory specific parameters
  final int? matchFinalScore;
  final int? matchPerfectEstimates;
  final int? matchComebacks;
  final int? matchBestRound;
  final String? matchRankTitle;

  const ShareMyEstimationDialog({
    super.key,
    this.type = ShareCardType.identityProfile,
    required this.playerName,
    required this.avatarUrl,
    this.profile,
    this.config,
    this.stats,
    this.matchFinalScore,
    this.matchPerfectEstimates,
    this.matchComebacks,
    this.matchBestRound,
    this.matchRankTitle,
  });

  static Future<void> show(
    BuildContext context, {
    ShareCardType type = ShareCardType.identityProfile,
    required String playerName,
    required String avatarUrl,
    PlayerPersonalityProfile? profile,
    PlayerIdentityCardConfig? config,
    EstimationStatistics? stats,
    int? matchFinalScore,
    int? matchPerfectEstimates,
    int? matchComebacks,
    int? matchBestRound,
    String? matchRankTitle,
  }) {
    HapticFeedback.mediumImpact();
    AudioService.instance.playCard();

    return showDialog(
      context: context,
      barrierColor: Colors.black87,
      builder: (ctx) => ShareMyEstimationDialog(
        type: type,
        playerName: playerName,
        avatarUrl: avatarUrl,
        profile: profile,
        config: config,
        stats: stats,
        matchFinalScore: matchFinalScore,
        matchPerfectEstimates: matchPerfectEstimates,
        matchComebacks: matchComebacks,
        matchBestRound: matchBestRound,
        matchRankTitle: matchRankTitle,
      ),
    );
  }

  @override
  State<ShareMyEstimationDialog> createState() => _ShareMyEstimationDialogState();
}

class _ShareMyEstimationDialogState extends State<ShareMyEstimationDialog> {
  final GlobalKey _posterBoundaryKey = GlobalKey();
  bool _isSharing = false;

  Future<void> _sharePoster() async {
    if (_isSharing) return;
    setState(() => _isSharing = true);
    HapticFeedback.mediumImpact();
    AudioService.instance.playCard();

    try {
      if (widget.type == ShareCardType.matchVictory) {
        await ShareCardService.instance.shareMatchVictory(
          playerName: widget.playerName,
          finalScore: widget.matchFinalScore ?? 0,
          perfectEstimates: widget.matchPerfectEstimates ?? 0,
          comebacks: widget.matchComebacks ?? 0,
          bestRoundDelta: widget.matchBestRound ?? 0,
          matchRankTitle: widget.matchRankTitle ?? 'الكينج 👑',
        );
      } else {
        final level = AuthService.instance.currentProfile?.level ?? 1;
        final profile = widget.profile ?? PlayerPersonalityProfile.initial();
        final config = widget.config ?? const PlayerIdentityCardConfig();
        final stats = widget.stats ?? const EstimationStatistics();

        await ShareCardService.instance.shareIdentityCard(
          boundaryKey: _posterBoundaryKey,
          playerName: widget.playerName,
          profile: profile,
          config: config,
          stats: stats,
          level: level,
        );
      }
    } catch (e) {
      debugPrint('[ShareMyEstimationDialog] Share error: $e');
    } finally {
      if (mounted) {
        setState(() => _isSharing = false);
      }
    }
  }

  void _copyCaptionText() {
    HapticFeedback.selectionClick();
    AudioService.instance.playCard();

    final displayName = widget.playerName.trim().isNotEmpty ? widget.playerName.trim() : 'لاعب كوتشينة';
    String textToCopy = '';

    if (widget.type == ShareCardType.matchVictory) {
      textToCopy =
          '🏆 انتصار جديد في إستميشن!\n👑 البطل: $displayName (${widget.matchRankTitle ?? "الكينج 👑"})\n🎯 السكور النهائي: ${widget.matchFinalScore ?? 0} نقطة\n🎯 كول مثالي: ${widget.matchPerfectEstimates ?? 0} جولات\n🔥 ريمونتادا: ${widget.matchComebacks ?? 0}\n#Estimation #كوتشينة';
    } else {
      final archetype = widget.profile?.primaryArchetype ?? PlaystyleArchetype.calculator;
      final accuracy = widget.stats?.declarationAccuracy.toStringAsFixed(1) ?? '0.0';
      final wins = widget.stats?.gamesWon ?? 0;
      final perfects = widget.stats?.perfectEstimates ?? 0;
      final streak = widget.stats?.longestWinningStreak ?? 0;

      textToCopy =
          '♠️ بطاقة لاعب إستميشن\n👑 اللاعب: $displayName\n📜 اللقب: ${widget.config?.selectedTitle ?? "أستاذ الإستميشن"}\n🧠 الشخصية: ${archetype.titleAr} ${archetype.emoji}\n🎯 دقة الكول: $accuracy%\n🏆 الانتصارات: $wins\n🎯 كول مثالي: $perfects\n🔥 أطول سلسلة: $streak\n#Estimation #كوتشينة';
    }

    Clipboard.setData(ClipboardData(text: textToCopy));
    SnackbarHelper.showSuccess(
      context,
      'تم نسخ ملخص الإنجاز إلى الحافظة!',
      title: 'تم النسخ',
    );
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 420),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // ── Top Dialog Header ─────────────────────────────────────────
              Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        Text(
                          widget.type == ShareCardType.matchVictory ? '🏆' : '📤',
                          style: const TextStyle(fontSize: 20),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          widget.type == ShareCardType.matchVictory
                              ? 'مشاركة بطاقة الانتصار'
                              : 'مشاركة بطاقة إستميشن',
                          style: GoogleFonts.cairo(
                            fontSize: 16,
                            fontWeight: FontWeight.w900,
                            color: AppTheme.cream,
                          ),
                        ),
                      ],
                    ),
                    IconButton(
                      onPressed: () => Navigator.pop(context),
                      icon: const Icon(Icons.close_rounded, color: Colors.white70),
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(),
                    ),
                  ],
                ),
              ),

              // ── Shareable Card Poster Boundary ────────────────────────────
              RepaintBoundary(
                key: _posterBoundaryKey,
                child: widget.type == ShareCardType.matchVictory
                    ? _buildVictorySharePoster()
                    : _buildIdentitySharePoster(),
              ),

              const SizedBox(height: 18),

              // ── Action Buttons Bar ────────────────────────────────────────
              Row(
                children: [
                  // Native Share Button
                  Expanded(
                    flex: 2,
                    child: ElevatedButton.icon(
                      onPressed: _isSharing ? null : _sharePoster,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppTheme.gold,
                        foregroundColor: AppTheme.navyDark,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                        elevation: 4,
                      ),
                      icon: _isSharing
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(
                                color: AppTheme.navyDark,
                                strokeWidth: 2,
                              ),
                            )
                          : const Icon(Icons.share_rounded, size: 18),
                      label: Text(
                        _isSharing ? 'جاري التجهيز...' : 'مشاركة بالخارج',
                        style: GoogleFonts.cairo(
                          fontSize: 13,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),

                  // Copy Summary Button
                  Expanded(
                    flex: 1,
                    child: OutlinedButton.icon(
                      onPressed: _copyCaptionText,
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.white,
                        side: const BorderSide(color: Colors.white24),
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                      ),
                      icon: const Icon(Icons.copy_rounded, size: 16, color: AppTheme.goldLight),
                      label: Text(
                        'نسخ',
                        style: GoogleFonts.cairo(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ── 1. Identity Profile Share Poster ───────────────────────────────────────

  Widget _buildIdentitySharePoster() {
    final theme = widget.config?.theme ?? CardSkinTheme.royalGold;
    final level = AuthService.instance.currentProfile?.level ?? 1;
    final tier = RankTier.fromLevel(level);
    final archetype = widget.profile?.primaryArchetype ?? PlaystyleArchetype.calculator;
    final accuracy = widget.stats?.declarationAccuracy.toStringAsFixed(1) ?? '0.0';
    final wins = widget.stats?.gamesWon ?? 0;
    final perfects = widget.stats?.perfectEstimates ?? 0;
    final streak = widget.stats?.longestWinningStreak ?? 0;

    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
        gradient: LinearGradient(
          colors: theme.gradientColors,
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        border: Border.all(
          color: theme.borderColor.withValues(alpha: 0.85),
          width: 2.0,
        ),
        boxShadow: [
          BoxShadow(
            color: theme.accentGlow.withValues(alpha: 0.35),
            blurRadius: 24,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(22),
        child: Stack(
          children: [
            // Background Watermark
            Positioned(
              right: -10,
              top: -10,
              child: Text(
                '♠',
                style: TextStyle(
                  fontSize: 150,
                  color: Colors.white.withValues(alpha: 0.04),
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),

            Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                children: [
                  // App Title Header
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'MY ESTIMATION • إستميشن',
                        style: GoogleFonts.cairo(
                          fontSize: 11,
                          fontWeight: FontWeight.w900,
                          color: theme.borderColor,
                          letterSpacing: 1.2,
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                        decoration: BoxDecoration(
                          color: tier.primaryColor.withValues(alpha: 0.2),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: tier.primaryColor),
                        ),
                        child: Text(
                          '${tier.badgeEmoji} مستوى $level',
                          style: GoogleFonts.cairo(
                            fontSize: 11,
                            fontWeight: FontWeight.w900,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 16),

                  // Avatar & Identity
                  Container(
                    padding: const EdgeInsets.all(3),
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(color: theme.borderColor, width: 2),
                      boxShadow: [
                        BoxShadow(
                          color: theme.accentGlow.withValues(alpha: 0.4),
                          blurRadius: 10,
                        ),
                      ],
                    ),
                    child: PlayerAvatar(
                      photoData: widget.avatarUrl,
                      size: 64,
                    ),
                  ),
                  const SizedBox(height: 10),

                  Text(
                    widget.playerName.isNotEmpty ? widget.playerName : 'لاعب كوتشينة',
                    style: GoogleFonts.cairo(
                      fontSize: 18,
                      fontWeight: FontWeight.w900,
                      color: Colors.white,
                    ),
                  ),
                  Text(
                    widget.config?.selectedTitle ?? 'أستاذ الإستميشن',
                    style: GoogleFonts.cairo(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: theme.borderColor,
                    ),
                  ),

                  const SizedBox(height: 6),

                  // Archetype Badge
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                    decoration: BoxDecoration(
                      color: archetype.primaryColor.withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: archetype.primaryColor),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(archetype.emoji, style: const TextStyle(fontSize: 13)),
                        const SizedBox(width: 6),
                        Text(
                          archetype.titleAr,
                          style: GoogleFonts.cairo(
                            fontSize: 11.5,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 16),

                  // Stats Grid
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: 0.35),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: Colors.white10),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceAround,
                      children: [
                        _buildPosterStat('دقة الكول', '$accuracy%', const Color(0xFF38BDF8)),
                        _buildPosterStat('الانتصارات', '$wins', AppTheme.gold),
                        _buildPosterStat('كول مثالي', '$perfects', const Color(0xFF10B981)),
                        _buildPosterStat('أطول سلسلة', '🔥 $streak', const Color(0xFFFF7043)),
                      ],
                    ),
                  ),

                  const SizedBox(height: 12),

                  Text(
                    'كوتشينة مالتيبلاير • لعبة الذكاء والتكتيك ♠️',
                    style: GoogleFonts.cairo(
                      fontSize: 10,
                      color: Colors.white54,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── 2. Match Victory Share Poster ──────────────────────────────────────────

  Widget _buildVictorySharePoster() {
    final finalScore = widget.matchFinalScore ?? 0;
    final perfects = widget.matchPerfectEstimates ?? 0;
    final comebacks = widget.matchComebacks ?? 0;
    final bestRound = widget.matchBestRound ?? 0;
    final rankTitle = widget.matchRankTitle ?? 'الكينج 👑';

    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
        gradient: const LinearGradient(
          colors: [
            Color(0xFF2E1065), // Royal deep violet
            Color(0xFF4C1D95), // Purple
            Color(0xFF1E1B4B), // Midnight navy
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        border: Border.all(
          color: AppTheme.gold,
          width: 2.0,
        ),
        boxShadow: [
          BoxShadow(
            color: AppTheme.gold.withValues(alpha: 0.35),
            blurRadius: 24,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(22),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            children: [
              // Header
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.emoji_events_rounded, color: AppTheme.gold, size: 24),
                  const SizedBox(width: 8),
                  Text(
                    'انتصار ساحق • ESTIMATION VICTORY',
                    style: GoogleFonts.cairo(
                      fontSize: 13,
                      fontWeight: FontWeight.w900,
                      color: AppTheme.gold,
                      letterSpacing: 1.1,
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 14),

              // Winner Info
              PlayerAvatar(
                photoData: widget.avatarUrl,
                size: 60,
              ),
              const SizedBox(height: 8),

              Text(
                widget.playerName.isNotEmpty ? widget.playerName : 'لاعب كوتشينة',
                style: GoogleFonts.cairo(
                  fontSize: 18,
                  fontWeight: FontWeight.w900,
                  color: Colors.white,
                ),
              ),
              Text(
                rankTitle,
                style: GoogleFonts.cairo(
                  fontSize: 13,
                  fontWeight: FontWeight.bold,
                  color: AppTheme.gold,
                ),
              ),

              const SizedBox(height: 14),

              // Final Score Hero Card
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.4),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: AppTheme.gold.withValues(alpha: 0.5)),
                ),
                child: Column(
                  children: [
                    Text(
                      'السكور النهائي',
                      style: GoogleFonts.cairo(
                        fontSize: 11,
                        color: Colors.white70,
                      ),
                    ),
                    Text(
                      '$finalScore نقطة',
                      style: GoogleFonts.cairo(
                        fontSize: 26,
                        fontWeight: FontWeight.w900,
                        color: AppTheme.gold,
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 14),

              // Match Highlights
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  _buildPosterStat('كول مثالي', '$perfects', const Color(0xFF10B981)),
                  _buildPosterStat('ريمونتادا', '$comebacks', const Color(0xFFFF5722)),
                  _buildPosterStat('أفضل جولة', bestRound > 0 ? '+$bestRound' : '$bestRound', const Color(0xFF38BDF8)),
                ],
              ),

              const SizedBox(height: 12),

              Text(
                'كوتشينة مالتيبلاير • بطل البولة ♠️',
                style: GoogleFonts.cairo(
                  fontSize: 10,
                  color: Colors.white54,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPosterStat(String label, String value, Color color) {
    return Column(
      children: [
        Text(
          value,
          style: GoogleFonts.cairo(
            fontSize: 14,
            fontWeight: FontWeight.w900,
            color: color,
          ),
        ),
        Text(
          label,
          style: GoogleFonts.cairo(
            fontSize: 10,
            color: Colors.white60,
          ),
        ),
      ],
    );
  }
}
