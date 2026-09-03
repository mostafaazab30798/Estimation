import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../theme/app_theme.dart';
import '../utils/home_layout_metrics.dart';
import '../utils/wallpaper_precache.dart';
import 'app_buttons.dart';
import 'player_avatar.dart';
import 'package:estimation/core/icons/app_icons.dart';

// ── Background ───────────────────────────────────────────────────────────────

class FeltPatternPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.white.withValues(alpha: 0.015)
      ..strokeWidth = 0.5;

    const spacing = 28.0;
    for (double x = 0; x < size.width; x += spacing) {
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), paint);
    }
    for (double y = 0; y < size.height; y += spacing) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), paint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class ModeHomeBackground extends StatefulWidget {
  final String wallpaperAsset;
  final Color primaryGlow;
  final Color secondaryGlow;
  final bool subtleOverlay;

  const ModeHomeBackground({
    super.key,
    required this.wallpaperAsset,
    this.primaryGlow = AppTheme.gold,
    this.secondaryGlow = AppTheme.midBlue,
    this.subtleOverlay = false,
  });

  @override
  State<ModeHomeBackground> createState() => _ModeHomeBackgroundState();
}

class _ModeHomeBackgroundState extends State<ModeHomeBackground>
    with SingleTickerProviderStateMixin {
  late final AnimationController _shimmer;

  @override
  void initState() {
    super.initState();
    _shimmer = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 3),
    )..repeat();
  }

  @override
  void dispose() {
    _shimmer.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final wallpaper = WallpaperPrecache.wallpaperProvider(
      widget.wallpaperAsset,
      context,
    );

    return Stack(
      fit: StackFit.expand,
      children: [
        Image(
          image: wallpaper,
          fit: BoxFit.cover,
          gaplessPlayback: true,
          filterQuality: FilterQuality.medium,
          frameBuilder: (context, child, frame, wasSynchronouslyLoaded) {
            if (wasSynchronouslyLoaded || frame != null) return child;
            return Container(
              decoration: const BoxDecoration(gradient: AppTheme.bgGradient),
            );
          },
          errorBuilder: (_, __, ___) => Container(
            decoration: const BoxDecoration(gradient: AppTheme.bgGradient),
          ),
        ),
        Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: widget.subtleOverlay
                  ? [
                      Colors.black.withValues(alpha: 0.08),
                      AppTheme.deepNavy.withValues(alpha: 0.22),
                      AppTheme.deepNavy.withValues(alpha: 0.42),
                    ]
                  : [
                      Colors.black.withValues(alpha: 0.55),
                      AppTheme.deepNavy.withValues(alpha: 0.88),
                      AppTheme.deepNavy.withValues(alpha: 0.97),
                    ],
              stops: const [0.0, 0.45, 1.0],
            ),
          ),
        ),
        Positioned(
          top: -60,
          left: -40,
          child: _GlowOrb(
            animation: _shimmer,
            color: widget.primaryGlow,
            size: 220,
            alpha: 0.12,
          ),
        ),
        Positioned(
          bottom: 80,
          right: -50,
          child: _GlowOrb(
            animation: _shimmer,
            color: widget.secondaryGlow,
            size: 180,
            alpha: 0.18,
          ),
        ),
        CustomPaint(painter: FeltPatternPainter(), size: Size.infinite),
      ],
    );
  }
}

class _GlowOrb extends StatelessWidget {
  final Animation<double> animation;
  final Color color;
  final double size;
  final double alpha;

  const _GlowOrb({
    required this.animation,
    required this.color,
    required this.size,
    required this.alpha,
  });

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: animation,
      builder: (context, _) {
        final pulse = 0.92 + (animation.value * 0.16);
        return Transform.scale(
          scale: pulse,
          child: Container(
            width: size,
            height: size,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: RadialGradient(
                colors: [color.withValues(alpha: alpha), Colors.transparent],
              ),
            ),
          ),
        );
      },
    );
  }
}

// ── Chrome ───────────────────────────────────────────────────────────────────

class ModeHomeIconCapsule extends StatelessWidget {
  final AppIconData icon;
  final String label;
  final Color accent;
  final VoidCallback onTap;

  const ModeHomeIconCapsule({
    super.key,
    required this.icon,
    required this.label,
    required this.accent,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return AppIconCapsule(
      icon: icon,
      label: label,
      accent: accent,
      onTap: onTap,
    );
  }
}

class ModeHomeProfileChip extends StatelessWidget {
  final String photo;
  final String name;
  final VoidCallback onTap;

  const ModeHomeProfileChip({
    super.key,
    required this.photo,
    required this.name,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 2),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Floating Avatar with subtle golden halo and deep ambient shadow
            Container(
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.50),
                    blurRadius: 10,
                    offset: const Offset(0, 3),
                  ),
                  BoxShadow(
                    color: AppTheme.gold.withValues(alpha: 0.25),
                    blurRadius: 12,
                    spreadRadius: -1,
                  ),
                ],
              ),
              child: PlayerAvatar(
                photoData: photo,
                size: 36,
                borderWidth: 2,
                borderColor: AppTheme.goldLight,
              ),
            ),
            const SizedBox(width: 10),
            // Floating Name directly in the air with soft shadow
            ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 150),
              child: Text(
                name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: AppFonts.tajawal(
                  color: AppTheme.white,
                  fontWeight: FontWeight.w700,
                  fontSize: 15,
                  letterSpacing: 0.2,
                  shadows: [
                    Shadow(
                      color: Colors.black.withValues(alpha: 0.85),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class ModeHomeSectionLabel extends StatelessWidget {
  final String text;
  final Color accent;

  const ModeHomeSectionLabel({
    super.key,
    required this.text,
    this.accent = AppTheme.gold,
  });

  @override
  Widget build(BuildContext context) {
    final metrics = HomeLayoutMetrics.of(context);
    final fontSize = metrics.isLargeTablet ? 14.5 : (metrics.isTablet ? 14.0 : 13.0);

    return Row(
      children: [
        Container(
          width: 3,
          height: metrics.isTablet ? 16 : 14,
          decoration: BoxDecoration(
            color: accent,
            borderRadius: BorderRadius.circular(2),
          ),
        ),
        const SizedBox(width: 8),
        Text(
          text,
          style: AppFonts.cooper(
            fontSize: fontSize,
            fontWeight: FontWeight.bold,
            color: AppTheme.cream.withValues(alpha: 0.85),
          ),
        ),
      ],
    );
  }
}

class ModeHomeSuitFooter extends StatelessWidget {
  const ModeHomeSuitFooter({super.key});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10, top: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: const [
          Text('♠', style: TextStyle(fontSize: 13, color: AppTheme.accentLight)),
          SizedBox(width: 14),
          Text('♥', style: TextStyle(fontSize: 13, color: AppTheme.suitRed)),
          SizedBox(width: 14),
          Text('♦', style: TextStyle(fontSize: 13, color: AppTheme.suitRed)),
          SizedBox(width: 14),
          Text('♣', style: TextStyle(fontSize: 13, color: AppTheme.accentLight)),
        ],
      ),
    );
  }
}

class ModeHomeLandscapeDivider extends StatelessWidget {
  final Color accent;

  const ModeHomeLandscapeDivider({super.key, required this.accent});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 1,
      margin: const EdgeInsets.symmetric(vertical: 24),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            Colors.transparent,
            accent.withValues(alpha: 0.35),
            Colors.transparent,
          ],
        ),
      ),
    );
  }
}

/// Responsive body for Basra / 99 / Estimation mode home screens.
class ModeHomeScreenLayout extends StatelessWidget {
  const ModeHomeScreenLayout({
    super.key,
    required this.topBar,
    required this.hero,
    required this.primaryAction,
    required this.multiplayerSection,
    this.extraSection,
    this.accent = AppTheme.gold,
  });

  final Widget topBar;
  final Widget hero;
  final Widget primaryAction;
  final Widget multiplayerSection;
  final Widget? extraSection;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    final metrics = HomeLayoutMetrics.of(context);
    final isPhoneLandscape = metrics.isPhoneLandscape;

    return Column(
      children: [
        topBar,
        Expanded(
          child: metrics.useTabletHomeLayout
              ? (metrics.isLandscape
                  ? _buildTabletLandscape(context, metrics)
                  : _buildTabletPortrait(context, metrics))
              : (isPhoneLandscape
                  ? (metrics.isCompactLandscape
                      ? _buildPhoneCompactLandscape(context)
                      : _buildPhoneLandscape(context))
                  : _buildPhonePortrait(context)),
        ),
        const ModeHomeSuitFooter(),
      ],
    );
  }

  Widget _buildPhonePortrait(BuildContext context) {
    return SingleChildScrollView(
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(20, 4, 20, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          hero,
          const SizedBox(height: 22),
          primaryAction,
          const SizedBox(height: 18),
          multiplayerSection,
          if (extraSection != null) ...[
            const SizedBox(height: 22),
            extraSection!,
          ],
        ],
      ),
    );
  }

  Widget _buildPhoneLandscape(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 0, 24, 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Expanded(
            flex: 5,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                hero,
                const SizedBox(height: 20),
                primaryAction,
              ],
            ),
          ),
          const SizedBox(width: 20),
          ModeHomeLandscapeDivider(accent: accent),
          const SizedBox(width: 20),
          Expanded(
            flex: 6,
            child: SingleChildScrollView(
              physics: const BouncingScrollPhysics(),
              child: Column(
                children: [
                  multiplayerSection,
                  if (extraSection != null) ...[
                    const SizedBox(height: 16),
                    extraSection!,
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPhoneCompactLandscape(BuildContext context) {
    return SingleChildScrollView(
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            flex: 5,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                hero,
                const SizedBox(height: 12),
                primaryAction,
              ],
            ),
          ),
          const SizedBox(width: 12),
          ModeHomeLandscapeDivider(accent: accent),
          const SizedBox(width: 12),
          Expanded(
            flex: 6,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                multiplayerSection,
                if (extraSection != null) ...[
                  const SizedBox(height: 12),
                  extraSection!,
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTabletPortrait(BuildContext context, HomeLayoutMetrics metrics) {
    return Center(
      child: SingleChildScrollView(
        physics: const BouncingScrollPhysics(),
        padding: EdgeInsets.fromLTRB(
          metrics.modeHomeHorizontalPadding(),
          metrics.isLargeTablet ? 12 : 8,
          metrics.modeHomeHorizontalPadding(),
          16,
        ),
        child: ConstrainedBox(
          constraints: BoxConstraints(maxWidth: metrics.modeHomeContentMaxWidth()),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              hero,
              SizedBox(height: metrics.modeHomeSectionSpacing() + 6),
              ModeHomeActionsPanel(
                accent: accent,
                primaryAction: primaryAction,
                multiplayerSection: multiplayerSection,
                extraSection: extraSection,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTabletLandscape(BuildContext context, HomeLayoutMetrics metrics) {
    return Center(
      child: Padding(
        padding: EdgeInsets.fromLTRB(
          metrics.modeHomeHorizontalPadding(),
          0,
          metrics.modeHomeHorizontalPadding(),
          metrics.isLargeTablet ? 12 : 8,
        ),
        child: ConstrainedBox(
          constraints: BoxConstraints(maxWidth: metrics.modeHomeContentMaxWidth()),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Expanded(
                flex: metrics.isLargeTablet ? 5 : 4,
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [hero],
                ),
              ),
              SizedBox(width: metrics.isLargeTablet ? 36 : 28),
              Expanded(
                flex: metrics.isLargeTablet ? 6 : 5,
                child: ModeHomeActionsPanel(
                  accent: accent,
                  primaryAction: primaryAction,
                  multiplayerSection: multiplayerSection,
                  extraSection: extraSection,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Glass panel grouping solo + multiplayer actions on tablets.
class ModeHomeActionsPanel extends StatelessWidget {
  const ModeHomeActionsPanel({
    super.key,
    required this.accent,
    required this.primaryAction,
    required this.multiplayerSection,
    this.extraSection,
  });

  final Color accent;
  final Widget primaryAction;
  final Widget multiplayerSection;
  final Widget? extraSection;

  @override
  Widget build(BuildContext context) {
    final metrics = HomeLayoutMetrics.of(context);
    final radius = metrics.isLargeTablet ? 28.0 : 24.0;
    final padding = metrics.isLargeTablet ? 28.0 : 22.0;

    return Container(
      padding: EdgeInsets.all(padding),
      decoration: AppTheme.glassDecoration(
        borderRadius: radius,
        borderColor: accent.withValues(alpha: 0.34),
        fillColor: AppTheme.navyMid.withValues(alpha: 0.74),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          primaryAction,
          SizedBox(height: metrics.modeHomeSectionSpacing()),
          multiplayerSection,
          if (extraSection != null) ...[
            SizedBox(height: metrics.modeHomeSectionSpacing()),
            extraSection!,
          ],
        ],
      ),
    );
  }
}

// ── Hero ─────────────────────────────────────────────────────────────────────

class ModeHomeFloatingCard extends StatelessWidget {
  final String suit;
  final Color color;
  final double angle;

  const ModeHomeFloatingCard({
    super.key,
    required this.suit,
    required this.color,
    this.angle = 0,
  });

  @override
  Widget build(BuildContext context) {
    return Transform.rotate(
      angle: angle,
      child: Container(
        width: 38,
        height: 52,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(6),
          gradient: const LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFFF5F0E6), Color(0xFFE8DFD0)],
          ),
          border: Border.all(color: Colors.white.withValues(alpha: 0.6)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.35),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        alignment: Alignment.center,
        child: Text(
          suit,
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w900,
            color: color,
          ),
        ),
      ),
    );
  }
}

class ModeHomeHero extends StatelessWidget {
  final Widget emblem;
  final String title;
  final String subtitle;
  final bool compact;
  final bool showFloatingCards;
  final Widget? footer;

  const ModeHomeHero({
    super.key,
    required this.emblem,
    required this.title,
    required this.subtitle,
    this.compact = false,
    this.showFloatingCards = true,
    this.footer,
  });

  @override
  Widget build(BuildContext context) {
    final metrics = HomeLayoutMetrics.of(context);

    return Column(
      children: [
        Stack(
          alignment: Alignment.center,
          clipBehavior: Clip.none,
          children: [
            if (showFloatingCards && !compact) ...[
              const Positioned(
                right: -18,
                top: -8,
                child: ModeHomeFloatingCard(
                  suit: '♥',
                  color: AppTheme.suitRed,
                  angle: 0.08,
                ),
              ),
              const Positioned(
                left: -14,
                bottom: -6,
                child: ModeHomeFloatingCard(
                  suit: '♣',
                  color: AppTheme.steelBlue,
                  angle: -0.12,
                ),
              ),
            ],
            emblem,
          ],
        ),
        SizedBox(height: metrics.modeHomeHeroVerticalSpacing(compact: compact)),
        Text(
          title,
          style: AppFonts.dg(
            fontSize: metrics.modeHomeHeroTitleSize(compact: compact),
            fontWeight: FontWeight.w900,
            color: AppTheme.white,
            letterSpacing: 0.5,
            height: 1.1,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          subtitle,
          style: AppFonts.cooper(
            fontSize: metrics.modeHomeHeroSubtitleSize(compact: compact),
            color: AppTheme.steelBlue,
            fontWeight: FontWeight.w600,
          ),
          textAlign: TextAlign.center,
        ),
        if (footer != null) ...[
          SizedBox(height: compact ? 12 : (metrics.isTablet ? 18 : 16)),
          footer!,
        ],
      ],
    );
  }
}

/// Mode brand art for home heroes — optional overhang past the disc rim.
class ModeHomeArtEmblem extends StatelessWidget {
  final String asset;
  final Color accent;
  final double size;
  final bool overflows;

  const ModeHomeArtEmblem({
    super.key,
    required this.asset,
    required this.accent,
    this.size = 88,
    this.overflows = false,
  });

  /// Derives emblem size from the current screen bucket.
  factory ModeHomeArtEmblem.responsive(
    BuildContext context, {
    required String asset,
    required Color accent,
    bool compact = false,
    bool overflows = false,
  }) {
    final metrics = HomeLayoutMetrics.of(context);
    return ModeHomeArtEmblem(
      asset: asset,
      accent: accent,
      size: metrics.modeEmblemSize(compact: compact),
      overflows: overflows,
    );
  }

  /// Art mark for mode-selection cards.
  factory ModeHomeArtEmblem.forModeCard(
    BuildContext context, {
    required String asset,
    required Color accent,
    bool tall = false,
    bool overflows = false,
  }) {
    final metrics = HomeLayoutMetrics.of(context);
    return ModeHomeArtEmblem(
      asset: asset,
      accent: accent,
      size: metrics.modeCardArtSize(tall: tall),
      overflows: overflows,
    );
  }

  @override
  Widget build(BuildContext context) {
    return _ModeBrandEmblemFrame(
      asset: asset,
      accent: accent,
      size: size,
      overflows: overflows,
    );
  }
}

class _ModeBrandEmblemFrame extends StatelessWidget {
  const _ModeBrandEmblemFrame({
    required this.asset,
    required this.accent,
    required this.size,
    required this.overflows,
  });

  final String asset;
  final Color accent;
  final double size;
  final bool overflows;

  @override
  Widget build(BuildContext context) {
    final glowSize = size * 1.22;
    final frameSize = overflows ? size * 0.82 : size;
    final artSize = overflows ? size * 1.14 : size * 0.88;

    return SizedBox(
      width: size,
      height: size,
      child: Stack(
        clipBehavior: Clip.none,
        alignment: Alignment.center,
        children: [
          Container(
            width: glowSize,
            height: glowSize,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: RadialGradient(
                colors: [
                  accent.withValues(alpha: 0.20),
                  accent.withValues(alpha: 0.06),
                  Colors.transparent,
                ],
                stops: const [0.0, 0.55, 1.0],
              ),
            ),
          ),
          Container(
            width: frameSize,
            height: frameSize,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  AppTheme.surface2.withValues(alpha: 0.92),
                  const Color(0xFF07070C),
                ],
              ),
              border: Border.all(
                color: accent.withValues(alpha: 0.52),
                width: 1.8,
              ),
              boxShadow: [
                BoxShadow(
                  color: accent.withValues(alpha: 0.26),
                  blurRadius: 20,
                  spreadRadius: 1,
                ),
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.38),
                  blurRadius: 12,
                  offset: const Offset(0, 6),
                ),
              ],
            ),
          ),
          SizedBox(
            width: artSize,
            height: artSize,
            child: Image.asset(
              asset,
              fit: BoxFit.contain,
              filterQuality: FilterQuality.high,
            ),
          ),
        ],
      ),
    );
  }
}

// ── Actions ──────────────────────────────────────────────────────────────────

class ModeHomeActionButton extends StatefulWidget {
  final String label;
  final String? subtitle;
  final AppIconData icon;
  final List<Color> gradient;
  final VoidCallback? onTap;
  final bool isLarge;
  final bool enabled;

  const ModeHomeActionButton({
    super.key,
    required this.label,
    this.subtitle,
    required this.icon,
    required this.gradient,
    this.onTap,
    this.isLarge = false,
    this.enabled = true,
  });

  @override
  State<ModeHomeActionButton> createState() => _ModeHomeActionButtonState();
}

class _ModeHomeActionButtonState extends State<ModeHomeActionButton> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    final canTap = widget.enabled && widget.onTap != null;
    return GestureDetector(
      onTapDown: canTap ? (_) => setState(() => _pressed = true) : null,
      onTapUp: canTap
          ? (_) {
              setState(() => _pressed = false);
              widget.onTap!();
            }
          : null,
      onTapCancel: canTap ? () => setState(() => _pressed = false) : null,
      child: AnimatedOpacity(
        opacity: canTap ? 1 : 0.55,
        duration: const Duration(milliseconds: 200),
        child: AnimatedScale(
          scale: _pressed ? (widget.isLarge ? 0.98 : 0.96) : 1.0,
          duration: const Duration(milliseconds: 100),
          child: widget.isLarge ? _buildLarge() : _buildCompact(),
        ),
      ),
    );
  }

  Widget _buildLarge() {
    final metrics = HomeLayoutMetrics.of(context);
    final iconWellSize = metrics.isLargeTablet ? 56.0 : (metrics.isTablet ? 52.0 : 48.0);
    final iconSize = metrics.isLargeTablet ? 28.0 : AppIconTokens.sizeHero;
    final titleSize = metrics.isLargeTablet ? 19.0 : (metrics.isTablet ? 18.0 : 17.0);
    final verticalPadding = metrics.isTablet ? 18.0 : 16.0;

    return Container(
      padding: EdgeInsets.symmetric(horizontal: 18, vertical: verticalPadding),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(22),
        gradient: LinearGradient(
          colors: widget.gradient,
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        boxShadow: [
          BoxShadow(
            color: widget.gradient.first.withValues(alpha: 0.40),
            blurRadius: 18,
            offset: const Offset(0, 6),
          ),
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.28),
            blurRadius: 8,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Row(
        children: [
          AppIconWell(
            icon: widget.icon,
            size: iconWellSize,
            iconSize: iconSize,
            color: Colors.white,
            fill: Colors.white.withValues(alpha: 0.16),
            borderColor: Colors.white.withValues(alpha: 0.28),
            strokeWidth: AppIconTokens.strokeBold,
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  widget.label,
                  style: AppFonts.cooper(
                    color: Colors.white,
                    fontSize: titleSize,
                    fontWeight: FontWeight.w900,
                    height: 1.15,
                  ),
                ),
                if (widget.subtitle != null && widget.subtitle!.isNotEmpty) ...[
                  const SizedBox(height: 2),
                  Text(
                    widget.subtitle!,
                    style: AppFonts.cooper(
                      color: Colors.white.withValues(alpha: 0.78),
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      height: 1.2,
                    ),
                  ),
                ],
              ],
            ),
          ),
          AppIcon(
            AppIcons.arrowForwardIos,
            color: Colors.white.withValues(alpha: 0.72),
            size: AppIconTokens.sizeMd,
            strokeWidth: AppIconTokens.stroke,
          ),
        ],
      ),
    );
  }

  Widget _buildCompact() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 14),
      decoration: BoxDecoration(
        color: AppTheme.navyDark.withValues(alpha: 0.72),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: widget.gradient.first.withValues(alpha: 0.32),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.25),
            blurRadius: 8,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        children: [
          AppIconWell(
            icon: widget.icon,
            size: 42,
            iconSize: AppIconTokens.sizeLg,
            color: Colors.white,
            gradient: LinearGradient(
              colors: widget.gradient,
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderColor: Colors.white.withValues(alpha: 0.20),
            strokeWidth: AppIconTokens.strokeBold,
          ),
          const SizedBox(height: 9),
          Text(
            widget.label,
            style: AppFonts.cooper(
              color: AppTheme.white,
              fontSize: 12.5,
              fontWeight: FontWeight.bold,
              height: 1.15,
            ),
            textAlign: TextAlign.center,
          ),
          if (widget.subtitle != null && widget.subtitle!.isNotEmpty) ...[
            const SizedBox(height: 2),
            Text(
              widget.subtitle!,
              style: AppFonts.cooper(
                color: AppTheme.steelBlue,
                fontSize: 10,
                fontWeight: FontWeight.w600,
                height: 1.2,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ],
      ),
    );
  }
}

class ModeHomeCompactTile extends StatefulWidget {
  final String title;
  final AppIconData icon;
  final Color color;
  final VoidCallback onTap;

  const ModeHomeCompactTile({
    super.key,
    required this.title,
    required this.icon,
    required this.color,
    required this.onTap,
  });

  @override
  State<ModeHomeCompactTile> createState() => _ModeHomeCompactTileState();
}

class _ModeHomeCompactTileState extends State<ModeHomeCompactTile> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (_) => setState(() => _pressed = true),
      onTapUp: (_) {
        setState(() => _pressed = false);
        widget.onTap();
      },
      onTapCancel: () => setState(() => _pressed = false),
      child: AnimatedScale(
        scale: _pressed ? 0.97 : 1.0,
        duration: const Duration(milliseconds: 100),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
          decoration: BoxDecoration(
            color: widget.color.withValues(alpha: 0.10),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: widget.color.withValues(alpha: 0.28)),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              AppIconWell(
                icon: widget.icon,
                size: 30,
                iconSize: AppIconTokens.sizeSm,
                color: widget.color,
                fill: widget.color.withValues(alpha: 0.14),
                borderColor: widget.color.withValues(alpha: 0.30),
              ),
              const SizedBox(width: 10),
              Text(
                widget.title,
                style: AppFonts.cooper(
                  color: AppTheme.cream,
                  fontSize: 13,
                  fontWeight: FontWeight.bold,
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

// ── Sheets & Inputs ──────────────────────────────────────────────────────────

Future<T?> showModeHomeSheet<T>(
  BuildContext context, {
  required String title,
  required String subtitle,
  required Color accent,
  required Widget child,
}) {
  return showModalBottomSheet<T>(
    context: context,
    backgroundColor: Colors.transparent,
    isScrollControlled: true,
    builder: (ctx) => Padding(
      padding: EdgeInsets.only(
        left: 16,
        right: 16,
        bottom: MediaQuery.of(ctx).viewInsets.bottom + 16,
      ),
      child: Container(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
        decoration: AppTheme.glassDecoration(
          borderRadius: 24,
          borderColor: accent.withValues(alpha: 0.35),
          fillColor: AppTheme.navyDark.withValues(alpha: 0.96),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 36,
              height: 4,
              margin: const EdgeInsets.only(bottom: 16),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            Text(
              title,
              style: AppFonts.cooper(
                color: AppTheme.white,
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              subtitle,
              style: AppFonts.cooper(
                color: AppTheme.steelBlue,
                fontSize: 12,
              ),
            ),
            const SizedBox(height: 18),
            child,
          ],
        ),
      ),
    ),
  );
}

class PlayerCountTile extends StatelessWidget {
  final String label;
  final AppIconData icon;
  final VoidCallback onTap;

  const PlayerCountTile({
    super.key,
    required this.label,
    required this.icon,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(18),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 14),
          decoration: BoxDecoration(
            color: AppTheme.deepNavy.withValues(alpha: 0.8),
            borderRadius: BorderRadius.circular(18),
            border: Border.all(
              color: AppTheme.accentBlue.withValues(alpha: 0.32),
            ),
          ),
          child: Column(
            children: [
              AppIconWell(
                icon: icon,
                size: 40,
                iconSize: AppIconTokens.sizeXl,
                color: AppTheme.mintSoft,
                fill: AppTheme.accentBlue.withValues(alpha: 0.14),
                borderColor: AppTheme.accentBlue.withValues(alpha: 0.30),
              ),
              const SizedBox(height: 8),
              Text(
                label,
                style: AppFonts.cooper(
                  color: AppTheme.white,
                  fontSize: 18,
                  fontWeight: FontWeight.w900,
                  height: 1.1,
                ),
              ),
              Text(
                'لاعبين',
                style: AppFonts.cooper(
                  color: AppTheme.steelBlue,
                  fontSize: 10,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class PlayerCountRow extends StatelessWidget {
  final List<int> counts;
  final ValueChanged<int> onSelect;

  const PlayerCountRow({
    super.key,
    this.counts = const [2, 3, 4],
    required this.onSelect,
  });

  @override
  Widget build(BuildContext context) {
    AppIconData iconFor(int count) {
      if (count <= 2) return AppIcons.person;
      if (count == 3) return AppIcons.group;
      return AppIcons.groups;
    }

    return Row(
      children: [
        for (int i = 0; i < counts.length; i++) ...[
          if (i > 0) const SizedBox(width: 8),
          Expanded(
            child: PlayerCountTile(
              label: '${counts[i]}',
              icon: iconFor(counts[i]),
              onTap: () => onSelect(counts[i]),
            ),
          ),
        ],
      ],
    );
  }
}

class PlayerCountWrap extends StatelessWidget {
  final List<int> counts;
  final int selected;
  final Color accent;
  final ValueChanged<int> onSelect;

  const PlayerCountWrap({
    super.key,
    required this.counts,
    required this.selected,
    required this.accent,
    required this.onSelect,
  });

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      alignment: WrapAlignment.center,
      children: counts.map((count) {
        final isSel = selected == count;
        return GestureDetector(
          onTap: () {
            HapticFeedback.selectionClick();
            onSelect(count);
          },
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 180),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            decoration: BoxDecoration(
              color: isSel ? accent : Colors.white.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: isSel ? accent : Colors.white12,
              ),
              boxShadow: isSel
                  ? [
                      BoxShadow(
                        color: accent.withValues(alpha: 0.35),
                        blurRadius: 8,
                      ),
                    ]
                  : [],
            ),
            child: Text(
              '$count لاعبين',
              style: AppFonts.cooper(
                color: isSel ? Colors.white : Colors.white70,
                fontWeight: FontWeight.bold,
                fontSize: 12,
              ),
            ),
          ),
        );
      }).toList(),
    );
  }
}

class ModeHomeJoinTextField extends StatelessWidget {
  final TextEditingController controller;

  const ModeHomeJoinTextField({super.key, required this.controller});

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      textAlign: TextAlign.center,
      textDirection: TextDirection.ltr,
      keyboardType: TextInputType.visiblePassword,
      maxLength: 6,
      textCapitalization: TextCapitalization.characters,
      inputFormatters: [
        FilteringTextInputFormatter.allow(RegExp(r'[A-Z0-9]')),
      ],
      style: AppFonts.cooper(
        color: AppTheme.mintSoft,
        fontSize: 20,
        fontWeight: FontWeight.bold,
        letterSpacing: 6,
      ),
      decoration: InputDecoration(
        hintText: 'ABCDEF',
        hintStyle: AppFonts.cooper(
          color: AppTheme.accentLight.withValues(alpha: 0.4),
          fontSize: 16,
          letterSpacing: 4,
        ),
        prefixIcon: AppIcon(
          AppIcons.tag,
          color: AppTheme.accentLight.withValues(alpha: 0.7),
          size: 20,
        ),
        counterText: '',
        filled: true,
        fillColor: AppTheme.deepNavy.withValues(alpha: 0.8),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(
            color: AppTheme.accentBlue.withValues(alpha: 0.3),
          ),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(
            color: AppTheme.accentBlue.withValues(alpha: 0.3),
          ),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: AppTheme.accentBlue, width: 2),
        ),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      ),
    );
  }
}
