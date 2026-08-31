// lib/widgets/double_round_overlay.dart
//
// Dramatic cinematic overlay shown when all players pass during auction,
// announcing that the next round is double-scored (⚡ x2).

import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import '../theme/app_theme.dart';

class DoubleRoundOverlay extends StatefulWidget {
  final VoidCallback? onDismissed;
  final Duration displayDuration;

  const DoubleRoundOverlay({
    super.key,
    this.onDismissed,
    this.displayDuration = const Duration(milliseconds: 2800),
  });

  @override
  State<DoubleRoundOverlay> createState() => _DoubleRoundOverlayState();
}

class _DoubleRoundOverlayState extends State<DoubleRoundOverlay>
    with TickerProviderStateMixin {
  late final AnimationController _mainController;
  late final AnimationController _particleController;
  late final AnimationController _pulseController;
  late final AnimationController _shockwaveController;

  late final Animation<double> _scaleAnim;
  late final Animation<double> _fadeAnim;
  late final Animation<double> _iconScaleAnim;
  late final Animation<double> _glowAnim;
  late final Animation<double> _shockwaveAnim;

  Timer? _autoDismissTimer;
  bool _dismissing = false;

  late final List<_SparkParticle> _particles;

  @override
  void initState() {
    super.initState();

    final rng = math.Random();
    _particles = List.generate(28, (index) {
      final angle = (index / 28) * 2 * math.pi + (rng.nextDouble() * 0.25 - 0.12);
      final distance = 80.0 + rng.nextDouble() * 120.0;
      final size = 3.5 + rng.nextDouble() * 5.5;
      final isGold = rng.nextBool();
      return _SparkParticle(
        angle: angle,
        distance: distance,
        size: size,
        color: isGold ? const Color(0xFFFFD700) : const Color(0xFFFF9100),
      );
    });

    _mainController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 650),
    );

    _particleController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1600),
    )..forward();

    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    )..repeat(reverse: true);

    _shockwaveController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..forward();

    _scaleAnim = Tween<double>(begin: 0.25, end: 1.0).animate(
      CurvedAnimation(
        parent: _mainController,
        curve: const Interval(0.0, 0.85, curve: Curves.elasticOut),
      ),
    );

    _fadeAnim = CurvedAnimation(
      parent: _mainController,
      curve: const Interval(0.0, 0.35, curve: Curves.easeIn),
    );

    _iconScaleAnim = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _mainController,
        curve: const Interval(0.15, 0.9, curve: Curves.elasticOut),
      ),
    );

    _glowAnim = Tween<double>(begin: 0.65, end: 1.0).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );

    _shockwaveAnim = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _shockwaveController, curve: Curves.easeOutCubic),
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
    _shockwaveController.dispose();
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
                color: Colors.black.withValues(alpha: 0.65),
              ),
            ),

            // Shockwave ring animation
            AnimatedBuilder(
              animation: _shockwaveAnim,
              builder: (context, _) {
                final val = _shockwaveAnim.value;
                final opacity = (1.0 - val).clamp(0.0, 0.8);
                return Container(
                  width: 220 + val * 200,
                  height: 220 + val * 200,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: const Color(0xFFFFD700).withValues(alpha: opacity * 0.7),
                      width: 3.0 * (1.0 - val),
                    ),
                  ),
                );
              },
            ),

            // Lightning Sparks
            AnimatedBuilder(
              animation: _particleController,
              builder: (context, _) {
                final t = _particleController.value;
                final particleOpacity = (1.0 - t).clamp(0.0, 1.0);
                return CustomPaint(
                  painter: _SparkPainter(
                    particles: _particles,
                    progress: t,
                    opacity: particleOpacity,
                  ),
                );
              },
            ),

            // Central Announcement Card
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
                      padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 26),
                      constraints: const BoxConstraints(maxWidth: 420),
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: [
                            Color(0xF01C2438),
                            Color(0xF00F172A),
                          ],
                        ),
                        borderRadius: BorderRadius.circular(28),
                        border: Border.all(
                          color: const Color(0xFFFFD700).withValues(alpha: 0.85 * glow),
                          width: 2.2,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: const Color(0xFFFFD700).withValues(alpha: 0.45 * glow),
                            blurRadius: 36 * glow,
                            spreadRadius: 4 * glow,
                          ),
                          BoxShadow(
                            color: const Color(0xFFFF6D00).withValues(alpha: 0.3 * glow),
                            blurRadius: 28,
                            spreadRadius: 3,
                          ),
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.75),
                            blurRadius: 32,
                            offset: const Offset(0, 12),
                          ),
                        ],
                      ),
                      child: child,
                    );
                  },
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // Lightning Bolt Hero Icon
                      ScaleTransition(
                        scale: _iconScaleAnim,
                        child: Container(
                          width: 76,
                          height: 76,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            gradient: const LinearGradient(
                              colors: [Color(0xFFFFEA00), Color(0xFFFF9100)],
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: const Color(0xFFFFD700).withValues(alpha: 0.7),
                                blurRadius: 24,
                                spreadRadius: 4,
                              ),
                            ],
                          ),
                          child: const Center(
                            child: Text(
                              '⚡',
                              style: TextStyle(fontSize: 42, height: 1.1),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),

                      // Upper Header: EVERYONE PASSED
                      ShaderMask(
                        shaderCallback: (bounds) => const LinearGradient(
                          colors: [
                            Color(0xFFFFD54F),
                            Color(0xFFFFFFFF),
                            Color(0xFFFFCA28),
                          ],
                        ).createShader(bounds),
                        child: Text(
                          'EVERYONE PASSED',
                          textAlign: TextAlign.center,
                          style: GoogleFonts.cinzel(
                            fontSize: 22,
                            fontWeight: FontWeight.w900,
                            letterSpacing: 2.0,
                            color: Colors.white,
                          ),
                        ),
                      ),
                      const SizedBox(height: 2),

                      // Arabic Subtitle for Everyone Passed
                      Text(
                        'الجميع مرر المزاد (Pass)',
                        textAlign: TextAlign.center,
                        style: GoogleFonts.cairo(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          color: const Color(0xFFFFE082).withValues(alpha: 0.9),
                        ),
                      ),
                      const SizedBox(height: 16),

                      // Hero Badge: ⚡ DOUBLE ROUND NEXT
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(
                            colors: [Color(0xFFFF9100), Color(0xFFFF3D00)],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                          borderRadius: BorderRadius.circular(20),
                          boxShadow: [
                            BoxShadow(
                              color: const Color(0xFFFF6D00).withValues(alpha: 0.5),
                              blurRadius: 14,
                              offset: const Offset(0, 3),
                            ),
                          ],
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Text('⚡', style: TextStyle(fontSize: 16)),
                            const SizedBox(width: 6),
                            Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(
                                  'DOUBLE ROUND NEXT',
                                  style: GoogleFonts.cairo(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w900,
                                    color: Colors.white,
                                    letterSpacing: 0.8,
                                    height: 1.1,
                                  ),
                                ),
                                Text(
                                  'جولة مضاعفة تالية',
                                  style: GoogleFonts.cairo(
                                    fontSize: 11.5,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.white.withValues(alpha: 0.9),
                                    height: 1.1,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(width: 6),
                            const Text('⚡', style: TextStyle(fontSize: 16)),
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),

                      // Explanatory Note: All scores in the next round will be multiplied ×2
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.07),
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(
                            color: Colors.white.withValues(alpha: 0.12),
                          ),
                        ),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              'All scores in the next round\nwill be multiplied ×2.',
                              textAlign: TextAlign.center,
                              style: GoogleFonts.cairo(
                                fontSize: 13,
                                fontWeight: FontWeight.w700,
                                color: Colors.white.withValues(alpha: 0.95),
                                height: 1.3,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'ستتم مضاعفة جميع النقاط في الجولة القادمة ×2.',
                              textAlign: TextAlign.center,
                              style: GoogleFonts.cairo(
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                                color: AppTheme.goldLight.withValues(alpha: 0.85),
                                height: 1.2,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 14),

                      // ×2 Indicator
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                        decoration: BoxDecoration(
                          color: const Color(0xFFFFD700).withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: const Color(0xFFFFD700).withValues(alpha: 0.5),
                          ),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Text('⚡', style: TextStyle(fontSize: 12)),
                            const SizedBox(width: 4),
                            Text(
                              '×2 ROUND ACTIVE',
                              style: GoogleFonts.cairo(
                                fontSize: 11,
                                fontWeight: FontWeight.w800,
                                color: const Color(0xFFFFD700),
                                letterSpacing: 0.8,
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
}

class _SparkParticle {
  final double angle;
  final double distance;
  final double size;
  final Color color;

  _SparkParticle({
    required this.angle,
    required this.distance,
    required this.size,
    required this.color,
  });
}

class _SparkPainter extends CustomPainter {
  final List<_SparkParticle> particles;
  final double progress;
  final double opacity;

  _SparkPainter({
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
      canvas.drawCircle(Offset(dx, dy), p.size * (1.0 - progress * 0.35), paint);
    }
  }

  @override
  bool shouldRepaint(covariant _SparkPainter oldDelegate) {
    return oldDelegate.progress != progress || oldDelegate.opacity != opacity;
  }
}
