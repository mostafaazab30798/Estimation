// lib/widgets/double_round_overlay.dart
//
// Announcement overlay when all players pass — next round scores ×2.

import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../core/icons/app_icons.dart';
import '../core/utils/game_layout_metrics.dart';
import '../core/widgets/app_buttons.dart';
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
    with SingleTickerProviderStateMixin {
  static const _accent = Color(0xFFFF9100);
  static const _accentLight = Color(0xFFFFD54F);

  late final AnimationController _entrance;
  late final Animation<double> _fade;
  late final Animation<double> _scale;
  late final Animation<Offset> _slide;
  late final List<_Spark> _sparks;

  Timer? _autoDismissTimer;
  bool _dismissing = false;

  @override
  void initState() {
    super.initState();
    final rng = math.Random();
    _sparks = List.generate(
      16,
      (i) => _Spark(
        angle: (i / 16) * math.pi * 2 + rng.nextDouble() * 0.2,
        distance: 48 + rng.nextDouble() * 72,
        size: 2.5 + rng.nextDouble() * 3.5,
      ),
    );

    _entrance = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 520),
      reverseDuration: const Duration(milliseconds: 240),
    );
    final curve = CurvedAnimation(
      parent: _entrance,
      curve: Curves.easeOutCubic,
      reverseCurve: Curves.easeInCubic,
    );
    _fade = curve;
    _scale = Tween<double>(begin: 0.94, end: 1).animate(curve);
    _slide = Tween<Offset>(
      begin: const Offset(0, 0.05),
      end: Offset.zero,
    ).animate(curve);

    _entrance.forward();
    HapticFeedback.heavyImpact();
    _autoDismissTimer = Timer(widget.displayDuration, _dismiss);
  }

  void _dismiss() {
    if (_dismissing || !mounted) return;
    _dismissing = true;
    _autoDismissTimer?.cancel();
    _entrance.reverse().then((_) {
      if (mounted) widget.onDismissed?.call();
    });
  }

  @override
  void dispose() {
    _autoDismissTimer?.cancel();
    _entrance.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final layout = GameLayoutMetrics.of(context);
    final maxWidth = layout.isLargeTablet
        ? 520.0
        : (layout.isTablet ? 460.0 : 390.0);
    final horizontalInset = layout.isTablet ? 28.0 : 22.0;

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: _dismiss,
      child: Material(
        color: Colors.transparent,
        child: Stack(
          alignment: Alignment.center,
          children: [
            FadeTransition(
              opacity: _fade,
              child: ColoredBox(
                color: AppTheme.deepNavy.withValues(alpha: 0.78),
              ),
            ),
            IgnorePointer(
              child: AnimatedBuilder(
                animation: _entrance,
                builder: (context, _) => CustomPaint(
                  size: MediaQuery.sizeOf(context),
                  painter: _SparkPainter(
                    sparks: _sparks,
                    progress: _entrance.value,
                  ),
                ),
              ),
            ),
            SafeArea(
              child: FadeTransition(
                opacity: _fade,
                child: SlideTransition(
                  position: _slide,
                  child: ScaleTransition(
                    scale: _scale,
                    child: Container(
                      width: double.infinity,
                      constraints: BoxConstraints(maxWidth: maxWidth),
                      margin: EdgeInsets.symmetric(horizontal: horizontalInset),
                      decoration: AppTheme.dialogDecoration(accent: _accent),
                      padding: EdgeInsets.fromLTRB(
                        layout.isTablet ? 28 : 24,
                        layout.isTablet ? 24 : 20,
                        layout.isTablet ? 28 : 24,
                        layout.isTablet ? 22 : 20,
                      ),
                      child: Column(
                            mainAxisSize: MainAxisSize.min,
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              Row(
                                children: [
                                  AppIconWell(
                                    icon: AppIcons.bolt,
                                    size: layout.isTablet ? 54 : 48,
                                    iconSize: layout.isTablet ? 26 : 22,
                                    color: _accentLight,
                                    fill: _accent.withValues(alpha: 0.16),
                                    borderColor: _accent.withValues(alpha: 0.38),
                                  ),
                                  const Spacer(),
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 10,
                                      vertical: 6,
                                    ),
                                    decoration: BoxDecoration(
                                      color: _accent.withValues(alpha: 0.14),
                                      borderRadius: BorderRadius.circular(20),
                                      border: Border.all(
                                        color: _accent.withValues(alpha: 0.32),
                                      ),
                                    ),
                                    child: Text(
                                      'ALL PASS',
                                      style: AppFonts.cooper(
                                        color: _accentLight,
                                        fontSize: 10,
                                        fontWeight: FontWeight.w800,
                                        letterSpacing: 0.8,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              SizedBox(height: layout.isTablet ? 22 : 18),
                              Text(
                                'EVERYONE PASSED',
                                textAlign: TextAlign.center,
                                style: AppFonts.cinzel(
                                  fontSize: layout.isTablet ? 24 : 21,
                                  fontWeight: FontWeight.w900,
                                  letterSpacing: 1.6,
                                  color: AppTheme.cream,
                                  height: 1.1,
                                ),
                              ),
                              const SizedBox(height: 6),
                              Text(
                                'الجميع مرر المزاد (Pass)',
                                textAlign: TextAlign.center,
                                style: AppFonts.cooper(
                                  fontSize: layout.isTablet ? 14 : 13,
                                  fontWeight: FontWeight.w700,
                                  color: AppTheme.steelBlue,
                                  height: 1.3,
                                ),
                              ),
                              SizedBox(height: layout.isTablet ? 20 : 16),
                              Container(
                                padding: EdgeInsets.symmetric(
                                  horizontal: layout.isTablet ? 18 : 14,
                                  vertical: layout.isTablet ? 14 : 12,
                                ),
                                decoration: BoxDecoration(
                                  gradient: LinearGradient(
                                    colors: [
                                      _accent.withValues(alpha: 0.22),
                                      const Color(0xFFFF3D00).withValues(alpha: 0.14),
                                    ],
                                    begin: Alignment.topLeft,
                                    end: Alignment.bottomRight,
                                  ),
                                  borderRadius: BorderRadius.circular(18),
                                  border: Border.all(
                                    color: _accent.withValues(alpha: 0.42),
                                  ),
                                ),
                                child: Column(
                                  children: [
                                    Text(
                                      'DOUBLE ROUND NEXT',
                                      textAlign: TextAlign.center,
                                      style: AppFonts.cooper(
                                        fontSize: layout.isTablet ? 16 : 14,
                                        fontWeight: FontWeight.w900,
                                        color: AppTheme.cream,
                                        letterSpacing: 0.6,
                                        height: 1.2,
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      'جولة مضاعفة تالية',
                                      textAlign: TextAlign.center,
                                      style: AppFonts.cooper(
                                        fontSize: layout.isTablet ? 13 : 12,
                                        fontWeight: FontWeight.w700,
                                        color: AppTheme.cream.withValues(alpha: 0.9),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              SizedBox(height: layout.isTablet ? 18 : 14),
                              Container(
                                padding: EdgeInsets.all(layout.isTablet ? 16 : 14),
                                decoration: BoxDecoration(
                                  color: AppTheme.deepNavy.withValues(alpha: 0.46),
                                  borderRadius: BorderRadius.circular(18),
                                  border: Border.all(
                                    color: AppTheme.steelBlue.withValues(alpha: 0.14),
                                  ),
                                ),
                                child: Column(
                                  children: [
                                    Text(
                                      'All scores in the next round\nwill be multiplied ×2.',
                                      textAlign: TextAlign.center,
                                      style: AppFonts.cooper(
                                        fontSize: layout.isTablet ? 14 : 13,
                                        fontWeight: FontWeight.w700,
                                        color: AppTheme.cream,
                                        height: 1.35,
                                      ),
                                    ),
                                    const SizedBox(height: 6),
                                    Text(
                                      'ستتم مضاعفة جميع النقاط في الجولة القادمة ×2.',
                                      textAlign: TextAlign.center,
                                      style: AppFonts.cooper(
                                        fontSize: layout.isTablet ? 12 : 11,
                                        fontWeight: FontWeight.w600,
                                        color: AppTheme.steelBlue,
                                        height: 1.35,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              SizedBox(height: layout.isTablet ? 16 : 14),
                              Center(
                                child: Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 12,
                                    vertical: 6,
                                  ),
                                  decoration: BoxDecoration(
                                    color: AppTheme.gold.withValues(alpha: 0.12),
                                    borderRadius: BorderRadius.circular(999),
                                    border: Border.all(
                                      color: AppTheme.gold.withValues(alpha: 0.38),
                                    ),
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      const AppIcon(
                                        AppIcons.bolt,
                                        size: 14,
                                        color: AppTheme.gold,
                                        strokeWidth: AppIconTokens.strokeBold,
                                      ),
                                      const SizedBox(width: 6),
                                      Text(
                                        '×2 ROUND ACTIVE',
                                        style: AppFonts.cooper(
                                          fontSize: 11,
                                          fontWeight: FontWeight.w800,
                                          color: AppTheme.gold,
                                          letterSpacing: 0.6,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ],
                          ),
                    ),
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

class _Spark {
  const _Spark({
    required this.angle,
    required this.distance,
    required this.size,
  });

  final double angle;
  final double distance;
  final double size;
}

class _SparkPainter extends CustomPainter {
  _SparkPainter({required this.sparks, required this.progress});

  final List<_Spark> sparks;
  final double progress;

  @override
  void paint(Canvas canvas, Size size) {
    if (progress <= 0) return;
    final center = Offset(size.width / 2, size.height / 2);
    final paint = Paint()..style = PaintingStyle.fill;
    final t = Curves.easeOutCubic.transform(progress.clamp(0.0, 1.0));
    final opacity = (1 - progress).clamp(0.0, 1.0);

    for (var i = 0; i < sparks.length; i++) {
      final spark = sparks[i];
      final dist = spark.distance * t;
      paint.color = (i.isEven
              ? const Color(0xFFFFD700)
              : const Color(0xFFFF9100))
          .withValues(alpha: opacity * 0.85);
      canvas.drawCircle(
        Offset(
          center.dx + dist * math.cos(spark.angle),
          center.dy + dist * math.sin(spark.angle),
        ),
        spark.size * (1 - progress * 0.3),
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _SparkPainter oldDelegate) =>
      oldDelegate.progress != progress;
}
