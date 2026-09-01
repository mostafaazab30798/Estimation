import 'package:flutter/material.dart';

import '../../core/utils/game_layout_metrics.dart';
import '../../theme/app_theme.dart';

/// Shared chrome for in-game decision dialogs (bid, declare, dash, tricks, etc.).
class GameplayDialogShell extends StatelessWidget {
  const GameplayDialogShell({
    super.key,
    required this.child,
    this.accent = AppTheme.gold,
    this.maxWidth,
    this.padding,
    this.alignment,
    this.insetPadding,
    this.scrollable = false,
  });

  final Widget child;
  final Color accent;
  final double? maxWidth;
  final EdgeInsets? padding;
  final Alignment? alignment;
  final EdgeInsets? insetPadding;
  final bool scrollable;

  /// Responsive max width — wider on landscape tablets for dense controls.
  static double widthFor(
    BuildContext context, {
    double phoneFraction = 0.94,
    double tablet = 500,
    double tabletLandscape = 580,
    double largeTablet = 560,
    double largeTabletLandscape = 640,
  }) {
    final layout = GameLayoutMetrics.of(context);
    final screenW = MediaQuery.sizeOf(context).width;
    if (layout.isLargeTablet) {
      return layout.isPortrait ? largeTablet : largeTabletLandscape;
    }
    if (layout.isTablet) {
      return layout.isPortrait ? tablet : tabletLandscape;
    }
    return screenW * phoneFraction;
  }

  static Alignment dialogAlignment(BuildContext context) {
    final layout = GameLayoutMetrics.of(context);
    return layout.isPortrait
        ? const Alignment(0, -0.35)
        : const Alignment(0, -0.2);
  }

  @override
  Widget build(BuildContext context) {
    final layout = GameLayoutMetrics.of(context);
    final resolvedMaxWidth = maxWidth ?? widthFor(context);
    final resolvedAlignment = alignment ?? dialogAlignment(context);
    final resolvedPadding = padding ??
        EdgeInsets.fromLTRB(
          layout.isTablet ? 24 : 20,
          layout.isTablet ? 22 : 18,
          layout.isTablet ? 24 : 20,
          layout.isTablet ? 20 : 18,
        );
    final resolvedInset = insetPadding ??
        EdgeInsets.symmetric(
          horizontal: layout.isTablet ? 24 : 16,
          vertical: 12,
        );

    final body = scrollable
        ? SingleChildScrollView(
            physics: const BouncingScrollPhysics(),
            child: child,
          )
        : child;

    return Dialog(
      alignment: resolvedAlignment,
      insetPadding: resolvedInset,
      backgroundColor: Colors.transparent,
      elevation: 0,
      child: Container(
        width: double.infinity,
        constraints: BoxConstraints(maxWidth: resolvedMaxWidth),
        decoration: AppTheme.dialogDecoration(accent: accent),
        padding: resolvedPadding,
        child: body,
      ),
    );
  }
}
