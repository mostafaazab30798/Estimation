// lib/widgets/comeback_overlay.dart
//
// Short, cinematic celebration overlay when a Comeback Event is detected.

import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import '../core/models/comeback_event.dart';
import '../theme/app_theme.dart';
import 'package:estimation/core/icons/app_icons.dart';

class ComebackOverlay extends StatefulWidget {
  final ComebackEvent event;
  final VoidCallback? onDismissed;
  final Duration displayDuration;

  const ComebackOverlay({
    super.key,
    required this.event,
    this.onDismissed,
    this.displayDuration = const Duration(milliseconds: 3200),
  });

  @override
  State<ComebackOverlay> createState() => _ComebackOverlayState();
}

class _ComebackOverlayState extends State<ComebackOverlay>
    with TickerProviderStateMixin {
  late final AnimationController _mainController;
  late final AnimationController _particleController;
  late final AnimationController _pulseController;

  late final Animation<double> _scaleAnim;
  late final Animation<double> _fadeAnim;
  late final Animation<double> _badgeScaleAnim;
  late final Animation<double> _glowAnim;

  Timer? _autoDismissTimer;
  bool _dismissing = false;
  late final List<_ComebackParticleData> _particles;

  @override
  void initState() {
    super.initState();

    final rng = math.Random();
    final isFire = widget.event.type == ComebackType.majorComeback;
    final isCrown = widget.event.type == ComebackType.finalRoundComeback;

    // Generate burst particles
    _particles = List.generate(30, (index) {
      final angle = (index / 30) * 2 * math.pi + (rng.nextDouble() * 0.2 - 0.1);
      final distance = 80.0 + rng.nextDouble() * 140.0;
      final size = 4.0 + rng.nextDouble() * 7.0;
      Color pColor;
      if (isFire) {
        pColor = rng.nextBool()
            ? const Color(0xFFFF5722)
            : (rng.nextBool() ? const Color(0xFFFFB300) : AppTheme.gold);
      } else if (isCrown) {
        pColor = rng.nextBool()
            ? AppTheme.gold
            : (rng.nextBool() ? const Color(0xFFFFD54F) : const Color(0xFF80D8FF));
      } else {
        pColor = rng.nextBool()
            ? const Color(0xFF00E676)
            : (rng.nextBool() ? AppTheme.gold : const Color(0xFF69F0AE));
      }

      return _ComebackParticleData(
        angle: angle,
        distance: distance,
        size: size,
        color: pColor,
      );
    });

    _mainController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 700),
    );

    _particleController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1600),
    )..forward();

    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    )..repeat(reverse: true);

    _scaleAnim = Tween<double>(begin: 0.2, end: 1.0).animate(
      CurvedAnimation(
        parent: _mainController,
        curve: const Interval(0.0, 0.8, curve: Curves.elasticOut),
      ),
    );

    _fadeAnim = CurvedAnimation(
      parent: _mainController,
      curve: const Interval(0.0, 0.4, curve: Curves.easeIn),
    );

    _badgeScaleAnim = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _mainController,
        curve: const Interval(0.2, 0.9, curve: Curves.elasticOut),
      ),
    );

    _glowAnim = Tween<double>(begin: 0.5, end: 1.0).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );

    _mainController.forward();

    try {
      HapticFeedback.heavyImpact();
    } catch (_) {}

    _autoDismissTimer = Timer(widget.displayDuration, () {
      _dismiss();
    });
  }

  void _dismiss() {
    if (_dismissing || !mounted) return;
    _dismissing = true;
    _autoDismissTimer?.cancel();
    _mainController.reverse().then((_) {
      if (mounted) {
        widget.onDismissed?.call();
      }
    });
  }

  @override
  void dispose() {
    _autoDismissTimer?.cancel();
    _mainController.dispose();
    _particleController.dispose();
    _pulseController.dispose();
    super.dispose();
  }

  Color get _primaryAccent {
    switch (widget.event.type) {
      case ComebackType.majorComeback:
        return const Color(0xFFFF5722);
      case ComebackType.finalRoundComeback:
        return AppTheme.gold;
      case ComebackType.rankSurge:
        return const Color(0xFF00E676);
    }
  }

  @override
  Widget build(BuildContext context) {
    final event = widget.event;
    final accent = _primaryAccent;

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: _dismiss,
      child: Material(
        color: Colors.transparent,
        child: Stack(
          alignment: Alignment.center,
          children: [
            // Dark vignette backdrop
            FadeTransition(
              opacity: _fadeAnim,
              child: Container(
                color: Colors.black.withValues(alpha: 0.65),
              ),
            ),

            // Radiating particles
            AnimatedBuilder(
              animation: _particleController,
              builder: (context, child) {
                return CustomPaint(
                  size: const Size(360, 360),
                  painter: _ComebackParticlePainter(
                    particles: _particles,
                    progress: _particleController.value,
                  ),
                );
              },
            ),

            // Main celebratory dialog card
            ScaleTransition(
              scale: _scaleAnim,
              child: FadeTransition(
                opacity: _fadeAnim,
                child: AnimatedBuilder(
                  animation: _glowAnim,
                  builder: (context, child) {
                    return Container(
                      margin: const EdgeInsets.symmetric(horizontal: 24),
                      constraints: const BoxConstraints(maxWidth: 380),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 24,
                        vertical: 24,
                      ),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [
                            AppTheme.navyDark.withValues(alpha: 0.95),
                            const Color(0xFF1E2838).withValues(alpha: 0.98),
                          ],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        borderRadius: BorderRadius.circular(28),
                        border: Border.all(
                          color: accent.withValues(alpha: 0.7 * _glowAnim.value),
                          width: 2.5,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: accent.withValues(alpha: 0.35 * _glowAnim.value),
                            blurRadius: 36 * _glowAnim.value,
                            spreadRadius: 4,
                          ),
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.6),
                            blurRadius: 20,
                            offset: const Offset(0, 10),
                          ),
                        ],
                      ),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          // Emoji Badge
                          ScaleTransition(
                            scale: _badgeScaleAnim,
                            child: Container(
                              width: 80,
                              height: 80,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                gradient: RadialGradient(
                                  colors: [
                                    accent.withValues(alpha: 0.35),
                                    Colors.transparent,
                                  ],
                                ),
                                border: Border.all(
                                  color: accent.withValues(alpha: 0.8),
                                  width: 2,
                                ),
                              ),
                              child: Center(
                                child: Text(
                                  event.iconEmoji,
                                  style: const TextStyle(fontSize: 44),
                                ),
                              ),
                            ),
                          ),

                          const SizedBox(height: 14),

                          // English Title
                          Text(
                            event.titleEn,
                            textAlign: TextAlign.center,
                            style: GoogleFonts.cinzel(
                              fontSize: 22,
                              fontWeight: FontWeight.w900,
                              color: accent,
                              letterSpacing: 1.5,
                              shadows: [
                                Shadow(
                                  color: accent.withValues(alpha: 0.8),
                                  blurRadius: 16,
                                ),
                              ],
                            ),
                          ),

                          // Arabic Title
                          Text(
                            event.titleAr,
                            textAlign: TextAlign.center,
                            style: GoogleFonts.cairo(
                              fontSize: 20,
                              fontWeight: FontWeight.w900,
                              color: AppTheme.cream,
                              height: 1.2,
                            ),
                          ),

                          const SizedBox(height: 16),

                          // Rank Progression Pill
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 18,
                              vertical: 10,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.black.withValues(alpha: 0.35),
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(
                                color: AppTheme.gold.withValues(alpha: 0.3),
                              ),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                _buildRankBadge(
                                  event.previousRank,
                                  isPrevious: true,
                                ),
                                const Padding(
                                  padding: EdgeInsets.symmetric(horizontal: 12),
                                  child: AppIcon(
                                    AppIcons.trendingUp,
                                    color: AppTheme.gold,
                                    size: 26,
                                  ),
                                ),
                                _buildRankBadge(
                                  event.newRank,
                                  isPrevious: false,
                                ),
                              ],
                            ),
                          ),

                          const SizedBox(height: 14),

                          // Subtitle (Localized explanation)
                          Text(
                            event.subtitleAr,
                            textAlign: TextAlign.center,
                            style: GoogleFonts.cairo(
                              fontSize: 14,
                              fontWeight: FontWeight.w700,
                              color: AppTheme.cream.withValues(alpha: 0.9),
                            ),
                          ),

                          if (event.pointsDeficitOvercome > 0) ...[
                            const SizedBox(height: 4),
                            Text(
                              'تم تعويض فارق +${event.pointsDeficitOvercome} نقطة!',
                              textAlign: TextAlign.center,
                              style: GoogleFonts.cairo(
                                fontSize: 13,
                                fontWeight: FontWeight.bold,
                                color: AppTheme.goldLight,
                              ),
                            ),
                          ],

                          const SizedBox(height: 16),

                          // Dismiss prompt hint
                          Text(
                            'المس للمتابعة',
                            style: GoogleFonts.cairo(
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                              color: Colors.white38,
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRankBadge(int rank, {required bool isPrevious}) {
    final ranks = ['1st', '2nd', '3rd', '4th'];
    final rankText = (rank >= 1 && rank <= 4) ? ranks[rank - 1] : '${rank}th';
    final isFirst = rank == 1;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: isFirst
            ? AppTheme.gold.withValues(alpha: 0.25)
            : (isPrevious
                ? Colors.white.withValues(alpha: 0.08)
                : const Color(0xFF00E676).withValues(alpha: 0.2)),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: isFirst
              ? AppTheme.gold
              : (isPrevious ? Colors.white24 : const Color(0xFF00E676)),
          width: 1.5,
        ),
      ),
      child: Text(
        rankText,
        style: GoogleFonts.cairo(
          fontSize: 15,
          fontWeight: FontWeight.w900,
          color: isFirst
              ? AppTheme.gold
              : (isPrevious ? Colors.white70 : const Color(0xFF00E676)),
        ),
      ),
    );
  }
}

class _ComebackParticleData {
  final double angle;
  final double distance;
  final double size;
  final Color color;

  const _ComebackParticleData({
    required this.angle,
    required this.distance,
    required this.size,
    required this.color,
  });
}

class _ComebackParticlePainter extends CustomPainter {
  final List<_ComebackParticleData> particles;
  final double progress;

  _ComebackParticlePainter({
    required this.particles,
    required this.progress,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final curveProgress = Curves.easeOutCubic.transform(progress);
    final fadeAlpha = (1.0 - progress).clamp(0.0, 1.0);

    for (final p in particles) {
      final currentDist = p.distance * curveProgress;
      final dx = center.dx + currentDist * math.cos(p.angle);
      final dy = center.dy + currentDist * math.sin(p.angle);

      final paint = Paint()
        ..color = p.color.withValues(alpha: p.color.a * fadeAlpha)
        ..style = PaintingStyle.fill;

      canvas.drawCircle(Offset(dx, dy), p.size * (1.0 - progress * 0.4), paint);
    }
  }

  @override
  bool shouldRepaint(_ComebackParticlePainter oldDelegate) =>
      oldDelegate.progress != progress;
}
