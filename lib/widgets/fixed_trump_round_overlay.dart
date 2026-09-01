// lib/widgets/fixed_trump_round_overlay.dart
//
// Announcement overlay for championship fixed-trump rounds (14–18).

import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';

import '../core/constants.dart';
import '../core/utils/game_layout_metrics.dart';
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
    with SingleTickerProviderStateMixin {
  late final AnimationController _entrance;
  late final Animation<double> _fade;
  late final Animation<double> _scale;
  late final Animation<Offset> _slide;
  late final List<_Spark> _sparks;

  Timer? _autoDismissTimer;
  bool _dismissing = false;

  _TrumpTheme get _theme => _themeFor(widget.fixedTrump);

  @override
  void initState() {
    super.initState();
    final rng = math.Random();
    _sparks = List.generate(
      14,
      (i) => _Spark(
        angle: (i / 14) * math.pi * 2 + rng.nextDouble() * 0.2,
        distance: 48 + rng.nextDouble() * 72,
        size: 2.5 + rng.nextDouble() * 3.5,
        color: i.isEven ? _theme.primaryColor : _theme.accentColor,
      ),
    );

    _entrance = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 540),
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
    final theme = _theme;
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
                      decoration: AppTheme.dialogDecoration(accent: theme.primaryColor),
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
                          Center(
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 10,
                                vertical: 5,
                              ),
                              decoration: BoxDecoration(
                                color: AppTheme.gold.withValues(alpha: 0.12),
                                borderRadius: BorderRadius.circular(20),
                                border: Border.all(
                                  color: AppTheme.gold.withValues(alpha: 0.38),
                                ),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  const Text('👑', style: TextStyle(fontSize: 11)),
                                  const SizedBox(width: 6),
                                  Text(
                                    'CHAMPIONSHIP PHASE',
                                    style: GoogleFonts.cairo(
                                      color: AppTheme.gold,
                                      fontSize: 10.5,
                                      fontWeight: FontWeight.w900,
                                      letterSpacing: 0.7,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                          SizedBox(height: layout.isTablet ? 20 : 16),
                          Center(
                            child: Container(
                              width: layout.isTablet ? 72 : 64,
                              height: layout.isTablet ? 72 : 64,
                              alignment: Alignment.center,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                gradient: LinearGradient(
                                  colors: [
                                    theme.primaryColor,
                                    theme.secondaryColor,
                                  ],
                                ),
                                boxShadow: [
                                  BoxShadow(
                                    color: theme.primaryColor.withValues(alpha: 0.45),
                                    blurRadius: 18,
                                  ),
                                ],
                              ),
                              child: Text(
                                theme.suitSymbol,
                                style: TextStyle(
                                  fontSize: widget.fixedTrump == Trump.sans ? 34 : 38,
                                  color: Colors.white,
                                  height: 1,
                                ),
                              ),
                            ),
                          ),
                          SizedBox(height: layout.isTablet ? 18 : 14),
                          Text(
                            'ROUND ${widget.roundNumber}',
                            textAlign: TextAlign.center,
                            style: GoogleFonts.cinzel(
                              fontSize: layout.isTablet ? 24 : 21,
                              fontWeight: FontWeight.w900,
                              letterSpacing: 1.6,
                              color: AppTheme.cream,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            theme.arabicName,
                            textAlign: TextAlign.center,
                            style: GoogleFonts.cairo(
                              fontSize: layout.isTablet ? 14 : 13,
                              fontWeight: FontWeight.w700,
                              color: AppTheme.steelBlue,
                            ),
                          ),
                          SizedBox(height: layout.isTablet ? 18 : 14),
                          Container(
                            padding: EdgeInsets.all(layout.isTablet ? 16 : 14),
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                colors: [
                                  theme.primaryColor.withValues(alpha: 0.22),
                                  theme.secondaryColor.withValues(alpha: 0.12),
                                ],
                              ),
                              borderRadius: BorderRadius.circular(18),
                              border: Border.all(
                                color: theme.primaryColor.withValues(alpha: 0.42),
                              ),
                            ),
                            child: Column(
                              children: [
                                Text(
                                  theme.englishName,
                                  textAlign: TextAlign.center,
                                  style: GoogleFonts.cairo(
                                    fontSize: layout.isTablet ? 16 : 14,
                                    fontWeight: FontWeight.w900,
                                    color: AppTheme.cream,
                                  ),
                                ),
                                const SizedBox(height: 6),
                                Text(
                                  theme.trumpFixedEn,
                                  textAlign: TextAlign.center,
                                  style: GoogleFonts.cairo(
                                    fontSize: layout.isTablet ? 13 : 12,
                                    fontWeight: FontWeight.w700,
                                    color: AppTheme.cream.withValues(alpha: 0.92),
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  theme.trumpFixedAr,
                                  textAlign: TextAlign.center,
                                  style: GoogleFonts.cairo(
                                    fontSize: layout.isTablet ? 12 : 11,
                                    fontWeight: FontWeight.w600,
                                    color: AppTheme.steelBlue,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          SizedBox(height: layout.isTablet ? 16 : 14),
                          Container(
                            padding: EdgeInsets.all(layout.isTablet ? 14 : 12),
                            decoration: BoxDecoration(
                              color: AppTheme.deepNavy.withValues(alpha: 0.46),
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(
                                color: AppTheme.steelBlue.withValues(alpha: 0.14),
                              ),
                            ),
                            child: Column(
                              children: [
                                Text(
                                  'Bid 8+ to override the fixed contract.',
                                  textAlign: TextAlign.center,
                                  style: GoogleFonts.cairo(
                                    fontSize: layout.isTablet ? 13 : 12,
                                    fontWeight: FontWeight.w700,
                                    color: AppTheme.cream,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  'Direct Declarations • Highest Declarer Starts',
                                  textAlign: TextAlign.center,
                                  style: GoogleFonts.cairo(
                                    fontSize: layout.isTablet ? 12 : 11,
                                    fontWeight: FontWeight.w800,
                                    color: theme.accentColor,
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
                                color: theme.primaryColor.withValues(alpha: 0.14),
                                borderRadius: BorderRadius.circular(999),
                                border: Border.all(
                                  color: theme.primaryColor.withValues(alpha: 0.38),
                                ),
                              ),
                              child: Text(
                                'FIXED CONTRACT ACTIVE',
                                style: GoogleFonts.cairo(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w800,
                                  color: theme.accentColor,
                                  letterSpacing: 0.6,
                                ),
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

class _TrumpTheme {
  const _TrumpTheme({
    required this.suitSymbol,
    required this.englishName,
    required this.arabicName,
    required this.trumpFixedEn,
    required this.trumpFixedAr,
    required this.primaryColor,
    required this.secondaryColor,
    required this.accentColor,
  });

  final String suitSymbol;
  final String englishName;
  final String arabicName;
  final String trumpFixedEn;
  final String trumpFixedAr;
  final Color primaryColor;
  final Color secondaryColor;
  final Color accentColor;
}

_TrumpTheme _themeFor(Trump trump) {
  switch (trump) {
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
      );
  }
}

class _Spark {
  const _Spark({
    required this.angle,
    required this.distance,
    required this.size,
    required this.color,
  });

  final double angle;
  final double distance;
  final double size;
  final Color color;
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

    for (final spark in sparks) {
      final dist = spark.distance * t;
      paint.color = spark.color.withValues(alpha: opacity * 0.85);
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
