// lib/widgets/player_identity_card.dart

import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../services/share_card_service.dart';
import '../models/playstyle_models.dart';
import '../models/estimation_statistics.dart';
import '../models/rank_tier.dart';
import '../services/auth_service.dart';
import '../theme/app_theme.dart';
import '../core/constants.dart';
import '../core/widgets/player_avatar.dart';
import '../core/widgets/app_buttons.dart';
import '../core/utils/snackbar_helper.dart';
import 'estimation_poster_card.dart';
import 'package:estimation/core/icons/app_icons.dart';

class PlayerIdentityCard extends StatefulWidget {
  final String playerName;
  final String avatarUrl;
  final EstimationStatistics stats;
  final PlayerPersonalityProfile profile;
  final PlayerIdentityCardConfig config;
  final ValueChanged<PlayerIdentityCardConfig>? onConfigChanged;
  final VoidCallback? onShareRequested;

  const PlayerIdentityCard({
    super.key,
    required this.playerName,
    required this.avatarUrl,
    required this.stats,
    required this.profile,
    required this.config,
    this.onConfigChanged,
    this.onShareRequested,
  });

  @override
  State<PlayerIdentityCard> createState() => _PlayerIdentityCardState();
}

class _PlayerIdentityCardState extends State<PlayerIdentityCard>
    with SingleTickerProviderStateMixin {
  static const double _cardFaceHeight = 400;

  final GlobalKey _cardBoundaryKey = GlobalKey();
  final GlobalKey _posterBoundaryKey = GlobalKey();
  late AnimationController _flipController;
  late Animation<double> _flipAnimation;
  bool _isBack = false;
  bool _isSharing = false;

  @override
  void initState() {
    super.initState();
    _flipController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 560),
    );
    _flipAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _flipController, curve: Curves.easeInOutCubic),
    );
  }

  @override
  void dispose() {
    _flipController.dispose();
    super.dispose();
  }

  void _flipCard() {
    HapticFeedback.mediumImpact();
    if (_isBack) {
      _flipController.reverse();
      setState(() => _isBack = false);
    } else {
      _flipController.forward();
      setState(() => _isBack = true);
    }
  }

  Future<void> _shareCard() async {
    if (_isSharing) return;
    setState(() => _isSharing = true);
    HapticFeedback.mediumImpact();

    final level = AuthService.instance.currentProfile?.level ?? 1;

    try {
      final success = await ShareCardService.instance.shareIdentityCard(
        boundaryKey: _posterBoundaryKey,
        playerName: widget.playerName,
        profile: widget.profile,
        config: widget.config,
        stats: widget.stats,
        level: level,
      );

      if (success && mounted) {
        SnackbarHelper.showSuccess(
          context,
          'تم تجهيز بوستر بطاقة إستميشن ومشاركتها!',
          title: 'مشاركة البوستر ♠️',
        );
      } else if (!success && mounted) {
        SnackbarHelper.showError(
          context,
          'يلزم إعادة تشغيل التطبيق (Stop ثم flutter run) لتفعيل نافذة مشاركة الصور لأول مرة.',
          title: 'تنبيه إعادة التشغيل',
        );
      }
    } catch (e) {
      debugPrint('[PlayerIdentityCard] Share error: $e');
    } finally {
      if (mounted) {
        setState(() => _isSharing = false);
      }
    }
  }

  void _openCustomizerSheet() {
    HapticFeedback.selectionClick();

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (ctx) => _IdentityCardCustomizerSheet(
        config: widget.config,
        onChanged: (newConfig) {
          widget.onConfigChanged?.call(newConfig);
        },
      ),
    );
  }

  Widget _actionChip({
    required AppIconData icon,
    required String label,
    required VoidCallback? onTap,
    bool emphasized = false,
    bool loading = false,
  }) {
    final theme = widget.config.theme;
    return AppIconChip(
      icon: icon,
      label: label,
      onTap: onTap,
      color: theme.borderColor,
      emphasized: emphasized,
      loading: loading,
    );
  }

  @override
  Widget build(BuildContext context) {
    final auth = AuthService.instance;
    final level = auth.currentProfile?.level ?? 1;

    return Stack(
      clipBehavior: Clip.none,
      children: [
        Positioned(
          left: -99999,
          top: 0,
          child: RepaintBoundary(
            key: _posterBoundaryKey,
            child: EstimationPosterCard(
              playerName: widget.playerName,
              avatarUrl: widget.avatarUrl,
              stats: widget.stats,
              profile: widget.profile,
              config: widget.config,
              level: level,
              currentXp: auth.currentProfile?.xp ?? 1450,
              nextLevelTargetXp: auth.currentProfile?.nextLevelTargetXp ?? 2000,
            ),
          ),
        ),
        Column(
          children: [
            // Compact action bar
            Row(
              children: [
                Expanded(
                  child: _actionChip(
                    icon: AppIcons.flip,
                    label: _isBack ? 'الوجه الأمامي' : 'التحليل التكتيكي',
                    onTap: _flipCard,
                    emphasized: true,
                  ),
                ),
                const SizedBox(width: 8),
                _actionChip(
                  icon: AppIcons.palette,
                  label: 'تخصيص',
                  onTap: _openCustomizerSheet,
                ),
                const SizedBox(width: 8),
                _actionChip(
                  icon: AppIcons.iosShare,
                  label: 'مشاركة',
                  onTap: _isSharing ? null : _shareCard,
                  loading: _isSharing,
                ),
              ],
            ),
            const SizedBox(height: 14),
            RepaintBoundary(
              key: _cardBoundaryKey,
              child: GestureDetector(
                onTap: _flipCard,
                child: AnimatedBuilder(
                  animation: _flipAnimation,
                  builder: (context, child) {
                    final angle = _flipAnimation.value * pi;
                    final isUnder = angle > pi / 2;

                    return SizedBox(
                      height: _cardFaceHeight,
                      width: double.infinity,
                      child: Transform(
                        transform: Matrix4.identity()
                          ..setEntry(3, 2, 0.001)
                          ..rotateY(angle),
                        alignment: Alignment.center,
                        child: isUnder
                            ? Transform(
                                transform: Matrix4.identity()..rotateY(pi),
                                alignment: Alignment.center,
                                child: _buildBackFace(),
                              )
                            : _buildFrontFace(),
                      ),
                    );
                  },
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  // ── FRONT FACE ─────────────────────────────────────────────────────────────

  Widget _buildFrontFace() {
    final theme = widget.config.theme;
    final level = AuthService.instance.currentProfile?.level ?? 1;
    final tier = RankTier.fromLevel(level);
    final archetype = widget.profile.primaryArchetype;
    final name =
        widget.playerName.isNotEmpty ? widget.playerName : kDefaultPlayerName;

    return SizedBox(
      height: _cardFaceHeight,
      width: double.infinity,
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(28),
          gradient: LinearGradient(
            colors: [
              theme.gradientColors.first,
              theme.gradientColors.length > 1
                  ? theme.gradientColors[1]
                  : theme.gradientColors.first,
              theme.gradientColors.last,
            ],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          border: Border.all(
            color: theme.borderColor.withValues(alpha: 0.45),
            width: 1.4,
          ),
          boxShadow: [
            BoxShadow(
              color: theme.accentGlow.withValues(alpha: 0.22),
              blurRadius: 28,
              offset: const Offset(0, 12),
            ),
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.35),
              blurRadius: 18,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(26.5),
          child: Stack(
            children: [
              // Soft ambient orbs
              Positioned(
                top: -60,
                right: -40,
                child: Container(
                  width: 160,
                  height: 160,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: RadialGradient(
                      colors: [
                        theme.accentGlow.withValues(alpha: 0.22),
                        Colors.transparent,
                      ],
                    ),
                  ),
                ),
              ),
              Positioned(
                bottom: -50,
                left: -30,
                child: Container(
                  width: 140,
                  height: 140,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: RadialGradient(
                      colors: [
                        theme.borderColor.withValues(alpha: 0.10),
                        Colors.transparent,
                      ],
                    ),
                  ),
                ),
              ),
              // Suit watermark
              Positioned(
                right: 12,
                top: 8,
                child: Text(
                  '♠',
                  style: TextStyle(
                    fontSize: 92,
                    height: 1,
                    color: Colors.white.withValues(alpha: 0.04),
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),

              Padding(
                padding: const EdgeInsets.fromLTRB(18, 18, 18, 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Top meta row
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 5,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.black.withValues(alpha: 0.28),
                            borderRadius: BorderRadius.circular(99),
                            border: Border.all(
                              color: theme.borderColor.withValues(alpha: 0.35),
                            ),
                          ),
                          child: Text(
                            '♠️ بطاقة اللاعب',
                            style: AppFonts.cooper(
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                              color: theme.borderColor,
                            ),
                          ),
                        ),
                        const Spacer(),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 5,
                          ),
                          decoration: BoxDecoration(
                            color: tier.primaryColor.withValues(alpha: 0.16),
                            borderRadius: BorderRadius.circular(99),
                            border: Border.all(
                              color: tier.primaryColor.withValues(alpha: 0.55),
                            ),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(tier.badgeEmoji,
                                  style: const TextStyle(fontSize: 12)),
                              const SizedBox(width: 5),
                              Text(
                                'Lv $level',
                                style: AppFonts.cooper(
                                  fontSize: 11.5,
                                  fontWeight: FontWeight.w800,
                                  color: Colors.white,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 20),

                    // Hero identity
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        Container(
                          padding: const EdgeInsets.all(3),
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            gradient: LinearGradient(
                              colors: [
                                theme.borderColor,
                                theme.accentGlow.withValues(alpha: 0.7),
                              ],
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: theme.accentGlow.withValues(alpha: 0.35),
                                blurRadius: 16,
                              ),
                            ],
                          ),
                          child: Container(
                            padding: const EdgeInsets.all(2),
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: theme.gradientColors.first,
                            ),
                            child: PlayerAvatar(
                              photoData: widget.avatarUrl,
                              size: 72,
                            ),
                          ),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                name,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: AppFonts.cooper(
                                  fontSize: 21,
                                  fontWeight: FontWeight.w900,
                                  color: Colors.white,
                                  height: 1.15,
                                ),
                              ),
                              const SizedBox(height: 3),
                              Text(
                                widget.config.selectedTitle,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: AppFonts.cooper(
                                  fontSize: 12.5,
                                  fontWeight: FontWeight.w600,
                                  color:
                                      theme.borderColor.withValues(alpha: 0.95),
                                ),
                              ),
                              const SizedBox(height: 8),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 10,
                                  vertical: 4,
                                ),
                                decoration: BoxDecoration(
                                  color: archetype.primaryColor
                                      .withValues(alpha: 0.16),
                                  borderRadius: BorderRadius.circular(99),
                                  border: Border.all(
                                    color: archetype.primaryColor
                                        .withValues(alpha: 0.45),
                                  ),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Text(
                                      archetype.emoji,
                                      style: const TextStyle(fontSize: 12),
                                    ),
                                    const SizedBox(width: 5),
                                    Text(
                                      archetype.titleAr,
                                      style: AppFonts.cooper(
                                        fontSize: 11.5,
                                        fontWeight: FontWeight.w700,
                                        color: Colors.white,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),

                    const Spacer(),

                    // Stats grid 2×2
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: Colors.black.withValues(alpha: 0.28),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                          color: Colors.white.withValues(alpha: 0.07),
                        ),
                      ),
                      child: Column(
                        children: [
                          Row(
                            children: [
                              Expanded(
                                child: _buildShowcaseStatItem(
                                  title: 'دقة الكول',
                                  value:
                                      '${widget.stats.declarationAccuracy.toStringAsFixed(0)}%',
                                  icon: AppIcons.trackChanges,
                                  color: const Color(0xFF38BDF8),
                                ),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: _buildShowcaseStatItem(
                                  title: 'الانتصارات',
                                  value: '${widget.stats.gamesWon}',
                                  icon: AppIcons.emojiEvents,
                                  color: AppTheme.gold,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Row(
                            children: [
                              Expanded(
                                child: _buildShowcaseStatItem(
                                  title: 'كول مثالي',
                                  value: '${widget.stats.perfectEstimates}',
                                  icon: AppIcons.autoAwesome,
                                  color: const Color(0xFF10B981),
                                ),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: _buildShowcaseStatItem(
                                  title: 'أطول سلسلة',
                                  value: '${widget.stats.longestWinningStreak}',
                                  icon: AppIcons.localFireDepartment,
                                  color: const Color(0xFFFF7043),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 12),

                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        AppIcon(
                          AppIcons.swipe,
                          size: 13,
                          color: Colors.white.withValues(alpha: 0.4),
                        ),
                        const SizedBox(width: 5),
                        Text(
                          'اضغط لقلب البطاقة',
                          style: AppFonts.cooper(
                            fontSize: 10.5,
                            color: Colors.white.withValues(alpha: 0.45),
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ── BACK FACE ──────────────────────────────────────────────────────────────

  Widget _buildBackFace() {
    final theme = widget.config.theme;
    final profile = widget.profile;
    final archetype = profile.primaryArchetype;
    final secondary = profile.secondaryArchetype;
    final metrics = profile.metrics;
    final accent = archetype.primaryColor;

    final metricBars = <({String label, double value, Color color})>[
      (
        label: 'الدقة',
        value: metrics.precision,
        color: const Color(0xFF38BDF8)
      ),
      (
        label: 'الهجوم',
        value: metrics.aggression,
        color: const Color(0xFFF87171)
      ),
      (
        label: 'الانضباط',
        value: metrics.bidDiscipline,
        color: const Color(0xFF34D399)
      ),
    ];

    final tip = profile.recommendation.isNotEmpty
        ? profile.recommendation
        : archetype.descriptionAr;

    return SizedBox(
      height: _cardFaceHeight,
      width: double.infinity,
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(28),
          color: const Color(0xFF0C1520),
          border: Border.all(color: accent.withValues(alpha: 0.5), width: 1.5),
          boxShadow: [
            BoxShadow(
              color: accent.withValues(alpha: 0.28),
              blurRadius: 28,
              offset: const Offset(0, 12),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(26.5),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 9, vertical: 4),
                      decoration: BoxDecoration(
                        color: accent.withValues(alpha: 0.16),
                        borderRadius: BorderRadius.circular(99),
                        border:
                            Border.all(color: accent.withValues(alpha: 0.4)),
                      ),
                      child: Text(
                        'تحليل تكتيكي',
                        style: AppFonts.cooper(
                          fontSize: 10.5,
                          fontWeight: FontWeight.w800,
                          color: accent,
                        ),
                      ),
                    ),
                    const Spacer(),
                    Text(
                      '${metrics.confidenceLabelAr} · ${metrics.profileConfidence.toStringAsFixed(0)}%',
                      style: AppFonts.cooper(
                        fontSize: 10.5,
                        fontWeight: FontWeight.w700,
                        color: Colors.white60,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Container(
                      width: 48,
                      height: 48,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: accent.withValues(alpha: 0.16),
                        borderRadius: BorderRadius.circular(16),
                        border:
                            Border.all(color: accent.withValues(alpha: 0.4)),
                      ),
                      child: Text(archetype.emoji,
                          style: const TextStyle(fontSize: 24)),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            archetype.titleAr,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: AppFonts.cooper(
                              fontSize: 17,
                              fontWeight: FontWeight.w900,
                              color: Colors.white,
                              height: 1.15,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            archetype.taglineAr,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: AppFonts.cooper(
                              fontSize: 11,
                              color: Colors.white60,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 5),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.06),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                            color: theme.borderColor.withValues(alpha: 0.35)),
                      ),
                      child: Text(
                        '${secondary.emoji} ${secondary.titleAr}',
                        style: AppFonts.cooper(
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                          color: Colors.white70,
                        ),
                      ),
                    ),
                  ],
                ),
                if (profile.signatureBehavior.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.04),
                      borderRadius: BorderRadius.circular(12),
                      border:
                          Border(right: BorderSide(color: accent, width: 3)),
                    ),
                    child: Text(
                      '«${profile.signatureBehavior}»',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppFonts.cooper(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        fontStyle: FontStyle.italic,
                        color: Colors.white.withValues(alpha: 0.88),
                      ),
                    ),
                  ),
                ],
                const SizedBox(height: 12),
                ...metricBars.map(
                  (m) => Padding(
                    padding: const EdgeInsets.only(bottom: 6),
                    child: _metricBar(
                        label: m.label, value: m.value, color: m.color),
                  ),
                ),
                if (profile.strengths.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    children: profile.strengths.take(3).map((s) {
                      return Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 9, vertical: 4),
                        decoration: BoxDecoration(
                          color: accent.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(99),
                          border:
                              Border.all(color: accent.withValues(alpha: 0.28)),
                        ),
                        child: Text(
                          s,
                          style: AppFonts.cooper(
                            fontSize: 10,
                            fontWeight: FontWeight.w700,
                            color: Colors.white.withValues(alpha: 0.9),
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                ],
                const Spacer(),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                  decoration: BoxDecoration(
                    color: AppTheme.gold.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                        color: AppTheme.gold.withValues(alpha: 0.25)),
                  ),
                  child: Row(
                    children: [
                      const AppIcon(AppIcons.lightbulb,
                          size: 14, color: AppTheme.goldLight),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          tip,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: AppFonts.cooper(
                            fontSize: 11,
                            height: 1.3,
                            color: Colors.white.withValues(alpha: 0.85),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 8),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    AppIcon(AppIcons.flip,
                        size: 12, color: Colors.white.withValues(alpha: 0.35)),
                    const SizedBox(width: 5),
                    Text(
                      'اضغط للعودة',
                      style: AppFonts.cooper(
                        fontSize: 10,
                        color: Colors.white.withValues(alpha: 0.4),
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _metricBar({
    required String label,
    required double value,
    required Color color,
  }) {
    final clamped = (value / 100.0).clamp(0.0, 1.0);
    return Row(
      children: [
        SizedBox(
          width: 54,
          child: Text(
            label,
            style: AppFonts.cooper(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              color: Colors.white70,
            ),
          ),
        ),
        Expanded(
          child: ClipRRect(
            borderRadius: BorderRadius.circular(99),
            child: SizedBox(
              height: 6,
              child: Stack(
                children: [
                  Container(color: Colors.white.withValues(alpha: 0.08)),
                  FractionallySizedBox(
                    widthFactor: clamped,
                    child: Container(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [color.withValues(alpha: 0.7), color],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
        const SizedBox(width: 8),
        SizedBox(
          width: 26,
          child: Text(
            value.toStringAsFixed(0),
            textAlign: TextAlign.end,
            style: AppFonts.cooper(
              fontSize: 11,
              fontWeight: FontWeight.w800,
              color: color,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildShowcaseStatItem({
    required String title,
    required String value,
    required AppIconData icon,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.04),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        children: [
          Container(
            width: 30,
            height: 30,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.16),
              borderRadius: BorderRadius.circular(10),
            ),
            child: AppIcon(icon, size: 15, color: color),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  value,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppFonts.cooper(
                    fontSize: 15,
                    fontWeight: FontWeight.w900,
                    color: Colors.white,
                    height: 1.1,
                  ),
                ),
                Text(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppFonts.cooper(
                    fontSize: 10,
                    fontWeight: FontWeight.w600,
                    color: Colors.white60,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ── CUSTOMIZER MODAL SHEET ───────────────────────────────────────────────────

class _IdentityCardCustomizerSheet extends StatefulWidget {
  final PlayerIdentityCardConfig config;
  final ValueChanged<PlayerIdentityCardConfig> onChanged;

  const _IdentityCardCustomizerSheet({
    required this.config,
    required this.onChanged,
  });

  @override
  State<_IdentityCardCustomizerSheet> createState() =>
      _IdentityCardCustomizerSheetState();
}

class _IdentityCardCustomizerSheetState
    extends State<_IdentityCardCustomizerSheet> {
  late CardSkinTheme _selectedTheme;
  late String _selectedTitle;
  late bool _isPublic;

  @override
  void initState() {
    super.initState();
    _selectedTheme = widget.config.theme;
    _selectedTitle = widget.config.selectedTitle;
    _isPublic = widget.config.isPublic;
  }

  void _applyChange() {
    final updated = widget.config.copyWith(
      theme: _selectedTheme,
      selectedTitle: _selectedTitle,
      isPublic: _isPublic,
    );
    widget.onChanged(updated);
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: AppTheme.navyDark,
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
        border: Border(top: BorderSide(color: AppTheme.gold, width: 1.2)),
      ),
      padding: EdgeInsets.only(
        left: 20,
        right: 20,
        top: 12,
        bottom: MediaQuery.of(context).viewInsets.bottom + 24,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Center(
            child: Container(
              width: 40,
              height: 4,
              margin: const EdgeInsets.only(bottom: 14),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(99),
              ),
            ),
          ),
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'تخصيص البطاقة',
                      style: AppFonts.cooper(
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                        color: AppTheme.cream,
                      ),
                    ),
                    Text(
                      'المظهر واللقب والخصوصية',
                      style: AppFonts.cooper(
                        fontSize: 12,
                        color: AppTheme.steelBlue,
                      ),
                    ),
                  ],
                ),
              ),
              Material(
                color: Colors.transparent,
                child: InkWell(
                  onTap: () => Navigator.pop(context),
                  borderRadius: BorderRadius.circular(12),
                  child: Ink(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.06),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const AppIcon(
                      AppIcons.close,
                      color: Colors.white70,
                      size: 20,
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          Text(
            'مظهر البطاقة',
            style: AppFonts.cooper(
              fontSize: 13,
              fontWeight: FontWeight.w800,
              color: AppTheme.goldLight,
            ),
          ),
          const SizedBox(height: 10),
          SizedBox(
            height: 52,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: CardSkinTheme.values.length,
              separatorBuilder: (_, __) => const SizedBox(width: 8),
              itemBuilder: (context, index) {
                final theme = CardSkinTheme.values[index];
                final isSelected = _selectedTheme == theme;

                return Material(
                  color: Colors.transparent,
                  child: InkWell(
                    onTap: () {
                      HapticFeedback.selectionClick();
                      setState(() => _selectedTheme = theme);
                      _applyChange();
                    },
                    borderRadius: BorderRadius.circular(16),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      padding: const EdgeInsets.symmetric(horizontal: 14),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(colors: theme.gradientColors),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: isSelected
                              ? theme.borderColor
                              : Colors.white.withValues(alpha: 0.12),
                          width: isSelected ? 1.8 : 1.0,
                        ),
                        boxShadow: isSelected
                            ? [
                                BoxShadow(
                                  color:
                                      theme.accentGlow.withValues(alpha: 0.4),
                                  blurRadius: 10,
                                ),
                              ]
                            : null,
                      ),
                      alignment: Alignment.center,
                      child: Text(
                        theme.titleAr,
                        style: AppFonts.cooper(
                          fontSize: 12,
                          fontWeight: FontWeight.w800,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
          const SizedBox(height: 20),
          Text(
            'اللقب على البطاقة',
            style: AppFonts.cooper(
              fontSize: 13,
              fontWeight: FontWeight.w800,
              color: AppTheme.goldLight,
            ),
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: PlayerIdentityCardConfig.availableTitles.map((title) {
              final isSelected = _selectedTitle == title;
              return Material(
                color: Colors.transparent,
                child: InkWell(
                  onTap: () {
                    HapticFeedback.selectionClick();
                    setState(() => _selectedTitle = title);
                    _applyChange();
                  },
                  borderRadius: BorderRadius.circular(99),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 180),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 8,
                    ),
                    decoration: BoxDecoration(
                      color: isSelected
                          ? AppTheme.gold.withValues(alpha: 0.16)
                          : Colors.white.withValues(alpha: 0.05),
                      borderRadius: BorderRadius.circular(99),
                      border: Border.all(
                        color: isSelected
                            ? AppTheme.gold.withValues(alpha: 0.5)
                            : Colors.white.withValues(alpha: 0.08),
                      ),
                    ),
                    child: Text(
                      title,
                      style: AppFonts.cooper(
                        fontSize: 11.5,
                        fontWeight:
                            isSelected ? FontWeight.w800 : FontWeight.w600,
                        color: isSelected ? AppTheme.goldLight : Colors.white70,
                      ),
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
          const SizedBox(height: 20),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.04),
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
            ),
            child: Row(
              children: [
                Container(
                  width: 38,
                  height: 38,
                  decoration: BoxDecoration(
                    color: (_isPublic ? const Color(0xFF10B981) : Colors.white)
                        .withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: AppIcon(
                    _isPublic ? AppIcons.public : AppIcons.lock,
                    color: _isPublic ? const Color(0xFF10B981) : Colors.white60,
                    size: 18,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'إتاحة البطاقة للعامة',
                        style: AppFonts.cooper(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          color: Colors.white,
                        ),
                      ),
                      Text(
                        _isPublic
                            ? 'يمكن للاعبين رؤية بطاقتك وشخصيتك'
                            : 'بطاقتك خاصة ومخفية عن الآخرين',
                        style: AppFonts.cooper(
                          fontSize: 11,
                          color: Colors.white54,
                        ),
                      ),
                    ],
                  ),
                ),
                Switch(
                  value: _isPublic,
                  onChanged: (val) {
                    setState(() => _isPublic = val);
                    _applyChange();
                  },
                  activeThumbColor: AppTheme.gold,
                  activeTrackColor: AppTheme.gold.withValues(alpha: 0.4),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
