import 'dart:math' as math;

import 'package:flutter/material.dart';

/// Screen-size buckets for game table layouts.
enum GameScreenSize {
  phone,
  tablet,
  largeTablet,
}

/// Responsive layout values shared across Estimation, Basra, and 99 game screens.
class GameLayoutMetrics {
  GameLayoutMetrics._({
    required this.size,
    required this.orientation,
  });

  final Size size;
  final Orientation orientation;

  bool get isPortrait => orientation == Orientation.portrait;
  double get width => size.width;
  double get height => size.height;
  double get minDimension => math.min(width, height);
  double get maxDimension => math.max(width, height);
  double get shortestSide => minDimension;
  double get longestSide => maxDimension;

  bool get isTablet => shortestSide >= 600;
  bool get isLargeTablet => isTablet && longestSide >= 900;

  /// Split top HUD when the bar itself is wide enough (left + center gap + right).
  /// Uses allocated width instead of shortestSide so rebuilds / DPI scaling stay stable.
  bool shouldUseSplitHud(double availableWidth) {
    if (!availableWidth.isFinite) return isTablet;
    return availableWidth >= 620;
  }

  GameScreenSize get screenSize {
    if (isLargeTablet) return GameScreenSize.largeTablet;
    if (isTablet) return GameScreenSize.tablet;
    return GameScreenSize.phone;
  }

  static GameLayoutMetrics of(BuildContext context) {
    final media = MediaQuery.of(context);
    return GameLayoutMetrics._(
      size: media.size,
      orientation: media.orientation,
    );
  }

  // ── Center play area ───────────────────────────────────────────────────

  double get trickAreaSize {
    switch (screenSize) {
      case GameScreenSize.phone:
        return isPortrait
            ? (minDimension * 0.52).clamp(140.0, 250.0)
            : (height * 0.44).clamp(160.0, 290.0);
      case GameScreenSize.tablet:
        return isPortrait
            ? (minDimension * 0.46).clamp(250.0, 320.0)
            : (height * 0.46).clamp(270.0, 360.0);
      case GameScreenSize.largeTablet:
        return isPortrait
            ? (minDimension * 0.44).clamp(280.0, 380.0)
            : (height * 0.50).clamp(300.0, 400.0);
    }
  }

  Alignment get trickAreaAlignment {
    switch (screenSize) {
      case GameScreenSize.phone:
        return Alignment(0, isPortrait ? -0.32 : -0.25);
      case GameScreenSize.tablet:
        return Alignment(0, isPortrait ? -0.20 : -0.12);
      case GameScreenSize.largeTablet:
        return Alignment(0, isPortrait ? -0.14 : -0.08);
    }
  }

  /// Card width fraction inside [TrickArea] relative to the trick square size.
  double get trickCardWidthFraction {
    switch (screenSize) {
      case GameScreenSize.phone:
        return isPortrait ? 0.27 : 0.31;
      case GameScreenSize.tablet:
        return isPortrait ? 0.25 : 0.28;
      case GameScreenSize.largeTablet:
        return isPortrait ? 0.26 : 0.29;
    }
  }

  // ── Opponent positioning ─────────────────────────────────────────────────

  double get topOpponentTop {
    switch (screenSize) {
      case GameScreenSize.phone:
        return isPortrait ? 128.0 : 64.0;
      case GameScreenSize.tablet:
        return isPortrait ? 148.0 : 76.0;
      case GameScreenSize.largeTablet:
        return isPortrait ? 164.0 : 88.0;
    }
  }

  double get sideInset {
    switch (screenSize) {
      case GameScreenSize.phone:
        return isPortrait ? 4.0 : 14.0;
      case GameScreenSize.tablet:
        return isPortrait ? 18.0 : 36.0;
      case GameScreenSize.largeTablet:
        return isPortrait ? 28.0 : 52.0;
    }
  }

  double get topHudInset => screenSize == GameScreenSize.phone ? 6.0 : 12.0;

  double get topHudHorizontalInset {
    switch (screenSize) {
      case GameScreenSize.phone:
        return 10.0;
      case GameScreenSize.tablet:
        return 20.0;
      case GameScreenSize.largeTablet:
        return 32.0;
    }
  }

  double get topHudPanelGap {
    switch (screenSize) {
      case GameScreenSize.phone:
        return 0.0;
      case GameScreenSize.tablet:
        return 10.0;
      case GameScreenSize.largeTablet:
        return 14.0;
    }
  }

  /// Whether opponent info at the top should use the compact layout.
  bool get topOpponentCompact => screenSize == GameScreenSize.phone;

  /// Whether side opponents should use the compact layout.
  bool get sideOpponentCompact => screenSize == GameScreenSize.phone;

  /// Whether the local player's info card should use the compact layout.
  bool get localPlayerCompact =>
      !isPortrait && screenSize == GameScreenSize.phone;

  /// Extra inset for the local identity card on large screens.
  /// Applied around the card only — not used to shrink the hand.
  EdgeInsets get localPlayerInfoPadding {
    if (screenSize == GameScreenSize.phone) return EdgeInsets.zero;
    final bottom = screenSize == GameScreenSize.largeTablet ? 16.0 : 12.0;
    final side = screenSize == GameScreenSize.largeTablet ? 20.0 : 14.0;
    if (isPortrait) {
      return EdgeInsets.fromLTRB(side, 0, side, bottom);
    }
    return EdgeInsets.fromLTRB(side, 0, 0, bottom);
  }

  // ── Hidden opponent card backs ──────────────────────────────────────────

  double get hiddenCardWidth {
    switch (screenSize) {
      case GameScreenSize.phone:
        return 30.0;
      case GameScreenSize.tablet:
        return 38.0;
      case GameScreenSize.largeTablet:
        return 44.0;
    }
  }

  double get hiddenCardOverlap =>
      hiddenCardWidth * (screenSize == GameScreenSize.phone ? 0.37 : 0.34);

  // ── Player hand ──────────────────────────────────────────────────────────

  double get handSideReserve {
    if (screenSize == GameScreenSize.phone) {
      return isPortrait ? 20.0 : 180.0;
    }
    if (screenSize == GameScreenSize.tablet) {
      return isPortrait ? 48.0 : 240.0;
    }
    return isPortrait ? 64.0 : 280.0;
  }

  double get handMaxWidthFraction {
    if (screenSize == GameScreenSize.phone) {
      return isPortrait ? 0.97 : 0.80;
    }
    if (screenSize == GameScreenSize.tablet) {
      return isPortrait ? 0.88 : 0.74;
    }
    return isPortrait ? 0.82 : 0.68;
  }

  double get handMaxCardWidth {
    switch (screenSize) {
      case GameScreenSize.phone:
        return isPortrait ? 66.0 : 58.0;
      case GameScreenSize.tablet:
        return isPortrait ? 92.0 : 84.0;
      case GameScreenSize.largeTablet:
        return isPortrait ? 108.0 : 96.0;
    }
  }

  double get handMinCardWidth => isPortrait ? 48.0 : 44.0;

  double get handMaxOverlap {
    switch (screenSize) {
      case GameScreenSize.phone:
        return isPortrait ? 44.0 : 38.0;
      case GameScreenSize.tablet:
        return isPortrait ? 56.0 : 50.0;
      case GameScreenSize.largeTablet:
        return isPortrait ? 64.0 : 58.0;
    }
  }

  double handAvailableWidth(double screenWidth) =>
      (screenWidth - handSideReserve)
          .clamp(280.0, screenWidth * handMaxWidthFraction);

  // ── Reaction bubble anchors ──────────────────────────────────────────────

  ReactionBubbleLayout reactionLayout({required bool isPortrait}) {
    switch (screenSize) {
      case GameScreenSize.phone:
        return ReactionBubbleLayout(
          myBottom: isPortrait ? 138.0 : 88.0,
          myLeft: isPortrait ? 20.0 : 110.0,
          sideBottom: isPortrait ? 260.0 : 180.0,
          sideInset: isPortrait ? 8.0 : 16.0,
          topOffset: isPortrait ? 80.0 : 70.0,
        );
      case GameScreenSize.tablet:
        return ReactionBubbleLayout(
          myBottom: isPortrait ? 168.0 : 108.0,
          myLeft: isPortrait ? 32.0 : 140.0,
          sideBottom: isPortrait ? 320.0 : 220.0,
          sideInset: isPortrait ? 20.0 : 32.0,
          topOffset: isPortrait ? 96.0 : 84.0,
        );
      case GameScreenSize.largeTablet:
        return ReactionBubbleLayout(
          myBottom: isPortrait ? 188.0 : 124.0,
          myLeft: isPortrait ? 48.0 : 168.0,
          sideBottom: isPortrait ? 360.0 : 260.0,
          sideInset: isPortrait ? 28.0 : 44.0,
          topOffset: isPortrait ? 108.0 : 96.0,
        );
    }
  }

  /// 99-mode center pile container dimensions.
  ({double width, double height, double cardWidth}) get centerPileSize {
    switch (screenSize) {
      case GameScreenSize.phone:
        return (width: 170.0, height: 120.0, cardWidth: 58.0);
      case GameScreenSize.tablet:
        return (width: 190.0, height: 132.0, cardWidth: 62.0);
      case GameScreenSize.largeTablet:
        return (width: 210.0, height: 148.0, cardWidth: 68.0);
    }
  }

  /// Basra table card width inside the center play area.
  double basraTableCardWidth(double tableSize) {
    final base = tableSize * (isPortrait ? 0.27 : 0.31);
    switch (screenSize) {
      case GameScreenSize.phone:
        return base.clamp(48.0, 68.0);
      case GameScreenSize.tablet:
        return base.clamp(50.0, 72.0);
      case GameScreenSize.largeTablet:
        return base.clamp(54.0, 78.0);
    }
  }

  EllipseOpponentLayout ellipseLayout() {
    final scale = switch (screenSize) {
      GameScreenSize.phone => 1.0,
      GameScreenSize.tablet => 1.12,
      GameScreenSize.largeTablet => 1.22,
    };
    return EllipseOpponentLayout(
      radiusX: (isPortrait ? width * 0.44 : width * 0.42) * scale,
      radiusY: (isPortrait ? height * 0.35 : height * 0.40) * scale,
      centerY: isPortrait ? height * 0.48 : height * 0.54,
      widgetWidth: screenSize == GameScreenSize.phone ? 200.0 : 240.0,
    );
  }
}

class ReactionBubbleLayout {
  const ReactionBubbleLayout({
    required this.myBottom,
    required this.myLeft,
    required this.sideBottom,
    required this.sideInset,
    required this.topOffset,
  });

  final double myBottom;
  final double myLeft;
  final double sideBottom;
  final double sideInset;
  final double topOffset;
}

class EllipseOpponentLayout {
  const EllipseOpponentLayout({
    required this.radiusX,
    required this.radiusY,
    required this.centerY,
    required this.widgetWidth,
  });

  final double radiusX;
  final double radiusY;
  final double centerY;
  final double widgetWidth;
}
