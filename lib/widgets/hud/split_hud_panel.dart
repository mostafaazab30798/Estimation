import 'package:flutter/material.dart';

import '../../theme/app_theme.dart';
import '../performance_blur.dart';

/// A single glass segment used in the tablet split top-HUD layout.
class SplitHudPanel extends StatelessWidget {
  final Widget child;
  final Color? glowColor;
  final EdgeInsetsGeometry padding;

  const SplitHudPanel({
    super.key,
    required this.child,
    this.glowColor,
    this.padding = const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
  });

  @override
  Widget build(BuildContext context) {
    final accent = glowColor ?? AppTheme.steelBlue;

    return PerformanceBlur(
      borderRadius: BorderRadius.circular(20),
      sigmaX: 14,
      sigmaY: 14,
      child: DecoratedBox(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [
              const Color(0xD22F4A64),
              const Color(0xD21A3044),
              accent.withValues(alpha: 0.10),
            ],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            stops: const [0.0, 0.62, 1.0],
          ),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: AppTheme.cream.withValues(alpha: 0.11),
            width: 1.0,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.34),
              blurRadius: 20,
              offset: const Offset(0, 8),
            ),
            BoxShadow(
              color: accent.withValues(alpha: 0.12),
              blurRadius: 22,
              spreadRadius: 0.5,
            ),
          ],
        ),
        child: Padding(
          padding: padding,
          child: child,
        ),
      ),
    );
  }
}
