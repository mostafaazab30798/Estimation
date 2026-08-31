// lib/widgets/perfect_estimate_overlay.dart
//
// Short, satisfying celebration overlay when Declared == Actual.

import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import '../theme/app_theme.dart';
import 'package:estimation/core/icons/app_icons.dart';

class PerfectEstimateOverlay extends StatefulWidget {
  final int declared;
  final int won;
  final int? xpBonus;
  final VoidCallback? onDismissed;
  final Duration displayDuration;

  const PerfectEstimateOverlay({
    super.key,
    required this.declared,
    required this.won,
    this.xpBonus = 20,
    this.onDismissed,
    this.displayDuration = const Duration(milliseconds: 2600),
  });

  @override
  State<PerfectEstimateOverlay> createState() => _PerfectEstimateOverlayState();
}

class _PerfectEstimateOverlayState extends State<PerfectEstimateOverlay>
    with TickerProviderStateMixin {
  late final AnimationController _mainController;
  late final AnimationController _particleController;
  late final AnimationController _pulseController;

  late final Animation<double> _scaleAnim;
  late final Animation<double> _fadeAnim;
  late final Animation<double> _iconScaleAnim;
  late final Animation<double> _glowAnim;

  Timer? _autoDismissTimer;
  bool _dismissing = false;

  static final List<({String titleEn, String titleAr})> _variants = [
    (titleEn: 'PERFECT ESTIMATE!', titleAr: 'تقدير مثالي!'),
    (titleEn: 'PERFECT BID!', titleAr: 'مزايدة دقيقة!'),
    (titleEn: 'DEAD-ON!', titleAr: 'بالضبط!'),
    (titleEn: 'NAILED IT!', titleAr: 'في الصميم!'),
  ];

  late final ({String titleEn, String titleAr}) _chosenVariant;
  late final List<_ParticleData> _particles;

  @override
  void initState() {
    super.initState();

    final rng = math.Random();
    _chosenVariant = _variants[rng.nextInt(_variants.length)];

    // Generate random celebration particles
    _particles = List.generate(24, (index) {
      final angle = (index / 24) * 2 * math.pi + (rng.nextDouble() * 0.2 - 0.1);
      final distance = 70.0 + rng.nextDouble() * 110.0;
      final size = 4.0 + rng.nextDouble() * 6.0;
      final isGold = rng.nextBool();
      return _ParticleData(
        angle: angle,
        distance: distance,
        size: size,
        color: isGold ? AppTheme.gold : const Color(0xFF00E676),
      );
    });

    _mainController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 650),
    );

    _particleController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    )..forward();

    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1000),
    )..repeat(reverse: true);

    _scaleAnim = Tween<double>(begin: 0.3, end: 1.0).animate(
      CurvedAnimation(
        parent: _mainController,
        curve: const Interval(0.0, 0.8, curve: Curves.elasticOut),
      ),
    );

    _fadeAnim = CurvedAnimation(
      parent: _mainController,
      curve: const Interval(0.0, 0.4, curve: Curves.easeIn),
    );

    _iconScaleAnim = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _mainController,
        curve: const Interval(0.2, 0.9, curve: Curves.elasticOut),
      ),
    );

    _glowAnim = Tween<double>(begin: 0.6, end: 1.0).animate(
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

  @override
  Widget build(BuildContext context) {
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
                color: Colors.black.withValues(alpha: 0.45),
              ),
            ),

            // Particle Burts
            AnimatedBuilder(
              animation: _particleController,
              builder: (context, _) {
                final t = _particleController.value;
                final particleOpacity = (1.0 - t).clamp(0.0, 1.0);
                return CustomPaint(
                  painter: _ParticlePainter(
                    particles: _particles,
                    progress: t,
                    opacity: particleOpacity,
                  ),
                );
              },
            ),

            // Central Card
            FadeTransition(
              opacity: _fadeAnim,
              child: ScaleTransition(
                scale: _scaleAnim,
                child: AnimatedBuilder(
                  animation: _pulseController,
                  builder: (context, child) {
                    final glow = _glowAnim.value;
                    return Container(
                      margin: const EdgeInsets.symmetric(horizontal: 24),
                      padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 24),
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: [
                            Color(0xF0182C40),
                            Color(0xF00D1B2A),
                          ],
                        ),
                        borderRadius: BorderRadius.circular(28),
                        border: Border.all(
                          color: AppTheme.gold.withValues(alpha: 0.7 * glow),
                          width: 2.0,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: AppTheme.gold.withValues(alpha: 0.35 * glow),
                            blurRadius: 36 * glow,
                            spreadRadius: 4 * glow,
                          ),
                          BoxShadow(
                            color: const Color(0xFF00E676).withValues(alpha: 0.2 * glow),
                            blurRadius: 24,
                            spreadRadius: 2,
                          ),
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.6),
                            blurRadius: 30,
                            offset: const Offset(0, 10),
                          ),
                        ],
                      ),
                      child: child,
                    );
                  },
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // Target Icon with animation
                      ScaleTransition(
                        scale: _iconScaleAnim,
                        child: Container(
                          width: 68,
                          height: 68,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            gradient: const LinearGradient(
                              colors: [Color(0xFFFFD700), Color(0xFFFFA000)],
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: AppTheme.gold.withValues(alpha: 0.6),
                                blurRadius: 20,
                                spreadRadius: 3,
                              ),
                            ],
                          ),
                          child: const Center(
                            child: Text(
                              '🎯',
                              style: TextStyle(fontSize: 36),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),

                      // Variant Title
                      ShaderMask(
                        shaderCallback: (bounds) => const LinearGradient(
                          colors: [
                            Color(0xFFFFE082),
                            Color(0xFFFFD54F),
                            Color(0xFFFFFFFF),
                            Color(0xFFFFB300),
                          ],
                        ).createShader(bounds),
                        child: Text(
                          _chosenVariant.titleEn,
                          textAlign: TextAlign.center,
                          style: GoogleFonts.cinzel(
                            fontSize: 22,
                            fontWeight: FontWeight.w900,
                            letterSpacing: 1.5,
                            color: Colors.white,
                          ),
                        ),
                      ),
                      const SizedBox(height: 2),

                      // Arabic Subtitle
                      Text(
                        _chosenVariant.titleAr,
                        textAlign: TextAlign.center,
                        style: GoogleFonts.cairo(
                          fontSize: 15,
                          fontWeight: FontWeight.w800,
                          color: AppTheme.goldLight.withValues(alpha: 0.9),
                        ),
                      ),
                      const SizedBox(height: 18),

                      // Stats Row: 7 declared | 7 won
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.08),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                            color: Colors.white.withValues(alpha: 0.15),
                          ),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            _buildStatItem(
                              value: '${widget.declared}',
                              labelEn: 'declared',
                              labelAr: 'صرّح',
                              color: AppTheme.gold,
                            ),
                            Container(
                              height: 32,
                              width: 1.2,
                              margin: const EdgeInsets.symmetric(horizontal: 18),
                              color: Colors.white.withValues(alpha: 0.2),
                            ),
                            _buildStatItem(
                              value: '${widget.won}',
                              labelEn: 'won',
                              labelAr: 'ربح',
                              color: const Color(0xFF00E676),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),

                      // +XP Bonus Badge
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(
                            colors: [Color(0xFF00E676), Color(0xFF00B0FF)],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                          borderRadius: BorderRadius.circular(20),
                          boxShadow: [
                            BoxShadow(
                              color: const Color(0xFF00E676).withValues(alpha: 0.4),
                              blurRadius: 10,
                              offset: const Offset(0, 2),
                            ),
                          ],
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const AppIcon(
                              AppIcons.stars,
                              size: 18,
                              color: Colors.white,
                            ),
                            const SizedBox(width: 6),
                            Text(
                              '+${widget.xpBonus ?? 20} XP BONUS',
                              style: GoogleFonts.cairo(
                                fontSize: 13,
                                fontWeight: FontWeight.w900,
                                color: Colors.white,
                                letterSpacing: 0.5,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatItem({
    required String value,
    required String labelEn,
    required String labelAr,
    required Color color,
  }) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          value,
          style: GoogleFonts.cairo(
            fontSize: 22,
            fontWeight: FontWeight.w900,
            color: color,
            height: 1.1,
          ),
        ),
        Text(
          '$labelEn • $labelAr',
          style: GoogleFonts.cairo(
            fontSize: 11,
            fontWeight: FontWeight.w600,
            color: Colors.white70,
            height: 1.1,
          ),
        ),
      ],
    );
  }
}

class _ParticleData {
  final double angle;
  final double distance;
  final double size;
  final Color color;

  _ParticleData({
    required this.angle,
    required this.distance,
    required this.size,
    required this.color,
  });
}

class _ParticlePainter extends CustomPainter {
  final List<_ParticleData> particles;
  final double progress;
  final double opacity;

  _ParticlePainter({
    required this.particles,
    required this.progress,
    required this.opacity,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (opacity <= 0.0) return;

    final center = Offset(size.width / 2, size.height / 2);
    final paint = Paint()..style = PaintingStyle.fill;

    for (final p in particles) {
      final currentDist = p.distance * Curves.easeOutCubic.transform(progress);
      final dx = center.dx + currentDist * math.cos(p.angle);
      final dy = center.dy + currentDist * math.sin(p.angle);

      paint.color = p.color.withValues(alpha: opacity);
      canvas.drawCircle(Offset(dx, dy), p.size * (1.0 - progress * 0.3), paint);
    }
  }

  @override
  bool shouldRepaint(covariant _ParticlePainter oldDelegate) {
    return oldDelegate.progress != progress || oldDelegate.opacity != opacity;
  }
}
