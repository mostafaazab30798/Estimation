import 'dart:math' as math;

import 'package:flutter/material.dart';

/// Responsive sizing for mode-selection and mode-home hero marks.
class HomeLayoutMetrics {
  HomeLayoutMetrics._({
    required this.size,
    required this.orientation,
  });

  final Size size;
  final Orientation orientation;

  double get width => size.width;
  double get height => size.height;
  double get minDimension => math.min(width, height);
  double get maxDimension => math.max(width, height);
  bool get isLandscape => orientation == Orientation.landscape;
  bool get isPortrait => !isLandscape;
  bool get isTablet => minDimension >= 600;
  bool get isLargeTablet => isTablet && maxDimension >= 900;
  bool get isPhone => !isTablet;
  bool get isPhoneLandscape => isLandscape && isPhone;
  bool get isPhonePortrait => isPortrait && isPhone;

  /// Phone landscape with limited vertical space (typical small phones).
  bool get isCompactLandscape => isPhoneLandscape && height < 420;

  /// Vertical stacked menus — portrait phones and very short landscape phones.
  bool get useStackedMenuLayout => isPortrait || isCompactLandscape;

  /// Horizontal split menus — phone/tablet landscape with enough height.
  bool get useSideBySideMenuLayout => isLandscape && !isCompactLandscape;

  /// Stacked menus on phones only (keeps tablet layouts unchanged).
  bool get usePhoneStackedMenuLayout => isPhone && useStackedMenuLayout;

  /// Side-by-side menus on phones only (keeps tablet layouts unchanged).
  bool get usePhoneSideBySideMenuLayout => isPhone && useSideBySideMenuLayout;

  static HomeLayoutMetrics of(BuildContext context) {
    final media = MediaQuery.of(context);
    return HomeLayoutMetrics._(
      size: media.size,
      orientation: media.orientation,
    );
  }

  /// Main app mark on the mode picker and splash.
  double appBrandMarkSize({bool compact = false}) {
    if (compact) {
      return (height * 0.15).clamp(56.0, 84.0);
    }
    if (isLargeTablet) {
      return (width * 0.12).clamp(112.0, 148.0);
    }
    if (isTablet) {
      return (width * 0.14).clamp(96.0, 128.0);
    }
    if (isLandscape) {
      return (height * 0.24).clamp(72.0, 104.0);
    }
    return (width * 0.30).clamp(96.0, 128.0);
  }

  double appHeroTitleSize({bool compact = false}) {
    if (compact) {
      return (height * 0.034).clamp(22.0, 28.0);
    }
    if (isTablet) {
      return (width * 0.042).clamp(30.0, 38.0);
    }
    return (width * 0.085).clamp(28.0, 36.0);
  }

  double appHeroSubtitleSize({bool compact = false}) {
    if (compact) {
      return (height * 0.016).clamp(11.0, 13.0);
    }
    return (width * 0.032).clamp(12.0, 14.5);
  }

  double appHeroSpacing({bool compact = false}) {
    if (compact) return 8.0;
    if (isTablet) return 14.0;
    return 12.0;
  }

  /// Splash / bootstrap loader mark.
  double splashLogoSize() {
    if (isLargeTablet) {
      return (minDimension * 0.22).clamp(128.0, 168.0);
    }
    if (isTablet) {
      return (minDimension * 0.24).clamp(120.0, 152.0);
    }
    return (minDimension * 0.30).clamp(112.0, 144.0);
  }

  /// Mode art emblem on individual mode home heroes.
  double modeEmblemSize({bool compact = false}) {
    if (compact) {
      return (height * 0.15).clamp(64.0, 88.0);
    }
    if (isLargeTablet) {
      return (width * 0.09).clamp(96.0, 124.0);
    }
    if (isTablet) {
      return (width * 0.11).clamp(84.0, 108.0);
    }
    if (isLandscape) {
      return (height * 0.20).clamp(68.0, 92.0);
    }
    return (width * 0.22).clamp(76.0, 104.0);
  }

  /// Mode card art on the mode-selection list / grid.
  double modeCardArtSize({bool tall = false}) {
    if (tall) {
      return (height * 0.17).clamp(96.0, 132.0);
    }
    if (isTablet) {
      return (width * 0.10).clamp(84.0, 108.0);
    }
    return (width * 0.21).clamp(76.0, 96.0);
  }

  /// Layout bucket for mode home screens (Basra, 99, Estimation).
  bool get useTabletHomeLayout => isTablet;

  double modeHomeContentMaxWidth() {
    if (isLargeTablet) {
      return isLandscape ? 1120.0 : 720.0;
    }
    if (isTablet) {
      return isLandscape ? 960.0 : 600.0;
    }
    return isLandscape ? 880.0 : double.infinity;
  }

  double modeHomeHorizontalPadding() {
    if (isLargeTablet) return 40.0;
    if (isTablet) return 28.0;
    return 20.0;
  }

  double modeHomeSectionSpacing() {
    if (isLargeTablet) return 28.0;
    if (isTablet) return 22.0;
    return 18.0;
  }

  double modeHomeHeroTitleSize({bool compact = false}) {
    if (compact) {
      if (isLargeTablet) return 30.0;
      if (isTablet) return 28.0;
      return 26.0;
    }
    if (isLargeTablet) return 42.0;
    if (isTablet) return 36.0;
    return 32.0;
  }

  double modeHomeHeroSubtitleSize({bool compact = false}) {
    if (compact) {
      if (isTablet) return 13.0;
      return 11.0;
    }
    if (isLargeTablet) return 15.0;
    if (isTablet) return 14.0;
    return 12.5;
  }

  double modeHomeHeroVerticalSpacing({bool compact = false}) {
    if (compact) return isTablet ? 12.0 : 10.0;
    if (isLargeTablet) return 18.0;
    if (isTablet) return 16.0;
    return 14.0;
  }
}
