// lib/widgets/earthquake/earthquake_crack_painter.dart
//
// CustomPainter rendering glowing ground fissures, layered shockwaves,
// dust plumes, and debris radiating from the card slam point.

import 'dart:math' as math;
import 'package:flutter/material.dart';

class EarthquakeCrackPainter extends CustomPainter {
  /// Progress from 0.0 (impact) to 1.0 (fully faded)
  final double progress;
  final Color baseGlowColor;
  final Offset origin;

  EarthquakeCrackPainter({
    required this.progress,
    this.baseGlowColor = const Color(0xFFFF9100),
    this.origin = Offset.zero,
  });

  static final List<List<Offset>> _crackBranches = _generateCrackPaths();
  static final List<_DebrisSpec> _debris = _generateDebris();

  static List<List<Offset>> _generateCrackPaths() {
    final rand = math.Random(42);
    final branches = <List<Offset>>[];
    const int branchCount = 11;

    for (int b = 0; b < branchCount; b++) {
      final baseAngle =
          (b * 2 * math.pi / branchCount) + rand.nextDouble() * 0.35;
      final points = <Offset>[Offset.zero];
      double currentDist = 0.0;
      double currentAngle = baseAngle;

      final int segments = 5 + rand.nextInt(4);
      for (int s = 0; s < segments; s++) {
        currentDist += 22.0 + rand.nextDouble() * 38.0;
        currentAngle += (rand.nextDouble() - 0.5) * 0.55;
        points.add(Offset(
          math.cos(currentAngle) * currentDist,
          math.sin(currentAngle) * currentDist,
        ));

        // Occasional side fork for realism
        if (s > 1 && rand.nextDouble() < 0.35) {
          final forkAngle = currentAngle + (rand.nextBool() ? 0.7 : -0.7);
          final forkDist = currentDist + 18 + rand.nextDouble() * 28;
          points.add(Offset(
            math.cos(forkAngle) * forkDist,
            math.sin(forkAngle) * forkDist,
          ));
          // Return toward main branch for next segment continuity
          points.add(Offset(
            math.cos(currentAngle) * currentDist,
            math.sin(currentAngle) * currentDist,
          ));
        }
      }
      branches.add(points);
    }
    return branches;
  }

  static List<_DebrisSpec> _generateDebris() {
    final rand = math.Random(1337);
    return List.generate(42, (i) {
      return _DebrisSpec(
        angle: rand.nextDouble() * 2 * math.pi,
        speed: 70.0 + rand.nextDouble() * 200.0,
        size: 1.2 + rand.nextDouble() * 4.5,
        spin: (rand.nextDouble() - 0.5) * 8.0,
        warm: i % 3 != 0,
        gravity: 40 + rand.nextDouble() * 90,
      );
    });
  }

  @override
  void paint(Canvas canvas, Size size) {
    if (progress <= 0.0 || progress >= 1.0) return;

    final center =
        origin == Offset.zero ? Offset(size.width / 2, size.height / 2) : origin;
    final alpha = (1.0 - progress).clamp(0.0, 1.0);
    final flashAlpha = (1.0 - (progress * 2.8)).clamp(0.0, 1.0);
    final dustAlpha = (1.0 - progress).clamp(0.0, 1.0) * 0.55;

    // ── 1. Impact Flash / Radial Core Burst ─────────────────────────────
    if (flashAlpha > 0.0) {
      final burstR = 160 * (0.25 + progress * 1.1);
      final corePaint = Paint()
        ..shader = RadialGradient(
          colors: [
            const Color(0xFFFFF8E1).withValues(alpha: flashAlpha * 0.95),
            const Color(0xFFFFD54F).withValues(alpha: flashAlpha * 0.7),
            baseGlowColor.withValues(alpha: flashAlpha * 0.45),
            Colors.transparent,
          ],
          stops: const [0.0, 0.25, 0.55, 1.0],
        ).createShader(Rect.fromCircle(center: center, radius: burstR));
      canvas.drawCircle(center, burstR, corePaint);

      // Hot white pin-flash at the exact hit point
      final pinPaint = Paint()
        ..color = Colors.white.withValues(alpha: flashAlpha)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 8);
      canvas.drawCircle(center, 18 * (1.0 - progress * 0.5), pinPaint);
    }

    // ── 2. Expanding Shockwave Rings (staggered) ────────────────────────
    _drawShockRing(
      canvas,
      center,
      radius: 200.0 * (0.15 + progress * 0.95),
      alpha: ((1.0 - progress) * 0.85).clamp(0.0, 1.0),
      width: math.max(1.2, 7.0 * (1.0 - progress)),
      color: const Color(0xFFFFE082),
      blur: 5,
    );
    _drawShockRing(
      canvas,
      center,
      radius: 270.0 * (0.08 + progress * 1.05),
      alpha: ((1.0 - progress) * 0.55).clamp(0.0, 1.0),
      width: math.max(1.0, 4.0 * (1.0 - progress)),
      color: baseGlowColor,
      blur: 3,
    );
    _drawShockRing(
      canvas,
      center,
      radius: 340.0 * (0.05 + progress * 1.1),
      alpha: ((1.0 - progress) * 0.28).clamp(0.0, 1.0),
      width: math.max(0.8, 2.2 * (1.0 - progress)),
      color: const Color(0xFFFF6F00),
      blur: 2,
    );

    // ── 3. Dust plume / smoke under the hit ─────────────────────────────
    if (dustAlpha > 0.05) {
      final dustPaint = Paint()
        ..shader = RadialGradient(
          colors: [
            const Color(0xFF5D4037).withValues(alpha: dustAlpha * 0.55),
            const Color(0xFF8D6E63).withValues(alpha: dustAlpha * 0.28),
            Colors.transparent,
          ],
        ).createShader(Rect.fromCircle(
          center: center.translate(0, 12),
          radius: 90 + progress * 130,
        ));
      canvas.drawOval(
        Rect.fromCenter(
          center: center.translate(0, 18 + progress * 20),
          width: (110 + progress * 180) * 1.6,
          height: 55 + progress * 70,
        ),
        dustPaint,
      );
    }

    // ── 4. Glowing Ground Crack Fissures ────────────────────────────────
    final glowPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round
      ..strokeWidth = 7.0 * (1.0 - progress * 0.45)
      ..color = baseGlowColor.withValues(alpha: alpha * 0.75)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 6);

    final magmaPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round
      ..strokeWidth = math.max(1.5, 3.8 * (1.0 - progress * 0.4))
      ..color = const Color(0xFFFFAB40).withValues(alpha: alpha * 0.9);

    final coreLinePaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round
      ..strokeWidth = math.max(0.8, 1.8 * (1.0 - progress))
      ..color = const Color(0xFFFFFDE7).withValues(alpha: alpha);

    for (final branch in _crackBranches) {
      final path = Path();
      path.moveTo(center.dx, center.dy);

      // Cracks grow outward rapidly during first 40% of animation
      final growthProgress = (progress / 0.40).clamp(0.0, 1.0);
      final maxIndex =
          (branch.length * growthProgress).ceil().clamp(1, branch.length);

      for (int i = 1; i < maxIndex; i++) {
        final pt = branch[i];
        path.lineTo(center.dx + pt.dx, center.dy + pt.dy);
      }

      canvas.drawPath(path, glowPaint);
      canvas.drawPath(path, magmaPaint);
      canvas.drawPath(path, coreLinePaint);
    }

    // ── 5. Flying debris / sparks with gravity ──────────────────────────
    final sparkPaint = Paint()..style = PaintingStyle.fill;

    for (final d in _debris) {
      final dist = d.speed * progress;
      final fall = d.gravity * progress * progress;
      final px = center.dx + math.cos(d.angle) * dist;
      final py = center.dy + math.sin(d.angle) * dist + fall;
      final pRadius = math.max(0.5, d.size * (1.0 - progress * 0.85));
      final pAlpha = (1.0 - progress * 1.05).clamp(0.0, 1.0);

      sparkPaint.color = (d.warm
              ? const Color(0xFFFFEA00)
              : const Color(0xFFFF5722))
          .withValues(alpha: pAlpha);

      canvas.save();
      canvas.translate(px, py);
      canvas.rotate(d.spin * progress);
      if (d.warm) {
        canvas.drawCircle(Offset.zero, pRadius, sparkPaint);
      } else {
        // Angular rock chips
        canvas.drawRRect(
          RRect.fromRectAndRadius(
            Rect.fromCenter(
              center: Offset.zero,
              width: pRadius * 1.8,
              height: pRadius * 1.1,
            ),
            const Radius.circular(1),
          ),
          sparkPaint
            ..color = const Color(0xFF6D4C41).withValues(alpha: pAlpha * 0.9),
        );
      }
      canvas.restore();
    }
  }

  void _drawShockRing(
    Canvas canvas,
    Offset center, {
    required double radius,
    required double alpha,
    required double width,
    required Color color,
    required double blur,
  }) {
    if (alpha <= 0.01) return;
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = width
      ..color = color.withValues(alpha: alpha)
      ..maskFilter = MaskFilter.blur(BlurStyle.solid, blur);
    canvas.drawCircle(center, radius, paint);
  }

  @override
  bool shouldRepaint(covariant EarthquakeCrackPainter oldDelegate) {
    return oldDelegate.progress != progress ||
        oldDelegate.origin != origin ||
        oldDelegate.baseGlowColor != baseGlowColor;
  }
}

class _DebrisSpec {
  final double angle;
  final double speed;
  final double size;
  final double spin;
  final bool warm;
  final double gravity;

  const _DebrisSpec({
    required this.angle,
    required this.speed,
    required this.size,
    required this.spin,
    required this.warm,
    required this.gravity,
  });
}
