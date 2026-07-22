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

class LobbyScreen extends StatefulWidget {
  const LobbyScreen({super.key});

  @override
  State<LobbyScreen> createState() => _LobbyScreenState();
}

class _LobbyScreenState extends State<LobbyScreen> {
  static const List<String> _seatEmojis = ['♠', '♥', '♦', '♣'];
  static const List<Color> _seatColors = [
    AppTheme.accentBlue,
    AppTheme.suitRed,
    AppTheme.accentLight,
    Color(0xFFA78BFA),
  ];

  List<String> _previousPlayerIds = [];

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<GameProvider>();
    final state = provider.state;
    final isTestMode = provider.isTestMode;
    // Use state?.players for all modes to reflect live presence from GameServer
    final List<dynamic> players = state?.players ?? [];

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
    if (state != null && state.phase != GamePhase.lobby) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (context.mounted) Navigator.pushReplacementNamed(context, '/game');
      });
    }

    // Navigate back on error
    final errorMessage = provider.errorMessage;
    if (provider.status == ConnectionStatus.error) {
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
          Navigator.pushReplacementNamed(context, '/');
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
        
        if (provider.isHost) ...[
          _buildThemeSelector(provider),
          const SizedBox(height: 16),
          _buildStartButton(provider, players),
        ] else
          _buildWaitingText(context),
      ],
    );

    final rightPlayers = Column(
      mainAxisSize: MainAxisSize.min,
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        _buildPlayerCount(players, provider),
        const SizedBox(height: 16),
        Wrap(
          spacing: 12,
          runSpacing: 16,
          alignment: WrapAlignment.center,
          children: List.generate(4, (i) => _buildPlayerAvatar(context, provider, players, i, isTestMode)),
        ),
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
                    rightPlayers,
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
                      child: rightPlayers,
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
        body: Container(
          width: double.infinity,
          height: double.infinity,
          decoration: const BoxDecoration(gradient: AppTheme.bgGradient),
          child: SafeArea(
            child: Column(
              children: [
                // ── Top bar ──────────────────────────────────────
                _buildTopBar(context, provider),

                Expanded(child: contentWidget),
              ],
            ),
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
                        Navigator.pop(ctx);
                        provider.reset();
                        Navigator.pushReplacementNamed(context, '/');
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

  Widget _buildTopBar(BuildContext context, GameProvider provider) {
    return Container(
      padding: const EdgeInsets.fromLTRB(8, 12, 20, 12),
      decoration: BoxDecoration(
        color: AppTheme.navyDark.withValues(alpha: 0.6),
        border: Border(bottom: BorderSide(color: Colors.white.withValues(alpha: 0.08))),
      ),
      child: Row(
        children: [
          IconButton(
            icon: Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(Icons.close_rounded, color: AppTheme.accentLight, size: 20),
            ),
            tooltip: provider.isHost ? 'إلغاء الغرفة' : 'مغادرة الغرفة',
            onPressed: () => _confirmExit(context, provider),
          ),
          Expanded(
            child: Text(
              'غرفة الانتظار',
              textAlign: TextAlign.center,
              style: GoogleFonts.cairo(
                color: AppTheme.mintSoft,
                fontSize: 18,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          const SizedBox(width: 48),
        ],
      ),
    );
  }

  Widget _buildGameCodeCard(BuildContext context, GameProvider provider) {
    final code = provider.gameCode!;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF253070), AppTheme.navyMid],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppTheme.accentBlue.withValues(alpha: 0.4), width: 1.5),
        boxShadow: AppTheme.glowShadow,
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.share_rounded, size: 14, color: AppTheme.accentLight),
              const SizedBox(width: 6),
              Text(
                'كود الغرفة — شاركه مع أصدقائك',
                style: GoogleFonts.cairo(color: AppTheme.accentLight, fontSize: 13),
              ),
            ],
          ),
          const SizedBox(height: 14),
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
                    color: AppTheme.navyDark,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: AppTheme.accentBlue, width: 2),
                    boxShadow: [
                      BoxShadow(
                        color: AppTheme.accentBlue.withValues(alpha: 0.2),
                        blurRadius: 8,
                      ),
                    ],
                  ),
                  alignment: Alignment.center,
                  child: Text(
                    char,
                    style: GoogleFonts.cairo(
                      color: AppTheme.mintSoft,
                      fontSize: 26,
                      fontWeight: FontWeight.w900,
                      height: 1,
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 14),
          GestureDetector(
            onTap: () {
              Clipboard.setData(ClipboardData(text: code));
              SnackbarHelper.showSuccess(context, 'تم نسخ الكود بنجاح! 📋', title: 'نسخ');
            },
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: BoxDecoration(
                color: AppTheme.accentBlue.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: AppTheme.accentBlue.withValues(alpha: 0.3)),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.copy_rounded, size: 14, color: AppTheme.accentLight),
                  const SizedBox(width: 6),
                  Text(
                    'اضغط لنسخ الكود',
                    style: GoogleFonts.cairo(color: AppTheme.accentLight, fontSize: 13),
                  ),
                ],
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
        color: Colors.greenAccent.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.greenAccent.withValues(alpha: 0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.check_circle_rounded, color: Colors.greenAccent, size: 18),
          const SizedBox(width: 8),
          Text('متصل بالغرفة بنجاح ✓',
              style: GoogleFonts.cairo(color: Colors.greenAccent, fontSize: 14, fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }

  Widget _buildTestBadge() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: AppTheme.accentLight.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppTheme.accentLight.withValues(alpha: 0.25)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.smart_toy_outlined, size: 16, color: AppTheme.accentLight),
          const SizedBox(width: 6),
          Text('وضع التجربة — البوتات تلعب عنك',
              style: GoogleFonts.cairo(color: AppTheme.accentLight, fontSize: 13)),
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
          style: GoogleFonts.cairo(color: AppTheme.accentLight, fontSize: 14, fontWeight: FontWeight.w600),
        ),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
          decoration: BoxDecoration(
            color: AppTheme.accentBlue.withValues(alpha: 0.2),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: AppTheme.accentBlue.withValues(alpha: 0.4)),
          ),
          child: Text(
            '${players.length} / ${provider.expectedPlayers}',
            style: GoogleFonts.cairo(color: AppTheme.mintSoft, fontSize: 14, fontWeight: FontWeight.w700),
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
    final seatColor = _seatColors[i];

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Stack(
          clipBehavior: Clip.none,
          alignment: Alignment.center,
          children: [
            if (occupied && player.photo != null)
              PlayerAvatar(
                photoData: player.photo!,
                size: 72,
                borderColor: seatColor,
                borderWidth: 3,
                boxShadow: [
                  BoxShadow(color: seatColor.withValues(alpha: 0.3), blurRadius: 10, spreadRadius: 2),
                ],
              )
            else
              Container(
                width: 72,
                height: 72,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.white.withValues(alpha: 0.05),
                  border: Border.all(
                    color: Colors.white.withValues(alpha: 0.2),
                    width: 2,
                  ),
                ),
                child: Center(
                  child: Text(
                    _seatEmojis[i],
                    style: TextStyle(
                      fontSize: 32,
                      color: Colors.white.withValues(alpha: 0.3),
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
                  decoration: const BoxDecoration(
                    color: Colors.greenAccent,
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.check, color: AppTheme.navyDark, size: 16),
                ),
              )
          ],
        ),
        const SizedBox(height: 16),
        SizedBox(
          width: 72,
          child: Text(
            occupied ? player.name : 'انتظار...',
            textAlign: TextAlign.center,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: GoogleFonts.cairo(
              fontSize: 14,
              fontWeight: occupied ? FontWeight.w700 : FontWeight.w500,
              color: occupied ? AppTheme.mintSoft : AppTheme.accentLight.withValues(alpha: 0.5),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildStartButton(GameProvider provider, List<dynamic> players) {
    final canStart = players.length >= provider.expectedPlayers;
    return SizedBox(
      width: double.infinity,
      height: 56,
      child: DecoratedBox(
        decoration: BoxDecoration(
          gradient: canStart ? AppTheme.accentGradient : null,
          color: canStart ? null : AppTheme.navyMid,
          borderRadius: BorderRadius.circular(16),
          boxShadow: canStart ? AppTheme.glowShadow : [],
        ),
        child: ElevatedButton(
          onPressed: canStart ? () => provider.startGame() : null,
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.transparent,
            shadowColor: Colors.transparent,
            disabledBackgroundColor: Colors.transparent,
            foregroundColor: canStart ? AppTheme.white : AppTheme.accentLight.withValues(alpha: 0.4),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 0),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                canStart ? 'ابدأ اللعبة! 🃏' : 'في انتظار اللاعبين (${players.length}/${provider.expectedPlayers})...',
                style: GoogleFonts.cairo(fontSize: 18, fontWeight: FontWeight.bold, letterSpacing: 0.5),
              ),
              Icon(canStart ? Icons.play_arrow_rounded : Icons.hourglass_bottom_rounded, size: 28),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildThemeSelector(GameProvider provider) {
    final currentTheme = provider.state?.cardTheme ?? 'theme_1';
    
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: AppTheme.navyMid,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppTheme.accentBlue.withValues(alpha: 0.3)),
      ),
      child: Row(
        children: [
          const Icon(Icons.style_rounded, color: AppTheme.accentLight),
          const SizedBox(width: 12),
          Text(
            'شكل البطاقات:',
            style: GoogleFonts.cairo(
              color: AppTheme.accentLight,
              fontSize: 15,
              fontWeight: FontWeight.w600,
            ),
          ),
          const Spacer(),
          DropdownButtonHideUnderline(
            child: DropdownButton<String>(
              value: currentTheme,
              dropdownColor: AppTheme.navyDark,
              icon: const Icon(Icons.arrow_drop_down_rounded, color: AppTheme.accentBlue),
              style: GoogleFonts.cairo(color: AppTheme.mintSoft, fontSize: 15, fontWeight: FontWeight.bold),
              items: provider.availableThemes.map((theme) {
                // Extract number to show something like 'التصميم 1'
                final name = theme.replaceAll('theme_', 'التصميم ');
                return DropdownMenuItem(value: theme, child: Text(name));
              }).toList(),
              onChanged: (val) {
                if (val != null) {
                  provider.changeTheme(val);
                }
              },
            ),
          ),
        ],
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
