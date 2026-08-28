// lib/screens/mode_selection_screen.dart

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';

import '../core/widgets/mode_home_shell.dart';
import '../core/widgets/app_buttons.dart';
import '../theme/app_theme.dart';
import '../services/audio_service.dart';
import '../services/settings_service.dart';
import '../services/profile_service.dart';
import 'package:estimation/core/icons/app_icons.dart';

// ── Game Mode Model ──────────────────────────────────────────────────────────

class _MainGameMode {
  final String title;
  final String subtitle;
  final Color accent;
  final String artAsset;
  final String route;
  /// When true, art sits above the disc and may overhang its rim.
  final bool artOverflows;

  const _MainGameMode({
    required this.title,
    required this.subtitle,
    required this.accent,
    required this.artAsset,
    required this.route,
    this.artOverflows = false,
  });
}

// ── Main Mode Selection Screen ───────────────────────────────────────────────

class ModeSelectionScreen extends StatefulWidget {
  const ModeSelectionScreen({super.key});

  @override
  State<ModeSelectionScreen> createState() => _ModeSelectionScreenState();
}

class _ModeSelectionScreenState extends State<ModeSelectionScreen>
    with SingleTickerProviderStateMixin {
  String _playerName = 'لاعب كوتشينة';
  String _playerPhoto = ProfileService.presetAvatars.first.id;
  late final AnimationController _animController;
  late final Animation<double> _fadeIn;
  late final Animation<Offset> _slideIn;

  static const List<_MainGameMode> _modes = [
    _MainGameMode(
      title: 'إستميشن',
      subtitle: 'البولة الكلاسيكية والميني جيم',
      accent: Color(0xFFC8F542),
      artAsset: 'assets/estimation.png',
      route: '/kotchina/home',
      artOverflows: true,
    ),
    _MainGameMode(
      title: 'باصرة',
      subtitle: 'اقتناص الأرض حتى 121 نقطة',
      accent: Color(0xFFE8B923),
      artAsset: 'assets/basra.png',
      route: '/basra/home',
      artOverflows: true,
    ),
    _MainGameMode(
      title: 'مود الـ 99',
      subtitle: 'تحدي السرعة والموت المفاجئ',
      accent: Color(0xFFFF2D95),
      artAsset: 'assets/99.png',
      route: '/ninety_nine/home',
    ),
  ];

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 700),
    );
    _fadeIn = CurvedAnimation(
      parent: _animController,
      curve: Curves.easeOutCubic,
    );
    _slideIn = Tween<Offset>(begin: const Offset(0, 0.04), end: Offset.zero)
        .animate(CurvedAnimation(
      parent: _animController,
      curve: Curves.easeOutCubic,
    ));
    _animController.forward();
    _loadPlayerProfile();
  }

  @override
  void dispose() {
    _animController.dispose();
    super.dispose();
  }

  Future<void> _loadPlayerProfile() async {
    try {
      final name = await ProfileService.getProfileName();
      final photo = await ProfileService.getProfilePhoto();
      if (mounted && name.isNotEmpty) {
        setState(() {
          _playerName = name;
          _playerPhoto = photo;
        });
      }
    } catch (_) {}
  }

  void _openProfile() async {
    HapticFeedback.selectionClick();
    AudioService.instance.playCard();
    await Navigator.pushNamed(context, '/profile');
    _loadPlayerProfile();
  }

  void _tap(VoidCallback action) {
    HapticFeedback.mediumImpact();
    AudioService.instance.playCard();
    action();
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final isLandscape = size.width > size.height;

    return Scaffold(
      backgroundColor: AppTheme.deepNavy,
      body: Stack(
        fit: StackFit.expand,
        children: [
          const ModeHomeBackground(
            wallpaperAsset: 'assets/wallpapers/w1.jpg',
            primaryGlow: AppTheme.gold,
            secondaryGlow: AppTheme.midBlue,
          ),
          SafeArea(
            child: FadeTransition(
              opacity: _fadeIn,
              child: SlideTransition(
                position: _slideIn,
                child: Column(
                  children: [
                    _buildTopBar(),
                    SizedBox(height: isLandscape ? 4 : 12),
                    _buildHeroHeader(compact: isLandscape),
                    const Spacer(),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 20),
                      child: ConstrainedBox(
                        constraints: BoxConstraints(
                          maxWidth: isLandscape ? 880 : 420,
                        ),
                        child: isLandscape
                            ? _buildLandscapeModes(context)
                            : _buildPortraitModes(context),
                      ),
                    ),
                    const Spacer(),
                    const ModeHomeSuitFooter(),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTopBar() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
      child: Row(
        children: [
          ModeHomeProfileChip(
            photo: _playerPhoto,
            name: _playerName,
            onTap: _openProfile,
          ),
          const Spacer(),
          ListenableBuilder(
            listenable: SettingsService.instance,
            builder: (context, _) {
              final sfx = SettingsService.instance.sfxEnabled;
              return AppIconButton(
                icon: sfx ? AppIcons.volumeUp : AppIcons.volumeOff,
                color: sfx ? AppTheme.gold : Colors.white54,
                backgroundColor: AppTheme.navyDark.withValues(alpha: 0.72),
                borderColor: sfx
                    ? AppTheme.gold.withValues(alpha: 0.35)
                    : Colors.white12,
                size: AppIconButtonSize.md,
                onTap: () {
                  SettingsService.instance.setSfxEnabled(!sfx);
                  if (!sfx) AudioService.instance.playCard();
                },
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildHeroHeader({bool compact = false}) {
    return Column(
      children: [
        Text(
          'كوتشينة',
          style: GoogleFonts.cairo(
            fontSize: compact ? 26 : 34,
            fontWeight: FontWeight.w900,
            color: AppTheme.white,
            letterSpacing: 0.5,
            height: 1.1,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          'اختر نمط اللعب',
          style: GoogleFonts.cairo(
            fontSize: compact ? 12 : 13.5,
            color: AppTheme.steelBlue,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }

  Widget _buildPortraitModes(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (int i = 0; i < _modes.length; i++) ...[
          if (i > 0) const SizedBox(height: 14),
          _ModeCard(
            mode: _modes[i],
            onTap: () => _tap(
              () => Navigator.pushNamed(context, _modes[i].route),
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildLandscapeModes(BuildContext context) {
    return Row(
      children: [
        for (int i = 0; i < _modes.length; i++) ...[
          if (i > 0) const SizedBox(width: 16),
          Expanded(
            child: _ModeCard(
              mode: _modes[i],
              tall: true,
              onTap: () => _tap(
                () => Navigator.pushNamed(context, _modes[i].route),
              ),
            ),
          ),
        ],
      ],
    );
  }
}

// ── Mode Card ────────────────────────────────────────────────────────────────

class _ModeCard extends StatefulWidget {
  final _MainGameMode mode;
  final VoidCallback onTap;
  final bool tall;

  const _ModeCard({
    required this.mode,
    required this.onTap,
    this.tall = false,
  });

  @override
  State<_ModeCard> createState() => _ModeCardState();
}

class _ModeCardState extends State<_ModeCard> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    final mode = widget.mode;

    return GestureDetector(
      onTapDown: (_) => setState(() => _pressed = true),
      onTapUp: (_) {
        setState(() => _pressed = false);
        widget.onTap();
      },
      onTapCancel: () => setState(() => _pressed = false),
      child: AnimatedScale(
        scale: _pressed ? 0.98 : 1.0,
        duration: const Duration(milliseconds: 120),
        curve: Curves.easeOut,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 160),
          height: widget.tall ? 232 : 120,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(22),
            color: AppTheme.navyDark.withValues(alpha: 0.78),
            border: Border.all(
              color: _pressed
                  ? mode.accent.withValues(alpha: 0.7)
                  : Colors.white.withValues(alpha: 0.08),
              width: 1.2,
            ),
            boxShadow: [
              BoxShadow(
                color: mode.accent.withValues(alpha: _pressed ? 0.22 : 0.1),
                blurRadius: _pressed ? 22 : 16,
                offset: const Offset(0, 6),
              ),
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.28),
                blurRadius: 12,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Stack(
            fit: StackFit.expand,
            clipBehavior: Clip.none,
            children: [
              // Soft accent wash — clipped to card shape
              ClipRRect(
                borderRadius: BorderRadius.circular(22),
                child: Align(
                  alignment: widget.tall
                      ? Alignment.topCenter
                      : Alignment.centerRight,
                  child: Container(
                    width: widget.tall ? double.infinity : 160,
                    height: widget.tall ? 140 : double.infinity,
                    decoration: BoxDecoration(
                      gradient: RadialGradient(
                        center: widget.tall
                            ? const Alignment(0, -0.2)
                            : const Alignment(0.6, 0),
                        radius: 0.95,
                        colors: [
                          mode.accent.withValues(alpha: 0.16),
                          mode.accent.withValues(alpha: 0.0),
                        ],
                      ),
                    ),
                  ),
                ),
              ),

              // Content (art may overhang the disc)
              Padding(
                padding: EdgeInsets.symmetric(
                  horizontal: widget.tall ? 20 : 16,
                  vertical: widget.tall ? 18 : 14,
                ),
                child: widget.tall
                    ? _buildTall(mode)
                    : _buildRow(mode),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildRow(_MainGameMode mode) {
    return Row(
      children: [
        _ModeArt(
          asset: mode.artAsset,
          accent: mode.accent,
          size: 88,
          overflows: mode.artOverflows,
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                mode.title,
                style: GoogleFonts.cairo(
                  fontSize: 21,
                  fontWeight: FontWeight.w900,
                  color: AppTheme.white,
                  height: 1.1,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                mode.subtitle,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: GoogleFonts.cairo(
                  fontSize: 12.5,
                  color: Colors.white.withValues(alpha: 0.62),
                  fontWeight: FontWeight.w600,
                  height: 1.25,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(width: 8),
        _Chevron(accent: mode.accent),
      ],
    );
  }

  Widget _buildTall(_MainGameMode mode) {
    return Column(
      children: [
        Expanded(
          child: Center(
            child: _ModeArt(
              asset: mode.artAsset,
              accent: mode.accent,
              size: 112,
              overflows: mode.artOverflows,
            ),
          ),
        ),
        Text(
          mode.title,
          style: GoogleFonts.cairo(
            fontSize: 22,
            fontWeight: FontWeight.w900,
            color: AppTheme.white,
            height: 1.1,
          ),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 4),
        Text(
          mode.subtitle,
          style: GoogleFonts.cairo(
            fontSize: 12.5,
            color: Colors.white.withValues(alpha: 0.62),
            fontWeight: FontWeight.w600,
          ),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 14),
        _Chevron(accent: mode.accent),
      ],
    );
  }
}

class _ModeArt extends StatelessWidget {
  final String asset;
  final Color accent;
  final double size;
  final bool overflows;

  const _ModeArt({
    required this.asset,
    required this.accent,
    required this.size,
    this.overflows = false,
  });

  @override
  Widget build(BuildContext context) {
    if (!overflows) {
      return Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: const Color(0xFF07070C),
          border: Border.all(
            color: accent.withValues(alpha: 0.45),
            width: 1.6,
          ),
          boxShadow: [
            BoxShadow(
              color: accent.withValues(alpha: 0.22),
              blurRadius: 18,
            ),
          ],
        ),
        child: ClipOval(
          child: Padding(
            padding: EdgeInsets.all(size * 0.05),
            child: Image.asset(
              asset,
              fit: BoxFit.cover,
              filterQuality: FilterQuality.high,
            ),
          ),
        ),
      );
    }

    // Estimation: black disc behind, art stacked on top so edges can overhang.
    final disc = size * 0.78;
    final artSize = size * 1.18;

    return SizedBox(
      width: size,
      height: size,
      child: Stack(
        clipBehavior: Clip.none,
        alignment: Alignment.center,
        children: [
          Container(
            width: disc,
            height: disc,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: const Color(0xFF07070C),
              border: Border.all(
                color: accent.withValues(alpha: 0.45),
                width: 1.6,
              ),
              boxShadow: [
                BoxShadow(
                  color: accent.withValues(alpha: 0.22),
                  blurRadius: 18,
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

class _Chevron extends StatelessWidget {
  final Color accent;

  const _Chevron({required this.accent});

  @override
  Widget build(BuildContext context) {
    return AppIconWell(
      icon: AppIcons.arrowForwardIos,
      size: 34,
      iconSize: 13,
      color: accent.withValues(alpha: 0.95),
      fill: accent.withValues(alpha: 0.10),
      borderColor: accent.withValues(alpha: 0.28),
      strokeWidth: AppIconTokens.stroke,
    );
  }
}
