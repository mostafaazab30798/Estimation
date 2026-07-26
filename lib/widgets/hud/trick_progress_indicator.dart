// lib/widgets/hud/trick_progress_indicator.dart
//
// Segmented trick progress bar — each segment = one trick out of 13.
// Color responds to player declaration state; segments animate independently.

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../theme/app_theme.dart';

/// A segmented bar showing [actual] tricks won out of 13 possible tricks
/// per round. If [declared] is non-null, the bar also draws a "target"
/// marker at the declared position and colors filled segments accordingly.
///
/// Color rules:
///  - Default (no declaration)    → [AppTheme.playerBlue]
///  - Actual == declared          → [AppTheme.playerGreen]
///  - Actual >  declared          → [AppTheme.playerRed]
///  - Near-end, under target      → [AppTheme.playerOrange]
///  - Otherwise                   → [AppTheme.playerBlue]
class TrickProgressIndicator extends StatefulWidget {
  final int actual;
  final int? declared;
  final int tricksPlayedThisRound;
  final bool compact;

  const TrickProgressIndicator({
    super.key,
    required this.actual,
    this.declared,
    this.tricksPlayedThisRound = 0,
    this.compact = false,
  });

  @override
  State<TrickProgressIndicator> createState() =>
      _TrickProgressIndicatorState();
}

class _TrickProgressIndicatorState extends State<TrickProgressIndicator>
    with TickerProviderStateMixin {
  // One controller per segment — only the newly-filled one bounces.
  static const _kSegments = 13;
  final List<AnimationController> _segCtrl = [];
  final List<Animation<double>> _segScale = [];
  int _prevActual = 0;

  @override
  void initState() {
    super.initState();
    _buildControllers();
    _prevActual = widget.actual;
  }

  void _buildControllers() {
    for (int i = 0; i < _kSegments; i++) {
      final ctrl = AnimationController(
        vsync: this,
        duration: const Duration(milliseconds: 320),
      );
      _segCtrl.add(ctrl);
      _segScale.add(Tween<double>(begin: 0.5, end: 1.0).animate(
        CurvedAnimation(parent: ctrl, curve: Curves.elasticOut),
      ));
      // Pre-fill segments that are already won on init.
      if (i < widget.actual) ctrl.value = 1.0;
    }
  }

  @override
  void didUpdateWidget(TrickProgressIndicator old) {
    super.didUpdateWidget(old);
    if (widget.actual != _prevActual) {
      if (widget.actual > _prevActual) {
        // Animate newly-filled segments.
        for (int i = _prevActual; i < widget.actual && i < _kSegments; i++) {
          _segCtrl[i].forward(from: 0.0);
        }
      } else {
        // Reset unfilled segments instantly.
        for (int i = widget.actual; i < _prevActual && i < _kSegments; i++) {
          _segCtrl[i].value = 0.0;
        }
      }
      _prevActual = widget.actual;
    }
  }

  @override
  void dispose() {
    for (final c in _segCtrl) {
      c.dispose();
    }
    super.dispose();
  }

  Color _barColor() {
    final d = widget.declared;
    if (d == null) return AppTheme.playerBlue;
    if (widget.actual == d) return AppTheme.playerGreen;
    if (widget.actual > d) return AppTheme.playerRed;
    if (widget.tricksPlayedThisRound >= 10) return AppTheme.playerOrange;
    return AppTheme.playerBlue;
  }

  @override
  Widget build(BuildContext context) {
    final color = _barColor();
    final segW = widget.compact ? 5.5 : 7.0;
    final segH = widget.compact ? 5.0 : 6.5;
    final gap = widget.compact ? 1.5 : 2.0;
    final labelSize = widget.compact ? 8.0 : 9.5;
    final segmentCount = widget.declared ?? 0;

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // ── Segmented bar ──────────────────────────────────────────
        if (segmentCount > 0) ...[
          Row(
            mainAxisSize: MainAxisSize.min,
            children: List.generate(segmentCount, (i) {
              final filled = i < widget.actual;
              final isTarget = i == segmentCount - 1;

              return Padding(
                padding: EdgeInsets.only(right: i < segmentCount - 1 ? gap : 0),
                child: AnimatedBuilder(
                  animation: _segCtrl[i],
                  builder: (_, __) {
                    final scale = filled ? _segScale[i].value : 1.0;
                    return Transform.scale(
                      scale: scale,
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 300),
                        width: segW,
                        height: segH,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(2),
                          color: filled
                              ? color
                              : AppTheme.deepNavy,
                          border: Border.all(
                            color: isTarget && !filled
                                ? color.withValues(alpha: 0.7)
                                : (filled ? Colors.transparent : AppTheme.steelBlue.withValues(alpha: 0.2)),
                            width: isTarget && !filled ? 1.2 : 0.8,
                          ),
                          boxShadow: filled
                              ? [
                                  BoxShadow(
                                    color: color.withValues(alpha: 0.35),
                                    blurRadius: 4,
                                  )
                                ]
                              : null,
                        ),
                      ),
                    );
                  },
                ),
              );
            }),
          ),
          const SizedBox(height: 3),
        ],

        // ── Fraction label ─────────────────────────────────────────
        AnimatedDefaultTextStyle(
          duration: const Duration(milliseconds: 300),
          style: GoogleFonts.cairo(
            color: color,
            fontSize: labelSize,
            fontWeight: FontWeight.w700,
          ),
          child: Text(
            widget.declared != null
                ? '${widget.actual} / ${widget.declared}'
                : '${widget.actual}',
          ),
        ),
      ],
    );
  }
}
