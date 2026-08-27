import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';

import '../icons/app_icons.dart';
import '../../theme/app_theme.dart';

/// Size / stroke tokens tuned for HugeIcons stroke-rounded glyphs.
abstract final class AppIconTokens {
  static const double sizeSm = 16;
  static const double sizeMd = 18;
  static const double sizeLg = 20;
  static const double sizeXl = 22;
  static const double sizeHero = 24;

  /// Slightly heavier than package default so thin strokes read clearly on glass.
  static const double stroke = 1.65;
  static const double strokeBold = 1.9;
  static const double strokeThin = 1.4;
}

enum AppIconButtonSize {
  sm, // 32
  md, // 38
  lg, // 44
}

/// Square/squircle glass icon control — canonical chrome for HugeIcons.
class AppIconButton extends StatelessWidget {
  const AppIconButton({
    super.key,
    required this.icon,
    required this.onTap,
    this.color,
    this.backgroundColor,
    this.borderColor,
    this.size = AppIconButtonSize.md,
    this.tooltip,
    this.enabled = true,
    this.haptic = true,
  });

  final AppIconData icon;
  final VoidCallback? onTap;
  final Color? color;
  final Color? backgroundColor;
  final Color? borderColor;
  final AppIconButtonSize size;
  final String? tooltip;
  final bool enabled;
  final bool haptic;

  double get _box => switch (size) {
        AppIconButtonSize.sm => 32,
        AppIconButtonSize.md => 38,
        AppIconButtonSize.lg => 44,
      };

  double get _icon => switch (size) {
        AppIconButtonSize.sm => AppIconTokens.sizeSm,
        AppIconButtonSize.md => AppIconTokens.sizeMd,
        AppIconButtonSize.lg => AppIconTokens.sizeLg,
      };

  double get _radius => _box * 0.36;

  @override
  Widget build(BuildContext context) {
    final accent = color ?? AppTheme.cream;
    final bg = backgroundColor ?? accent.withValues(alpha: 0.10);
    final border = borderColor ?? accent.withValues(alpha: 0.22);
    final active = enabled && onTap != null;

    Widget button = Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: active
            ? () {
                if (haptic) HapticFeedback.selectionClick();
                onTap!();
              }
            : null,
        borderRadius: BorderRadius.circular(_radius),
        child: Ink(
          width: _box,
          height: _box,
          decoration: BoxDecoration(
            color: active ? bg : Colors.white.withValues(alpha: 0.04),
            borderRadius: BorderRadius.circular(_radius),
            border: Border.all(
              color: active ? border : Colors.white.withValues(alpha: 0.08),
              width: 1,
            ),
          ),
          child: Center(
            child: AppIcon(
              icon,
              size: _icon,
              color: active ? accent : accent.withValues(alpha: 0.35),
              strokeWidth: AppIconTokens.stroke,
            ),
          ),
        ),
      ),
    );

    if (tooltip != null && tooltip!.isNotEmpty) {
      button = Tooltip(message: tooltip!, child: button);
    }
    return button;
  }
}

/// Soft frosted / tinted well that frames a stroke icon inside larger CTAs.
class AppIconWell extends StatelessWidget {
  const AppIconWell({
    super.key,
    required this.icon,
    this.size = 44,
    this.iconSize,
    this.color = Colors.white,
    this.fill,
    this.gradient,
    this.borderColor,
    this.circular = true,
    this.strokeWidth = AppIconTokens.stroke,
  });

  final AppIconData icon;
  final double size;
  final double? iconSize;
  final Color color;
  final Color? fill;
  final Gradient? gradient;
  final Color? borderColor;
  final bool circular;
  final double strokeWidth;

  @override
  Widget build(BuildContext context) {
    final radius = circular ? size / 2 : size * 0.32;
    return Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: gradient == null ? (fill ?? Colors.white.withValues(alpha: 0.16)) : null,
        gradient: gradient,
        shape: circular ? BoxShape.circle : BoxShape.rectangle,
        borderRadius: circular ? null : BorderRadius.circular(radius),
        border: Border.all(
          color: borderColor ?? Colors.white.withValues(alpha: 0.22),
          width: 1,
        ),
      ),
      child: AppIcon(
        icon,
        size: iconSize ?? size * 0.48,
        color: color,
        strokeWidth: strokeWidth,
      ),
    );
  }
}

/// Labeled pill with leading HugeIcon — nav / filter chrome.
class AppIconCapsule extends StatelessWidget {
  const AppIconCapsule({
    super.key,
    required this.icon,
    required this.label,
    required this.onTap,
    this.accent = AppTheme.gold,
    this.backgroundColor,
    this.dense = false,
  });

  final AppIconData icon;
  final String label;
  final VoidCallback onTap;
  final Color accent;
  final Color? backgroundColor;
  final bool dense;

  @override
  Widget build(BuildContext context) {
    final vPad = dense ? 6.0 : 8.0;
    final hPad = dense ? 10.0 : 12.0;
    final iconSize = dense ? AppIconTokens.sizeSm : AppIconTokens.sizeMd;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () {
          HapticFeedback.selectionClick();
          onTap();
        },
        borderRadius: BorderRadius.circular(22),
        child: Ink(
          padding: EdgeInsets.symmetric(horizontal: hPad, vertical: vPad),
          decoration: BoxDecoration(
            color: backgroundColor ?? AppTheme.navyDark.withValues(alpha: 0.72),
            borderRadius: BorderRadius.circular(22),
            border: Border.all(color: accent.withValues(alpha: 0.32), width: 1),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              AppIcon(
                icon,
                color: accent,
                size: iconSize,
                strokeWidth: AppIconTokens.stroke,
              ),
              SizedBox(width: dense ? 6 : 8),
              Text(
                label,
                style: GoogleFonts.cairo(
                  color: accent == AppTheme.gold ? AppTheme.goldLight : AppTheme.white,
                  fontWeight: FontWeight.w700,
                  fontSize: dense ? 11.5 : 12.5,
                  height: 1.1,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Compact icon + label chip for secondary actions.
class AppIconChip extends StatelessWidget {
  const AppIconChip({
    super.key,
    required this.icon,
    required this.label,
    required this.onTap,
    this.color,
    this.emphasized = false,
    this.loading = false,
  });

  final AppIconData icon;
  final String label;
  final VoidCallback? onTap;
  final Color? color;
  final bool emphasized;
  final bool loading;

  @override
  Widget build(BuildContext context) {
    final accent = color ?? AppTheme.cream;
    final active = onTap != null && !loading;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: active
            ? () {
                HapticFeedback.selectionClick();
                onTap!();
              }
            : null,
        borderRadius: BorderRadius.circular(16),
        child: Ink(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
          decoration: BoxDecoration(
            color: emphasized
                ? accent.withValues(alpha: 0.14)
                : Colors.white.withValues(alpha: 0.06),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: emphasized
                  ? accent.withValues(alpha: 0.38)
                  : Colors.white.withValues(alpha: 0.10),
              width: 1,
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (loading)
                SizedBox(
                  width: 14,
                  height: 14,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: accent,
                  ),
                )
              else
                AppIcon(
                  icon,
                  size: AppIconTokens.sizeSm,
                  color: emphasized ? accent : AppTheme.cream,
                  strokeWidth: AppIconTokens.stroke,
                ),
              const SizedBox(width: 7),
              Text(
                label,
                style: GoogleFonts.cairo(
                  fontSize: 11.5,
                  fontWeight: FontWeight.w700,
                  color: emphasized ? accent : AppTheme.cream,
                  height: 1.1,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
