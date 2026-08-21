// lib/widgets/hud/casino_table.dart
//
// Premium casino table painter — replaces the original _PremiumTablePainter
// with a richer layered oval: wooden frame → navy felt → gold stitching →
// inner radial glow. Phase-reactive felt glow is driven by [glowColor].
// Subtle Trump watermark in felt center when a trump contract is active.

import 'package:flutter/material.dart';
import '../../core/constants.dart';
import '../../theme/app_theme.dart';

/// Singleton painter factory. Call [CasinoTablePainter.forPhase] to get a
/// cached painter that repaints only when the glow color changes.
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

    // ── 1. Table drop shadow ─────────────────────────────────────
    final shadowPaint = Paint()
      ..color = Colors.black.withValues(alpha: 0.65)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 28);
    canvas.drawOval(tableRect.translate(0, 14), shadowPaint);

    // ── 2. Wooden frame (outer ring) ─────────────────────────────
    final frameRect = tableRect;
    final frameGradient = const RadialGradient(
      center: Alignment(-0.3, -0.5),
      radius: 1.1,
      colors: [
        Color(0xFF3D2314), // lighter wood highlight
        Color(0xFF2C1810), // mid tone
        Color(0xFF1A0F09), // dark shadow
      ],
      stops: [0.0, 0.55, 1.0],
    ).createShader(frameRect);

    canvas.drawOval(
      frameRect,
      Paint()
        ..shader = frameGradient
        ..style = PaintingStyle.fill,
    );

    // Thin bright edge on wood (top-left highlight)
    canvas.drawOval(
      frameRect,
      Paint()
        ..color = const Color(0xFF8B5E3C).withValues(alpha: 0.35)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.5,
    );

    // ── 3. Felt surface ──────────────────────────────────────────
    final feltRect = tableRect.deflate(14);

    final feltGradient = RadialGradient(
      center: const Alignment(0, -0.2),
      radius: 0.9,
      colors: [
        AppTheme.surface2.withValues(alpha: 0.92),
        AppTheme.deepNavy,
        const Color(0xFF141E2A),
      ],
      stops: const [0.0, 0.6, 1.0],
    ).createShader(feltRect);

    canvas.drawOval(
      feltRect,
      Paint()
        ..shader = feltGradient
        ..style = PaintingStyle.fill,
    );

    // ── 4. Phase-reactive inner glow ─────────────────────────────
    if (glowColor != AppTheme.deepNavy) {
      final glowGradient = RadialGradient(
        center: Alignment.center,
        radius: 0.8,
        colors: [
          glowColor.withValues(alpha: 0.08),
          Colors.transparent,
        ],
      ).createShader(feltRect);

      canvas.drawOval(
        feltRect,
        Paint()
          ..shader = glowGradient
          ..style = PaintingStyle.fill,
      );
    }

    // ── 5. Center Trump Watermark ─────────────────────────────────
    if (trump != null) {
      final center = feltRect.center;
      final watermarkSymbol = _trumpSymbol(trump!);
      final isRed = trump == Trump.heart || trump == Trump.diamond;
      final watermarkColor = (isRed ? AppTheme.suitRed : AppTheme.accentLight)
          .withValues(alpha: 0.065);

      final textSpan = TextSpan(
        text: watermarkSymbol,
        style: TextStyle(
          fontSize: isPortrait ? 95 : 120,
          fontWeight: FontWeight.bold,
          color: watermarkColor,
          height: 1.0,
        ),
      );
      final textPainter = TextPainter(
        text: textSpan,
        textAlign: TextAlign.center,
        textDirection: TextDirection.ltr,
      )..layout();

      final textOffset = Offset(
        center.dx - textPainter.width / 2,
        center.dy - textPainter.height / 2 - (isPortrait ? 8 : 0),
      );
      textPainter.paint(canvas, textOffset);
    }

    // ── 6. Gold stitching ring ────────────────────────────────────
    final stitchRect = feltRect.deflate(12);
    final stitchPaint = Paint()
      ..color = AppTheme.gold.withValues(alpha: 0.22)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5;
    canvas.drawOval(stitchRect, stitchPaint);

    // Dashes on the stitching ring
    _drawDashedOval(
      canvas,
      stitchRect.deflate(4),
      Paint()
        ..color = AppTheme.gold.withValues(alpha: 0.10)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 0.8,
    );

    // ── 7. Inner light reflection (top highlight) ─────────────────
    final reflectGradient = RadialGradient(
      center: const Alignment(0, -0.7),
      radius: 0.6,
      colors: [
        AppTheme.steelBlue.withValues(alpha: 0.06),
        Colors.transparent,
      ],
    ).createShader(feltRect);

    canvas.drawOval(
      feltRect,
      Paint()
        ..shader = reflectGradient
        ..style = PaintingStyle.fill,
    );
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
    const segments = 36;
    const dashFraction = 0.55;
    final path = Path();
    for (int i = 0; i < segments; i++) {
      final startAngle = (i / segments) * 2 * 3.1416;
      final sweepAngle = (1 / segments) * 2 * 3.1416 * dashFraction;
      path.addArc(rect, startAngle, sweepAngle);
    }
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(CasinoTablePainter old) =>
      old.glowColor != glowColor || old.trump != trump;
}
