import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';

import '../../../../core/icons/app_icons.dart';
import '../../../../core/models/game_state.dart';
import '../../../../core/widgets/app_buttons.dart';
import '../../../../core/utils/wallpaper_precache.dart';
import '../../../../core/widgets/mode_home_shell.dart';
import '../../../../features/lobby/domain/models/room_player.dart';
import '../../../../providers/game_provider.dart';
import '../../../../theme/app_theme.dart';
import '../../../../widgets/performance_blur.dart';
import '../../domain/models/matchmaking_status.dart';
import '../widgets/bot_fill_dialog.dart';
import '../widgets/matchmaking_player_slot.dart';

class MatchmakingScreen extends StatefulWidget {
  const MatchmakingScreen({super.key});

  @override
  State<MatchmakingScreen> createState() => _MatchmakingScreenState();
}

class _MatchmakingScreenState extends State<MatchmakingScreen>
    with TickerProviderStateMixin, ModeWallpaperPrecacheMixin {
  bool _dialogOpen = false;
  bool _hasNavigatedToGame = false;
  bool _leaving = false;
  int? _dialogVersion;

  late final AnimationController _entrance;
  late final AnimationController _pulse;
  late final Animation<double> _fade;

  @override
  void initState() {
    super.initState();
    _entrance = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 700),
    );
    _pulse = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2200),
    );
    _fade = CurvedAnimation(parent: _entrance, curve: Curves.easeOutCubic);
    _entrance.forward();
    _startPulseIfAllowed();
  }

  void _startPulseIfAllowed() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final reduceMotion = MediaQuery.of(context).disableAnimations;
      if (!reduceMotion) _pulse.repeat();
    });
  }

  @override
  void dispose() {
    _entrance.dispose();
    _pulse.dispose();
    super.dispose();
  }

  Future<void> _cancel() async {
    if (_leaving) return;
    HapticFeedback.lightImpact();
    _leaving = true;
    await context.read<GameProvider>().cancelMatchmaking();
    if (mounted) {
      Navigator.pushNamedAndRemoveUntil(
        context,
        '/kotchina/home',
        (_) => false,
      );
    }
  }

  void _reactToState(GameProvider provider) {
    final room = provider.currentRoom;
    final shouldVote = room?.isBotVoteOpen == true &&
        provider.matchmakingHumanCount >= 2 &&
        provider.matchmakingHumanCount <= 3;
    if (_dialogOpen &&
        (!shouldVote || room!.botOfferVersion != _dialogVersion)) {
      _dialogOpen = false;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) Navigator.of(context, rootNavigator: true).pop();
      });
    }
    if (shouldVote &&
        !_dialogOpen &&
        provider.claimBotOfferPresentation(room!.botOfferVersion)) {
      _dialogOpen = true;
      _dialogVersion = room.botOfferVersion;
      WidgetsBinding.instance.addPostFrameCallback((_) async {
        if (!mounted ||
            provider.currentRoom?.botOfferVersion != _dialogVersion) {
          return;
        }
        await showDialog<void>(
          context: context,
          barrierDismissible: false,
          barrierColor: Colors.black.withValues(alpha: 0.62),
          builder: (_) => BotFillDialog(
            humanCount: provider.matchmakingHumanCount,
            onVote: (accepted) async {
              await provider.voteForBotFill(
                offerVersion: _dialogVersion!,
                accepted: accepted,
              );
              if (mounted && _dialogOpen) {
                Navigator.of(context, rootNavigator: true).pop();
              }
            },
          ),
        );
        _dialogOpen = false;
      });
    }
    if (!_hasNavigatedToGame &&
        provider.state?.phase != null &&
        provider.state!.phase != GamePhase.lobby) {
      _hasNavigatedToGame = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) Navigator.pushReplacementNamed(context, '/game');
      });
    }
  }

  String _headline(GameProvider provider, bool searching) {
    if (!searching) return 'الطاولة جاهزة';
    return switch (provider.matchmakingHumanCount) {
      1 => 'نبحث عن شركاء',
      2 => 'لاعبان — نكمل العدد',
      3 => 'مقعد واحد متبقٍ',
      _ => 'اكتملت الطاولة',
    };
  }

  String _status(GameProvider provider) {
    if (provider.matchmakingStatus == MatchmakingStatus.starting ||
        provider.matchmakingStatus == MatchmakingStatus.playing) {
      return 'اكتملت الطاولة — جاري بدء المباراة';
    }
    if (provider.currentRoom?.isBotVoteOpen == true &&
        provider.currentRoom!.botYesVotes > 0) {
      return 'في انتظار موافقة باقي اللاعبين على البوتات';
    }
    return switch (provider.matchmakingHumanCount) {
      1 => 'نطابقك مع لاعبين على مستوى مهارتك',
      2 => 'يمكنكم الانتظار أو الموافقة على بوتات بعد قليل',
      3 => 'لاعب واحد فقط ينقص لبدء المباراة',
      _ => 'الجميع حاضر — سنبدأ خلال لحظات',
    };
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<GameProvider>();
    _reactToState(provider);

    final starting = provider.matchmakingStatus == MatchmakingStatus.starting ||
        provider.matchmakingStatus == MatchmakingStatus.playing;
    final searching = !starting;
    final players = provider.roomPlayers;
    final bots = starting ? provider.matchmakingBotsToFill : 0;
    final filled = players.length + bots;
    final myId = provider.myPlayerId;
    final size = MediaQuery.sizeOf(context);
    final tableWidth = math.min(size.width - 48, 360.0);

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {
        if (!didPop && !starting) _cancel();
      },
      child: Scaffold(
        backgroundColor: AppTheme.deepNavy,
        body: Stack(
          fit: StackFit.expand,
          children: [
            const ModeHomeBackground(
              wallpaperAsset: 'assets/wallpapers/w2.jpg',
              primaryGlow: Color(0xFF11998E),
              secondaryGlow: AppTheme.gold,
              subtleOverlay: true,
            ),
            SafeArea(
              child: FadeTransition(
                opacity: _fade,
                child: Column(
                  children: [
                    _TopBar(
                      filled: filled,
                      searching: searching,
                      onCancel: starting || _leaving ? null : _cancel,
                      leaving: _leaving,
                    ),
                    Padding(
                      padding: const EdgeInsets.fromLTRB(24, 4, 24, 0),
                      child: Align(
                        alignment: Alignment.centerRight,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              _headline(provider, searching),
                              style: GoogleFonts.cairo(
                                color: AppTheme.cream,
                                fontSize: 28,
                                fontWeight: FontWeight.w900,
                                height: 1.1,
                                letterSpacing: -0.5,
                              ),
                            ),
                            const SizedBox(height: 6),
                            _ProgressSegments(filled: filled),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Expanded(
                      child: Center(
                        child: _MatchmakingTable(
                          width: tableWidth,
                          pulse: _pulse,
                          filled: filled,
                          players: players,
                          bots: bots,
                          myId: myId,
                          searching: searching,
                        ),
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
                      child: _StatusPanel(
                        message: _status(provider),
                        searching: searching,
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
                      child: SizedBox(
                        width: double.infinity,
                        child: OutlinedButton.icon(
                          onPressed:
                              starting || _leaving ? null : _cancel,
                          icon: _leaving
                              ? SizedBox(
                                  width: 18,
                                  height: 18,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: AppTheme.steelBlue.withValues(
                                      alpha: 0.9,
                                    ),
                                  ),
                                )
                              : AppIcon(
                                  AppIcons.close,
                                  size: 18,
                                  color: AppTheme.steelBlue,
                                  strokeWidth: AppIconTokens.stroke,
                                ),
                          label: Text(
                            _leaving ? 'جاري الخروج...' : 'إلغاء البحث',
                            style: GoogleFonts.cairo(
                              fontWeight: FontWeight.w700,
                              fontSize: 15,
                            ),
                          ),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: AppTheme.cream,
                            side: BorderSide(
                              color: AppTheme.steelBlue.withValues(alpha: 0.35),
                            ),
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16),
                            ),
                          ),
                        ),
                      ),
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

class _TopBar extends StatelessWidget {
  final int filled;
  final bool searching;
  final VoidCallback? onCancel;
  final bool leaving;

  const _TopBar({
    required this.filled,
    required this.searching,
    this.onCancel,
    this.leaving = false,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(8, 4, 16, 0),
      child: Row(
        children: [
          IconButton(
            onPressed: leaving ? null : onCancel,
            icon: AppIcon(
              AppIcons.arrowForwardIos,
              size: 20,
              color: AppTheme.cream.withValues(alpha: 0.85),
              strokeWidth: AppIconTokens.stroke,
            ),
          ),
          Expanded(
            child: Text(
              'طابور أونلاين',
              textAlign: TextAlign.center,
              style: GoogleFonts.cairo(
                color: AppTheme.steelBlue,
                fontSize: 13,
                fontWeight: FontWeight.w700,
                letterSpacing: 0.4,
              ),
            ),
          ),
          _LiveBadge(searching: searching, filled: filled),
        ],
      ),
    );
  }
}

class _LiveBadge extends StatefulWidget {
  final bool searching;
  final int filled;

  const _LiveBadge({required this.searching, required this.filled});

  @override
  State<_LiveBadge> createState() => _LiveBadgeState();
}

class _LiveBadgeState extends State<_LiveBadge>
    with SingleTickerProviderStateMixin {
  late final AnimationController _dot;

  @override
  void initState() {
    super.initState();
    _dot = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1000),
    );
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _sync();
  }

  @override
  void didUpdateWidget(_LiveBadge oldWidget) {
    super.didUpdateWidget(oldWidget);
    _sync();
  }

  void _sync() {
    final reduceMotion =
        MediaQuery.maybeOf(context)?.disableAnimations ?? false;
    if (widget.searching && !reduceMotion) {
      if (!_dot.isAnimating) _dot.repeat(reverse: true);
    } else {
      _dot.stop();
      _dot.value = 1;
    }
  }

  @override
  void dispose() {
    _dot.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final accent = widget.searching ? AppTheme.gold : AppTheme.playerGreen;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: AppTheme.navyDark.withValues(alpha: 0.65),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: accent.withValues(alpha: 0.35)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          AnimatedBuilder(
            animation: _dot,
            builder: (_, __) {
              return Container(
                width: 7,
                height: 7,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: accent.withValues(
                    alpha: widget.searching
                        ? 0.4 + (_dot.value * 0.6)
                        : 1,
                  ),
                ),
              );
            },
          ),
          const SizedBox(width: 6),
          Text(
            '${widget.filled}/4',
            style: GoogleFonts.cairo(
              color: AppTheme.cream,
              fontSize: 12,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }
}

class _ProgressSegments extends StatelessWidget {
  final int filled;

  const _ProgressSegments({required this.filled});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: List.generate(4, (i) {
        final active = i < filled;
        return Expanded(
          child: Padding(
            padding: EdgeInsets.only(left: i == 0 ? 0 : 5),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 350),
              curve: Curves.easeOutCubic,
              height: 4,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(999),
                color: active
                    ? (filled >= 4 ? AppTheme.playerGreen : AppTheme.gold)
                    : AppTheme.steelBlue.withValues(alpha: 0.22),
                boxShadow: active
                    ? [
                        BoxShadow(
                          color: AppTheme.gold.withValues(alpha: 0.25),
                          blurRadius: 6,
                        ),
                      ]
                    : null,
              ),
            ),
          ),
        );
      }),
    );
  }
}

class _MatchmakingTable extends StatelessWidget {
  final double width;
  final AnimationController pulse;
  final int filled;
  final List<RoomPlayer> players;
  final int bots;
  final String myId;
  final bool searching;

  const _MatchmakingTable({
    required this.width,
    required this.pulse,
    required this.filled,
    required this.players,
    required this.bots,
    required this.myId,
    required this.searching,
  });

  @override
  Widget build(BuildContext context) {
    final height = width * 0.88;
    const seatW = 80.0;

    Widget slotForIndex(int index) {
      if (index < players.length) {
        final player = players[index];
        return MatchmakingPlayerSlot(
          playerName: player.playerName,
          seatIndex: index,
          isYou: player.playerId == myId,
        );
      }
      if (index < players.length + bots) {
        return MatchmakingPlayerSlot(isBot: true, seatIndex: index);
      }
      return MatchmakingPlayerSlot(isSearching: searching, seatIndex: index);
    }

    // Top, right, bottom, left — natural for RTL phone portrait.
    final seats = <Alignment>[
      Alignment.topCenter,
      Alignment.centerRight,
      Alignment.bottomCenter,
      Alignment.centerLeft,
    ];

    return SizedBox(
      width: width,
      height: height,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Center(
            child: _TableSurface(
              width: width * 0.78,
              height: height * 0.62,
              pulse: pulse,
              filled: filled,
              searching: searching,
            ),
          ),
          for (var i = 0; i < 4; i++)
            Align(
              alignment: seats[i],
              child: SizedBox(
                width: seatW,
                child: slotForIndex(i),
              ),
            ),
        ],
      ),
    );
  }
}

class _TableSurface extends StatelessWidget {
  final double width;
  final double height;
  final AnimationController pulse;
  final int filled;
  final bool searching;

  const _TableSurface({
    required this.width,
    required this.height,
    required this.pulse,
    required this.filled,
    required this.searching,
  });

  @override
  Widget build(BuildContext context) {
    final reduceMotion = MediaQuery.of(context).disableAnimations;

    return SizedBox(
      width: width + 24,
      height: height + 24,
      child: Stack(
        alignment: Alignment.center,
        children: [
          if (searching && !reduceMotion)
            AnimatedBuilder(
              animation: pulse,
              builder: (_, __) {
                return CustomPaint(
                  size: Size(width + 20, height + 20),
                  painter: _TablePulsePainter(t: pulse.value),
                );
              },
            ),
          CustomPaint(
            size: Size(width, height),
            painter: _FeltTablePainter(),
          ),
          PerformanceBlur(
            borderRadius: BorderRadius.circular(999),
            sigmaX: 10,
            sigmaY: 10,
            fallbackColor: AppTheme.deepNavy.withValues(alpha: 0.55),
            blurColor: AppTheme.deepNavy.withValues(alpha: 0.2),
            child: Container(
              width: 92,
              height: 92,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(
                  color: Colors.white.withValues(alpha: 0.12),
                ),
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  AppIcon(
                    searching ? AppIcons.wifiFind : AppIcons.checkCircle,
                    size: 26,
                    color: searching ? AppTheme.gold : AppTheme.playerGreen,
                    strokeWidth: AppIconTokens.stroke,
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '$filled',
                    style: GoogleFonts.cairo(
                      color: AppTheme.cream,
                      fontSize: 26,
                      fontWeight: FontWeight.w900,
                      height: 1,
                    ),
                  ),
                  Text(
                    'من 4',
                    style: GoogleFonts.cairo(
                      color: AppTheme.steelBlue,
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      height: 1,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _FeltTablePainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final rect = Rect.fromLTWH(0, 0, size.width, size.height);
    final r = RRect.fromRectAndRadius(rect, Radius.circular(size.height / 2));

    final rail = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [
          const Color(0xFF5C3D2E),
          const Color(0xFF3D2819),
          const Color(0xFF2A1810),
        ],
      ).createShader(rect);
    canvas.drawRRect(r, rail);

    final inset = RRect.fromRectAndRadius(
      rect.deflate(7),
      Radius.circular(size.height / 2 - 7),
    );
    final felt = Paint()
      ..shader = RadialGradient(
        center: const Alignment(0, -0.2),
        radius: 1.1,
        colors: [
          const Color(0xFF1B6B52),
          const Color(0xFF0F4A38),
          const Color(0xFF0A3228),
        ],
      ).createShader(rect.deflate(7));
    canvas.drawRRect(inset, felt);

    final line = Paint()
      ..color = Colors.white.withValues(alpha: 0.06)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.2;
    canvas.drawRRect(inset.deflate(18), line);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _TablePulsePainter extends CustomPainter {
  final double t;

  _TablePulsePainter({required this.t});

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final paint = Paint()
      ..color = AppTheme.gold.withValues(alpha: 0.08 * (1 - t))
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2;
    final rx = size.width / 2 * (0.85 + t * 0.12);
    final ry = size.height / 2 * (0.85 + t * 0.12);
    canvas.drawOval(
      Rect.fromCenter(center: center, width: rx * 2, height: ry * 2),
      paint,
    );
  }

  @override
  bool shouldRepaint(covariant _TablePulsePainter oldDelegate) =>
      oldDelegate.t != t;
}

class _StatusPanel extends StatelessWidget {
  final String message;
  final bool searching;

  const _StatusPanel({required this.message, required this.searching});

  @override
  Widget build(BuildContext context) {
    return PerformanceBlur(
      borderRadius: BorderRadius.circular(18),
      sigmaX: 12,
      sigmaY: 12,
      fallbackColor: AppTheme.navyDark.withValues(alpha: 0.88),
      blurColor: AppTheme.deepNavy.withValues(alpha: 0.25),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
            color: AppTheme.steelBlue.withValues(alpha: 0.2),
          ),
        ),
        child: Row(
          children: [
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: (searching ? AppTheme.gold : AppTheme.playerGreen)
                    .withValues(alpha: 0.14),
              ),
              child: Center(
                child: searching
                    ? SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: AppTheme.gold.withValues(alpha: 0.95),
                        ),
                      )
                    : AppIcon(
                        AppIcons.playCircle,
                        size: 18,
                        color: AppTheme.playerGreen,
                        strokeWidth: AppIconTokens.stroke,
                      ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                message,
                style: GoogleFonts.cairo(
                  color: AppTheme.cream.withValues(alpha: 0.95),
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  height: 1.4,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
