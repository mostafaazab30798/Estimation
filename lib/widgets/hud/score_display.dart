// lib/widgets/hud/score_display.dart
//
// Animated score section with count-up animation on value change.

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../theme/app_theme.dart';

/// Shows [score] as a large animated number with a small caption below.
///
/// When the score value changes, the number fades/slides out and the new
/// value fades/slides in via [AnimatedSwitcher].
class ScoreDisplay extends StatelessWidget {
  final int score;
  final bool compact;

  const ScoreDisplay({super.key, required this.score, this.compact = false});

  @override
  Widget build(BuildContext context) {
    final numberSize = compact ? 15.0 : 20.0;
    final captionSize = compact ? 7.0 : 8.5;

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        AnimatedSwitcher(
          duration: const Duration(milliseconds: 400),
          transitionBuilder: (child, anim) => FadeTransition(
            opacity: anim,
            child: SlideTransition(
              position: Tween<Offset>(
                begin: const Offset(0, -0.3),
                end: Offset.zero,
              ).animate(CurvedAnimation(parent: anim, curve: Curves.easeOut)),
              child: child,
            ),
          ),
          child: Text(
            '$score',
            key: ValueKey(score),
            style: GoogleFonts.cairo(
              color: AppTheme.cream,
              fontSize: numberSize,
              fontWeight: FontWeight.w800,
              height: 1.0,
            ),
          ),
        ),
        Text(
          'نقطة',
          style: GoogleFonts.cairo(
            color: AppTheme.steelBlue,
            fontSize: captionSize,
            fontWeight: FontWeight.w600,
            letterSpacing: 0.3,
          ),
        ),
      ],
    );
  }
}
