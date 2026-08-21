// lib/screens/mode_selection_screen.dart

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';

import '../theme/app_theme.dart';
import '../services/audio_service.dart';
import '../services/settings_service.dart';
import '../services/profile_service.dart';
import '../core/widgets/player_avatar.dart';

// ── Game Mode Data ────────────────────────────────────────────────────────────

class _ModeData {
  final String title;
  final String description;
  final String badgeText;
  final Color accentColor;
  final Color secondaryColor;
  final String symbol;
  final String route;
  final List<String> tags;

  const _ModeData({
    required this.title,
    required this.description,
    required this.badgeText,
    required this.accentColor,
    required this.secondaryColor,
    required this.symbol,
    required this.route,
    required this.tags,
  });
}

// ── Main Screen ──────────────────────────────────────────────────────────────

class ModeSelectionScreen extends StatefulWidget {
  const ModeSelectionScreen({super.key});

  @override
  State<ModeSelectionScreen> createState() => _ModeSelectionScreenState();
}

class _ModeSelectionScreenState extends State<ModeSelectionScreen> {
  String _playerName = 'لاعب كوتشينة';
  String _playerPhoto = ProfileService.presetAvatars.first.id;

  static const List<_ModeData> _modes = [
    _ModeData(
      title: 'إستميشن',
      description: 'البولة الرسمية ١٨ جولة • سانز وداش كول وكول عادي',
      badgeText: 'كلاسيك ♠️',
      accentColor: AppTheme.gold,
      secondaryColor: Color(0xFFD97706),
      symbol: '♠',
      route: '/kotchina/home',
      tags: ['٤ لاعبين', '١٨ جولة', 'ذكاء وتكتيك'],
    ),
    _ModeData(
      title: 'مود الـ 99',
      description: 'وصل مجموع الأرض لـ 99 وتفادى الخسارة السريعة',
      badgeText: 'حماسي 🔥',
      accentColor: Color(0xFFEF4444),
      secondaryColor: Color(0xFF991B1B),
      symbol: '99',
      route: '/ninety_nine/home',
      tags: ['٢ - ٧ لاعبين', 'موت مفاجئ', 'إيقاع سريع'],
    ),
  ];

  @override
  void initState() {
    super.initState();
    _loadPlayerProfile();
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

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final isLandscape = size.width > size.height;

    return Scaffold(
      backgroundColor: AppTheme.deepNavy,
      body: Stack(
        fit: StackFit.expand,
        children: [
          // Background wallpaper
          Positioned.fill(
            child: Image.asset(
              'assets/wallpapers/w1.jpg',
              fit: BoxFit.cover,
              errorBuilder: (_, __, ___) => Container(
                decoration: const BoxDecoration(gradient: AppTheme.bgGradient),
              ),
            ),
          ),

          // Deep modern glass gradient overlay
          Positioned.fill(
            child: Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Colors.black.withValues(alpha: 0.60),
                    AppTheme.deepNavy.withValues(alpha: 0.88),
                    AppTheme.deepNavy.withValues(alpha: 0.98),
                  ],
                  stops: const [0.0, 0.45, 1.0],
                ),
              ),
            ),
          ),

          // Main content
          SafeArea(
            child: Column(
              children: [
                // Top Bar (Profile + Sound)
                _buildTopBar(),

                // Compact Modern Title Header
                _buildCompactHeader(),

                // Center Mode Cards
                Expanded(
                  child: Center(
                    child: ConstrainedBox(
                      constraints: BoxConstraints(
                        maxWidth: isLandscape ? 860 : 460,
                      ),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 18),
                        child: isLandscape
                            ? _buildLandscapeModes(context)
                            : _buildPortraitModes(context),
                      ),
                    ),
                  ),
                ),

                // Compact Footer
                _buildSuitFooter(),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ── Top Bar ────────────────────────────────────────────────────────────────

  Widget _buildTopBar() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          // Profile Capsule (Avatar + Name)
          InkWell(
            onTap: _openProfile,
            borderRadius: BorderRadius.circular(24),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
              decoration: BoxDecoration(
                color: AppTheme.navyDark.withValues(alpha: 0.75),
                borderRadius: BorderRadius.circular(24),
                border: Border.all(
                  color: AppTheme.gold.withValues(alpha: 0.3),
                  width: 1,
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.3),
                    blurRadius: 10,
                    offset: const Offset(0, 3),
                  ),
                ],
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    padding: const EdgeInsets.all(2),
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(color: AppTheme.gold, width: 1.4),
                    ),
                    child: PlayerAvatar(
                      photoData: _playerPhoto,
                      size: 28,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    _playerName,
                    style: GoogleFonts.cairo(
                      color: AppTheme.cream,
                      fontWeight: FontWeight.bold,
                      fontSize: 13,
                    ),
                  ),
                  const SizedBox(width: 6),
                  Icon(
                    Icons.tune_rounded,
                    color: AppTheme.gold.withValues(alpha: 0.8),
                    size: 14,
                  ),
                ],
              ),
            ),
          ),

          // Sound Quick Toggle
          ListenableBuilder(
            listenable: SettingsService.instance,
            builder: (context, _) {
              final sfx = SettingsService.instance.sfxEnabled;
              return InkWell(
                onTap: () {
                  HapticFeedback.lightImpact();
                  SettingsService.instance.setSfxEnabled(!sfx);
                  if (!sfx) AudioService.instance.playCard();
                },
                borderRadius: BorderRadius.circular(16),
                child: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: AppTheme.navyDark.withValues(alpha: 0.75),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: sfx
                          ? AppTheme.gold.withValues(alpha: 0.3)
                          : Colors.white12,
                      width: 1,
                    ),
                  ),
                  child: Icon(
                    sfx ? Icons.volume_up_rounded : Icons.volume_off_rounded,
                    color: sfx ? AppTheme.gold : Colors.white54,
                    size: 18,
                  ),
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  // ── Compact Header ─────────────────────────────────────────────────────────

  Widget _buildCompactHeader() {
    return Padding(
      padding: const EdgeInsets.only(top: 4, bottom: 8),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'اختر نمط اللعب',
                style: GoogleFonts.cairo(
                  fontSize: 22,
                  fontWeight: FontWeight.w900,
                  color: AppTheme.white,
                  letterSpacing: 0.5,
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: AppTheme.gold.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: AppTheme.gold.withValues(alpha: 0.4),
                    width: 0.8,
                  ),
                ),
                child: Text(
                  'مودات كوتشينة 🎴',
                  style: GoogleFonts.cairo(
                    fontSize: 10.5,
                    fontWeight: FontWeight.bold,
                    color: AppTheme.goldLight,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 2),
          Text(
            'استمتع باللعب الفردي مع البوتات أو تنافس أونلاين ومحلياً',
            style: GoogleFonts.cairo(
              fontSize: 11.5,
              color: AppTheme.steelBlue,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  // ── Portrait Modes ─────────────────────────────────────────────────────────

  Widget _buildPortraitModes(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (int i = 0; i < _modes.length; i++) ...[
          if (i > 0) const SizedBox(height: 14),
          _SleekModeCard(
            mode: _modes[i],
            onTap: () {
              HapticFeedback.mediumImpact();
              AudioService.instance.playCard();
              Navigator.pushNamed(context, _modes[i].route);
            },
          ),
        ],
      ],
    );
  }

  // ── Landscape Modes ────────────────────────────────────────────────────────

  Widget _buildLandscapeModes(BuildContext context) {
    return Row(
      children: [
        for (int i = 0; i < _modes.length; i++) ...[
          if (i > 0) const SizedBox(width: 16),
          Expanded(
            child: _SleekModeCard(
              mode: _modes[i],
              onTap: () {
                HapticFeedback.mediumImpact();
                AudioService.instance.playCard();
                Navigator.pushNamed(context, _modes[i].route);
              },
            ),
          ),
        ],
      ],
    );
  }

  // ── Compact Suit Footer ────────────────────────────────────────────────────

  Widget _buildSuitFooter() {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10, top: 4),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.03),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.white.withValues(alpha: 0.06)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: const [
            Text('♠', style: TextStyle(fontSize: 13, color: AppTheme.accentLight)),
            SizedBox(width: 12),
            Text('♥', style: TextStyle(fontSize: 13, color: AppTheme.suitRed)),
            SizedBox(width: 12),
            Text('♦', style: TextStyle(fontSize: 13, color: AppTheme.suitRed)),
            SizedBox(width: 12),
            Text('♣', style: TextStyle(fontSize: 13, color: AppTheme.accentLight)),
          ],
        ),
      ),
    );
  }
}

// ── Sleek Modern Mode Card ───────────────────────────────────────────────────

class _SleekModeCard extends StatefulWidget {
  final _ModeData mode;
  final VoidCallback onTap;

  const _SleekModeCard({required this.mode, required this.onTap});

  @override
  State<_SleekModeCard> createState() => _SleekModeCardState();
}

class _SleekModeCardState extends State<_SleekModeCard> {
  bool _isPressed = false;

  @override
  Widget build(BuildContext context) {
    final mode = widget.mode;

    return GestureDetector(
      onTapDown: (_) => setState(() => _isPressed = true),
      onTapUp: (_) {
        setState(() => _isPressed = false);
        widget.onTap();
      },
      onTapCancel: () => setState(() => _isPressed = false),
      child: AnimatedScale(
        scale: _isPressed ? 0.98 : 1.0,
        duration: const Duration(milliseconds: 120),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                mode.accentColor.withValues(alpha: _isPressed ? 0.20 : 0.10),
                AppTheme.navyDark.withValues(alpha: 0.85),
                AppTheme.navyDark.withValues(alpha: 0.95),
              ],
            ),
            border: Border.all(
              color: _isPressed
                  ? mode.accentColor.withValues(alpha: 0.85)
                  : mode.accentColor.withValues(alpha: 0.35),
              width: _isPressed ? 1.6 : 1.1,
            ),
            boxShadow: [
              BoxShadow(
                color: mode.accentColor.withValues(alpha: _isPressed ? 0.35 : 0.12),
                blurRadius: _isPressed ? 24 : 14,
                offset: const Offset(0, 4),
              ),
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.4),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            mainAxisSize: MainAxisSize.min,
            children: [
              // Top Row: Emblem + Title + Badge + Arrow Pill
              Row(
                children: [
                  // Emblem Circle/Square
                  Container(
                    width: 46,
                    height: 46,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(14),
                      gradient: LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [
                          mode.accentColor.withValues(alpha: 0.3),
                          mode.secondaryColor.withValues(alpha: 0.15),
                        ],
                      ),
                      border: Border.all(
                        color: mode.accentColor.withValues(alpha: 0.5),
                        width: 1.2,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: mode.accentColor.withValues(alpha: 0.25),
                          blurRadius: 8,
                        ),
                      ],
                    ),
                    alignment: Alignment.center,
                    child: Text(
                      mode.symbol,
                      style: GoogleFonts.cairo(
                        fontSize: mode.symbol == '99' ? 20 : 24,
                        fontWeight: FontWeight.w900,
                        color: mode.accentColor,
                        height: 1,
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),

                  // Title + Subtitle description
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Text(
                              mode.title,
                              style: GoogleFonts.cairo(
                                fontSize: 18,
                                fontWeight: FontWeight.w900,
                                color: AppTheme.white,
                              ),
                            ),
                            const SizedBox(width: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 1.5),
                              decoration: BoxDecoration(
                                color: mode.accentColor.withValues(alpha: 0.15),
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(
                                  color: mode.accentColor.withValues(alpha: 0.4),
                                  width: 0.8,
                                ),
                              ),
                              child: Text(
                                mode.badgeText,
                                style: GoogleFonts.cairo(
                                  fontSize: 10,
                                  fontWeight: FontWeight.bold,
                                  color: mode.accentColor,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 2),
                        Text(
                          mode.description,
                          style: GoogleFonts.cairo(
                            fontSize: 11.5,
                            color: AppTheme.steelBlue,
                            fontWeight: FontWeight.w500,
                            height: 1.2,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),

                  // Action Chevron Pill
                  const SizedBox(width: 8),
                  Container(
                    width: 32,
                    height: 32,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: mode.accentColor.withValues(alpha: 0.12),
                      border: Border.all(
                        color: mode.accentColor.withValues(alpha: 0.35),
                        width: 1,
                      ),
                    ),
                    child: Icon(
                      Icons.arrow_forward_ios_rounded,
                      color: mode.accentColor,
                      size: 14,
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 12),

              // Feature Tags Row
              Wrap(
                spacing: 6,
                runSpacing: 4,
                children: mode.tags.map((tag) {
                  return Container(
                    padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 3),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.05),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                        color: Colors.white.withValues(alpha: 0.08),
                        width: 0.8,
                      ),
                    ),
                    child: Text(
                      tag,
                      style: GoogleFonts.cairo(
                        fontSize: 10.5,
                        color: AppTheme.cream.withValues(alpha: 0.85),
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  );
                }).toList(),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
