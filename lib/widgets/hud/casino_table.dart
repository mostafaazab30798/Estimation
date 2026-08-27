// lib/widgets/hud/casino_table.dart
//
// Premium "Midnight Salon" casino table — walnut rail, sapphire felt,
// gold inlay, and a soft center play zone. Phase-reactive glow only.
// No game logic.

import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../../core/constants.dart';
import '../../theme/app_theme.dart';

class CasinoTablePainter extends CustomPainter {
  final Color glowColor;
  final Trump? trump;

  const CasinoTablePainter({
    this.glowColor = AppTheme.deepNavy,
    this.trump,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final isPortrait = size.height > size.width;

    final Rect tableRect;
    if (isPortrait) {
      final radius = size.width * 0.44;
      tableRect = Rect.fromCircle(
        center: Offset(size.width / 2, size.height * 0.41),
        radius: radius,
      );
    } else {
      tableRect = Rect.fromCenter(
        center: Offset(size.width / 2, size.height / 2),
        width: size.width * 0.74,
        height: size.height * 0.83,
      );
    }

    // ── 1. Soft floor shadow ─────────────────────────────────────
    final shadowPaint = Paint()
      ..color = Colors.black.withValues(alpha: 0.55)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 32);
    canvas.drawOval(tableRect.translate(0, 16), shadowPaint);

    // Secondary tighter shadow for depth
    canvas.drawOval(
      tableRect.translate(0, 6),
      Paint()
        ..color = Colors.black.withValues(alpha: 0.35)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 12),
    );

    // ── 2. Walnut rail (outer ring) ──────────────────────────────
    final frameGradient = const RadialGradient(
      center: Alignment(-0.35, -0.55),
      radius: 1.15,
      colors: [
        Color(0xFF5A3824),
        Color(0xFF3A2416),
        Color(0xFF1E120B),
      ],
      stops: [0.0, 0.5, 1.0],
    ).createShader(tableRect);

    canvas.drawOval(
      tableRect,
      Paint()
        ..shader = frameGradient
        ..style = PaintingStyle.fill,
    );

    // Outer rim highlight
    canvas.drawOval(
      tableRect,
      Paint()
        ..color = const Color(0xFFC4A484).withValues(alpha: 0.28)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.0,
    );

    // Inner wood bevel
    canvas.drawOval(
      tableRect.deflate(6),
      Paint()
        ..color = const Color(0xFF1A0F09).withValues(alpha: 0.55)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3.5,
    );

    // ── 3. Sapphire felt ─────────────────────────────────────────
    final feltRect = tableRect.deflate(13);

    final feltGradient = RadialGradient(
      center: const Alignment(0, -0.25),
      radius: 0.95,
      colors: [
        const Color(0xFF2E4A63),
        AppTheme.deepNavy,
        const Color(0xFF101820),
      ],
      stops: const [0.0, 0.55, 1.0],
    ).createShader(feltRect);

    canvas.drawOval(
      feltRect,
      Paint()
        ..shader = feltGradient
        ..style = PaintingStyle.fill,
    );

    // Subtle felt grain (deterministic, cheap)
    _drawFeltGrain(canvas, feltRect);

    // ── 4. Phase-reactive ambient wash ───────────────────────────
    if (glowColor != AppTheme.deepNavy) {
      canvas.drawOval(
        feltRect,
        Paint()
          ..shader = RadialGradient(
            center: Alignment.center,
            radius: 0.85,
            colors: [
              glowColor.withValues(alpha: 0.10),
              glowColor.withValues(alpha: 0.03),
              Colors.transparent,
            ],
            stops: const [0.0, 0.45, 1.0],
          ).createShader(feltRect),
      );
    }

    // ── 5. Center play zone (soft oval) ──────────────────────────
    final playZone = Rect.fromCenter(
      center: feltRect.center.translate(0, isPortrait ? -6 : 0),
      width: feltRect.width * 0.42,
      height: feltRect.height * 0.42,
    );
    canvas.drawOval(
      playZone,
      Paint()
        ..shader = RadialGradient(
          colors: [
            Colors.black.withValues(alpha: 0.18),
            Colors.transparent,
          ],
        ).createShader(playZone),
    );
    canvas.drawOval(
      playZone,
      Paint()
        ..color = AppTheme.gold.withValues(alpha: 0.08)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.0,
    );

    // ── 6. Trump watermark ───────────────────────────────────────
    if (trump != null) {
      final center = feltRect.center;
      final watermarkSymbol = _trumpSymbol(trump!);
      final isRed = trump == Trump.heart || trump == Trump.diamond;
      final watermarkColor = (isRed ? AppTheme.suitRed : AppTheme.accentLight)
          .withValues(alpha: 0.07);

      final textPainter = TextPainter(
        text: TextSpan(
          text: watermarkSymbol,
          style: TextStyle(
            fontSize: isPortrait ? 88 : 110,
            fontWeight: FontWeight.w700,
            color: watermarkColor,
            height: 1.0,
          ),
        ),
        textAlign: TextAlign.center,
        textDirection: TextDirection.ltr,
      )..layout();

      textPainter.paint(
        canvas,
        Offset(
          center.dx - textPainter.width / 2,
          center.dy - textPainter.height / 2 - (isPortrait ? 8 : 0),
        ),
      );
    }

    // ── 7. Gold inlay + dashed stitching ─────────────────────────
    final stitchRect = feltRect.deflate(10);
    canvas.drawOval(
      stitchRect,
      Paint()
        ..color = AppTheme.gold.withValues(alpha: 0.28)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.4,
    );
    _drawDashedOval(
      canvas,
      stitchRect.deflate(5),
      Paint()
        ..color = AppTheme.gold.withValues(alpha: 0.12)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 0.9,
    );

    // ── 8. Top-edge light kiss ───────────────────────────────────
    canvas.drawOval(
      feltRect,
      Paint()
        ..shader = RadialGradient(
          center: const Alignment(0, -0.72),
          radius: 0.55,
          colors: [
            AppTheme.steelBlue.withValues(alpha: 0.08),
            Colors.transparent,
          ],
        ).createShader(feltRect),
    );
  }

  void _drawFeltGrain(Canvas canvas, Rect rect) {
    final paint = Paint()..style = PaintingStyle.fill;
    final rng = math.Random(17);
    final count = 48;
    for (int i = 0; i < count; i++) {
      final t = rng.nextDouble() * math.pi * 2;
      final r = math.sqrt(rng.nextDouble()) * 0.92;
      final x = rect.center.dx + math.cos(t) * (rect.width / 2) * r;
      final y = rect.center.dy + math.sin(t) * (rect.height / 2) * r;
      paint.color = AppTheme.steelBlue.withValues(
        alpha: 0.015 + rng.nextDouble() * 0.025,
      );
      canvas.drawCircle(Offset(x, y), 0.8 + rng.nextDouble() * 1.6, paint);
    }
  }

  static String _trumpSymbol(Trump trump) {
    switch (trump) {
      case Trump.spade:
        return '♠';
      case Trump.heart:
        return '♥';
      case Trump.diamond:
        return '♦';
      case Trump.club:
        return '♣';
      case Trump.sans:
        return 'SANS';
    }
  }

  void _drawDashedOval(Canvas canvas, Rect rect, Paint paint) {
    const segments = 40;
    const dashFraction = 0.5;
    final path = Path();
    for (int i = 0; i < segments; i++) {
      final startAngle = (i / segments) * 2 * math.pi;
      final sweepAngle = (1 / segments) * 2 * math.pi * dashFraction;
      path.addArc(rect, startAngle, sweepAngle);
    }
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(CasinoTablePainter old) =>
      old.glowColor != glowColor || old.trump != trump;
}
