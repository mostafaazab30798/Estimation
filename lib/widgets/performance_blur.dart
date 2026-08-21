// lib/widgets/performance_blur.dart

import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/device_performance_service.dart';
import '../theme/app_theme.dart';

/// A performance-aware backdrop blur widget.
///
/// On high-spec devices, it applies full real-time GPU [BackdropFilter] glassmorphism.
/// On low-spec devices (e.g., Galaxy Note 9, legacy Androids), it bypasses offscreen
/// GPU blur passes entirely and renders a clean translucent solid background, preventing
/// overheating and thermal throttling.
class PerformanceBlur extends StatelessWidget {
  final Widget child;
  final double sigmaX;
  final double sigmaY;
  final BorderRadius borderRadius;
  final Color? fallbackColor;
  final Color? blurColor;

  const PerformanceBlur({
    super.key,
    required this.child,
    this.sigmaX = 8.0,
    this.sigmaY = 8.0,
    this.borderRadius = BorderRadius.zero,
    this.fallbackColor,
    this.blurColor,
  });

  @override
  Widget build(BuildContext context) {
    // Check performance service or fallback to singleton instance
    final isLowSpec = context.select<DevicePerformanceService, bool>(
      (s) => s.isLowSpecDevice,
    );

    if (isLowSpec) {
      // ── Low-spec mode: 0 GPU blur passes ──────────────────────────
      return ClipRRect(
        borderRadius: borderRadius,
        child: Container(
          color: fallbackColor ?? AppTheme.navyMid.withValues(alpha: 0.90),
          child: child,
        ),
      );
    }

    // ── High-spec mode: Full real-time BackdropFilter ───────────────
    return ClipRRect(
      borderRadius: borderRadius,
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: sigmaX, sigmaY: sigmaY),
        child: Container(
          color: blurColor,
          child: child,
        ),
      ),
    );
  }
}
