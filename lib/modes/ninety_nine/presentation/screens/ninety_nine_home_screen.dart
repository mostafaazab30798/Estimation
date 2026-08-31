import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';

import '../../../../core/utils/snackbar_helper.dart';
import '../../../../core/widgets/mode_home_shell.dart';
import '../../../../providers/game_provider.dart';
import '../../../../services/profile_service.dart';
import '../../../../theme/app_theme.dart';
import '../../../../widgets/performance_blur.dart';
import '../../../../widgets/ongoing_game_guard.dart';
import 'package:estimation/core/icons/app_icons.dart';

class NinetyNineHomeScreen extends StatefulWidget {
  const NinetyNineHomeScreen({super.key});

  @override
  State<NinetyNineHomeScreen> createState() => _NinetyNineHomeScreenState();
}

class _NinetyNineHomeScreenState extends State<NinetyNineHomeScreen>
    with SingleTickerProviderStateMixin {
  static const _red = Color(0xFFEF4444);
  static const _redDark = Color(0xFF991B1B);
  static const _purple = Color(0xFF8E2DE2);

  final _playerName = ValueNotifier<String>('');
  final _codeController = TextEditingController();
  late AnimationController _animController;
  late Animation<double> _fadeIn;
  late Animation<Offset> _slideIn;

  int _selectedPlayerCount = 4;
  late final _profilePhoto =
      ValueNotifier<String>(ProfileService.presetAvatars.first.id);

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
    _playerName.dispose();
    _profilePhoto.dispose();
    super.dispose();
  }

  String? _validateName() {
    if (_playerName.value.trim().isEmpty) {
      return 'يرجى تعيين اسمك في الملف الشخصي أولاً';
    }
    return null;
  }

  Future<void> _hostOnlineRoom(
      BuildContext context, int expectedPlayers) async {
    if (await guardAgainstOngoingGame(context)) return;
    if (!context.mounted) return;
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
    if (await guardAgainstOngoingGame(context)) return;
    if (!context.mounted) return;
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

  Future<void> _startBotGame(BuildContext context) async {
    if (await guardAgainstOngoingGame(context)) return;
    if (!context.mounted) return;
    final err = _validateName();
    if (err != null) {
      _snack(context, err);
      return;
    }

    final provider = context.read<GameProvider>();
    await provider.startNinetyNineTestGame(
      _playerName.value.trim(),
      totalPlayers: _selectedPlayerCount,
    );

    if (context.mounted && provider.status == ConnectionStatus.connected) {
      Navigator.pushReplacementNamed(context, '/lobby');
    } else if (context.mounted && provider.status == ConnectionStatus.error) {
      _snack(context, provider.errorMessage);
    }
  }

  void _snack(BuildContext context, String msg) {
    SnackbarHelper.showError(context, msg, title: 'عذراً ⚠️');
  }

  void _tap(VoidCallback action) {
    HapticFeedback.lightImpact();
    action();
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<GameProvider>();
    final isLoading =
        provider.status == ConnectionStatus.connecting || provider.isSearching;
    final isLandscape =
        MediaQuery.of(context).size.width > MediaQuery.of(context).size.height;

    return PopScope(
      canPop: true,
      child: Scaffold(
        backgroundColor: AppTheme.deepNavy,
        body: Stack(
          fit: StackFit.expand,
          children: [
            const ModeHomeBackground(
              wallpaperAsset: 'assets/wallpapers/w2.jpg',
              primaryGlow: _red,
              secondaryGlow: AppTheme.gold,
            ),
            SafeArea(
              child: FadeTransition(
                opacity: _fadeIn,
                child: SlideTransition(
                  position: _slideIn,
                  child: isLandscape
                      ? _buildLandscapeBody(context)
                      : _buildPortraitBody(context),
                ),
              ),
            ),
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
    );
  }

  Widget _buildPortraitBody(BuildContext context) {
    return Column(
      children: [
        _buildTopBar(context),
        Expanded(
          child: SingleChildScrollView(
            physics: const BouncingScrollPhysics(),
            padding: const EdgeInsets.fromLTRB(20, 4, 20, 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _buildHeroSection(),
                const SizedBox(height: 22),
                _buildPrimaryAction(context),
                const SizedBox(height: 18),
                _buildMultiplayerGrid(context),
              ],
            ),
          ),
        ),
        const ModeHomeSuitFooter(),
      ],
    );
  }

  Widget _buildLandscapeBody(BuildContext context) {
    return Column(
      children: [
        _buildTopBar(context),
        Expanded(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(24, 0, 24, 8),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Expanded(
                  flex: 5,
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      _buildHeroSection(compact: true),
                      const SizedBox(height: 20),
                      _buildPrimaryAction(context),
                    ],
                  ),
                ),
                const SizedBox(width: 20),
                const ModeHomeLandscapeDivider(accent: _red),
                const SizedBox(width: 20),
                Expanded(
                  flex: 6,
                  child: Center(child: _buildMultiplayerGrid(context)),
                ),
              ],
            ),
          ),
        ),
        const ModeHomeSuitFooter(),
      ],
    );
  }

  Widget _buildTopBar(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
      child: Row(
        children: [
          ModeHomeIconCapsule(
            icon: AppIcons.arrowBackIosNew,
            label: 'المودات',
            accent: _red,
            onTap: () => _tap(() {
              if (Navigator.canPop(context)) {
                Navigator.pop(context);
              } else {
                Navigator.pushReplacementNamed(context, '/');
              }
            }),
          ),
          const Spacer(),
          ValueListenableBuilder<String>(
            valueListenable: _profilePhoto,
            builder: (context, photo, _) {
              return ValueListenableBuilder<String>(
                valueListenable: _playerName,
                builder: (context, name, _) {
                  return ModeHomeProfileChip(
                    photo: photo,
                    name: name.isEmpty ? 'لاعب' : name,
                    onTap: () => _tap(() async {
                      await Navigator.pushNamed(context, '/profile');
                      _loadSavedName();
                    }),
                  );
                },
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildHeroSection({bool compact = false}) {
    return ModeHomeHero(
      compact: compact,
      title: 'مود الـ 99',
      subtitle: 'تحدي السرعة والموت المفاجئ',
      emblem: ModeHomeArtEmblem(
        asset: 'assets/99.png',
        accent: const Color(0xFFFF2D95),
        size: compact ? 72 : 88,
      ),
    );
  }

  Widget _buildPrimaryAction(BuildContext context) {
    return ModeHomeActionButton(
      label: 'لعب فردي سريع',
      icon: AppIcons.bolt,
      gradient: const [_purple, Color(0xFF4A00E0)],
      isLarge: true,
      onTap: () => _tap(() => _showBotSheet(context)),
    );
  }

  Widget _buildMultiplayerGrid(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const ModeHomeSectionLabel(text: 'العب مع الآخرين', accent: _red),
        const SizedBox(height: 10),
        Row(
          children: [
            Expanded(
              child: ModeHomeActionButton(
                label: 'إنشاء غرفة',
                icon: AppIcons.addCircleOutline,
                gradient: const [_red, _redDark],
                onTap: () => _tap(() => _showHostSheet(context)),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: ModeHomeActionButton(
                label: 'انضمام',
                icon: AppIcons.login,
                gradient: const [Color(0xFF11998E), Color(0xFF0D7377)],
                onTap: () => _tap(() => _showJoinSheet(context)),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Future<void> _showBotSheet(BuildContext context) async {
    await showModeHomeSheet<void>(
      context,
      title: 'لعب فردي سريع',
      subtitle: 'اختر عدد اللاعبين (٢–٧)',
      accent: _purple,
      child: StatefulBuilder(
        builder: (ctx, setSheetState) {
          return Column(
            children: [
              PlayerCountWrap(
                counts: const [2, 3, 4, 5, 6, 7],
                selected: _selectedPlayerCount,
                accent: _purple,
                onSelect: (count) => setSheetState(() {
                  _selectedPlayerCount = count;
                }),
              ),
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: () {
                    Navigator.pop(ctx);
                    _startBotGame(context);
                  },
                  icon: const AppIcon(AppIcons.playArrow, size: 20),
                  label: Text(
                    'ابدأ ($_selectedPlayerCount لاعبين)',
                    style: GoogleFonts.cairo(fontWeight: FontWeight.bold),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _purple,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Future<void> _showHostSheet(BuildContext context) async {
    var count = _selectedPlayerCount;
    await showModeHomeSheet<void>(
      context,
      title: 'إنشاء غرفة جديدة',
      subtitle: 'اختر عدد اللاعبين (٢–٧)',
      accent: _red,
      child: StatefulBuilder(
        builder: (ctx, setSheetState) {
          return Column(
            children: [
              PlayerCountWrap(
                counts: const [2, 3, 4, 5, 6, 7],
                selected: count,
                accent: _red,
                onSelect: (c) => setSheetState(() {
                  count = c;
                  _selectedPlayerCount = c;
                }),
              ),
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: () {
                    Navigator.pop(ctx);
                    _hostOnlineRoom(context, count);
                  },
                  icon: const AppIcon(AppIcons.wifiTethering, size: 18),
                  label: Text(
                    'إنشاء الغرفة',
                    style: GoogleFonts.cairo(fontWeight: FontWeight.bold),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _red,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Future<void> _showJoinSheet(BuildContext context) async {
    await showModeHomeSheet<void>(
      context,
      title: 'الانضمام لغرفة',
      subtitle: 'أدخل كود الغرفة المكوّن من 6 أحرف',
      accent: const Color(0xFF11998E),
      child: Column(
        children: [
          ModeHomeJoinTextField(controller: _codeController),
          const SizedBox(height: 14),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: () {
                Navigator.pop(context);
                _joinWithCode(context);
              },
              icon: const AppIcon(AppIcons.login, size: 18),
              label: Text(
                'دخول الغرفة',
                style: GoogleFonts.cairo(fontWeight: FontWeight.bold),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF11998E),
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
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
        borderColor: _red.withValues(alpha: 0.4),
        fillColor: AppTheme.navyMid.withValues(alpha: 0.9),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const SizedBox(
            width: 44,
            height: 44,
            child: CircularProgressIndicator(color: _red, strokeWidth: 3.5),
          ),
          const SizedBox(height: 16),
          Text(
            provider.isSearching
                ? 'جاري البحث عن غرفة 99...'
                : 'جاري الاتصال بالغرفة...',
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
            icon: const AppIcon(AppIcons.close, size: 18),
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
}
