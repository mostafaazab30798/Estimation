// lib/widgets/player_identity_card.dart

import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';

import '../services/share_card_service.dart';
import '../models/playstyle_models.dart';
import '../models/estimation_statistics.dart';
import '../models/rank_tier.dart';
import '../services/auth_service.dart';
import '../services/audio_service.dart';
import '../theme/app_theme.dart';
import '../core/widgets/player_avatar.dart';
import '../core/utils/snackbar_helper.dart';
import 'estimation_poster_card.dart';

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
      duration: const Duration(milliseconds: 600),
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
    AudioService.instance.playCard();
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
    AudioService.instance.playCard();

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
    AudioService.instance.playCard();

    showModalBottomSheet(
      context: context,
      backgroundColor: AppTheme.navyDark,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => _IdentityCardCustomizerSheet(
        config: widget.config,
        onChanged: (newConfig) {
          widget.onConfigChanged?.call(newConfig);
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final auth = AuthService.instance;
    final level = auth.currentProfile?.level ?? 1;

    return Stack(
      clipBehavior: Clip.none,
      children: [
        // ── Hidden Offscreen Full Template Poster for Capture ──────────────
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

        // ── Visible Interactive Card ───────────────────────────────────────
        Column(
          children: [
            // Action Controls Toolbar
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 6),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  // Flip indicator
                  InkWell(
                    onTap: _flipCard,
                    borderRadius: BorderRadius.circular(10),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.08),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: Colors.white12),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.flip_camera_android_rounded, size: 14, color: AppTheme.gold),
                          const SizedBox(width: 6),
                          Text(
                            _isBack ? 'الوجه الأمامي للبطاقة' : 'التحليل والشخصية (الخلف)',
                            style: GoogleFonts.cairo(
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                              color: AppTheme.cream,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),

                  // Customize & Share buttons
                  Row(
                    children: [
                      IconButton(
                        onPressed: _openCustomizerSheet,
                        icon: const Icon(Icons.palette_rounded, color: AppTheme.gold, size: 20),
                        tooltip: 'تخصيص مظهر البطاقة واللقب',
                        style: IconButton.styleFrom(
                          backgroundColor: Colors.white.withValues(alpha: 0.08),
                          padding: const EdgeInsets.all(8),
                        ),
                      ),
                      const SizedBox(width: 8),
                      IconButton(
                        onPressed: _isSharing ? null : _shareCard,
                        icon: _isSharing
                            ? const SizedBox(
                                width: 16,
                                height: 16,
                                child: CircularProgressIndicator(color: AppTheme.gold, strokeWidth: 2),
                              )
                            : const Icon(Icons.share_rounded, color: Colors.white, size: 20),
                        tooltip: 'مشاركة البوستر بالخارج',
                        style: IconButton.styleFrom(
                          backgroundColor: Colors.white.withValues(alpha: 0.08),
                          padding: const EdgeInsets.all(8),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),

            const SizedBox(height: 8),

            // Flippable 3D Card
            RepaintBoundary(
              key: _cardBoundaryKey,
              child: GestureDetector(
                onTap: _flipCard,
                child: AnimatedBuilder(
                  animation: _flipAnimation,
                  builder: (context, child) {
                    final angle = _flipAnimation.value * pi;
                    final isUnder = angle > pi / 2;

                    return Transform(
                      transform: Matrix4.identity()
                        ..setEntry(3, 2, 0.001) // 3D perspective
                        ..rotateY(angle),
                      alignment: Alignment.center,
                      child: isUnder
                          ? Transform(
                              transform: Matrix4.identity()..rotateY(pi),
                              alignment: Alignment.center,
                              child: _buildBackFace(),
                            )
                          : _buildFrontFace(),
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

  // ── FRONT FACE: Identity, Rank, Archetype & Showcase Stats ─────────────────

  Widget _buildFrontFace() {
    final theme = widget.config.theme;
    final level = AuthService.instance.currentProfile?.level ?? 1;
    final tier = RankTier.fromLevel(level);
    final archetype = widget.profile.primaryArchetype;

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
          color: theme.borderColor.withValues(alpha: 0.8),
          width: 2.0,
        ),
        boxShadow: [
          BoxShadow(
            color: theme.accentGlow.withValues(alpha: 0.30),
            blurRadius: 24,
            spreadRadius: 2,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(22),
        child: Stack(
          children: [
            // Background Suit Watermarks
            Positioned(
              right: -20,
              top: -20,
              child: Text(
                '♠',
                style: TextStyle(
                  fontSize: 160,
                  color: Colors.white.withValues(alpha: 0.04),
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            Positioned(
              left: -20,
              bottom: -20,
              child: Text(
                '♦',
                style: TextStyle(
                  fontSize: 140,
                  color: Colors.white.withValues(alpha: 0.03),
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),

            // Card Content
            Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Top Row: Game Badge & Card Title
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: Colors.black.withValues(alpha: 0.4),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: theme.borderColor.withValues(alpha: 0.5)),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text('♠️', style: const TextStyle(fontSize: 12)),
                            const SizedBox(width: 4),
                            Text(
                              'إستميشن • بطاقة اللاعب',
                              style: GoogleFonts.cairo(
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                                color: theme.borderColor,
                              ),
                            ),
                          ],
                        ),
                      ),
                      // Level Badge
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: tier.primaryColor.withValues(alpha: 0.2),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: tier.primaryColor),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(tier.badgeEmoji, style: const TextStyle(fontSize: 14)),
                            const SizedBox(width: 6),
                            Text(
                              'مستوى $level',
                              style: GoogleFonts.cairo(
                                fontSize: 11,
                                fontWeight: FontWeight.w900,
                                color: Colors.white,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 18),

                  // Player Info Section
                  Row(
                    children: [
                      // Avatar
                      Container(
                        padding: const EdgeInsets.all(3),
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          border: Border.all(color: theme.borderColor, width: 2),
                          boxShadow: [
                            BoxShadow(
                              color: theme.accentGlow.withValues(alpha: 0.4),
                              blurRadius: 12,
                            ),
                          ],
                        ),
                        child: PlayerAvatar(
                          photoData: widget.avatarUrl,
                          size: 68,
                        ),
                      ),
                      const SizedBox(width: 14),

                      // Name, Title & Personality Badge
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              widget.playerName.isNotEmpty ? widget.playerName : 'لاعب كوتشينة',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: GoogleFonts.cairo(
                                fontSize: 19,
                                fontWeight: FontWeight.w900,
                                color: Colors.white,
                                shadows: [
                                  Shadow(
                                    color: Colors.black.withValues(alpha: 0.6),
                                    blurRadius: 6,
                                  ),
                                ],
                              ),
                            ),
                            Text(
                              widget.config.selectedTitle,
                              style: GoogleFonts.cairo(
                                fontSize: 12,
                                fontWeight: FontWeight.w700,
                                color: theme.borderColor,
                              ),
                            ),
                            const SizedBox(height: 4),

                            // Archetype Chip
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                              decoration: BoxDecoration(
                                color: archetype.primaryColor.withValues(alpha: 0.2),
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(color: archetype.primaryColor, width: 1),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Text(archetype.emoji, style: const TextStyle(fontSize: 12)),
                                  const SizedBox(width: 4),
                                  Text(
                                    archetype.titleAr,
                                    style: GoogleFonts.cairo(
                                      fontSize: 11,
                                      fontWeight: FontWeight.bold,
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

                  const SizedBox(height: 20),

                  // Showcase Stats Grid (4 Cards)
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: 0.35),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          child: _buildShowcaseStatItem(
                            title: 'دقة الكول',
                            value: '${widget.stats.declarationAccuracy.toStringAsFixed(0)}%',
                            icon: Icons.track_changes_rounded,
                            color: const Color(0xFF38BDF8),
                          ),
                        ),
                        Container(width: 1, height: 36, color: Colors.white12),
                        Expanded(
                          child: _buildShowcaseStatItem(
                            title: 'الانتصارات',
                            value: '${widget.stats.gamesWon}',
                            icon: Icons.emoji_events_rounded,
                            color: AppTheme.gold,
                          ),
                        ),
                        Container(width: 1, height: 36, color: Colors.white12),
                        Expanded(
                          child: _buildShowcaseStatItem(
                            title: 'كول مثالي',
                            value: '${widget.stats.perfectEstimates}',
                            icon: Icons.stars_rounded,
                            color: const Color(0xFF10B981),
                          ),
                        ),
                        Container(width: 1, height: 36, color: Colors.white12),
                        Expanded(
                          child: _buildShowcaseStatItem(
                            title: 'أطول سلسلة',
                            value: '🔥 ${widget.stats.longestWinningStreak}',
                            icon: Icons.local_fire_department_rounded,
                            color: const Color(0xFFFF7043),
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 12),

                  // Card Bottom Footer Prompt
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.touch_app_rounded, size: 13, color: Colors.white54),
                      const SizedBox(width: 4),
                      Text(
                        'اضغط على البطاقة لقلبها وكشف التحليل التكتيكي',
                        style: GoogleFonts.cairo(
                          fontSize: 10,
                          color: Colors.white60,
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
    );
  }

  // ── BACK FACE: Personality Breakdown, Reasons, Strengths & Tips ────────────

  Widget _buildBackFace() {
    final theme = widget.config.theme;
    final archetype = widget.profile.primaryArchetype;

    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
        gradient: LinearGradient(
          colors: theme.gradientColors,
          begin: Alignment.topRight,
          end: Alignment.bottomLeft,
        ),
        border: Border.all(
          color: archetype.primaryColor.withValues(alpha: 0.9),
          width: 2.0,
        ),
        boxShadow: [
          BoxShadow(
            color: archetype.primaryColor.withValues(alpha: 0.35),
            blurRadius: 24,
            spreadRadius: 2,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(22),
        child: Padding(
          padding: const EdgeInsets.all(18),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Archetype Header
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: archetype.primaryColor.withValues(alpha: 0.25),
                      shape: BoxShape.circle,
                      border: Border.all(color: archetype.primaryColor),
                    ),
                    child: Text(archetype.emoji, style: const TextStyle(fontSize: 22)),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'الشخصية: ${archetype.titleAr}',
                          style: GoogleFonts.cairo(
                            fontSize: 16,
                            fontWeight: FontWeight.w900,
                            color: Colors.white,
                          ),
                        ),
                        Text(
                          archetype.taglineAr,
                          style: GoogleFonts.cairo(
                            fontSize: 11,
                            color: archetype.primaryColor,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                  // Secondary Archetype Badge
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: 0.3),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.white24),
                    ),
                    child: Text(
                      '${widget.profile.secondaryArchetype.emoji} ${widget.profile.secondaryArchetype.titleAr}',
                      style: GoogleFonts.cairo(fontSize: 10, color: Colors.white70),
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 14),

              // "Why You Are [Archetype]" Evidence Box
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.35),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'لماذا أنت "${archetype.titleAr}"؟',
                      style: GoogleFonts.cairo(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: AppTheme.gold,
                      ),
                    ),
                    const SizedBox(height: 6),
                    ...widget.profile.measurableReasons.take(3).map((r) => Padding(
                          padding: const EdgeInsets.only(bottom: 3),
                          child: Text(
                            r,
                            style: GoogleFonts.cairo(fontSize: 11, color: Colors.white),
                          ),
                        )),
                  ],
                ),
              ),

              const SizedBox(height: 10),

              // Strengths & Coaching Tip
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.25),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.tips_and_updates_rounded, size: 14, color: AppTheme.gold),
                        const SizedBox(width: 6),
                        Text(
                          'نصيحة لتطوير لعبك:',
                          style: GoogleFonts.cairo(
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                            color: AppTheme.gold,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      widget.profile.recommendation,
                      style: GoogleFonts.cairo(
                        fontSize: 11,
                        color: Colors.white70,
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 10),

              // Bottom Return Prompt
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.flip_camera_android_rounded, size: 13, color: Colors.white54),
                  const SizedBox(width: 4),
                  Text(
                    'اضغط للعودة إلى وجه البطاقة الرئيسي',
                    style: GoogleFonts.cairo(
                      fontSize: 10,
                      color: Colors.white60,
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

  Widget _buildShowcaseStatItem({
    required String title,
    required String value,
    required IconData icon,
    required Color color,
  }) {
    return Column(
      children: [
        Icon(icon, size: 16, color: color),
        const SizedBox(height: 4),
        Text(
          value,
          style: GoogleFonts.cairo(
            fontSize: 14,
            fontWeight: FontWeight.w900,
            color: Colors.white,
          ),
        ),
        Text(
          title,
          style: GoogleFonts.cairo(
            fontSize: 10,
            color: Colors.white60,
          ),
        ),
      ],
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
    return Padding(
      padding: EdgeInsets.only(
        left: 20,
        right: 20,
        top: 20,
        bottom: MediaQuery.of(context).viewInsets.bottom + 24,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Header
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'تخصيص بطاقة الهوية واللاعب',
                style: GoogleFonts.cairo(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: AppTheme.cream,
                ),
              ),
              IconButton(
                onPressed: () => Navigator.pop(context),
                icon: const Icon(Icons.close_rounded, color: Colors.white70),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // 1. Theme Skin Picker
          Text(
            'مظهر البطاقة (Skin)',
            style: GoogleFonts.cairo(
              fontSize: 13,
              fontWeight: FontWeight.bold,
              color: AppTheme.gold,
            ),
          ),
          const SizedBox(height: 10),
          SizedBox(
            height: 48,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: CardSkinTheme.values.length,
              separatorBuilder: (_, __) => const SizedBox(width: 8),
              itemBuilder: (context, index) {
                final theme = CardSkinTheme.values[index];
                final isSelected = _selectedTheme == theme;

                return InkWell(
                  onTap: () {
                    HapticFeedback.selectionClick();
                    setState(() => _selectedTheme = theme);
                    _applyChange();
                  },
                  borderRadius: BorderRadius.circular(12),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(colors: theme.gradientColors),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: isSelected ? theme.borderColor : Colors.white24,
                        width: isSelected ? 2.2 : 1.0,
                      ),
                      boxShadow: isSelected
                          ? [
                              BoxShadow(
                                color: theme.accentGlow.withValues(alpha: 0.5),
                                blurRadius: 8,
                              ),
                            ]
                          : null,
                    ),
                    alignment: Alignment.center,
                    child: Text(
                      theme.titleAr,
                      style: GoogleFonts.cairo(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                  ),
                );
              },
            ),
          ),

          const SizedBox(height: 20),

          // 2. Title Picker
          Text(
            'اللقب المختار على البطاقة',
            style: GoogleFonts.cairo(
              fontSize: 13,
              fontWeight: FontWeight.bold,
              color: AppTheme.gold,
            ),
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: PlayerIdentityCardConfig.availableTitles.map((title) {
              final isSelected = _selectedTitle == title;
              return ChoiceChip(
                label: Text(title),
                selected: isSelected,
                onSelected: (selected) {
                  if (selected) {
                    HapticFeedback.selectionClick();
                    setState(() => _selectedTitle = title);
                    _applyChange();
                  }
                },
                selectedColor: AppTheme.gold.withValues(alpha: 0.25),
                backgroundColor: Colors.white.withValues(alpha: 0.05),
                labelStyle: GoogleFonts.cairo(
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                  color: isSelected ? AppTheme.gold : Colors.white70,
                ),
                side: BorderSide(
                  color: isSelected ? AppTheme.gold : Colors.white12,
                ),
              );
            }).toList(),
          ),

          const SizedBox(height: 20),

          // 3. Privacy Toggle
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.04),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: Colors.white12),
            ),
            child: Row(
              children: [
                Icon(
                  _isPublic ? Icons.public_rounded : Icons.lock_rounded,
                  color: _isPublic ? const Color(0xFF10B981) : Colors.white60,
                  size: 20,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'إتاحة البطاقة والشخصية للعامة',
                        style: GoogleFonts.cairo(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                      Text(
                        _isPublic
                            ? 'يمكن للاعبين الآخرين رؤية بطاقتك وشخصيتك التكتيكية'
                            : 'بطاقتك خاصة ومخفية عن بقية اللاعبين',
                        style: GoogleFonts.cairo(
                          fontSize: 10,
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
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
