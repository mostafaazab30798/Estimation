// lib/widgets/hud/game_background.dart
//
// Layered "Midnight Salon" atmosphere — deep radial base, phase ambient,
// soft dust, and dual vignettes. Decorative only; no game logic.

import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../../theme/app_theme.dart';
import '../../core/models/game_state.dart';

class GameBackground extends StatefulWidget {
  final GamePhase phase;

  const GameBackground({super.key, required this.phase});

  @override
  State<GameBackground> createState() => _GameBackgroundState();
}

class _GameBackgroundState extends State<GameBackground>
    with SingleTickerProviderStateMixin {
  late final AnimationController _particleCtrl;
  final _particles = <_Particle>[];
  static const _kParticleCount = 10;

  @override
  void initState() {
    super.initState();
    final rng = math.Random(42);
    for (int i = 0; i < _kParticleCount; i++) {
      _particles.add(_Particle.random(rng));
    }

    _particleCtrl = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 24),
    )..repeat();
  }

  @override
  void dispose() {
    _particleCtrl.dispose();
    super.dispose();
  }

  Color _ambientColor() {
    switch (widget.phase) {
      case GamePhase.auction:
        return AppTheme.phaseAuction;
      case GamePhase.declarations:
        return AppTheme.phaseDeclarations;
      case GamePhase.trickTaking:
        return AppTheme.phasePlay;
      case GamePhase.scoring:
        return AppTheme.phaseScoring;
      case GamePhase.voidCheck:
        return AppTheme.phaseReady;
      case GamePhase.dashCall:
        return Colors.orangeAccent;
      default:
        return AppTheme.deepNavy;
    }
  }

  @override
  Widget build(BuildContext context) {
    final ambient = _ambientColor();

    return Stack(
      fit: StackFit.expand,
      children: [
        // ── Base depth gradient ────────────────────────────────────
        const DecoratedBox(
          decoration: BoxDecoration(
            gradient: RadialGradient(
              center: Alignment(0, -0.15),
              radius: 1.35,
              colors: [
                Color(0xFF2A4158),
                Color(0xFF1A2B3C),
                Color(0xFF0E1620),
              ],
              stops: [0.0, 0.55, 1.0],
            ),
          ),
        ),

        // ── Soft corner wash (warm counter-light) ──────────────────
        DecoratedBox(
          decoration: BoxDecoration(
            gradient: RadialGradient(
              center: const Alignment(0.85, 0.9),
              radius: 0.9,
              colors: [
                AppTheme.gold.withValues(alpha: 0.035),
                Colors.transparent,
              ],
            ),
          ),
        ),

        // ── Phase ambient glow ─────────────────────────────────────
        AnimatedContainer(
          duration: const Duration(milliseconds: 800),
          curve: Curves.easeInOut,
          decoration: BoxDecoration(
            gradient: RadialGradient(
              center: Alignment.topCenter,
              radius: 1.15,
              colors: [
                ambient.withValues(alpha: 0.09),
                ambient.withValues(alpha: 0.02),
                Colors.transparent,
              ],
              stops: const [0.0, 0.4, 1.0],
            ),
          ),
        ),

        // ── Floating dust ──────────────────────────────────────────
        AnimatedBuilder(
          animation: _particleCtrl,
          builder: (_, __) {
            return RepaintBoundary(
              child: CustomPaint(
                painter: _ParticlePainter(
                  particles: _particles,
                  progress: _particleCtrl.value,
                ),
              ),
            );
          },
        ),

        // ── Edge vignette ──────────────────────────────────────────
        const DecoratedBox(
          decoration: BoxDecoration(
            gradient: RadialGradient(
              center: Alignment.center,
              radius: 1.05,
              colors: [
                Colors.transparent,
                Color(0x50101820),
              ],
              stops: [0.55, 1.0],
            ),
          ),
        ),

        // ── Bottom fade into hand area ─────────────────────────────
        Align(
          alignment: Alignment.bottomCenter,
          child: Container(
            height: 220,
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                colors: [Colors.transparent, Color(0xA00E1620)],
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _Particle {
  final double startX;
  final double startY;
  final double speed;
  final double size;
  final double opacity;
  final double phase;

  const _Particle({
    required this.startX,
    required this.startY,
    required this.speed,
    required this.size,
    required this.opacity,
    required this.phase,
  });

  factory _Particle.random(math.Random rng) => _Particle(
        startX: rng.nextDouble(),
        startY: rng.nextDouble(),
        speed: 0.015 + rng.nextDouble() * 0.035,
        size: 1.0 + rng.nextDouble() * 2.2,
        opacity: 0.035 + rng.nextDouble() * 0.07,
        phase: rng.nextDouble() * math.pi * 2,
      );
}

class _ParticlePainter extends CustomPainter {
  final List<_Particle> particles;
  final double progress;

  const _ParticlePainter({required this.particles, required this.progress});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..style = PaintingStyle.fill;

    for (final p in particles) {
      final t = (progress + p.phase / (math.pi * 2)) % 1.0;
      final y = (p.startY - t * p.speed * 10) % 1.0;
      final x = p.startX + math.sin(t * math.pi * 2 + p.phase) * 0.025;

      paint.color =
          AppTheme.cream.withValues(alpha: p.opacity * math.sin(t * math.pi));
      canvas.drawCircle(
        Offset(x * size.width, y * size.height),
        p.size,
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(_ParticlePainter old) => old.progress != progress;
}
