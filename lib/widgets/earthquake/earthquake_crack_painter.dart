// lib/widgets/earthquake/earthquake_crack_painter.dart
//
// CustomPainter rendering glowing ground fissures, layered shockwaves,
// dust plumes, and debris radiating from the card slam point.

import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../../models/earthquake_effect.dart';

class EarthquakeCrackPainter extends CustomPainter {
  /// Progress from 0.0 (impact) to 1.0 (fully faded)
  final double progress;
  final EarthquakeEffect effect;
  final Offset origin;

  EarthquakeCrackPainter({
    required this.progress,
    this.effect = EarthquakeEffect.magma,
    this.origin = Offset.zero,
  });

  Color get _glowColor => effect.primaryColor;
  Color get _highlightColor => effect.secondaryColor;

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
    switch (effect) {
      case EarthquakeEffect.magma:
        _paintMagma(canvas, size);
        break;
      case EarthquakeEffect.frost:
        _paintFrost(canvas, size);
        break;
      case EarthquakeEffect.voidRift:
        _paintVoidRift(canvas, size);
        break;
    }
  }

  void _paintMagma(Canvas canvas, Size size) {
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
            Colors.white.withValues(alpha: flashAlpha * 0.95),
            _highlightColor.withValues(alpha: flashAlpha * 0.7),
            _glowColor.withValues(alpha: flashAlpha * 0.45),
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
      color: _highlightColor,
      blur: 5,
    );
    _drawShockRing(
      canvas,
      center,
      radius: 270.0 * (0.08 + progress * 1.05),
      alpha: ((1.0 - progress) * 0.55).clamp(0.0, 1.0),
      width: math.max(1.0, 4.0 * (1.0 - progress)),
      color: _glowColor,
      blur: 3,
    );
    _drawShockRing(
      canvas,
      center,
      radius: 340.0 * (0.05 + progress * 1.1),
      alpha: ((1.0 - progress) * 0.28).clamp(0.0, 1.0),
      width: math.max(0.8, 2.2 * (1.0 - progress)),
      color: effect.debrisColor,
      blur: 2,
    );

    // ── 3. Dust plume / smoke under the hit ─────────────────────────────
    if (dustAlpha > 0.05) {
      final dustColors = switch (effect) {
        EarthquakeEffect.magma => [
            const Color(0xFF5D4037).withValues(alpha: dustAlpha * 0.55),
            const Color(0xFF8D6E63).withValues(alpha: dustAlpha * 0.28),
            Colors.transparent,
          ],
        EarthquakeEffect.frost => [
            const Color(0xFFBAE6FD).withValues(alpha: dustAlpha * 0.42),
            const Color(0xFF7DD3FC).withValues(alpha: dustAlpha * 0.18),
            Colors.transparent,
          ],
        EarthquakeEffect.voidRift => [
            const Color(0xFF2E1065).withValues(alpha: dustAlpha * 0.62),
            const Color(0xFF7E22CE).withValues(alpha: dustAlpha * 0.24),
            Colors.transparent,
          ],
      };
      final dustPaint = Paint()
        ..shader = RadialGradient(
          colors: dustColors,
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
      ..color = _glowColor.withValues(alpha: alpha * 0.75)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 6);

    final magmaPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round
      ..strokeWidth = math.max(1.5, 3.8 * (1.0 - progress * 0.4))
      ..color = _highlightColor.withValues(alpha: alpha * 0.9);

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

      sparkPaint.color = (d.warm ? _highlightColor : effect.debrisColor)
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
            ..color = effect.debrisColor.withValues(alpha: pAlpha * 0.9),
        );
      }
      canvas.restore();
    }
  }

  void _paintFrost(Canvas canvas, Size size) {
    if (progress <= 0.0 || progress >= 1.0) return;

    final center =
        origin == Offset.zero ? Offset(size.width / 2, size.height / 2) : origin;
    final fade = (1.0 - progress).clamp(0.0, 1.0);
    final expansion = Curves.easeOutCubic.transform(progress);
    final rand = math.Random(8080);

    final flashRadius = 42.0 + expansion * 130.0;
    final flashPaint = Paint()
      ..shader = RadialGradient(
        colors: [
          Colors.white.withValues(alpha: fade * 0.85),
          const Color(0xFFBAE6FD).withValues(alpha: fade * 0.55),
          const Color(0xFF0EA5E9).withValues(alpha: fade * 0.16),
          Colors.transparent,
        ],
        stops: const [0.0, 0.22, 0.62, 1.0],
      ).createShader(Rect.fromCircle(center: center, radius: flashRadius));
    canvas.drawCircle(center, flashRadius, flashPaint);

    // A faceted frozen shock front, intentionally polygonal rather than circular.
    for (int ring = 0; ring < 2; ring++) {
      final radius = (70.0 + ring * 55.0) + expansion * (145.0 + ring * 45.0);
      final sides = 10 + ring * 4;
      final path = Path();
      for (int i = 0; i <= sides; i++) {
        final angle = i * math.pi * 2 / sides + ring * 0.12;
        final jitter = i.isEven ? 1.0 : 0.82;
        final point = center + Offset(math.cos(angle), math.sin(angle)) * radius * jitter;
        if (i == 0) {
          path.moveTo(point.dx, point.dy);
        } else {
          path.lineTo(point.dx, point.dy);
        }
      }
      canvas.drawPath(
        path,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = math.max(1.0, (5.0 - ring * 1.5) * fade)
          ..strokeJoin = StrokeJoin.bevel
          ..color = (ring == 0 ? const Color(0xFFE0F2FE) : const Color(0xFF38BDF8))
              .withValues(alpha: fade * (0.8 - ring * 0.2))
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 3),
      );
    }

    // Long ice lances erupt from the impact point.
    for (int i = 0; i < 18; i++) {
      final angle = (i / 18) * math.pi * 2 + rand.nextDouble() * 0.16;
      final length = (70.0 + rand.nextDouble() * 170.0) * expansion;
      final width = 5.0 + rand.nextDouble() * 11.0;
      final direction = Offset(math.cos(angle), math.sin(angle));
      final normal = Offset(-direction.dy, direction.dx);
      final base = center + direction * 18.0;
      final tip = center + direction * length;
      final shard = Path()
        ..moveTo((base + normal * width).dx, (base + normal * width).dy)
        ..lineTo(tip.dx, tip.dy)
        ..lineTo((base - normal * width).dx, (base - normal * width).dy)
        ..close();
      canvas.drawPath(
        shard,
        Paint()
          ..shader = LinearGradient(
            colors: [
              Colors.white.withValues(alpha: fade * 0.9),
              const Color(0xFF7DD3FC).withValues(alpha: fade * 0.58),
              const Color(0xFF0284C7).withValues(alpha: fade * 0.12),
            ],
          ).createShader(shard.getBounds()),
      );
    }

    // Suspended snow crystals drift upward after the burst.
    for (int i = 0; i < 34; i++) {
      final angle = rand.nextDouble() * math.pi * 2;
      final distance = (35.0 + rand.nextDouble() * 230.0) * expansion;
      final lift = progress * (25.0 + rand.nextDouble() * 70.0);
      final point = center + Offset(math.cos(angle), math.sin(angle)) * distance - Offset(0, lift);
      final radius = 1.0 + rand.nextDouble() * 3.2;
      canvas.drawCircle(
        point,
        radius,
        Paint()..color = Colors.white.withValues(alpha: fade * 0.8),
      );
    }
  }

  void _paintVoidRift(Canvas canvas, Size size) {
    if (progress <= 0.0 || progress >= 1.0) return;

    final center =
        origin == Offset.zero ? Offset(size.width / 2, size.height / 2) : origin;
    final fade = (1.0 - progress).clamp(0.0, 1.0);
    final growth = Curves.easeOutExpo.transform((progress / 0.42).clamp(0.0, 1.0));
    final separation = math.sin(progress * math.pi) * 16.0;
    final extent = math.max(size.width, size.height) * 0.62;

    // Stable tear nodes create one strong diagonal silhouette through the hit point.
    final fullSpine = <Offset>[
      center + Offset(-extent * 0.34, -extent),
      center + Offset(-extent * 0.21, -extent * 0.72),
      center + Offset(-extent * 0.30, -extent * 0.45),
      center + Offset(-extent * 0.08, -extent * 0.22),
      center,
      center + Offset(extent * 0.16, extent * 0.19),
      center + Offset(extent * 0.05, extent * 0.43),
      center + Offset(extent * 0.28, extent * 0.70),
      center + Offset(extent * 0.18, extent),
    ];
    final visibleCount = (fullSpine.length * growth)
        .ceil()
        .clamp(2, fullSpine.length)
        .toInt();
    final spine = fullSpine.take(visibleCount).toList();

    Offset normalAt(int index) {
      final before = spine[index == 0 ? 0 : index - 1];
      final after = spine[index == spine.length - 1 ? index : index + 1];
      final direction = after - before;
      final length = direction.distance == 0 ? 1.0 : direction.distance;
      return Offset(-direction.dy / length, direction.dx / length);
    }

    final leftEdge = <Offset>[];
    final rightEdge = <Offset>[];
    for (int i = 0; i < spine.length; i++) {
      final normal = normalAt(i);
      final jaggedWidth = (i.isEven ? 7.0 : 14.0) + separation;
      leftEdge.add(spine[i] + normal * jaggedWidth);
      rightEdge.add(spine[i] - normal * jaggedWidth);
    }

    // The dark opening between both torn edges.
    final opening = Path()..moveTo(leftEdge.first.dx, leftEdge.first.dy);
    for (final point in leftEdge.skip(1)) {
      opening.lineTo(point.dx, point.dy);
    }
    for (final point in rightEdge.reversed) {
      opening.lineTo(point.dx, point.dy);
    }
    opening.close();
    canvas.drawPath(
      opening,
      Paint()
        ..shader = const LinearGradient(
          colors: [
            Color(0xFF020617),
            Color(0xFF2E1065),
            Color(0xFFD946EF),
            Color(0xFF2E1065),
            Color(0xFF020617),
          ],
          stops: [0.0, 0.24, 0.5, 0.76, 1.0],
        ).createShader(opening.getBounds()),
    );

    final edgeGlow = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 9
      ..strokeJoin = StrokeJoin.round
      ..color = const Color(0xFFA855F7).withValues(alpha: fade * 0.72)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 8);
    final edgeCore = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.2
      ..strokeJoin = StrokeJoin.round
      ..color = const Color(0xFFF5D0FE).withValues(alpha: fade * 0.95);

    for (final edge in [leftEdge, rightEdge]) {
      final path = Path()..moveTo(edge.first.dx, edge.first.dy);
      for (final point in edge.skip(1)) {
        path.lineTo(point.dx, point.dy);
      }
      canvas.drawPath(path, edgeGlow);
      canvas.drawPath(path, edgeCore);
    }

    // Secondary fractures grow from fixed nodes on alternating sides of the tear.
    const branchSpecs = <(int, double, double)>[
      (1, -2.55, 150),
      (2, 0.18, 120),
      (3, -2.95, 205),
      (4, 0.08, 230),
      (5, 2.85, 170),
      (6, -0.28, 190),
      (7, 2.72, 130),
    ];
    for (final spec in branchSpecs) {
      final nodeIndex = spec.$1;
      if (nodeIndex >= spine.length) continue;
      final branchGrowth = ((growth - nodeIndex * 0.055) / 0.62)
          .clamp(0.0, 1.0)
          .toDouble();
      if (branchGrowth <= 0) continue;

      final start = spine[nodeIndex];
      final direction = Offset(math.cos(spec.$2), math.sin(spec.$2));
      final middle = start + direction * spec.$3 * 0.48 * branchGrowth +
          Offset(direction.dy, -direction.dx) * (nodeIndex.isEven ? 18.0 : -18.0);
      final end = start + direction * spec.$3 * branchGrowth;
      final branch = Path()
        ..moveTo(start.dx, start.dy)
        ..lineTo(middle.dx, middle.dy)
        ..lineTo(end.dx, end.dy);
      canvas.drawPath(
        branch,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 5
          ..strokeCap = StrokeCap.round
          ..color = const Color(0xFF7E22CE).withValues(alpha: fade * 0.45)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 5),
      );
      canvas.drawPath(
        branch,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.4
          ..strokeCap = StrokeCap.round
          ..color = const Color(0xFFE879F9).withValues(alpha: fade * 0.9),
      );
    }

    // Surface shards slide away from the tear, reinforcing that the screen split open.
    final rand = math.Random(909);
    for (int i = 0; i < 20; i++) {
      final node = spine[i % spine.length];
      final side = i.isEven ? 1.0 : -1.0;
      final normal = normalAt(i % spine.length) * side;
      final travel = separation * (0.8 + rand.nextDouble() * 1.8);
      final shardCenter = node + normal * (24.0 + travel) +
          Offset(rand.nextDouble() * 36 - 18, rand.nextDouble() * 42 - 21);
      final shardSize = 5.0 + rand.nextDouble() * 13.0;
      final shard = Path()
        ..moveTo(shardCenter.dx, shardCenter.dy - shardSize)
        ..lineTo(shardCenter.dx + shardSize * 0.8, shardCenter.dy + shardSize * 0.5)
        ..lineTo(shardCenter.dx - shardSize * 0.65, shardCenter.dy + shardSize)
        ..close();
      canvas.drawPath(
        shard,
        Paint()
          ..color = const Color(0xFF6D28D9).withValues(alpha: fade * 0.48)
          ..style = PaintingStyle.fill,
      );
      canvas.drawPath(
        shard,
        Paint()
          ..color = const Color(0xFFD8B4FE).withValues(alpha: fade * 0.55)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 0.8,
      );
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
        oldDelegate.effect != effect;
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
