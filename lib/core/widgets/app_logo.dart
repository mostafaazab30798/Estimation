import 'package:flutter/material.dart';

import '../constants.dart';

/// Rounded app mark used on splash, login, and the mode picker.
class AppLogo extends StatelessWidget {
  const AppLogo({
    super.key,
    this.size = 160,
    this.borderRadius,
  });

  final double size;
  final double? borderRadius;

  @override
  Widget build(BuildContext context) {
    final radius = borderRadius ?? size * 0.22;
    return ClipRRect(
      borderRadius: BorderRadius.circular(radius),
      child: Image.asset(
        kAppLogoAsset,
        width: size,
        height: size,
        fit: BoxFit.cover,
        filterQuality: FilterQuality.high,
      ),
    );
  }
}
