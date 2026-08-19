// lib/screens/lobby_screen.dart

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../core/models/game_state.dart';
import '../providers/game_provider.dart';
import '../theme/app_theme.dart';
import '../core/utils/snackbar_helper.dart';
import '../core/widgets/player_avatar.dart';
import '../widgets/performance_blur.dart';
import '../modes/ninety_nine/presentation/providers/ninety_nine_game_provider.dart';
import '../features/lobby/domain/models/game_room.dart';
class LobbyScreen extends StatefulWidget {
  const LobbyScreen({super.key});

  @override
  State<LobbyScreen> createState() => _LobbyScreenState();
}

class _LobbyScreenState extends State<LobbyScreen> {
  static const List<String> _seatEmojis = ['♠', '♥', '♦', '♣', '★', '🔥', '🌀'];
  static const List<Color> _seatColors = [
    AppTheme.accentBlue,
    AppTheme.suitRed,
    AppTheme.accentLight,
    Color(0xFFA78BFA),
    Colors.orangeAccent,
    Colors.pinkAccent,
    Colors.cyanAccent,
  ];

  List<String> _previousPlayerIds = [];
  bool _hasNavigatedToGame = false;
  bool _hasNavigatedHome = false;
  // ValueNotifier — prevents double-tap on start during network call; no setState needed.
  final _isStartingGame = ValueNotifier<bool>(false);

  @override
  void dispose() {
    _isStartingGame.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<GameProvider>();
    final state = provider.state;
    final isTestMode = provider.isTestMode;
    final isNinetyNineMode = provider.currentRoom?.gameType == 'ninety_nine';
    final nnProvider = context.watch<NinetyNineGameProvider>();
    
    // Use the appropriate state for live presence
    final List<dynamic> players = isNinetyNineMode ? nnProvider.players : (state?.players ?? []);

    // Track player joins and leaves
    if (!isTestMode) {
      final currentPlayerIds = players.map((p) => p.id as String).toList();

      if (_previousPlayerIds.isNotEmpty) {
        final joined = currentPlayerIds.where((id) => !_previousPlayerIds.contains(id)).toList();
        final left = _previousPlayerIds.where((id) => !currentPlayerIds.contains(id)).toList();

        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (context.mounted) {
            for (final id in joined) {
              final p = players.firstWhere((p) => p.id == id);
              SnackbarHelper.showSuccess(context, 'يا مرحباً! ${p.name} دخل الساحة! ⚔️', title: 'لاعب جديد');
            }
            for (final _ in left) {
              SnackbarHelper.showWarning(context, 'في لاعب هرب من المواجهة! 🏃‍♂️', title: 'انسحاب');
            }
          }
        });
      }
      _previousPlayerIds = currentPlayerIds;
    }

    // Navigate to game
    final isKotchinaStarted = state != null && state.phase != GamePhase.lobby;
    final isNinetyNineStarted = provider.currentRoom?.gameType == 'ninety_nine' && provider.currentRoom?.status == GameRoomStatus.playing;
    
    if ((isKotchinaStarted || isNinetyNineStarted) && !_hasNavigatedToGame) {
      _hasNavigatedToGame = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (context.mounted) {
          if (isNinetyNineStarted) {
             final nnProvider = context.read<NinetyNineGameProvider>();
             nnProvider.setClient(provider.nnClient);
             provider.nnClient?.onStateUpdate = (state) {
               nnProvider.syncState(state);
             };
             Navigator.pushReplacementNamed(context, '/ninety_nine/game');
          } else {
             Navigator.pushReplacementNamed(context, '/game');
          }
        }
      });
    }

    // Navigate back on error
    final errorMessage = provider.errorMessage;
    if (provider.status == ConnectionStatus.error && !_hasNavigatedHome) {
      _hasNavigatedHome = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (context.mounted) {
          if (errorMessage.isNotEmpty) {
            SnackbarHelper.showError(
              context,
              errorMessage.contains('إلغاء') ? 'المضيف كنسل اللعبة، نشوفك في جولة تانية! 👋' : errorMessage,
              title: 'للأسف 🚪',
            );
          }
          provider.reset();
          Navigator.of(context, rootNavigator: true)
              .pushNamedAndRemoveUntil('/', (route) => false);
        }
      });
    }

    final isPortrait = MediaQuery.of(context).size.width < 800;

    final leftControls = Column(
      mainAxisSize: MainAxisSize.min,
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        if (provider.isHost && provider.gameCode != null)
          _buildGameCodeCard(context, provider)
        else if (!provider.isHost)
          _buildJoinedBadge(),
        
        if (provider.isTestMode) ...[
          const SizedBox(height: 12),
          _buildTestBadge(),
        ],
        
        const SizedBox(height: 24),
        
        _buildPlayerCount(players, provider),
        const SizedBox(height: 16),
        Wrap(
          spacing: 12,
          runSpacing: 16,
          alignment: WrapAlignment.center,
          children: List.generate(provider.expectedPlayers, (i) => _buildPlayerAvatar(context, provider, players, i, isTestMode)),
        ),
      ],
    );

    final rightControls = Column(
      mainAxisSize: MainAxisSize.min,
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        if (provider.isHost) ...[
          _buildThemeSelector(provider),
          if (!isPortrait) ...[
            const SizedBox(height: 24),
            Row(
              children: [
                Expanded(
                  flex: 6,
                  child: _buildStartButton(provider, players),
                ),
                const SizedBox(width: 12),
                Expanded(
                  flex: 4,
                  child: _buildCancelButton(context, provider),
                ),
              ],
            ),
          ],
        ] else ...[
          _buildWaitingText(context),
          if (!isPortrait) ...[
            const SizedBox(height: 24),
            _buildCancelButton(context, provider),
          ],
        ],
      ],
    );

    final contentWidget = isPortrait
        ? SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
            physics: const BouncingScrollPhysics(),
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 800),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    leftControls,
                    const SizedBox(height: 32),
                    rightControls,
                  ],
                ),
              ),
            ),
          )
        : Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(32, 16, 32, 16),
              physics: const BouncingScrollPhysics(),
              child: IntrinsicHeight(
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Expanded(
                      flex: 5,
                      child: leftControls,
                    ),
                    Container(
                      width: 1,
                      margin: const EdgeInsets.symmetric(horizontal: 32),
                      color: Colors.white12,
                    ),
                    Expanded(
                      flex: 6,
                      child: rightControls,
                    ),
                  ],
                ),
              ),
            ),
          );

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {
        if (didPop) return;
        _confirmExit(context, provider);
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
                  'assets/wallpapers/w1.jpg',
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
                        AppTheme.navyDark.withValues(alpha: 0.5),
                        AppTheme.navyDark.withValues(alpha: 0.8),
                      ],
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
                child: Column(
                  children: [
                    Expanded(child: contentWidget),

                    if (isPortrait)
                      Padding(
                        padding: const EdgeInsets.fromLTRB(20, 0, 20, 32),
                        child: Row(
                          children: [
                            if (provider.isHost) ...[
                              Expanded(
                                flex: 6,
                                child: _buildStartButton(provider, players),
                              ),
                              const SizedBox(width: 12),
                            ],
                            Expanded(
                              flex: 4,
                              child: _buildCancelButton(context, provider),
                            ),
                          ],
                        ),
                      ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _confirmExit(BuildContext context, GameProvider provider) {
    showDialog(
      context: context,
      builder: (ctx) => Dialog(
        backgroundColor: AppTheme.navyDark,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: BorderSide(color: Colors.white.withValues(alpha: 0.1), width: 1),
        ),
        child: Container(
          width: 400,
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.exit_to_app_rounded, color: AppTheme.errorRed, size: 48),
              const SizedBox(height: 16),
              Text(
                provider.isHost ? 'إلغاء الغرفة' : 'مغادرة الغرفة',
                style: Theme.of(context).textTheme.headlineMedium,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              Text(
                provider.isHost
                    ? 'هل أنت متأكد أنك تريد إلغاء الغرفة والعودة للرئيسية؟'
                    : 'هل أنت متأكد أنك تريد مغادرة الغرفة والعودة للرئيسية؟',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: AppTheme.textSecondary),
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
                        side: const BorderSide(color: Colors.white24, width: 2),
                        foregroundColor: AppTheme.textPrimary,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      ),
                      child: Text('إلغاء', style: GoogleFonts.cairo(fontWeight: FontWeight.bold, fontSize: 15)),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () {
                        provider.reset();
                        Navigator.of(context, rootNavigator: true)
                            .pushNamedAndRemoveUntil('/', (route) => false);
                      },
                      style: ElevatedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        backgroundColor: AppTheme.errorRed,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      ),
                      child: Text('مغادرة', style: GoogleFonts.cairo(fontWeight: FontWeight.bold, fontSize: 15)),
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


  Widget _buildGameCodeCard(BuildContext context, GameProvider provider) {
    final code = provider.gameCode!;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppTheme.navyDark.withValues(alpha: 0.7),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(
          color: AppTheme.accentBlue.withValues(alpha: 0.5),
          width: 1.5,
        ),
        boxShadow: [
          BoxShadow(
            color: AppTheme.accentBlue.withValues(alpha: 0.35),
            blurRadius: 20,
            spreadRadius: 1,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.share_rounded, size: 16, color: AppTheme.accentLight),
              const SizedBox(width: 8),
              Text(
                'كود الغرفة — شاركه مع أصدقائك',
                style: GoogleFonts.cairo(
                  color: AppTheme.mintSoft,
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          // Large code display
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            textDirection: TextDirection.ltr,
            children: [
              for (final char in code.split(''))
                Container(
                  margin: const EdgeInsets.symmetric(horizontal: 4),
                  width: 44,
                  height: 56,
                  decoration: BoxDecoration(
                    color: AppTheme.navyMid.withValues(alpha: 0.9),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: AppTheme.accentBlue, width: 2),
                    boxShadow: [
                      BoxShadow(
                        color: AppTheme.accentBlue.withValues(alpha: 0.3),
                        blurRadius: 10,
                      ),
                    ],
                  ),
                  alignment: Alignment.center,
                  child: Text(
                    char,
                    style: GoogleFonts.cairo(
                      color: AppTheme.white,
                      fontSize: 26,
                      fontWeight: FontWeight.w900,
                      height: 1,
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 16),
          if (provider.isLocal && provider.localHostIp != null) ...[
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
              decoration: BoxDecoration(
                color: Colors.amber.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: Colors.amber.withValues(alpha: 0.4)),
              ),
              child: SelectableText(
                'عنوان IP المحلي: ${provider.localHostIp}:${provider.localPort}',
                style: GoogleFonts.cairo(
                  color: Colors.amber,
                  fontWeight: FontWeight.bold,
                  fontSize: 13,
                ),
              ),
            ),
            const SizedBox(height: 12),
          ],
          Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: () {
                final textToCopy = provider.isLocal ? '${provider.localHostIp}:${provider.localPort}' : code;
                Clipboard.setData(ClipboardData(text: textToCopy));
                SnackbarHelper.showSuccess(context, 'تم النسخ بنجاح! 📋', title: 'نسخ');
              },
              borderRadius: BorderRadius.circular(12),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 9),
                decoration: BoxDecoration(
                  color: AppTheme.accentBlue.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppTheme.accentBlue.withValues(alpha: 0.4)),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.copy_rounded, size: 16, color: AppTheme.mintSoft),
                    const SizedBox(width: 8),
                    Text(
                      provider.isLocal ? 'اضغط لنسخ عنوان IP' : 'اضغط لنسخ الكود',
                      style: GoogleFonts.cairo(
                        color: AppTheme.mintSoft,
                        fontSize: 13,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildJoinedBadge() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.greenAccent.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.greenAccent.withValues(alpha: 0.4)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.check_circle_rounded, color: Colors.greenAccent, size: 20),
          const SizedBox(width: 10),
          Text('متصل بالغرفة بنجاح ✓',
              style: GoogleFonts.cairo(color: Colors.greenAccent, fontSize: 14, fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }

  Widget _buildTestBadge() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: AppTheme.accentLight.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppTheme.accentLight.withValues(alpha: 0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.smart_toy_outlined, size: 18, color: AppTheme.mintSoft),
          const SizedBox(width: 8),
          Text('وضع التجربة — البوتات تلعب عنك',
              style: GoogleFonts.cairo(color: AppTheme.mintSoft, fontSize: 13, fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }

  Widget _buildPlayerCount(List<dynamic> players, GameProvider provider) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          'اللاعبون',
          style: GoogleFonts.cairo(color: AppTheme.white, fontSize: 15, fontWeight: FontWeight.bold),
        ),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
          decoration: BoxDecoration(
            color: AppTheme.accentBlue.withValues(alpha: 0.25),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: AppTheme.accentBlue.withValues(alpha: 0.5)),
          ),
          child: Text(
            '${players.length} / ${provider.expectedPlayers}',
            style: GoogleFonts.cairo(color: AppTheme.mintSoft, fontSize: 14, fontWeight: FontWeight.bold),
          ),
        ),
      ],
    );
  }

  Widget _buildPlayerAvatar(BuildContext context, GameProvider provider, List<dynamic> players, int i, bool isTestMode) {
    final occupied = i < players.length;
    final player = occupied ? players[i] : null;
    final isMe = occupied && player.id == provider.myPlayerId;
    final isBot = occupied && player.id.startsWith('bot_');
    final seatColor = _seatColors[i % _seatColors.length];

    String? photoData;
    if (occupied) {
      try {
        photoData = player.photo;
      } on NoSuchMethodError {
        try {
          photoData = player.avatarId;
        } catch (_) {}
      }
    }

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Stack(
          clipBehavior: Clip.none,
          alignment: Alignment.center,
          children: [
            if (occupied && photoData != null)
              PlayerAvatar(
                photoData: photoData,
                size: 72,
                borderColor: seatColor,
                borderWidth: 3,
                boxShadow: [
                  BoxShadow(color: seatColor.withValues(alpha: 0.45), blurRadius: 14, spreadRadius: 2),
                ],
              )
            else
              Container(
                width: 72,
                height: 72,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: AppTheme.navyDark.withValues(alpha: 0.6),
                  border: Border.all(
                    color: seatColor.withValues(alpha: 0.4),
                    width: 2.5,
                  ),
                ),
                child: Center(
                  child: Text(
                    _seatEmojis[i % _seatEmojis.length],
                    style: TextStyle(
                      fontSize: 32,
                      color: seatColor.withValues(alpha: 0.6),
                    ),
                  ),
                ),
              ),
            if (isMe)
              Positioned(
                bottom: -6,
                child: _badge('أنت', AppTheme.accentBlue),
              )
            else if (isBot)
              Positioned(
                bottom: -6,
                child: _badge('بوت 🤖', AppTheme.accentLight),
              )
            else if (occupied)
              Positioned(
                bottom: 0,
                right: 0,
                child: Container(
                  padding: const EdgeInsets.all(2),
                  decoration: const BoxDecoration(
                    color: Colors.greenAccent,
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.check, color: AppTheme.navyDark, size: 14),
                ),
              )
          ],
        ),
        const SizedBox(height: 16),
        SizedBox(
          width: 76,
          child: Text(
            occupied ? player.name : 'انتظار...',
            textAlign: TextAlign.center,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: GoogleFonts.cairo(
              fontSize: 14,
              fontWeight: occupied ? FontWeight.w700 : FontWeight.w500,
              color: occupied ? AppTheme.white : AppTheme.accentLight.withValues(alpha: 0.6),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildStartButton(GameProvider provider, List<dynamic> players) {
    final canStart = players.length >= provider.expectedPlayers;
    return ValueListenableBuilder<bool>(
      valueListenable: _isStartingGame,
      builder: (context, isStarting, _) {
        return Container(
          width: double.infinity,
          height: 58,
          decoration: BoxDecoration(
            gradient: canStart
                ? const LinearGradient(
                colors: [Color(0xFF4CAF50), Color(0xFF2E7D32)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              )
            : null,
        color: canStart ? null : AppTheme.navyDark.withValues(alpha: 0.6),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: canStart
              ? Colors.greenAccent.withValues(alpha: 0.5)
              : Colors.white.withValues(alpha: 0.1),
          width: 1.5,
        ),
        boxShadow: canStart
            ? [
                BoxShadow(
                  color: Colors.greenAccent.withValues(alpha: 0.4),
                  blurRadius: 20,
                  spreadRadius: 2,
                  offset: const Offset(0, 4),
                ),
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.25),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
              ]
            : [],
      ),
      child: ElevatedButton(
          onPressed: (canStart && !isStarting)
              ? () {
                  _isStartingGame.value = true;
                  provider.startGame();
                }
              : null,
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.transparent,
          shadowColor: Colors.transparent,
          disabledBackgroundColor: Colors.transparent,
          foregroundColor: canStart ? AppTheme.white : AppTheme.accentLight.withValues(alpha: 0.5),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 0),
        ),
        child: FittedBox(
          fit: BoxFit.scaleDown,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                canStart ? 'ابدأ اللعبة الان' : 'في انتظار اللاعبين (${players.length}/${provider.expectedPlayers})...',
                style: GoogleFonts.cairo(fontSize: 17, fontWeight: FontWeight.w800, letterSpacing: 0.5),
              ),
              const SizedBox(width: 12),
              Icon(canStart ? Icons.play_circle_fill_rounded : Icons.hourglass_bottom_rounded, size: 28),
            ],
          ),
        ),
      ),
        );
      },
    );
  }

  Widget _buildThemeSelector(GameProvider provider) {
    final isNinetyNine = provider.currentRoom?.gameType == 'ninety_nine';
    final nnProvider = context.watch<NinetyNineGameProvider>();
    final currentTheme = isNinetyNine ? nnProvider.cardTheme : provider.state?.cardTheme ?? 'theme_1';
    
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(right: 8.0, bottom: 12.0),
          child: Row(
            children: [
              const Icon(Icons.style_rounded, color: AppTheme.mintSoft, size: 20),
              const SizedBox(width: 8),
              Text(
                'شكل البطاقات:',
                style: GoogleFonts.cairo(
                  color: AppTheme.white,
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
        ),
        SizedBox(
          height: 120,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            physics: const BouncingScrollPhysics(),
            itemCount: provider.availableThemes.length,
            itemBuilder: (context, index) {
              final themeId = provider.availableThemes[index];
              final isSelected = themeId == currentTheme;
              final name = themeId.replaceAll('theme_', 'التصميم ');
              
              return GestureDetector(
                onTap: () {
                  provider.changeTheme(themeId);
                },
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 250),
                  margin: EdgeInsets.only(
                    right: index == 0 ? 0 : 12,
                    left: index == provider.availableThemes.length - 1 ? 0 : 12,
                  ),
                  width: 95,
                  decoration: BoxDecoration(
                    color: isSelected 
                        ? AppTheme.gold.withValues(alpha: 0.15) 
                        : AppTheme.navyDark.withValues(alpha: 0.5),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: isSelected 
                          ? AppTheme.gold 
                          : Colors.white.withValues(alpha: 0.1),
                      width: isSelected ? 2.5 : 1,
                    ),
                    boxShadow: isSelected 
                        ? [
                            BoxShadow(
                              color: AppTheme.gold.withValues(alpha: 0.35),
                              blurRadius: 12,
                              spreadRadius: 1,
                            )
                          ] 
                        : [],
                  ),
                  child: Stack(
                    children: [
                      Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Container(
                              height: 56,
                              width: 40,
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(4),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black.withValues(alpha: 0.4),
                                    blurRadius: 4,
                                    offset: const Offset(2, 2),
                                  ),
                                ],
                              ),
                              child: ClipRRect(
                                borderRadius: BorderRadius.circular(4),
                                child: Image.asset(
                                  'assets/$themeId/A_S.png',
                                  fit: BoxFit.cover,
                                  errorBuilder: (context, error, stackTrace) => 
                                      Icon(Icons.style, color: AppTheme.accentLight.withValues(alpha: 0.5)),
                                ),
                              ),
                            ),
                            const SizedBox(height: 10),
                            Text(
                              name,
                              style: GoogleFonts.cairo(
                                color: isSelected ? AppTheme.white : AppTheme.accentLight.withValues(alpha: 0.7),
                                fontSize: 13,
                                fontWeight: isSelected ? FontWeight.bold : FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ),
                      if (isSelected)
                        Positioned(
                          top: 8,
                          right: 8,
                          child: Container(
                            padding: const EdgeInsets.all(2),
                            decoration: const BoxDecoration(
                              color: AppTheme.gold,
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(
                              Icons.check,
                              color: AppTheme.deepNavy,
                              size: 12,
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildCancelButton(BuildContext context, GameProvider provider) {
    final isHost = provider.isHost;
    return Container(
      height: 58,
      decoration: BoxDecoration(
        color: AppTheme.errorRed.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: AppTheme.errorRed.withValues(alpha: 0.5),
          width: 1.5,
        ),
        boxShadow: [
          BoxShadow(
            color: AppTheme.errorRed.withValues(alpha: 0.2),
            blurRadius: 16,
            spreadRadius: 1,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: ElevatedButton(
        onPressed: () => _confirmExit(context, provider),
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.transparent,
          shadowColor: Colors.transparent,
          disabledBackgroundColor: Colors.transparent,
          foregroundColor: AppTheme.errorRed,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          padding: const EdgeInsets.symmetric(horizontal: 8),
        ),
        child: FittedBox(
          fit: BoxFit.scaleDown,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.exit_to_app_rounded, size: 20),
              const SizedBox(width: 6),
              Text(
                isHost ? 'إلغاء الغرفة' : 'خروج',
                style: GoogleFonts.cairo(fontSize: 15, fontWeight: FontWeight.bold),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildWaitingText(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        SizedBox(
          width: 16,
          height: 16,
          child: CircularProgressIndicator(
            strokeWidth: 2,
            color: AppTheme.accentLight.withValues(alpha: 0.6),
          ),
        ),
        const SizedBox(width: 10),
        Text(
          'في انتظار المضيف لبدء اللعبة...',
          style: GoogleFonts.cairo(color: AppTheme.accentLight, fontSize: 14),
        ),
      ],
    );
  }

  Widget _badge(String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.withValues(alpha: 0.45)),
      ),
      child: Text(
        label,
        style: GoogleFonts.cairo(
            color: color, fontSize: 12, fontWeight: FontWeight.w700),
      ),
    );
  }
}
