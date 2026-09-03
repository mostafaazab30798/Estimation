// lib/widgets/perfect_estimate_overlay.dart

import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../core/icons/app_icons.dart';
import '../core/utils/game_layout_metrics.dart';
import '../core/widgets/app_buttons.dart';
import '../theme/app_theme.dart';

/// A focused celebration for an exact call or a successful blind Dash Call.
class PerfectEstimateOverlay extends StatefulWidget {
  final int declared;
  final int won;
  final int? xpBonus;
  final bool isDashCall;
  final VoidCallback? onDismissed;
  final Duration displayDuration;

  const PerfectEstimateOverlay({
    super.key,
    required this.declared,
    required this.won,
    this.xpBonus = 20,
    this.isDashCall = false,
    this.onDismissed,
    this.displayDuration = const Duration(milliseconds: 2800),
  });

  @override
  State<PerfectEstimateOverlay> createState() =>
      _PerfectEstimateOverlayState();
}

class _PerfectEstimateOverlayState extends State<PerfectEstimateOverlay>
    with TickerProviderStateMixin {
  late final AnimationController _entranceController;
  late final AnimationController _particleController;
  late final Animation<double> _fade;
  late final Animation<double> _scale;
  late final Animation<Offset> _slide;
  late final List<_ParticleData> _particles;

  Timer? _autoDismissTimer;
  bool _dismissing = false;

  Color get _accent =>
      widget.isDashCall ? AppTheme.playerOrange : AppTheme.playerGreen;

  @override
  void initState() {
    super.initState();
    final random = math.Random(
      widget.declared * 31 + widget.won * 17 + (widget.isDashCall ? 1 : 0),
    );
    _particles = List.generate(14, (index) {
      return _ParticleData(
        angle: (index / 14) * math.pi * 2,
        distance: 58 + random.nextDouble() * 76,
        size: 2.5 + random.nextDouble() * 3.5,
        color: index.isEven ? AppTheme.gold : _accent,
      );
    });

    _entranceController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 460),
      reverseDuration: const Duration(milliseconds: 220),
    );
    _particleController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1050),
    );

    final curve = CurvedAnimation(
      parent: _entranceController,
      curve: Curves.easeOutCubic,
      reverseCurve: Curves.easeInCubic,
    );
    _fade = curve;
    _scale = Tween<double>(begin: 0.94, end: 1).animate(curve);
    _slide = Tween<Offset>(
      begin: const Offset(0, 0.04),
      end: Offset.zero,
    ).animate(curve);

    _entranceController.forward();
    _particleController.forward();
    HapticFeedback.mediumImpact();
    _autoDismissTimer = Timer(widget.displayDuration, _dismiss);
  }

  void _dismiss() {
    if (_dismissing || !mounted) return;
    _dismissing = true;
    _autoDismissTimer?.cancel();
    _entranceController.reverse().then((_) {
      if (mounted) widget.onDismissed?.call();
    });
  }

  @override
  void dispose() {
    _autoDismissTimer?.cancel();
    _entranceController.dispose();
    _particleController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final layout = GameLayoutMetrics.of(context);
    final maxWidth = layout.isLargeTablet
        ? 520.0
        : (layout.isTablet ? 460.0 : 390.0);
    final horizontalInset = layout.isTablet ? 28.0 : 22.0;
    final isDash = widget.isDashCall;
    final title = isDash ? 'داش كول مثالي' : 'كول في الصميم';
    final eyebrow = isDash ? 'PERFECT DASH CALL' : 'PERFECT CALL';
    final description = isDash
        ? 'صفر لمّات. مخاطرة محسوبة وتنفيذ نظيف.'
        : 'توقعت ${widget.declared} وحققتها بالضبط.';

    return Semantics(
      namesRoute: true,
      label: '$title. $description',
      button: true,
      child: GestureDetector(
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
                  color: AppTheme.deepNavy.withValues(alpha: 0.76),
                ),
              ),
              IgnorePointer(
                child: AnimatedBuilder(
                  animation: _particleController,
                  builder: (context, _) => CustomPaint(
                    size: MediaQuery.sizeOf(context),
                    painter: _ParticlePainter(
                      particles: _particles,
                      progress: _particleController.value,
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
                        padding: EdgeInsets.fromLTRB(
                          layout.isTablet ? 28 : 24,
                          layout.isTablet ? 24 : 20,
                          layout.isTablet ? 28 : 24,
                          layout.isTablet ? 24 : 22,
                        ),
                        decoration: AppTheme.dialogDecoration(accent: _accent),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Row(
                              children: [
                                AppIconWell(
                                  icon: isDash
                                      ? AppIcons.bolt
                                      : AppIcons.emojiEvents,
                                  size: layout.isTablet ? 52 : 48,
                                  iconSize: layout.isTablet ? 24 : 21,
                                  color: _accent,
                                  fill: _accent.withValues(alpha: 0.14),
                                  borderColor: _accent.withValues(alpha: 0.32),
                                ),
                                const Spacer(),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 10,
                                    vertical: 6,
                                  ),
                                  decoration: BoxDecoration(
                                    color: _accent.withValues(alpha: 0.1),
                                    borderRadius: BorderRadius.circular(20),
                                    border: Border.all(
                                      color: _accent.withValues(alpha: 0.28),
                                    ),
                                  ),
                                  child: Text(
                                    eyebrow,
                                    style: AppFonts.cooper(
                                      color: _accent,
                                      fontSize: 10,
                                      fontWeight: FontWeight.w800,
                                      letterSpacing: 0.8,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            SizedBox(height: layout.isTablet ? 24 : 22),
                            Text(
                              title,
                              textAlign: TextAlign.right,
                              style: AppFonts.cooper(
                                color: AppTheme.cream,
                                fontSize: layout.isTablet ? 27 : 25,
                                fontWeight: FontWeight.w900,
                                height: 1.2,
                              ),
                            ),
                            SizedBox(height: layout.isTablet ? 8 : 6),
                            Text(
                              description,
                              textAlign: TextAlign.right,
                              style: AppFonts.cooper(
                                color: AppTheme.steelBlue,
                                fontSize: layout.isTablet ? 14.5 : 13.5,
                                fontWeight: FontWeight.w500,
                                height: 1.55,
                              ),
                            ),
                            SizedBox(height: layout.isTablet ? 22 : 20),
                            Container(
                              padding: EdgeInsets.all(layout.isTablet ? 16 : 14),
                              decoration: BoxDecoration(
                                color: AppTheme.deepNavy.withValues(alpha: 0.46),
                                borderRadius: BorderRadius.circular(18),
                                border: Border.all(
                                  color: AppTheme.steelBlue.withValues(
                                    alpha: 0.13,
                                  ),
                                ),
                              ),
                              child: Row(
                                children: [
                                  Expanded(
                                    child: _Stat(
                                      value: '${widget.declared}',
                                      label: 'declared • صرّح',
                                      color: AppTheme.goldLight,
                                    ),
                                  ),
                                  Container(
                                    width: 1,
                                    height: 34,
                                    color: AppTheme.steelBlue.withValues(
                                      alpha: 0.16,
                                    ),
                                  ),
                                  Expanded(
                                    child: _Stat(
                                      value: '${widget.won}',
                                      label: 'won • ربح',
                                      color: _accent,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            SizedBox(height: layout.isTablet ? 16 : 14),
                            Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 12,
                                    vertical: 7,
                                  ),
                                  decoration: BoxDecoration(
                                    color: AppTheme.gold.withValues(alpha: 0.13),
                                    borderRadius: BorderRadius.circular(20),
                                    border: Border.all(
                                      color: AppTheme.gold.withValues(alpha: 0.2),
                                    ),
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      const AppIcon(
                                        AppIcons.stars,
                                        size: 16,
                                        color: AppTheme.goldLight,
                                      ),
                                      const SizedBox(width: 6),
                                      Text(
                                        '+${widget.xpBonus ?? 20} XP BONUS',
                                        style: AppFonts.cooper(
                                          color: AppTheme.goldLight,
                                          fontSize: 12,
                                          fontWeight: FontWeight.w800,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                const Spacer(),
                                Text(
                                  'اضغط للمتابعة',
                                  style: AppFonts.cooper(
                                    color: AppTheme.steelBlue.withValues(
                                      alpha: 0.7,
                                    ),
                                    fontSize: 10.5,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ],
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
      ),
    );
  }
}

class _Stat extends StatelessWidget {
  final String value;
  final String label;
  final Color color;

  const _Stat({required this.value, required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          value,
          style: AppFonts.cooper(
            color: color,
            fontSize: 23,
            fontWeight: FontWeight.w900,
            height: 1,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: AppFonts.cooper(
            color: AppTheme.steelBlue,
            fontSize: 10.5,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }
}

class _ParticleData {
  final double angle;
  final double distance;
  final double size;
  final Color color;

  const _ParticleData({
    required this.angle,
    required this.distance,
    required this.size,
    required this.color,
  });
}

class _ParticlePainter extends CustomPainter {
  final List<_ParticleData> particles;
  final double progress;

  const _ParticlePainter({required this.particles, required this.progress});

  @override
  void paint(Canvas canvas, Size size) {
    final opacity = (1 - progress).clamp(0.0, 1.0);
    if (opacity == 0) return;
    final center = Offset(size.width / 2, size.height / 2);
    final paint = Paint()..style = PaintingStyle.fill;
    final eased = Curves.easeOutCubic.transform(progress);

    for (final particle in particles) {
      final distance = particle.distance * eased;
      final position = Offset(
        center.dx + distance * math.cos(particle.angle),
        center.dy + distance * math.sin(particle.angle),
      );
      paint.color = particle.color.withValues(alpha: opacity * 0.75);
      canvas.drawCircle(position, particle.size * (1 - progress * 0.25), paint);
    }
  }

  @override
  bool shouldRepaint(covariant _ParticlePainter oldDelegate) =>
      oldDelegate.progress != progress;
}
