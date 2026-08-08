import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';

import '../../../../core/utils/snackbar_helper.dart';
import '../../../../core/widgets/player_avatar.dart';
import '../../../../providers/game_provider.dart';
import '../../../../services/profile_service.dart';
import '../../../../theme/app_theme.dart';
import '../../../../widgets/performance_blur.dart';
import '../dialogs/ninety_nine_game_guide_dialog.dart';
import '../providers/ninety_nine_game_provider.dart';

class NinetyNineHomeScreen extends StatefulWidget {
  const NinetyNineHomeScreen({super.key});

  @override
  State<NinetyNineHomeScreen> createState() => _NinetyNineHomeScreenState();
}

class _NinetyNineHomeScreenState extends State<NinetyNineHomeScreen>
    with TickerProviderStateMixin {
  final _playerName = ValueNotifier<String>('');
  final _codeController = TextEditingController();
  late AnimationController _animController;
  late AnimationController _pulseController;
  late Animation<double> _fadeIn;
  late Animation<Offset> _slideIn;
  late Animation<double> _pulseAnim;

  final _pendingMode = ValueNotifier<String?>(null); // 'host' | 'join' | null
  int _selectedPlayerCount = 4; // Default 4, supports 2, 3, 4, 5, 6, 7
  late final _profilePhoto =
      ValueNotifier<String>(ProfileService.presetAvatars.first.id);

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

    _fadeIn = CurvedAnimation(
      parent: _animController,
      curve: Curves.easeOutCubic,
    );
    _slideIn = Tween<Offset>(
      begin: const Offset(0, 0.06),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _animController,
      curve: Curves.easeOutCubic,
    ));

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
    if (_playerName.value.trim().isEmpty) {
      return 'يرجى تعيين اسمك في الملف الشخصي أولاً';
    }
    return null;
  }

  Future<void> _hostOnlineRoom(BuildContext context, int expectedPlayers) async {
    final err = _validateName();
    if (err != null) {
      _snack(context, err);
      return;
    }

    final provider = context.read<GameProvider>();
    await provider.hostGame(
      _playerName.value,
      expectedPlayers: expectedPlayers,
      gameType: 'ninety_nine',
    );

    if (context.mounted && provider.status == ConnectionStatus.connected) {
      Navigator.pushReplacementNamed(context, '/lobby');
    } else if (context.mounted && provider.status == ConnectionStatus.error) {
      _snack(context, provider.errorMessage);
    }
  }

  Future<void> _joinWithCode(BuildContext context) async {
    final err = _validateName();
    if (err != null) {
      _snack(context, err);
      return;
    }

    final code = _codeController.text.trim();
    if (code.length != 6) {
      _snack(context, 'أدخل كود مكوّن من 6 أحرف');
      return;
    }

    final provider = context.read<GameProvider>();
    await provider.joinGameWithCode(
      _playerName.value,
      code,
      expectedGameType: 'ninety_nine',
    );

    if (context.mounted && provider.status == ConnectionStatus.connected) {
      Navigator.pushReplacementNamed(context, '/lobby');
    } else if (context.mounted && provider.status == ConnectionStatus.error) {
      _snack(context, provider.errorMessage);
    }
  }

  void _startBotGame(BuildContext context) async {
    final err = _validateName();
    if (err != null) {
      _snack(context, err);
      return;
    }

    final name = _playerName.value.trim();
    final provider = context.read<GameProvider>();
    await provider.startNinetyNineTestGame(name, totalPlayers: _selectedPlayerCount);

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

    final isPortrait =
        MediaQuery.of(context).orientation == Orientation.portrait;

    return PopScope(
      canPop: true,
      onPopInvokedWithResult: (didPop, result) {},
      child: Scaffold(
        backgroundColor: AppTheme.deepNavy,
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
                        AppTheme.navyDark.withValues(alpha: 0.82),
                        AppTheme.deepNavy,
                      ],
                      stops: const [0.0, 0.6, 1.0],
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
                            const Color(0xFFEF4444).withValues(alpha: 0.25),
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
                            AppTheme.gold.withValues(alpha: 0.18),
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
          const SizedBox(height: 28),
          _buildBrandHero(),
          const SizedBox(height: 24),
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
                // Left Column: Brand Hero
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
                        const Color(0xFFEF4444).withValues(alpha: 0.3),
                        Colors.transparent,
                      ],
                    ),
                  ),
                ),

                const SizedBox(width: 24),

                // Right Column: Interactive Action Tiles
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

  // ── Top Header / Back & Profile Row ──────────────────────────────

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
              // Return to Mode Selection Chip
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
                    borderColor: const Color(0xFFEF4444).withValues(alpha: 0.5),
                    fillColor: AppTheme.navyDark.withValues(alpha: 0.7),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 34,
                        height: 34,
                        decoration: BoxDecoration(
                          color: const Color(0xFFEF4444).withValues(alpha: 0.15),
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: const Color(0xFFEF4444).withValues(alpha: 0.5),
                            width: 1.5,
                          ),
                        ),
                        child: const Icon(
                          Icons.arrow_back_ios_new_rounded,
                          color: Color(0xFFEF4444),
                          size: 16,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        'المودات 🎴',
                        style: GoogleFonts.cairo(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 13,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 10),

              // Game Guide Chip
              InkWell(
                onTap: () => NinetyNineGameGuideDialog.show(context),
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
                      Text(
                        'دليل الـ 99 📖',
                        style: GoogleFonts.cairo(
                          color: AppTheme.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 13,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(width: 16),

          // Profile Avatar Chip
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
                            _playerName.value.isNotEmpty
                                ? _playerName.value
                                : 'الملف الشخصي',
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
    ),
  );
  });
  }

  // ── Brand Hero Section ─────────────────────────────────────────

  Widget _buildBrandHero() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Animated 99 logo — styled like estimation's poker.png pulse
        AnimatedBuilder(
          animation: _pulseAnim,
          builder: (context, child) {
            return Transform.scale(
              scale: _pulseAnim.value,
              child: Container(
                width: 120,
                height: 120,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: const Color(0xFFEF4444).withValues(alpha: 0.12),
                  border: Border.all(
                    color: const Color(0xFFEF4444).withValues(alpha: 0.5),
                    width: 2,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFFEF4444).withValues(alpha: 0.25),
                      blurRadius: 36,
                      spreadRadius: 2,
                    ),
                  ],
                ),
                alignment: Alignment.center,
                child: ShaderMask(
                  shaderCallback: (bounds) => const LinearGradient(
                    colors: [Colors.white, Color(0xFFFCA5A5), Color(0xFFEF4444)],
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                  ).createShader(bounds),
                  child: Text(
                    '99',
                    style: GoogleFonts.cairo(
                      fontSize: 54,
                      fontWeight: FontWeight.w900,
                      color: Colors.white,
                      height: 1,
                    ),
                  ),
                ),
              ),
            );
          },
        ),

        const SizedBox(height: 20),

        // Gradient title — same ShaderMask pattern as estimation
        ShaderMask(
          shaderCallback: (bounds) => const LinearGradient(
            colors: [
              AppTheme.white,
              Color(0xFFFCA5A5),
              Color(0xFFEF4444),
            ],
            begin: Alignment.topRight,
            end: Alignment.bottomLeft,
          ).createShader(bounds),
          child: Text(
            'مود الـ 99',
            style: GoogleFonts.cairo(
              fontSize: 44,
              fontWeight: FontWeight.w900,
              color: Colors.white,
              letterSpacing: 1,
              height: 1.1,
            ),
          ),
        ),
        const SizedBox(height: 8),
        Text(
          'وصل الأرض لـ99... ولا تكن آخر من يلعب!',
          style: GoogleFonts.cairo(
            fontSize: 13,
            color: AppTheme.steelBlue,
          ),
          textAlign: TextAlign.center,
        ),
      ],
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
        final isBotsActive = mode == 'bots';

        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: [
            // Option 1: Host Room
            _buildModeTile(
              title: 'إنشاء غرفة الـ 99 جديدة',
              subtitle: 'استضف أصدقائك أو العب أونلاين',
              icon: Icons.wifi_tethering_rounded,
              gradientColors: [const Color(0xFFEF4444), const Color(0xFF991B1B)],
              isActive: isHostActive,
              onTap: () {
                _pendingMode.value = isHostActive ? null : 'host';
              },
              expandableContent: _buildHostOptions(context),
            ),

            const SizedBox(height: 14),

            // Option 2: Join Room
            _buildModeTile(
              title: 'الانضمام لكود غرفة 99',
              subtitle: 'أدخل الكود المكون من 6 أحرف للانضمام',
              icon: Icons.vpn_key_rounded,
              gradientColors: [const Color(0xFF11998E), const Color(0xFF38EF7D)],
              isActive: isJoinActive,
              onTap: () {
                _pendingMode.value = isJoinActive ? null : 'join';
              },
              expandableContent: _buildJoinOptions(context),
            ),

            const SizedBox(height: 14),

            // Option 3: Practice vs Bots — expandable, same pattern
            _buildModeTile(
              title: 'لعب ضد البوتات',
              subtitle: 'تجربة فورية وسريعة بدون الحاجة للإنترنت',
              icon: Icons.smart_toy_rounded,
              gradientColors: [const Color(0xFF8E2DE2), const Color(0xFF4A00E0)],
              isActive: isBotsActive,
              onTap: () {
                _pendingMode.value = isBotsActive ? null : 'bots';
              },
              badgeText: 'لعب سريع',
              expandableContent: _buildBotOptions(context),
            ),
          ],
        );
      },
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
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.navyDark.withValues(alpha: 0.6),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'اختر عدد اللاعبين في الجولة (من 2 إلى 7 لاعبين):',
            style: GoogleFonts.cairo(
              color: AppTheme.steelBlue,
              fontSize: 13,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [2, 3, 4, 5, 6, 7].map((count) {
              final isSel = _selectedPlayerCount == count;
              return GestureDetector(
                onTap: () => setState(() => _selectedPlayerCount = count),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                  decoration: BoxDecoration(
                    color: isSel
                        ? const Color(0xFFEF4444)
                        : Colors.white.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: isSel ? const Color(0xFFEF4444) : Colors.white12,
                    ),
                    boxShadow: isSel
                        ? [
                            BoxShadow(
                              color: const Color(0xFFEF4444).withValues(alpha: 0.4),
                              blurRadius: 10,
                            )
                          ]
                        : [],
                  ),
                  child: Text(
                    '$count لاعبين',
                    style: GoogleFonts.cairo(
                      color: isSel ? Colors.white : Colors.white70,
                      fontWeight: FontWeight.bold,
                      fontSize: 13,
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
          const SizedBox(height: 16),
          ElevatedButton(
            onPressed: () => _hostOnlineRoom(context, _selectedPlayerCount),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFEF4444),
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 14),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
              ),
              elevation: 4,
              shadowColor: const Color(0xFFEF4444).withValues(alpha: 0.4),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.play_arrow_rounded, size: 22),
                const SizedBox(width: 8),
                Text(
                  'بدء وإنشاء الغرفة الآن',
                  style: GoogleFonts.cairo(
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildJoinOptions(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.navyDark.withValues(alpha: 0.6),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          TextField(
            controller: _codeController,
            style: GoogleFonts.cairo(
              color: Colors.white,
              fontSize: 18,
              letterSpacing: 4,
              fontWeight: FontWeight.bold,
            ),
            textCapitalization: TextCapitalization.characters,
            decoration: InputDecoration(
              hintText: 'كود الغرفة (6 أحرف)',
              hintStyle: GoogleFonts.cairo(
                color: Colors.white38,
                fontSize: 13,
                letterSpacing: 0,
              ),
              filled: true,
              fillColor: Colors.white.withValues(alpha: 0.08),
              contentPadding:
                  const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide:
                    BorderSide(color: Colors.white.withValues(alpha: 0.2)),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide:
                    BorderSide(color: Colors.white.withValues(alpha: 0.2)),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide:
                    const BorderSide(color: Color(0xFF11998E), width: 2),
              ),
            ),
          ),
          const SizedBox(height: 14),
          ElevatedButton(
            onPressed: () => _joinWithCode(context),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF11998E),
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 14),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
              ),
              elevation: 4,
              shadowColor: const Color(0xFF11998E).withValues(alpha: 0.4),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.login_rounded, size: 20),
                const SizedBox(width: 8),
                Text(
                  'الانضمام للغرفة',
                  style: GoogleFonts.cairo(
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBotOptions(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.navyDark.withValues(alpha: 0.6),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'اختر عدد اللاعبين في الجولة (من 2 إلى 7 لاعبين):',
            style: GoogleFonts.cairo(
              color: AppTheme.steelBlue,
              fontSize: 13,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [2, 3, 4, 5, 6, 7].map((count) {
              final isSel = _selectedPlayerCount == count;
              return GestureDetector(
                onTap: () => setState(() => _selectedPlayerCount = count),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                  decoration: BoxDecoration(
                    color: isSel
                        ? const Color(0xFF8E2DE2)
                        : Colors.white.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: isSel ? const Color(0xFF8E2DE2) : Colors.white12,
                    ),
                    boxShadow: isSel
                        ? [
                            BoxShadow(
                              color: const Color(0xFF8E2DE2).withValues(alpha: 0.4),
                              blurRadius: 10,
                            ),
                          ]
                        : [],
                  ),
                  child: Text(
                    '$count لاعبين',
                    style: GoogleFonts.cairo(
                      color: isSel ? Colors.white : Colors.white70,
                      fontWeight: FontWeight.bold,
                      fontSize: 13,
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
          const SizedBox(height: 16),
          Container(
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFF8E2DE2), Color(0xFF4A00E0)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(14),
              boxShadow: const [
                BoxShadow(
                  color: Color(0xFF8E2DE2),
                  blurRadius: 16,
                  offset: Offset(0, 4),
                ),
              ],
            ),
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                onTap: () => _startBotGame(context),
                borderRadius: BorderRadius.circular(14),
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.play_arrow_rounded,
                          color: Colors.white, size: 22),
                      const SizedBox(width: 8),
                      Text(
                        'ابدأ اللعب الآن ($_selectedPlayerCount لاعبين) 🤖',
                        style: GoogleFonts.cairo(
                          fontSize: 15,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLoadingCard(BuildContext context, GameProvider provider) {
    return Container(
      width: 280,
      padding: const EdgeInsets.all(24),
      decoration: AppTheme.glassDecoration(
        borderRadius: 24,
        borderColor: AppTheme.accentBlue.withValues(alpha: 0.5),
        fillColor: AppTheme.navyDark.withValues(alpha: 0.9),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const SizedBox(
            width: 48,
            height: 48,
            child: CircularProgressIndicator(
              color: Color(0xFFEF4444),
              strokeWidth: 3.5,
            ),
          ),
          const SizedBox(height: 20),
          Text(
            provider.isSearching
                ? 'جاري البحث عن غرفة 99...'
                : 'جاري الاتصال بالغرفة...',
            style: GoogleFonts.cairo(
              color: AppTheme.white,
              fontSize: 16,
              fontWeight: FontWeight.bold,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 16),
          OutlinedButton(
            onPressed: () => context.read<GameProvider>().reset(),
            child: Text('إلغاء', style: GoogleFonts.cairo(color: Colors.white)),
          ),
        ],
      ),
    );
  }
}
