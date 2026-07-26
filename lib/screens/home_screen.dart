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

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen>
    with TickerProviderStateMixin {
  String _playerName = '';
  final _codeController = TextEditingController();
  late AnimationController _animController;
  late AnimationController _pulseController;
  late Animation<double> _fadeIn;
  late Animation<Offset> _slideIn;
  late Animation<double> _pulseAnim;

  String? _pendingMode; // 'host' | 'join' | null
  String _profilePhoto = ProfileService.presetAvatars.first.id;

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
      setState(() {
        _playerName = savedName;
        _profilePhoto = savedPhoto;
      });
    }

    if (!mounted) return;
    final reconnect = context.read<ReconnectionManager>();
    final result = await reconnect.checkOnStartup();

    if (!mounted) return;
    if (result == ReconnectionState.reconnected) {
      final provider = context.read<GameProvider>();
      final route = (provider.currentRoom?.status.name == 'playing')
          ? '/game'
          : '/lobby';
      Navigator.pushReplacementNamed(context, route);
    }
  }

  @override
  void dispose() {
    _codeController.dispose();
    _animController.dispose();
    _pulseController.dispose();
    super.dispose();
  }

  String? _validateName() {
    if (_playerName.trim().isEmpty) return 'يرجى تعيين اسمك في الملف الشخصي أولاً';
    return null;
  }

  Future<void> _host(BuildContext context, int expectedPlayers) async {
    final err = _validateName();
    if (err != null) { _snack(context, err); return; }
    
    final provider = context.read<GameProvider>();
    await provider.hostGame(_playerName, expectedPlayers: expectedPlayers);
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
    await provider.joinGameWithCode(_playerName, code);
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
    await provider.startTestGame(_playerName);
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
              child: FadeTransition(
                opacity: _fadeIn,
                child: SlideTransition(
                  position: _slideIn,
                  child: isPortrait
                      ? _buildPortraitLayout(context, provider, isLoading)
                      : _buildLandscapeLayout(context, provider, isLoading),
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
          const SizedBox(height: 20),
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

  // ── Top Header / Profile Pill ───────────────────────────────────

  Widget _buildTopAppBar(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        // App Title Badge
        const Row(
          children: [
            // Container(
            //   padding: const EdgeInsets.all(8),
            //   decoration: BoxDecoration(
            //     color: AppTheme.accentBlue.withValues(alpha: 0.15),
            //     borderRadius: BorderRadius.circular(12),
            //     border: Border.all(
            //       color: AppTheme.accentBlue.withValues(alpha: 0.3),
            //     ),
            //   ),
            //   child: const Icon(
            //     Icons.style_rounded,
            //     color: AppTheme.mintSoft,
            //     size: 20,
            //   ),
            // ),
            // const SizedBox(width: 10),
            // Text(
            //   'كوتشينة إستميشن',
            //   style: GoogleFonts.cairo(
            //     color: AppTheme.mintSoft,
            //     fontSize: 15,
            //     fontWeight: FontWeight.w700,
            //   ),
            // ),
          ],
        ),

        // Profile Avatar Chip
        InkWell(
          onTap: () => Navigator.pushNamed(context, '/profile')
              .then((_) => _loadSavedName()),
          borderRadius: BorderRadius.circular(24),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: AppTheme.glassDecoration(
              borderRadius: 24,
              borderColor: AppTheme.accentBlue.withValues(alpha: 0.35),
              fillColor: AppTheme.navyDark.withValues(alpha: 0.7),
            ),
            child: Row(
              children: [
                Stack(
                  children: [
                    PlayerAvatar(
                      photoData: _profilePhoto,
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
                      _playerName.isNotEmpty ? _playerName : 'الملف الشخصي',
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
          ),
        ),
      ],
    );
  }

  // ── Brand Hero Section ─────────────────────────────────────────

  Widget _buildBrandHero() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Standalone Animated Logo
        AnimatedBuilder(
          animation: _pulseAnim,
          builder: (context, child) {
            return Transform.scale(
              scale: _pulseAnim.value,
              child: Image.asset(
                'assets/poker.png',
                height: 140,
                fit: BoxFit.contain,
              ),
            );
          },
        ),

        const SizedBox(height: 16),

        // Gradient Title Text
        ShaderMask(
          shaderCallback: (bounds) => const LinearGradient(
            colors: [
              AppTheme.white,
              AppTheme.mintSoft,
              AppTheme.accentLight,
            ],
            begin: Alignment.topRight,
            end: Alignment.bottomLeft,
          ).createShader(bounds),
          child: Text(
            'إستميشن',
            style: GoogleFonts.alexandria(
              fontSize: 44,
              fontWeight: FontWeight.w900,
              color: Colors.white,
              letterSpacing: 1,
              height: 1.1,
            ),
          ),
        ),

        const SizedBox(height: 6),

        // Text(
        //   'التحدي والذكاء في لعبة الكوتشينة المصرية',
        //   style: GoogleFonts.cairo(
        //     color: AppTheme.accentLight.withValues(alpha: 0.75),
        //     fontSize: 13,
        //     fontWeight: FontWeight.w600,
        //   ),
        //   textAlign: TextAlign.center,
        // ),

        const SizedBox(height: 14),

        // Suit Row Decor Chips
        _buildSuitRow(),
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
    final isHostActive = _pendingMode == 'host';
    final isJoinActive = _pendingMode == 'join';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        // Mode 1: Host Room
        _buildModeTile(
          title: 'إنشاء غرفة جديدة',
          subtitle: 'استضف أصدقائك أو العب مع البوتات',
          icon: Icons.wifi_tethering_rounded,
          gradientColors: [const Color(0xFF3A7BD5), const Color(0xFF3A6073)],
          isActive: isHostActive,
          onTap: () {
            setState(() {
              _pendingMode = isHostActive ? null : 'host';
            });
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
            setState(() {
              _pendingMode = isJoinActive ? null : 'join';
            });
          },
          expandableContent: _buildJoinOptions(context),
        ),

        const SizedBox(height: 14),

        // Mode 3: Practice vs Bots
        _buildPracticeTile(context),
      ],
    );
  }

  Widget _buildModeTile({
    required String title,
    required String subtitle,
    required IconData icon,
    required List<Color> gradientColors,
    required bool isActive,
    required VoidCallback onTap,
    required Widget expandableContent,
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
              ? AppTheme.accentBlue
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
                    // Icon Circle with vibrant gradient & glow
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
                          Text(
                            title,
                            style: GoogleFonts.cairo(
                              color: AppTheme.white,
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            subtitle,
                            style: GoogleFonts.cairo(
                              color: AppTheme.mintSoft.withValues(alpha: 0.8),
                              fontSize: 12,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.all(6),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.1),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        isActive
                            ? Icons.keyboard_arrow_up_rounded
                            : Icons.keyboard_arrow_down_rounded,
                        color: AppTheme.mintSoft,
                        size: 22,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
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

  Widget _buildPracticeTile(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppTheme.navyDark.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.18),
          width: 1.2,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.35),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () {
            setState(() => _pendingMode = null);
            _testMode(context);
          },
          borderRadius: BorderRadius.circular(22),
          child: Padding(
            padding: const EdgeInsets.all(18),
            child: Row(
              children: [
                Container(
                  width: 50,
                  height: 50,
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [Color(0xFF8E2DE2), Color(0xFF4A00E0)],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFF8E2DE2).withValues(alpha: 0.4),
                        blurRadius: 12,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: const Icon(
                    Icons.smart_toy_rounded,
                    color: Colors.white,
                    size: 26,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Text(
                            'تجربة ضد البوتات',
                            style: GoogleFonts.cairo(
                              color: AppTheme.white,
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 8, vertical: 2),
                            decoration: BoxDecoration(
                              color: AppTheme.accentLight.withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(
                                color: AppTheme.accentLight.withValues(alpha: 0.3),
                              ),
                            ),
                            child: Text(
                              'لعب سريع',
                              style: GoogleFonts.cairo(
                                color: AppTheme.mintSoft,
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'لعبة سريعة تدريبية بدون انتظار أونلاين',
                        style: GoogleFonts.cairo(
                          color: AppTheme.mintSoft.withValues(alpha: 0.8),
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.1),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.arrow_forward_ios_rounded,
                    color: AppTheme.mintSoft,
                    size: 18,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
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
