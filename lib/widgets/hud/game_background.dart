// lib/widgets/hud/game_background.dart
//
// Layered animated game background — dark gradient base with a subtle
// phase-reactive ambient glow and a very faint particle field.

import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../../theme/app_theme.dart';
import '../../core/models/game_state.dart';

/// Full-screen background widget that reacts to the current [phase] by
/// subtly tinting the ambient light. Particles are purely decorative
/// and run at very low repaint frequency via a custom Ticker.
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
  static const _kParticleCount = 8;

  @override
  void initState() {
    super.initState();
    final rng = math.Random(42);
    for (int i = 0; i < _kParticleCount; i++) {
      _particles.add(_Particle.random(rng));
    }

    _particleCtrl = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 20),
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
      children: [
        // ── Base gradient ──────────────────────────────────────────
        Container(
          decoration: BoxDecoration(
            gradient: RadialGradient(
              center: Alignment.topCenter,
              radius: 1.6,
              colors: [
                AppTheme.surface2,
                AppTheme.deepNavy,
                const Color(0xFF141E2A),
              ],
              stops: const [0.0, 0.5, 1.0],
            ),
          ),
        ),

        // ── Phase ambient glow — top radial tint ───────────────────
        AnimatedContainer(
          duration: const Duration(milliseconds: 800),
          curve: Curves.easeInOut,
          decoration: BoxDecoration(
            gradient: RadialGradient(
              center: Alignment.topCenter,
              radius: 1.2,
              colors: [
                ambient.withValues(alpha: 0.07),
                Colors.transparent,
              ],
            ),
          ),
        ),

        // ── Subtle floating dust particles ─────────────────────────
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

        // ── Bottom vignette ────────────────────────────────────────
        Align(
          alignment: Alignment.bottomCenter,
          child: Container(
            height: 200,
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                colors: [Colors.transparent, Color(0x80141E2A)],
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

// ── Particle ──────────────────────────────────────────────────────────────

class _Particle {
  final double startX;
  final double startY;
  final double speed;   // 0..1, relative to screen height
  final double size;
  final double opacity;
  final double phase;   // phase offset for drift

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
        speed: 0.02 + rng.nextDouble() * 0.04,
        size: 1.0 + rng.nextDouble() * 2.0,
        opacity: 0.04 + rng.nextDouble() * 0.08,
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
      final x = p.startX + math.sin(t * math.pi * 2 + p.phase) * 0.03;

      paint.color =
          AppTheme.steelBlue.withValues(alpha: p.opacity * math.sin(t * math.pi));
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
