import 'package:flutter/material.dart';

import '../constants.dart';
import '../utils/home_layout_metrics.dart';

/// App mark from [kAppLogoAsset], scaled to the current screen bucket.
class AppLogo extends StatelessWidget {
  const AppLogo({
    super.key,
    this.size,
    this.compact = false,
    this.borderRadius,
    this.pulsing = false,
  });

  /// When null, size comes from [HomeLayoutMetrics].
  final double? size;
  final bool compact;
  final double? borderRadius;

  /// Gentle scale pulse for splash / loading states.
  final bool pulsing;

  @override
  Widget build(BuildContext context) {
    final metrics = HomeLayoutMetrics.of(context);
    final resolvedSize = size ??
        (pulsing
            ? metrics.splashLogoSize()
            : metrics.appBrandMarkSize(compact: compact));
    final radius = borderRadius ?? resolvedSize * 0.22;

    final logo = _AppLogoImage(
      size: resolvedSize,
      borderRadius: radius,
    );

    if (!pulsing) return logo;
    return _PulsingAppLogo(size: resolvedSize, child: logo);
  }
}

class _AppLogoImage extends StatelessWidget {
  const _AppLogoImage({
    required this.size,
    required this.borderRadius,
  });

  final double size;
  final double borderRadius;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(borderRadius),
        child: Image.asset(
          kAppLogoAsset,
          width: size,
          height: size,
          fit: BoxFit.contain,
          filterQuality: FilterQuality.high,
        ),
      ),
    );
  }
}

class _PulsingAppLogo extends StatefulWidget {
  const _PulsingAppLogo({
    required this.size,
    required this.child,
  });

  final double size;
  final Widget child;

  @override
  State<_PulsingAppLogo> createState() => _PulsingAppLogoState();
}

class _PulsingAppLogoState extends State<_PulsingAppLogo>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _scale;
  late final Animation<double> _opacity;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    )..repeat(reverse: true);

    _scale = Tween<double>(begin: 0.92, end: 1.0).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
    );
    _opacity = Tween<double>(begin: 0.82, end: 1.0).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: widget.size,
      height: widget.size,
      child: AnimatedBuilder(
        animation: _controller,
        builder: (context, child) {
          return Opacity(
            opacity: _opacity.value,
            child: Transform.scale(
              scale: _scale.value,
              child: child,
            ),
          );
        },
        child: widget.child,
      ),
    );
  }
}
