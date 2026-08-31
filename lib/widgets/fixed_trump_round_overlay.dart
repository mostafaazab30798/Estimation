// lib/widgets/fixed_trump_round_overlay.dart
//
// Dramatic cinematic overlay shown at the beginning of the final 5 rounds (14-18),
// announcing the fixed-trump contract and the 8+ bid override rule.

import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import '../core/constants.dart';
import '../theme/app_theme.dart';

class FixedTrumpRoundOverlay extends StatefulWidget {
  final int roundNumber;
  final Trump fixedTrump;
  final VoidCallback? onDismissed;
  final Duration displayDuration;

  const FixedTrumpRoundOverlay({
    super.key,
    required this.roundNumber,
    required this.fixedTrump,
    this.onDismissed,
    this.displayDuration = const Duration(milliseconds: 2900),
  });

  @override
  State<FixedTrumpRoundOverlay> createState() => _FixedTrumpRoundOverlayState();
}

class _FixedTrumpRoundOverlayState extends State<FixedTrumpRoundOverlay>
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

  late final List<_TrumpParticle> _particles;

  _TrumpTheme _getTheme() {
    switch (widget.fixedTrump) {
      case Trump.sans:
        return const _TrumpTheme(
          suitSymbol: '♟',
          englishName: 'SANS ROUND',
          arabicName: 'جولة السانز',
          trumpFixedEn: 'Trump is fixed to SANS.',
          trumpFixedAr: 'نوع الحكم إجباري: سانز',
          primaryColor: Color(0xFFA855F7),
          secondaryColor: Color(0xFF6366F1),
          accentColor: Color(0xFFFFD700),
          badgeGradient: [Color(0xFF7E22CE), Color(0xFF4338CA)],
        );
      case Trump.spade:
        return const _TrumpTheme(
          suitSymbol: '♠',
          englishName: 'SPADE ROUND',
          arabicName: 'جولة الأسبيد',
          trumpFixedEn: 'Trump is fixed to SPADES.',
          trumpFixedAr: 'نوع الحكم إجباري: سبيد (♠)',
          primaryColor: Color(0xFF38BDF8),
          secondaryColor: Color(0xFF0EA5E9),
          accentColor: Color(0xFFFFD700),
          badgeGradient: [Color(0xFF0F172A), Color(0xFF1E293B)],
        );
      case Trump.heart:
        return const _TrumpTheme(
          suitSymbol: '♥',
          englishName: 'HEART ROUND',
          arabicName: 'جولة الهارت',
          trumpFixedEn: 'Trump is fixed to HEARTS.',
          trumpFixedAr: 'نوع الحكم إجباري: هارت (♥)',
          primaryColor: Color(0xFFF43F5E),
          secondaryColor: Color(0xFFE11D48),
          accentColor: Color(0xFFFFE4E6),
          badgeGradient: [Color(0xFFBE123C), Color(0xFF881337)],
        );
      case Trump.diamond:
        return const _TrumpTheme(
          suitSymbol: '♦',
          englishName: 'DIAMOND ROUND',
          arabicName: 'جولة الكارو',
          trumpFixedEn: 'Trump is fixed to DIAMONDS.',
          trumpFixedAr: 'نوع الحكم إجباري: كارو (♦)',
          primaryColor: Color(0xFFFB923C),
          secondaryColor: Color(0xFFEA580C),
          accentColor: Color(0xFFFEF08A),
          badgeGradient: [Color(0xFFC2410C), Color(0xFF9A3412)],
        );
      case Trump.club:
        return const _TrumpTheme(
          suitSymbol: '♣',
          englishName: 'CLUB ROUND',
          arabicName: 'جولة التريفل',
          trumpFixedEn: 'Trump is fixed to CLUBS.',
          trumpFixedAr: 'نوع الحكم إجباري: تريفل (♣)',
          primaryColor: Color(0xFF34D399),
          secondaryColor: Color(0xFF059669),
          accentColor: Color(0xFFA7F3D0),
          badgeGradient: [Color(0xFF065F46), Color(0xFF064E3B)],
        );
    }
  }

  @override
  void initState() {
    super.initState();

    final theme = _getTheme();
    final rng = math.Random();
    _particles = List.generate(30, (index) {
      final angle = (index / 30) * 2 * math.pi + (rng.nextDouble() * 0.25 - 0.12);
      final distance = 85.0 + rng.nextDouble() * 135.0;
      final size = 3.5 + rng.nextDouble() * 6.0;
      final isAccent = rng.nextBool();
      return _TrumpParticle(
        angle: angle,
        distance: distance,
        size: size,
        color: isAccent ? theme.accentColor : theme.primaryColor,
      );
    });

    _mainController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 650),
    );

    _particleController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1700),
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
    final theme = _getTheme();

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
                color: Colors.black.withValues(alpha: 0.68),
              ),
            ),

            // Shockwave ring animation
            AnimatedBuilder(
              animation: _shockwaveAnim,
              builder: (context, _) {
                final val = _shockwaveAnim.value;
                final opacity = (1.0 - val).clamp(0.0, 0.85);
                return Container(
                  width: 220 + val * 220,
                  height: 220 + val * 220,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: theme.primaryColor.withValues(alpha: opacity * 0.8),
                      width: 3.5 * (1.0 - val),
                    ),
                  ),
                );
              },
            ),

            // Particles
            AnimatedBuilder(
              animation: _particleController,
              builder: (context, _) {
                final t = _particleController.value;
                final particleOpacity = (1.0 - t).clamp(0.0, 1.0);
                return CustomPaint(
                  painter: _TrumpParticlePainter(
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
                      padding: const EdgeInsets.symmetric(horizontal: 26, vertical: 24),
                      constraints: const BoxConstraints(maxWidth: 420),
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: [
                            Color(0xF01A2338),
                            Color(0xF00D1526),
                          ],
                        ),
                        borderRadius: BorderRadius.circular(28),
                        border: Border.all(
                          color: theme.primaryColor.withValues(alpha: 0.85 * glow),
                          width: 2.2,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: theme.primaryColor.withValues(alpha: 0.45 * glow),
                            blurRadius: 36 * glow,
                            spreadRadius: 4 * glow,
                          ),
                          BoxShadow(
                            color: theme.secondaryColor.withValues(alpha: 0.3 * glow),
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
                      // Championship Phase Super-Badge
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                        decoration: BoxDecoration(
                          color: AppTheme.gold.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                            color: AppTheme.gold.withValues(alpha: 0.6),
                            width: 1.1,
                          ),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Text('👑', style: TextStyle(fontSize: 11)),
                            const SizedBox(width: 4),
                            Text(
                              'CHAMPIONSHIP PHASE',
                              style: GoogleFonts.cairo(
                                fontSize: 10.5,
                                fontWeight: FontWeight.w900,
                                color: const Color(0xFFFFD700),
                                letterSpacing: 0.8,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 14),

                      // Hero Trump / Suit Icon
                      ScaleTransition(
                        scale: _iconScaleAnim,
                        child: Container(
                          width: 76,
                          height: 76,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            gradient: LinearGradient(
                              colors: [
                                theme.primaryColor,
                                theme.secondaryColor,
                              ],
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: theme.primaryColor.withValues(alpha: 0.7),
                                blurRadius: 24,
                                spreadRadius: 4,
                              ),
                            ],
                          ),
                          child: Center(
                            child: Text(
                              theme.suitSymbol,
                              style: TextStyle(
                                fontSize: widget.fixedTrump == Trump.sans ? 40 : 46,
                                height: 1.0,
                                color: Colors.white,
                              ),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 14),

                      // Round Title (e.g. ROUND 14)
                      ShaderMask(
                        shaderCallback: (bounds) => LinearGradient(
                          colors: [
                            const Color(0xFFFFFFFF),
                            theme.accentColor,
                            const Color(0xFFFFFFFF),
                          ],
                        ).createShader(bounds),
                        child: Text(
                          'ROUND ${widget.roundNumber}',
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

                      // Arabic Round Subtitle
                      Text(
                        'الجولة ${widget.roundNumber}',
                        textAlign: TextAlign.center,
                        style: GoogleFonts.cairo(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          color: AppTheme.goldLight.withValues(alpha: 0.9),
                        ),
                      ),
                      const SizedBox(height: 12),

                      // Hero Badge: ♠ SPADE ROUND / ♟ SANS ROUND
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: theme.badgeGradient,
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(
                            color: theme.primaryColor.withValues(alpha: 0.7),
                            width: 1.4,
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: theme.secondaryColor.withValues(alpha: 0.5),
                              blurRadius: 14,
                              offset: const Offset(0, 3),
                            ),
                          ],
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              theme.suitSymbol,
                              style: TextStyle(
                                fontSize: 16,
                                color: theme.accentColor,
                              ),
                            ),
                            const SizedBox(width: 8),
                            Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(
                                  theme.englishName,
                                  style: GoogleFonts.cinzel(
                                    fontSize: 15,
                                    fontWeight: FontWeight.w900,
                                    color: Colors.white,
                                    letterSpacing: 1.2,
                                    height: 1.1,
                                  ),
                                ),
                                Text(
                                  theme.arabicName,
                                  style: GoogleFonts.cairo(
                                    fontSize: 12,
                                    fontWeight: FontWeight.bold,
                                    color: theme.accentColor.withValues(alpha: 0.95),
                                    height: 1.1,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(width: 8),
                            Text(
                              theme.suitSymbol,
                              style: TextStyle(
                                fontSize: 16,
                                color: theme.accentColor,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 14),

                      // Rules Box:
                      // "Trump is fixed to [TRUMP]."
                      // "Bid 8+ to override the fixed contract."
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.07),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                            color: Colors.white.withValues(alpha: 0.14),
                          ),
                        ),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            // Rule 1: Fixed Trump statement
                            Text(
                              theme.trumpFixedEn,
                              textAlign: TextAlign.center,
                              style: GoogleFonts.cairo(
                                fontSize: 14,
                                fontWeight: FontWeight.w800,
                                color: Colors.white,
                                height: 1.2,
                              ),
                            ),
                            Text(
                              theme.trumpFixedAr,
                              textAlign: TextAlign.center,
                              style: GoogleFonts.cairo(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                color: theme.accentColor.withValues(alpha: 0.9),
                                height: 1.2,
                              ),
                            ),
                            const Padding(
                              padding: EdgeInsets.symmetric(vertical: 8.0),
                              child: Divider(color: Colors.white12, height: 1),
                            ),
                            // Rule 2: Direct Declaration & Highest starts
                            Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                const Text('🎯', style: TextStyle(fontSize: 13)),
                                const SizedBox(width: 4),
                                Flexible(
                                  child: Text(
                                    'Direct Declarations • Highest Declarer Starts',
                                    textAlign: TextAlign.center,
                                    style: GoogleFonts.cairo(
                                      fontSize: 13,
                                      fontWeight: FontWeight.w800,
                                      color: const Color(0xFFFFD54F),
                                      height: 1.2,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 2),
                            Text(
                              'بدون مزاد • تقدير مباشر • صاحب أعلى تقدير يبدأ اللعب',
                              textAlign: TextAlign.center,
                              style: GoogleFonts.cairo(
                                fontSize: 11.5,
                                fontWeight: FontWeight.w600,
                                color: Colors.white70,
                                height: 1.2,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 12),

                      // Locked indicator pill
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                        decoration: BoxDecoration(
                          color: theme.primaryColor.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: theme.primaryColor.withValues(alpha: 0.5),
                          ),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Text('🔒', style: TextStyle(fontSize: 11)),
                            const SizedBox(width: 5),
                            Text(
                              'FIXED CONTRACT ACTIVE',
                              style: GoogleFonts.cairo(
                                fontSize: 11,
                                fontWeight: FontWeight.w800,
                                color: theme.accentColor,
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

class _TrumpTheme {
  final String suitSymbol;
  final String englishName;
  final String arabicName;
  final String trumpFixedEn;
  final String trumpFixedAr;
  final Color primaryColor;
  final Color secondaryColor;
  final Color accentColor;
  final List<Color> badgeGradient;

  const _TrumpTheme({
    required this.suitSymbol,
    required this.englishName,
    required this.arabicName,
    required this.trumpFixedEn,
    required this.trumpFixedAr,
    required this.primaryColor,
    required this.secondaryColor,
    required this.accentColor,
    required this.badgeGradient,
  });
}

class _TrumpParticle {
  final double angle;
  final double distance;
  final double size;
  final Color color;

  _TrumpParticle({
    required this.angle,
    required this.distance,
    required this.size,
    required this.color,
  });
}

class _TrumpParticlePainter extends CustomPainter {
  final List<_TrumpParticle> particles;
  final double progress;
  final double opacity;

  _TrumpParticlePainter({
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
  bool shouldRepaint(covariant _TrumpParticlePainter oldDelegate) {
    return oldDelegate.progress != progress || oldDelegate.opacity != opacity;
  }
}
