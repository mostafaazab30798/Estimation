// lib/screens/home_screen.dart

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../providers/game_provider.dart';
import '../services/reconnection_manager.dart';
import '../services/profile_service.dart';
import '../theme/app_theme.dart';
import '../core/utils/snackbar_helper.dart';
import '../core/widgets/player_avatar.dart';
import '../widgets/performance_blur.dart';
import '../widgets/game_guide_dialog.dart';
import '../services/audio_service.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen>
    with TickerProviderStateMixin {
  // ValueNotifiers — pure UI local state; no setState needed.
  final _playerName = ValueNotifier<String>('');
  final _codeController = TextEditingController();
  late AnimationController _animController;
  late AnimationController _pulseController;
  late Animation<double> _fadeIn;
  late Animation<Offset> _slideIn;
  late Animation<double> _pulseAnim;

  final _pendingMode = ValueNotifier<String?>(null); // 'host' | 'join' | null
  late final _profilePhoto = ValueNotifier<String>(ProfileService.presetAvatars.first.id);

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    );
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 4),
    )..repeat(reverse: true);

    _fadeIn = CurvedAnimation(parent: _animController, curve: Curves.easeOutCubic);
    _slideIn = Tween<Offset>(begin: const Offset(0, 0.06), end: Offset.zero)
        .animate(CurvedAnimation(parent: _animController, curve: Curves.easeOutCubic));
    _pulseAnim = Tween<double>(begin: 0.95, end: 1.05).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );

    _animController.forward();
    _loadSavedName();
  }

  Future<void> _loadSavedName() async {
    final savedName = await ProfileService.getProfileName();
    final savedPhoto = await ProfileService.getProfilePhoto();
    if (mounted) {
      _playerName.value = savedName;
      _profilePhoto.value = savedPhoto;
    }

    if (!mounted) return;
    final reconnect = context.read<ReconnectionManager>();
    final result = await reconnect.checkOnStartup();

    if (!mounted) return;
    if (result == ReconnectionState.reconnected) {
      final provider = context.read<GameProvider>();
      final is99Mode = provider.currentRoom?.gameType == 'ninety_nine';
      final route = (provider.currentRoom?.status.name == 'playing')
          ? (is99Mode ? '/ninety_nine/game' : '/game')
          : '/lobby';
      Navigator.pushReplacementNamed(context, route);
    }
  }

  @override
  void dispose() {
    _codeController.dispose();
    _animController.dispose();
    _pulseController.dispose();
    _playerName.dispose();
    _profilePhoto.dispose();
    _pendingMode.dispose();
    super.dispose();
  }

  String? _validateName() {
    if (_playerName.value.trim().isEmpty) return 'يرجى تعيين اسمك في الملف الشخصي أولاً';
    return null;
  }

  Future<void> _host(BuildContext context, int expectedPlayers) async {
    final err = _validateName();
    if (err != null) { _snack(context, err); return; }
    
    final provider = context.read<GameProvider>();
    await provider.hostGame(_playerName.value, expectedPlayers: expectedPlayers);
    if (context.mounted && provider.status == ConnectionStatus.connected) {
      Navigator.pushReplacementNamed(context, '/lobby');
    } else if (context.mounted && provider.status == ConnectionStatus.error) {
      _snack(context, provider.errorMessage);
    }
  }

  Future<void> _hostLocal(BuildContext context, int expectedPlayers) async {
    final err = _validateName();
    if (err != null) { _snack(context, err); return; }
    
    final provider = context.read<GameProvider>();
    await provider.hostLocalGame(_playerName.value, expectedPlayers: expectedPlayers, gameType: 'kotchina');
    if (context.mounted && provider.status == ConnectionStatus.connected) {
      Navigator.pushReplacementNamed(context, '/lobby');
    } else if (context.mounted && provider.status == ConnectionStatus.error) {
      _snack(context, provider.errorMessage);
    }
  }

  Future<void> _joinWithCode(BuildContext context) async {
    final err = _validateName();
    if (err != null) { _snack(context, err); return; }
    final code = _codeController.text.trim();
    if (code.length != 6) {
      _snack(context, 'أدخل كود مكوّن من 6 أحرف');
      return;
    }
    
    final provider = context.read<GameProvider>();
    await provider.joinGameWithCode(_playerName.value, code, expectedGameType: 'kotchina');
    if (context.mounted && provider.status == ConnectionStatus.connected) {
      Navigator.pushReplacementNamed(context, '/lobby');
    } else if (context.mounted && provider.status == ConnectionStatus.error) {
      _snack(context, provider.errorMessage);
    }
  }

  Future<void> _testMode(BuildContext context) async {
    final err = _validateName();
    if (err != null) { _snack(context, err); return; }
    
    final provider = context.read<GameProvider>();
    await provider.startTestGame(_playerName.value);
    if (context.mounted && provider.status == ConnectionStatus.connected) {
      Navigator.pushReplacementNamed(context, '/lobby');
    } else if (context.mounted && provider.status == ConnectionStatus.error) {
      _snack(context, provider.errorMessage);
    }
  }

  void _snack(BuildContext context, String msg) {
    SnackbarHelper.showError(context, msg, title: 'عذراً ⚠️');
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<GameProvider>();
    final isLoading = provider.status == ConnectionStatus.connecting ||
        provider.isSearching;
    final isPortrait = MediaQuery.of(context).size.width < 800;

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {
        if (didPop) return;
        _confirmExitApp(context);
      },
      child: Scaffold(
        backgroundColor: Colors.black,
        body: SizedBox.expand(
          child: Stack(
            fit: StackFit.expand,
            children: [
              // ── Background Wallpaper ─────────────────────────────────────
              Positioned.fill(
                child: Image.asset(
                  'assets/wallpapers/w2.jpg',
                  fit: BoxFit.cover,
                  alignment: Alignment.center,
                  width: double.infinity,
                  height: double.infinity,
                  gaplessPlayback: true,
                  filterQuality: FilterQuality.medium,
                ),
              ),
              // Dark Gradient Tint for Legibility & Contrast
              Positioned.fill(
                child: Container(
                  width: double.infinity,
                  height: double.infinity,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        AppTheme.navyDark.withValues(alpha: 0.45),
                        AppTheme.navyDark.withValues(alpha: 0.75),
                      ],
                    ),
                  ),
                ),
              ),

              // ── Background Ambient Light Orbs ────────────────────────────
              Positioned(
                top: -80,
                right: -80,
                child: AnimatedBuilder(
                  animation: _pulseAnim,
                  builder: (context, child) => Transform.scale(
                    scale: _pulseAnim.value,
                    child: Container(
                      width: 320,
                      height: 320,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: RadialGradient(
                          colors: [
                            AppTheme.accentBlue.withValues(alpha: 0.25),
                            Colors.transparent,
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
              Positioned(
                bottom: -60,
                left: -60,
                child: AnimatedBuilder(
                  animation: _pulseAnim,
                  builder: (context, child) => Transform.scale(
                    scale: 2.0 - _pulseAnim.value,
                    child: Container(
                      width: 280,
                      height: 280,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: RadialGradient(
                          colors: [
                            AppTheme.accentLight.withValues(alpha: 0.18),
                            Colors.transparent,
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),

              // ── Subtle Glass Blur Layer ──────────────────────────────────
              Positioned.fill(
                child: PerformanceBlur(
                  sigmaX: 6,
                  sigmaY: 6,
                  fallbackColor: Colors.black.withValues(alpha: 0.15),
                  child: const SizedBox.expand(),
                ),
              ),

            // ── Main Content SafeArea ─────────────────────────────────
            SafeArea(
              left: false,
              right: false,
              child: FadeTransition(
                opacity: _fadeIn,
                child: SlideTransition(
                  position: _slideIn,
                  child: Column(
                    children: [
                      Expanded(
                        child: isPortrait
                            ? _buildPortraitLayout(context, provider, isLoading)
                            : _buildLandscapeLayout(context, provider, isLoading),
                      ),
                      Padding(
                        padding: const EdgeInsets.only(bottom: 16, top: 8),
                        child: _buildSuitRow(),
                      ),
                    ],
                  ),
                ),
              ),
            ),

            // ── Loading Glass Overlay ─────────────────────────────────
            if (isLoading)
              Positioned.fill(
                child: PerformanceBlur(
                  sigmaX: 10,
                  sigmaY: 10,
                  fallbackColor: AppTheme.navyDark.withValues(alpha: 0.85),
                  blurColor: AppTheme.navyDark.withValues(alpha: 0.75),
                  child: Center(
                    child: _buildLoadingCard(context, provider),
                  ),
                ),
              ),
          ],
        ),
      ),
    ),
  );
  }

  // ── Layout Orientations ─────────────────────────────────────────

  Widget _buildPortraitLayout(
    BuildContext context,
    GameProvider provider,
    bool isLoading,
  ) {
    return SingleChildScrollView(
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _buildTopAppBar(context),
          const SizedBox(height: 36),
          _buildBrandHero(),
          const SizedBox(height: 28),
          _buildGameModesSection(context),
          const SizedBox(height: 24),
        ],
      ),
    );
  }

  Widget _buildLandscapeLayout(
    BuildContext context,
    GameProvider provider,
    bool isLoading,
  ) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
          child: _buildTopAppBar(context),
        ),
        const SizedBox(height: 12),
        Expanded(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 36, vertical: 8),
            child: Row(
              children: [
                // Left Column: Brand & Suit Decor
                Expanded(
                  flex: 5,
                  child: Center(
                    child: SingleChildScrollView(
                      physics: const BouncingScrollPhysics(),
                      child: _buildBrandHero(),
                    ),
                  ),
                ),

                const SizedBox(width: 24),

                // Vertical Glass Divider
                Container(
                  width: 1.5,
                  height: double.infinity,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        Colors.transparent,
                        AppTheme.accentLight.withValues(alpha: 0.25),
                        Colors.transparent,
                      ],
                    ),
                  ),
                ),

                const SizedBox(width: 24),

                // Right Column: Interactive Game Modes
                Expanded(
                  flex: 6,
                  child: Center(
                    child: SingleChildScrollView(
                      physics: const BouncingScrollPhysics(),
                      child: _buildGameModesSection(context),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  // ── Top Header / Guide (Left) & Profile (Right) Row ──────────────

  Widget _buildTopAppBar(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        return FittedBox(
          fit: BoxFit.scaleDown,
          child: ConstrainedBox(
            constraints: BoxConstraints(minWidth: constraints.maxWidth),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
            // 0. Change Mode Back Chip (Return to Mode Selection)
            InkWell(
              onTap: () {
                if (Navigator.canPop(context)) {
                  Navigator.pop(context);
                } else {
                  Navigator.pushReplacementNamed(context, '/');
                }
              },
              borderRadius: BorderRadius.circular(24),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: AppTheme.glassDecoration(
                  borderRadius: 24,
                  borderColor: AppTheme.gold.withValues(alpha: 0.5),
                  fillColor: AppTheme.navyDark.withValues(alpha: 0.7),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 34,
                      height: 34,
                      decoration: BoxDecoration(
                        color: AppTheme.gold.withValues(alpha: 0.15),
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: AppTheme.gold.withValues(alpha: 0.5),
                          width: 1.5,
                        ),
                      ),
                      child: const Icon(
                        Icons.arrow_back_ios_new_rounded,
                        color: AppTheme.gold,
                        size: 16,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      'المودات 🎴',
                      style: GoogleFonts.cairo(
                        color: AppTheme.goldLight,
                        fontWeight: FontWeight.bold,
                        fontSize: 13,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(width: 10),

            // 1. Game Guide Chip Button (Left side)
            InkWell(
              onTap: () => GameGuideDialog.show(context),
              borderRadius: BorderRadius.circular(24),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: AppTheme.glassDecoration(
                  borderRadius: 24,
                  borderColor: AppTheme.mintSoft.withValues(alpha: 0.4),
                  fillColor: AppTheme.navyDark.withValues(alpha: 0.7),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 34,
                      height: 34,
                      decoration: BoxDecoration(
                        color: AppTheme.mintSoft.withValues(alpha: 0.15),
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: AppTheme.mintSoft.withValues(alpha: 0.4),
                          width: 1.5,
                        ),
                      ),
                      child: const Icon(
                        Icons.menu_book_rounded,
                        color: AppTheme.mintSoft,
                        size: 16,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          'الدليل 📖',
                          style: GoogleFonts.cairo(
                            color: AppTheme.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 13,
                            height: 1.1,
                          ),
                        ),
                        Text(
                          'كيف تلعب',
                          style: GoogleFonts.cairo(
                            color: AppTheme.accentLight.withValues(alpha: 0.8),
                            fontSize: 10,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
        const SizedBox(width: 16),
        // 2. Profile Avatar Chip (Right side)
        InkWell(
          onTap: () => Navigator.pushNamed(context, '/profile')
              .then((_) => _loadSavedName()),
          borderRadius: BorderRadius.circular(24),
          child: ListenableBuilder(
            listenable: Listenable.merge([_playerName, _profilePhoto]),
            builder: (context, _) {
              return Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: AppTheme.glassDecoration(
                  borderRadius: 24,
                  borderColor: AppTheme.accentBlue.withValues(alpha: 0.35),
                  fillColor: AppTheme.navyDark.withValues(alpha: 0.7),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Stack(
                      children: [
                        PlayerAvatar(
                          photoData: _profilePhoto.value,
                          size: 36,
                          borderWidth: 1.5,
                        ),
                        Positioned(
                          bottom: 0,
                          right: 0,
                          child: Container(
                            width: 10,
                            height: 10,
                            decoration: BoxDecoration(
                              color: const Color(0xFF4CAF50),
                              shape: BoxShape.circle,
                              border: Border.all(
                                color: AppTheme.navyDark,
                                width: 1.5,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(width: 10),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          _playerName.value.isNotEmpty ? _playerName.value : 'الملف الشخصي',
                          style: GoogleFonts.cairo(
                            color: AppTheme.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 14,
                            height: 1.1,
                          ),
                        ),
                        Text(
                          'تعديل الحساب',
                          style: GoogleFonts.cairo(
                            color: AppTheme.accentLight.withValues(alpha: 0.8),
                            fontSize: 10,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(width: 8),
                    Icon(
                      Icons.tune_rounded,
                      color: AppTheme.accentLight.withValues(alpha: 0.9),
                      size: 16,
                    ),
                  ],
                ),
              );
            },
          ),
        ),
      ],
    ),
  ));
  });
  }

  // ── Brand Hero Section ─────────────────────────────────────────

  Widget _buildBrandHero() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // 3D Animated Floating Mini-Cards Fan
        AnimatedBuilder(
          animation: _pulseAnim,
          builder: (context, child) {
            return Transform.scale(
              scale: _pulseAnim.value,
              child: _buildFloatingCardFan(),
            );
          },
        ),

        const SizedBox(height: 18),

        // Gradient Title Text
        ShaderMask(
          shaderCallback: (bounds) => const LinearGradient(
            colors: [
              AppTheme.white,
              Color(0xFFFFF176),
              AppTheme.gold,
            ],
            begin: Alignment.topRight,
            end: Alignment.bottomLeft,
          ).createShader(bounds),
          child: Text(
            'إستميشن',
            style: GoogleFonts.cairo(
              fontSize: 46,
              fontWeight: FontWeight.w900,
              color: Colors.white,
              letterSpacing: 1,
              height: 1.1,
            ),
          ),
        ),

        const SizedBox(height: 8),

        // Official Rules Subtitle Badge
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
          decoration: BoxDecoration(
            color: AppTheme.gold.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: AppTheme.gold.withValues(alpha: 0.45),
              width: 1.2,
            ),
            boxShadow: [
              BoxShadow(
                color: AppTheme.gold.withValues(alpha: 0.15),
                blurRadius: 10,
              ),
            ],
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('👑', style: TextStyle(fontSize: 13)),
              const SizedBox(width: 6),
              Text(
                'البولة الرسمية 18 دور • سانز وداش كول',
                style: GoogleFonts.cairo(
                  color: AppTheme.goldLight,
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildFloatingCardFan() {
    return SizedBox(
      height: 125,
      width: 210,
      child: Stack(
        alignment: Alignment.center,
        children: [
          // Left Card (Ace of Spades) tilted
          Transform.translate(
            offset: const Offset(-38, 6),
            child: Transform.rotate(
              angle: -0.28,
              child: _buildMiniHeroCard('♠', 'A', AppTheme.accentLight, AppTheme.navyDark),
            ),
          ),
          // Right Card (Ace of Diamonds) tilted
          Transform.translate(
            offset: const Offset(38, 6),
            child: Transform.rotate(
              angle: 0.28,
              child: _buildMiniHeroCard('♦', 'A', AppTheme.suitRed, AppTheme.navyDark),
            ),
          ),
          // Center Card (King of Hearts) elevated
          Transform.translate(
            offset: const Offset(0, -6),
            child: _buildMiniHeroCard('♥', 'K', AppTheme.suitRed, const Color(0xFF1E293B), isCenter: true),
          ),
        ],
      ),
    );
  }

  Widget _buildMiniHeroCard(String suit, String rank, Color suitColor, Color bg, {bool isCenter = false}) {
    return Container(
      width: 68,
      height: 98,
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isCenter ? AppTheme.gold : Colors.white.withValues(alpha: 0.28),
          width: isCenter ? 1.8 : 1.2,
        ),
        boxShadow: [
          BoxShadow(
            color: isCenter
                ? AppTheme.gold.withValues(alpha: 0.4)
                : Colors.black.withValues(alpha: 0.45),
            blurRadius: isCenter ? 18 : 10,
            spreadRadius: isCenter ? 1 : 0,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      padding: const EdgeInsets.all(6),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            rank,
            style: GoogleFonts.cinzel(
              color: suitColor,
              fontSize: 14,
              fontWeight: FontWeight.w900,
              height: 1.0,
            ),
          ),
          Center(
            child: Text(
              suit,
              style: TextStyle(
                color: suitColor,
                fontSize: 22,
                height: 1.0,
              ),
            ),
          ),
          Align(
            alignment: Alignment.bottomRight,
            child: Text(
              rank,
              style: GoogleFonts.cinzel(
                color: suitColor,
                fontSize: 12,
                fontWeight: FontWeight.w900,
                height: 1.0,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSuitRow() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.04),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.08),
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (final e in [
            ('♠', AppTheme.accentLight),
            ('♥', AppTheme.suitRed),
            ('♦', AppTheme.suitRed),
            ('♣', AppTheme.accentLight),
          ])
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8),
              child: Text(
                e.$1,
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: e.$2,
                ),
              ),
            ),
        ],
      ),
    );
  }

  // ── Game Modes Section ──────────────────────────────────────────

  Widget _buildGameModesSection(BuildContext context) {
    return ValueListenableBuilder<String?>(
      valueListenable: _pendingMode,
      builder: (context, mode, _) {
        final isHostActive = mode == 'host';
        final isJoinActive = mode == 'join';
        final isLocalActive = mode == 'local';

        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: [
            // 🌟 Featured Hero Action: Quick Play vs Bots
            _buildHeroQuickPlayCard(context),

            const SizedBox(height: 16),

            // Mode 1: Host Room
            _buildModeTile(
              title: 'إنشاء غرفة جديدة',
              subtitle: 'استضف أصدقائك أو العب مع البوتات',
              icon: Icons.wifi_tethering_rounded,
              gradientColors: [const Color(0xFF3A7BD5), const Color(0xFF3A6073)],
              isActive: isHostActive,
              onTap: () {
                HapticFeedback.selectionClick();
                _pendingMode.value = isHostActive ? null : 'host';
              },
              expandableContent: _buildHostOptions(context),
            ),

            const SizedBox(height: 14),

            // Mode 2: Join Room
            _buildModeTile(
              title: 'الانضمام لكود غرفة',
              subtitle: 'أدخل الكود المكون من 6 أحرف للانضمام',
              icon: Icons.vpn_key_rounded,
              gradientColors: [const Color(0xFF11998E), const Color(0xFF38EF7D)],
              isActive: isJoinActive,
              onTap: () {
                HapticFeedback.selectionClick();
                _pendingMode.value = isJoinActive ? null : 'join';
              },
              expandableContent: _buildJoinOptions(context),
            ),

            const SizedBox(height: 14),

            // Mode 3: LAN Offline Multiplayer
            _buildModeTile(
              title: 'لعب محلي',
              subtitle: 'استضف أصدقائك أو انضم أوفلاين عبر الواي فاي',
              icon: Icons.wifi_find_rounded,
              gradientColors: [const Color(0xFFF59E0B), const Color(0xFFD97706)],
              isActive: isLocalActive,
              onTap: () {
                HapticFeedback.selectionClick();
                _pendingMode.value = isLocalActive ? null : 'local';
              },
              expandableContent: _buildLocalOptions(context),
              badgeText: 'أوفلاين 📡',
            ),
          ],
        );
      },
    );
  }

  Widget _buildHeroQuickPlayCard(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [
            Color(0xFF2E1065), // Royal deep violet
            Color(0xFF4C1D95), // Vibrant purple
            Color(0xFF1E1B4B), // Midnight navy
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: AppTheme.gold.withValues(alpha: 0.75),
          width: 1.6,
        ),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF7C3AED).withValues(alpha: 0.35),
            blurRadius: 20,
            spreadRadius: 1,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () {
            HapticFeedback.heavyImpact();
            AudioService.instance.playCard();
            _testMode(context);
          },
          borderRadius: BorderRadius.circular(24),
          child: Padding(
            padding: const EdgeInsets.all(18),
            child: Row(
              children: [
                Container(
                  width: 52,
                  height: 52,
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [AppTheme.gold, Color(0xFFFFD700), Color(0xFFD97706)],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(18),
                    boxShadow: [
                      BoxShadow(
                        color: AppTheme.gold.withValues(alpha: 0.45),
                        blurRadius: 14,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: const Center(
                    child: Text('🤖', style: TextStyle(fontSize: 26)),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Row(
                        children: [
                          Flexible(
                            child: Text(
                              'العب الآن ضد البوتات',
                              style: GoogleFonts.cairo(
                                color: AppTheme.white,
                                fontSize: 16.5,
                                fontWeight: FontWeight.w900,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                            decoration: BoxDecoration(
                              color: AppTheme.gold.withValues(alpha: 0.2),
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: AppTheme.gold.withValues(alpha: 0.5)),
                            ),
                            child: Text(
                              'سريع ⚡',
                              style: GoogleFonts.cairo(
                                color: AppTheme.gold,
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 3),
                      Text(
                        'بدء مباراة فورية بدون انتظار • 18 دور',
                        style: GoogleFonts.cairo(
                          color: Colors.white70,
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.all(9),
                  decoration: BoxDecoration(
                    color: AppTheme.gold.withValues(alpha: 0.15),
                    shape: BoxShape.circle,
                    border: Border.all(color: AppTheme.gold.withValues(alpha: 0.4)),
                  ),
                  child: const Icon(Icons.arrow_forward_ios_rounded, color: AppTheme.gold, size: 15),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildModeTile({
    required String title,
    required String subtitle,
    required IconData icon,
    required List<Color> gradientColors,
    required bool isActive,
    required VoidCallback onTap,
    String? badgeText,
    Widget? expandableContent,
  }) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeInOut,
      decoration: BoxDecoration(
        color: isActive
            ? AppTheme.navyMid.withValues(alpha: 0.85)
            : AppTheme.navyDark.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(
          color: isActive
              ? gradientColors.first
              : Colors.white.withValues(alpha: 0.18),
          width: isActive ? 1.8 : 1.2,
        ),
        boxShadow: isActive
            ? [
                BoxShadow(
                  color: gradientColors.first.withValues(alpha: 0.4),
                  blurRadius: 22,
                  spreadRadius: 1,
                  offset: const Offset(0, 4),
                ),
              ]
            : [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.35),
                  blurRadius: 12,
                  offset: const Offset(0, 4),
                ),
              ],
      ),
      child: Column(
        children: [
          Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: onTap,
              borderRadius: BorderRadius.circular(22),
              child: Padding(
                padding: const EdgeInsets.all(18),
                child: Row(
                  children: [
                    // Icon Circle
                    Container(
                      width: 50,
                      height: 50,
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: gradientColors,
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        borderRadius: BorderRadius.circular(16),
                        boxShadow: [
                          BoxShadow(
                            color: gradientColors.first.withValues(alpha: 0.45),
                            blurRadius: 12,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: Icon(icon, color: Colors.white, size: 26),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Flexible(
                                child: Text(
                                  title,
                                  style: GoogleFonts.cairo(
                                    color: AppTheme.white,
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                  ),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              if (badgeText != null) ...[
                                const SizedBox(width: 8),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 8, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: gradientColors.first.withValues(alpha: 0.15),
                                    borderRadius: BorderRadius.circular(8),
                                    border: Border.all(
                                      color: gradientColors.first.withValues(alpha: 0.3),
                                    ),
                                  ),
                                  child: Text(
                                    badgeText,
                                    style: GoogleFonts.cairo(
                                      color: gradientColors.first,
                                      fontSize: 10,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                              ],
                            ],
                          ),
                          const SizedBox(height: 2),
                          Text(
                            subtitle,
                            style: GoogleFonts.cairo(
                              color: AppTheme.steelBlue,
                              fontSize: 12,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    if (expandableContent != null)
                      AnimatedRotation(
                        turns: isActive ? 0.5 : 0.0,
                        duration: const Duration(milliseconds: 250),
                        child: Container(
                          padding: const EdgeInsets.all(6),
                          decoration: BoxDecoration(
                            color: isActive
                                ? gradientColors.first.withValues(alpha: 0.2)
                                : Colors.white.withValues(alpha: 0.05),
                            shape: BoxShape.circle,
                          ),
                          child: Icon(
                            Icons.keyboard_arrow_down_rounded,
                            color: isActive
                                ? gradientColors.first
                                : AppTheme.steelBlue,
                            size: 22,
                          ),
                        ),
                      )
                    else
                      Container(
                        padding: const EdgeInsets.all(6),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.05),
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          Icons.arrow_forward_ios_rounded,
                          color: AppTheme.steelBlue,
                          size: 18,
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ),
          if (expandableContent != null)
            AnimatedSize(
              duration: const Duration(milliseconds: 280),
              curve: Curves.easeInOut,
              child: isActive
                  ? Padding(
                      padding: const EdgeInsets.fromLTRB(18, 0, 18, 18),
                      child: expandableContent,
                    )
                  : const SizedBox.shrink(),
            ),
        ],
      ),
    );
  }

  Widget _buildHostOptions(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Divider(color: Colors.white.withValues(alpha: 0.15)),
        const SizedBox(height: 8),
        Text(
          'اختر عدد اللاعبين الحقيقيين:',
          style: GoogleFonts.cairo(
            color: AppTheme.mintSoft,
            fontSize: 13,
            fontWeight: FontWeight.w600,
          ),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: _buildPlayerCountChip(
                label: 'لاعبَين (2)',
                subLabel: '+ 2 بوتات',
                icon: Icons.person_rounded,
                onTap: () => _host(context, 2),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: _buildPlayerCountChip(
                label: '3 لاعبين',
                subLabel: '+ 1 بوت',
                icon: Icons.group_rounded,
                onTap: () => _host(context, 3),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: _buildPlayerCountChip(
                label: '4 لاعبين',
                subLabel: 'مكتمل',
                icon: Icons.groups_rounded,
                onTap: () => _host(context, 4),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildLocalOptions(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Divider(color: Colors.white.withValues(alpha: 0.15)),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              child: ElevatedButton.icon(
                onPressed: () => _hostLocal(context, 4),
                icon: const Icon(Icons.cell_tower_rounded, size: 18),
                label: Text('إنشاء غرفة أوفلاين', style: GoogleFonts.cairo(fontWeight: FontWeight.bold, fontSize: 12)),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFD97706),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: OutlinedButton.icon(
                onPressed: () => Navigator.pushNamed(context, '/local_discovery'),
                icon: const Icon(Icons.wifi_find_rounded, size: 18),
                label: Text('البحث عن ألعاب', style: GoogleFonts.cairo(fontWeight: FontWeight.bold, fontSize: 12)),
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppTheme.cream,
                  side: const BorderSide(color: Color(0xFFF59E0B), width: 1.5),
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildPlayerCountChip({
    required String label,
    required String subLabel,
    required IconData icon,
    required VoidCallback onTap,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: AppTheme.navyDark.withValues(alpha: 0.75),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: AppTheme.accentBlue.withValues(alpha: 0.45),
          width: 1.2,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.25),
            blurRadius: 8,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(16),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 6),
            child: Column(
              children: [
                Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: AppTheme.accentBlue.withValues(alpha: 0.2),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(icon, color: AppTheme.mintSoft, size: 20),
                ),
                const SizedBox(height: 6),
                Text(
                  label,
                  style: GoogleFonts.cairo(
                    color: AppTheme.white,
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Text(
                  subLabel,
                  style: GoogleFonts.cairo(
                    color: AppTheme.accentLight.withValues(alpha: 0.8),
                    fontSize: 10,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildJoinOptions(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Divider(color: Colors.white.withValues(alpha: 0.15)),
        const SizedBox(height: 10),
        _buildTextField(
          controller: _codeController,
          hint: 'أدخل كود الغرفة (٦ أحرف)',
          icon: Icons.tag_rounded,
          keyboardType: TextInputType.visiblePassword,
          maxLength: 6,
          textCapitalization: TextCapitalization.characters,
          textAlign: TextAlign.center,
          textDirection: TextDirection.ltr,
          inputFormatters: [
            FilteringTextInputFormatter.allow(RegExp(r'[A-Z0-9]')),
          ],
        ),
        const SizedBox(height: 14),
        Container(
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [Color(0xFF11998E), Color(0xFF38EF7D)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFF38EF7D).withValues(alpha: 0.35),
                blurRadius: 18,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: () => _joinWithCode(context),
              borderRadius: BorderRadius.circular(16),
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 14),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.login_rounded, color: Colors.white, size: 22),
                    const SizedBox(width: 10),
                    Text(
                      'دخول الغرفة',
                      style: GoogleFonts.cairo(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }



  // ── Input Text Fields ──────────────────────────────────────────

  Widget _buildTextField({
    required TextEditingController controller,
    required String hint,
    required IconData icon,
    TextInputType keyboardType = TextInputType.text,
    int? maxLength,
    TextCapitalization textCapitalization = TextCapitalization.none,
    List<TextInputFormatter>? inputFormatters,
    TextAlign textAlign = TextAlign.right,
    TextDirection textDirection = TextDirection.rtl,
  }) {
    return TextField(
      controller: controller,
      textAlign: textAlign,
      textDirection: textDirection,
      keyboardType: keyboardType,
      maxLength: maxLength,
      textCapitalization: textCapitalization,
      inputFormatters: inputFormatters,
      style: GoogleFonts.cairo(
        color: AppTheme.mintSoft,
        fontSize: 17,
        fontWeight: FontWeight.bold,
        letterSpacing: textAlign == TextAlign.center ? 4 : 0,
      ),
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: GoogleFonts.cairo(
          color: AppTheme.accentLight.withValues(alpha: 0.45),
          fontSize: 14,
          letterSpacing: 0,
        ),
        prefixIcon: Icon(
          icon,
          color: AppTheme.accentLight.withValues(alpha: 0.7),
          size: 20,
        ),
        counterText: '',
        filled: true,
        fillColor: AppTheme.navyDark.withValues(alpha: 0.7),
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

  // ── Loading Glass Card ─────────────────────────────────────────

  Widget _buildLoadingCard(BuildContext context, GameProvider provider) {
    final msg = provider.isSearching ? 'نبحث عن غرفتك...' : 'جاري الاتصال بالسيرفر...';
    return Container(
      width: 280,
      padding: const EdgeInsets.all(24),
      decoration: AppTheme.glassDecoration(
        borderRadius: 24,
        borderColor: AppTheme.accentBlue.withValues(alpha: 0.4),
        fillColor: AppTheme.navyMid.withValues(alpha: 0.9),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const SizedBox(
            width: 44,
            height: 44,
            child: CircularProgressIndicator(
              color: AppTheme.accentBlue,
              strokeWidth: 3.5,
            ),
          ),
          const SizedBox(height: 16),
          Text(
            msg,
            style: GoogleFonts.cairo(
              color: AppTheme.mintSoft,
              fontWeight: FontWeight.bold,
              fontSize: 15,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 16),
          OutlinedButton.icon(
            onPressed: () => context.read<GameProvider>().reset(),
            icon: const Icon(Icons.close_rounded, size: 18),
            label: Text(
              'إلغاء',
              style: GoogleFonts.cairo(fontWeight: FontWeight.bold),
            ),
            style: OutlinedButton.styleFrom(
              foregroundColor: AppTheme.errorRed,
              side: BorderSide(
                color: AppTheme.errorRed.withValues(alpha: 0.4),
              ),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ── Exit App Dialog ────────────────────────────────────────────

  void _confirmExitApp(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => Dialog(
        backgroundColor: Colors.transparent,
        child: Container(
          width: 360,
          padding: const EdgeInsets.all(24),
          decoration: AppTheme.glassDecoration(
            borderRadius: 24,
            borderColor: Colors.white.withValues(alpha: 0.15),
            fillColor: AppTheme.navyDark.withValues(alpha: 0.95),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppTheme.errorRed.withValues(alpha: 0.15),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.exit_to_app_rounded,
                  color: AppTheme.errorRed,
                  size: 36,
                ),
              ),
              const SizedBox(height: 16),
              Text(
                'الخروج من التطبيق',
                style: GoogleFonts.cairo(
                  color: AppTheme.mintSoft,
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              Text(
                'هل أنت متأكد أنك تريد الخروج من لعبة كوتشينة؟',
                style: GoogleFonts.cairo(
                  color: AppTheme.accentLight.withValues(alpha: 0.8),
                  fontSize: 13,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 24),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => Navigator.pop(ctx),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        side: BorderSide(
                          color: Colors.white.withValues(alpha: 0.2),
                        ),
                        foregroundColor: AppTheme.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: Text(
                        'إلغاء',
                        style: GoogleFonts.cairo(fontWeight: FontWeight.bold),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () {
                        Navigator.pop(ctx);
                        SystemNavigator.pop();
                      },
                      style: ElevatedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        backgroundColor: AppTheme.errorRed,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        elevation: 0,
                      ),
                      child: Text(
                        'خروج',
                        style: GoogleFonts.cairo(fontWeight: FontWeight.bold),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
