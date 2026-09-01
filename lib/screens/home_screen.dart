// lib/screens/home_screen.dart

import 'package:flutter/material.dart';
import '../core/widgets/app_dialog.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';

import '../providers/game_provider.dart';
import '../services/reconnection_manager.dart';
import '../services/online_play_gate.dart';
import '../widgets/recover_ongoing_game_banner.dart';
import '../widgets/online_play_block_dialog.dart';
import '../widgets/google_online_play_guard.dart';
import '../widgets/player_name_prompt.dart';
import '../services/profile_service.dart';
import '../theme/app_theme.dart';
import '../core/utils/snackbar_helper.dart';
import '../core/utils/wallpaper_precache.dart';
import '../core/widgets/mode_home_shell.dart';
import '../core/widgets/app_buttons.dart';
import '../core/constants.dart';
import '../widgets/performance_blur.dart';
import 'package:estimation/core/icons/app_icons.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen>
    with SingleTickerProviderStateMixin, ModeWallpaperPrecacheMixin {
  final _playerName = ValueNotifier<String>('');
  final _codeController = TextEditingController();
  late AnimationController _animController;
  late Animation<double> _fadeIn;
  late Animation<Offset> _slideIn;

  final _estimationMode = ValueNotifier<String>('classic');
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

    if (mounted) {
      final gate = context.read<OnlinePlayGate>();
      final status = await gate.refresh();
      if (!status.canJoinNewOnline) gate.startPolling();
    }

    if (mounted && context.read<OnlinePlayGate>().canReturnToOngoingGame) {
      await _showOngoingGameDisclaimer(context);
    }
  }

  Future<bool> _showOngoingGameDisclaimer(BuildContext context) async {
    final reconnect = context.read<ReconnectionManager>();
    final pendingSession = await reconnect.getPendingSession();
    if (!context.mounted || pendingSession == null) return false;
    final shouldReturn = await showDialog<bool>(
          context: context,
          barrierDismissible: false,
          builder: (dialogContext) => AppAlertDialog(
            title: Text(
              'العودة إلى المباراة؟',
              style: GoogleFonts.cairo(
                color: AppTheme.gold,
                fontWeight: FontWeight.w800,
              ),
            ),
            content: Text(
              'لديك مباراة ما زالت جارية. لا يمكنك بدء مباراة أو دخول طابور جديد حتى تنتهي أو تُفصل تلقائياً بعد 5 دقائق. البوت يلعب مكانك بعد 30 ثانية. يمكنك العودة واستعادة مقعدك خلال 5 دقائق.',
              style: GoogleFonts.cairo(color: AppTheme.cream, height: 1.5),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(dialogContext, false),
                child: Text('لاحقاً', style: GoogleFonts.cairo()),
              ),
              FilledButton(
                onPressed: () => Navigator.pop(dialogContext, true),
                child: Text('العودة الآن', style: GoogleFonts.cairo()),
              ),
            ],
          ),
        ) ??
        false;

    if (!shouldReturn) {
      return true;
    }

    final result = await reconnect.recoverPendingSession();

    if (!context.mounted) return true;
    if (result == ReconnectionState.reconnected) {
      final provider = context.read<GameProvider>();
      final is99Mode = provider.currentRoom?.gameType == 'ninety_nine';
      final isBasraMode = provider.currentRoom?.gameType == 'basra';
      final route = (provider.currentRoom?.status.name == 'playing')
          ? (is99Mode
              ? '/ninety_nine/game'
              : isBasraMode
                  ? '/basra/game'
                  : '/game')
          : '/lobby';
      Navigator.pushReplacementNamed(context, route);
    }
    return true;
  }

  @override
  void dispose() {
    _codeController.dispose();
    _animController.dispose();
    _playerName.dispose();
    _profilePhoto.dispose();
    _estimationMode.dispose();
    super.dispose();
  }

  Future<String?> _ensureName(BuildContext context) async {
    final name = await ensurePlayerName(
      context,
      currentName: _playerName.value,
    );
    if (name != null) _playerName.value = name;
    return name;
  }

  int get _selectedTotalRounds =>
      _estimationMode.value == 'mini' ? kMiniTotalRounds : kBoulaTotalRounds;

  Future<void> _host(BuildContext context, int expectedPlayers) async {
    if (await guardGoogleOnlinePlay(context)) return;
    if (!context.mounted) return;
    if (await _showOngoingGameDisclaimer(context)) return;
    if (!context.mounted) return;
    final name = await _ensureName(context);
    if (name == null || !context.mounted) return;

    final provider = context.read<GameProvider>();
    await provider.hostGame(
      name,
      expectedPlayers: expectedPlayers,
      totalRounds: _selectedTotalRounds,
    );
    if (context.mounted && provider.status == ConnectionStatus.connected) {
      Navigator.pushReplacementNamed(context, '/lobby');
    } else if (context.mounted && provider.status == ConnectionStatus.error) {
      _snack(context, provider.errorMessage);
    }
  }

  Future<void> _hostLocal(BuildContext context, int expectedPlayers) async {
    if (await _showOngoingGameDisclaimer(context)) return;
    if (!context.mounted) return;
    final name = await _ensureName(context);
    if (name == null || !context.mounted) return;

    final provider = context.read<GameProvider>();
    await provider.hostLocalGame(
      name,
      expectedPlayers: expectedPlayers,
      gameType: 'kotchina',
      totalRounds: _selectedTotalRounds,
    );
    if (context.mounted && provider.status == ConnectionStatus.connected) {
      Navigator.pushReplacementNamed(context, '/lobby');
    } else if (context.mounted && provider.status == ConnectionStatus.error) {
      _snack(context, provider.errorMessage);
    }
  }

  Future<void> _joinWithCode(BuildContext context) async {
    if (await guardGoogleOnlinePlay(context)) return;
    if (!context.mounted) return;
    if (await _showOngoingGameDisclaimer(context)) return;
    if (!context.mounted) return;
    final code = _codeController.text.trim();
    if (code.length != 6) {
      _snack(context, 'أدخل كود مكوّن من 6 أحرف');
      return;
    }
    final name = await _ensureName(context);
    if (name == null || !context.mounted) return;

    final provider = context.read<GameProvider>();
    await provider.joinGameWithCode(
      name,
      code,
      expectedGameType: 'kotchina',
    );
    if (context.mounted && provider.status == ConnectionStatus.connected) {
      Navigator.pushReplacementNamed(context, '/lobby');
    } else if (context.mounted && provider.status == ConnectionStatus.error) {
      _snack(context, provider.errorMessage);
    }
  }

  Future<void> _testMode(BuildContext context) async {
    if (await _showOngoingGameDisclaimer(context)) return;
    if (!context.mounted) return;
    final name = await _ensureName(context);
    if (name == null || !context.mounted) return;

    final provider = context.read<GameProvider>();
    await provider.startTestGame(
      name,
      totalRounds: _selectedTotalRounds,
    );
    if (context.mounted && provider.status == ConnectionStatus.connected) {
      Navigator.pushReplacementNamed(context, '/lobby');
    } else if (context.mounted && provider.status == ConnectionStatus.error) {
      _snack(context, provider.errorMessage);
    }
  }

  Future<void> _startOnlineMatchmaking(BuildContext context) async {
    if (await guardGoogleOnlinePlay(context)) return;
    if (!context.mounted) return;
    if (await guardOnlineMatchmaking(context)) return;
    if (!context.mounted) return;
    final name = await _ensureName(context);
    if (name == null || !context.mounted) return;
    final provider = context.read<GameProvider>();
    await provider.startMatchmaking(
      name,
      gameType: 'kotchina',
      totalRounds: _selectedTotalRounds,
    );
    if (!context.mounted) return;
    if (provider.status == ConnectionStatus.connected) {
      Navigator.pushReplacementNamed(context, '/matchmaking');
    } else if (provider.status == ConnectionStatus.error) {
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
    final status = context.select<GameProvider, ConnectionStatus>(
      (provider) => provider.status,
    );
    final isSearching = context.select<GameProvider, bool>(
      (provider) => provider.isSearching,
    );
    final isLoading = status == ConnectionStatus.connecting || isSearching;
    final size = MediaQuery.of(context).size;
    final isLandscape = size.width > size.height;

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {
        if (didPop) return;
        _confirmExitApp(context);
      },
      child: Scaffold(
        backgroundColor: AppTheme.deepNavy,
        body: Stack(
          fit: StackFit.expand,
          children: [
            const ModeHomeBackground(
              wallpaperAsset: 'assets/wallpapers/w2.jpg',
              primaryGlow: AppTheme.gold,
              secondaryGlow: AppTheme.midBlue,
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
                    child: _buildLoadingCard(context, isSearching),
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
                const SizedBox(height: 22),
                _buildTrainingSection(context),
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
                const ModeHomeLandscapeDivider(accent: AppTheme.gold),
                const SizedBox(width: 20),
                Expanded(
                  flex: 6,
                  child: SingleChildScrollView(
                    physics: const BouncingScrollPhysics(),
                    child: Column(
                      children: [
                        _buildMultiplayerGrid(context),
                        const SizedBox(height: 16),
                        _buildTrainingSection(context),
                      ],
                    ),
                  ),
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
            accent: AppTheme.gold,
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
      title: 'إستميشن',
      subtitle: 'البولة الكلاسيكية — ١٨ دور',
      showFloatingCards: false,
      emblem: ModeHomeArtEmblem(
        asset: 'assets/estimation.png',
        accent: const Color(0xFFC8F542),
        size: compact ? 78 : 96,
        overflows: true,
      ),
      footer: _buildModeToggle(),
    );
  }

  Widget _buildModeToggle() {
    return ValueListenableBuilder<String>(
      valueListenable: _estimationMode,
      builder: (context, mode, _) {
        return Container(
          padding: const EdgeInsets.all(3),
          decoration: BoxDecoration(
            color: AppTheme.navyDark.withValues(alpha: 0.65),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              _buildModeTab(
                label: 'كلاسيك',
                selected: mode == 'classic',
                accent: AppTheme.gold,
                onTap: () => _estimationMode.value = 'classic',
              ),
              _buildModeTab(
                label: 'ميني',
                selected: mode == 'mini',
                accent: const Color(0xFF06B6D4),
                onTap: () => _estimationMode.value = 'mini',
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildModeTab({
    required String label,
    required bool selected,
    required Color accent,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: () => _tap(onTap),
      borderRadius: BorderRadius.circular(11),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 8),
        decoration: BoxDecoration(
          color: selected ? accent.withValues(alpha: 0.22) : Colors.transparent,
          borderRadius: BorderRadius.circular(11),
          border: Border.all(
            color:
                selected ? accent.withValues(alpha: 0.55) : Colors.transparent,
          ),
        ),
        child: Text(
          label,
          style: GoogleFonts.cairo(
            fontSize: 13,
            fontWeight: FontWeight.bold,
            color: selected ? AppTheme.white : AppTheme.steelBlue,
          ),
        ),
      ),
    );
  }

  Widget _buildPrimaryAction(BuildContext context) {
    return Consumer<OnlinePlayGate>(
      builder: (context, gate, _) {
        final blocked = !gate.canJoinNewOnline;
        final countdown = gate.remainingLabel;
        final showCountdown = blocked && countdown.isNotEmpty;
        final canReturn = gate.canReturnToOngoingGame;
        return Column(
          children: [
            const RecoverOngoingGameBanner(),
            const OnlineBanNotice(),
            ModeHomeActionButton(
              label: showCountdown
                  ? 'لعب أونلاين ($countdown)'
                  : 'لعب أونلاين',
              subtitle: blocked
                  ? (canReturn
                      ? 'اضغط للخيارات: انتظر أو عد للمباراة'
                      : 'المباراة السابقة انتهت — انتظر انتهاء المهلة')
                  : null,
              icon: AppIcons.groups,
              gradient: const [Color(0xFF11998E), Color(0xFF0D7377)],
              isLarge: true,
              enabled: true,
              onTap: blocked
                  ? () => _tap(() => guardOnlineMatchmaking(context))
                  : () => _tap(() => _startOnlineMatchmaking(context)),
            ),
            const SizedBox(height: 10),
            ModeHomeActionButton(
              label: 'لعب فردي سريع',
              icon: AppIcons.bolt,
              gradient: const [Color(0xFFD4A853), Color(0xFFA07830)],
              isLarge: true,
              onTap: () => _tap(() => _testMode(context)),
            ),
          ],
        );
      },
    );
  }

  Widget _buildMultiplayerGrid(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const ModeHomeSectionLabel(text: 'العب مع الآخرين'),
        const SizedBox(height: 10),
        Row(
          children: [
            Expanded(
              child: ModeHomeActionButton(
                label: 'إنشاء غرفة',
                icon: AppIcons.addCircleOutline,
                gradient: const [Color(0xFF3A7BD5), Color(0xFF2E5984)],
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
            const SizedBox(width: 10),
            Expanded(
              child: ModeHomeActionButton(
                label: 'محلي',
                icon: AppIcons.wifiTethering,
                gradient: const [Color(0xFFF59E0B), Color(0xFFD97706)],
                onTap: () => _tap(() => _showLocalSheet(context)),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildTrainingSection(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const ModeHomeSectionLabel(text: 'تعلّم وطوّر'),
        const SizedBox(height: 10),
        Row(
          children: [
            Expanded(
              child: ModeHomeCompactTile(
                title: 'الأكاديمية',
                icon: AppIcons.school,
                color: const Color(0xFF8B5CF6),
                onTap: () =>
                    _tap(() => Navigator.pushNamed(context, '/academy')),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: ModeHomeCompactTile(
                title: 'الألغاز',
                icon: AppIcons.extension,
                color: const Color(0xFFEC4899),
                onTap: () =>
                    _tap(() => Navigator.pushNamed(context, '/puzzles')),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Future<void> _showHostSheet(BuildContext context) async {
    if (await guardGoogleOnlinePlay(context)) return;
    if (!context.mounted) return;
    await showModeHomeSheet<void>(
      context,
      title: 'إنشاء غرفة جديدة',
      subtitle: 'اختر عدد اللاعبين',
      accent: const Color(0xFF3A7BD5),
      child: PlayerCountRow(
        onSelect: (count) {
          Navigator.pop(context);
          _host(context, count);
        },
      ),
    );
  }

  Future<void> _showJoinSheet(BuildContext context) async {
    if (await guardGoogleOnlinePlay(context)) return;
    if (!context.mounted) return;
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
              icon: const AppIcon(
                AppIcons.login,
                size: AppIconTokens.sizeMd,
                strokeWidth: AppIconTokens.stroke,
              ),
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

  Future<void> _showLocalSheet(BuildContext context) async {
    await showModeHomeSheet<void>(
      context,
      title: 'لعب محلي',
      subtitle: 'استضافة عبر شبكة Wi-Fi',
      accent: const Color(0xFFF59E0B),
      child: Column(
        children: [
          PlayerCountRow(
            onSelect: (count) {
              Navigator.pop(context);
              _hostLocal(context, count);
            },
          ),
          const SizedBox(height: 14),
          OutlinedButton.icon(
            onPressed: () {
              Navigator.pop(context);
              Navigator.pushNamed(context, '/local_discovery');
            },
            icon: const AppIcon(
              AppIcons.wifiFind,
              size: AppIconTokens.sizeMd,
              strokeWidth: AppIconTokens.stroke,
            ),
            label: Text(
              'البحث عن غرف محلية',
              style: GoogleFonts.cairo(fontWeight: FontWeight.bold),
            ),
            style: OutlinedButton.styleFrom(
              foregroundColor: AppTheme.cream,
              side: const BorderSide(color: Color(0xFFF59E0B)),
              minimumSize: const Size(double.infinity, 48),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLoadingCard(BuildContext context, bool isSearching) {
    final msg = isSearching ? 'نبحث عن غرفتك...' : 'جاري الاتصال بالسيرفر...';
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
            icon: const AppIcon(
              AppIcons.close,
              size: AppIconTokens.sizeMd,
              strokeWidth: AppIconTokens.stroke,
            ),
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

  void _confirmExitApp(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => Dialog(
        backgroundColor: Colors.transparent,
        child: Container(
          width: 360,
          padding: const EdgeInsets.all(24),
          decoration: AppTheme.dialogDecoration(accent: AppTheme.errorRed),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppTheme.errorRed.withValues(alpha: 0.15),
                  shape: BoxShape.circle,
                ),
                child: const AppIcon(
                  AppIcons.exitToApp,
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
