import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';

import '../../../../core/icons/app_icons.dart';
import '../../../../core/models/game_state.dart';
import '../../../../core/utils/home_layout_metrics.dart';
import '../../../../core/widgets/app_buttons.dart';
import '../../../../features/lobby/domain/models/room_player.dart';
import '../../../../providers/game_provider.dart';
import '../../../../theme/app_theme.dart';
import '../../domain/models/matchmaking_status.dart';
import '../widgets/bot_fill_dialog.dart';
import '../widgets/matchmaking_player_slot.dart';

class MatchmakingScreen extends StatefulWidget {
  const MatchmakingScreen({super.key});

  @override
  State<MatchmakingScreen> createState() => _MatchmakingScreenState();
}

class _MatchmakingScreenState extends State<MatchmakingScreen>
    with TickerProviderStateMixin {
  bool _dialogOpen = false;
  bool _confirmingCancel = false;
  bool _hasNavigatedToGame = false;
  bool _leaving = false;
  int? _dialogVersion;

  late final AnimationController _pulse;

  @override
  void initState() {
    super.initState();
    _pulse = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2200),
    );
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

  Future<void> _requestCancel() async {
    if (_leaving || _confirmingCancel) return;
    _confirmingCancel = true;

    final shouldLeave = await showDialog<bool>(
      context: context,
      barrierColor: Colors.black.withValues(alpha: 0.6),
      builder: (dialogContext) => AlertDialog(
        elevation: 0,
        backgroundColor: AppTheme.surface2,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(
            color: AppTheme.steelBlue.withValues(alpha: 0.18),
          ),
        ),
        titlePadding: const EdgeInsets.fromLTRB(24, 22, 24, 0),
        contentPadding: const EdgeInsets.fromLTRB(24, 8, 24, 18),
        actionsPadding: const EdgeInsets.fromLTRB(16, 0, 16, 14),
        title: Text(
          'مغادرة طابور الانتظار؟',
          style: GoogleFonts.cairo(
            color: AppTheme.cream,
            fontSize: 18,
            fontWeight: FontWeight.w700,
          ),
        ),
        content: Text(
          'سيتم إلغاء البحث عن لاعبين والعودة إلى الشاشة الرئيسية.',
          style: GoogleFonts.cairo(
            color: AppTheme.steelBlue,
            fontSize: 13,
            fontWeight: FontWeight.w400,
            height: 1.5,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: Text(
              'متابعة الانتظار',
              style: GoogleFonts.cairo(fontWeight: FontWeight.w600),
            ),
          ),
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            style: TextButton.styleFrom(foregroundColor: AppTheme.errorRed),
            child: Text(
              'مغادرة',
              style: GoogleFonts.cairo(fontWeight: FontWeight.w700),
            ),
          ),
        ],
      ),
    );
    _confirmingCancel = false;

    if (shouldLeave == true && mounted) await _cancel();
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
    final metrics = HomeLayoutMetrics.of(context);
    final usePhoneSideBySide = metrics.usePhoneSideBySideMenuLayout;
    final tableWidth = usePhoneSideBySide
        ? math.min(size.height * 1.05, size.width * 0.42).clamp(200.0, 320.0)
        : math.min(size.width - 48, 360.0);

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {
        if (!didPop && !starting) _requestCancel();
      },
      child: Scaffold(
        backgroundColor: AppTheme.deepNavy,
        body: SafeArea(
          child: usePhoneSideBySide
              ? _buildSideBySideBody(
                  provider: provider,
                  searching: searching,
                  starting: starting,
                  filled: filled,
                  players: players,
                  bots: bots,
                  myId: myId,
                  tableWidth: tableWidth,
                )
              : _buildStackedBody(
                  provider: provider,
                  searching: searching,
                  starting: starting,
                  filled: filled,
                  players: players,
                  bots: bots,
                  myId: myId,
                  tableWidth: tableWidth,
                ),
        ),
      ),
    );
  }

  Widget _buildStackedBody({
    required GameProvider provider,
    required bool searching,
    required bool starting,
    required int filled,
    required List<RoomPlayer> players,
    required int bots,
    required String myId,
    required double tableWidth,
  }) {
    return Column(
      children: [
        _TopBar(
          filled: filled,
          searching: searching,
          onCancel: starting || _leaving ? null : _requestCancel,
          leaving: _leaving,
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(24, 20, 24, 0),
          child: _MatchmakingHeader(
            headline: _headline(provider, searching),
            status: _status(provider),
            filled: filled,
            searching: searching,
          ),
        ),
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
          padding: const EdgeInsets.fromLTRB(24, 0, 24, 12),
          child: _CancelSearchButton(
            starting: starting,
            leaving: _leaving,
            onCancel: _requestCancel,
          ),
        ),
      ],
    );
  }

  Widget _buildSideBySideBody({
    required GameProvider provider,
    required bool searching,
    required bool starting,
    required int filled,
    required List<RoomPlayer> players,
    required int bots,
    required String myId,
    required double tableWidth,
  }) {
    final metrics = HomeLayoutMetrics.of(context);
    final headlineSize = metrics.isCompactLandscape ? 22.0 : 26.0;

    return Column(
      children: [
        _TopBar(
          filled: filled,
          searching: searching,
          onCancel: starting || _leaving ? null : _requestCancel,
          leaving: _leaving,
        ),
        Expanded(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(24, 8, 24, 12),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Expanded(
                  flex: 5,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      _MatchmakingHeader(
                        headline: _headline(provider, searching),
                        status: _status(provider),
                        filled: filled,
                        searching: searching,
                        headlineSize: headlineSize,
                      ),
                      const SizedBox(height: 24),
                      _CancelSearchButton(
                        starting: starting,
                        leaving: _leaving,
                        onCancel: _requestCancel,
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  flex: 6,
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
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _CancelSearchButton extends StatelessWidget {
  final bool starting;
  final bool leaving;
  final VoidCallback onCancel;

  const _CancelSearchButton({
    required this.starting,
    required this.leaving,
    required this.onCancel,
  });

  @override
  Widget build(BuildContext context) {
    return OutlinedButton.icon(
      onPressed: starting || leaving ? null : onCancel,
      icon: leaving
          ? SizedBox(
              width: 14,
              height: 14,
              child: CircularProgressIndicator(
                strokeWidth: 1.5,
                color: AppTheme.steelBlue.withValues(alpha: 0.9),
              ),
            )
          : AppIcon(
              AppIcons.close,
              size: 15,
              color: AppTheme.steelBlue,
              strokeWidth: AppIconTokens.strokeThin,
            ),
      label: Text(
        leaving ? 'جاري الخروج...' : 'إلغاء البحث',
        style: GoogleFonts.cairo(
          fontWeight: FontWeight.w600,
          fontSize: 13,
        ),
      ),
      style: OutlinedButton.styleFrom(
        foregroundColor: AppTheme.steelBlue,
        side: BorderSide(
          color: AppTheme.steelBlue.withValues(alpha: 0.24),
        ),
        minimumSize: const Size(0, 40),
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 9),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(10),
        ),
      ),
    );
  }
}

class _MatchmakingHeader extends StatelessWidget {
  final String headline;
  final String status;
  final int filled;
  final bool searching;
  final double headlineSize;

  const _MatchmakingHeader({
    required this.headline,
    required this.status,
    required this.filled,
    required this.searching,
    this.headlineSize = 28,
  });

  @override
  Widget build(BuildContext context) {
    final accent = searching ? AppTheme.gold : AppTheme.playerGreen;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          searching ? 'جاري البحث' : 'جاهزون',
          style: GoogleFonts.cairo(
            color: accent,
            fontSize: 11,
            fontWeight: FontWeight.w700,
            letterSpacing: 0.6,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          headline,
          style: GoogleFonts.cairo(
            color: AppTheme.cream,
            fontSize: headlineSize,
            fontWeight: FontWeight.w700,
            height: 1.15,
            letterSpacing: -0.35,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          status,
          style: GoogleFonts.cairo(
            color: AppTheme.steelBlue.withValues(alpha: 0.82),
            fontSize: 13,
            fontWeight: FontWeight.w400,
            height: 1.45,
          ),
        ),
        const SizedBox(height: 18),
        _ProgressSegments(filled: filled),
      ],
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
      padding: const EdgeInsets.fromLTRB(12, 8, 20, 0),
      child: Row(
        children: [
          IconButton(
            onPressed: leaving ? null : onCancel,
            tooltip: 'رجوع',
            style: IconButton.styleFrom(
              minimumSize: const Size(40, 40),
              padding: EdgeInsets.zero,
            ),
            icon: AppIcon(
              AppIcons.arrowForwardIos,
              size: 18,
              color: AppTheme.cream.withValues(alpha: 0.8),
              strokeWidth: AppIconTokens.strokeThin,
              matchTextDirection: false,
            ),
          ),
          Expanded(
            child: Text(
              'المطابقة',
              textAlign: TextAlign.center,
              style: GoogleFonts.cairo(
                color: AppTheme.cream.withValues(alpha: 0.72),
                fontSize: 12,
                fontWeight: FontWeight.w600,
                letterSpacing: 0.3,
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
      constraints: const BoxConstraints(minWidth: 40),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          AnimatedBuilder(
            animation: _dot,
            builder: (_, __) {
              return Container(
                width: 6,
                height: 6,
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
              color: AppTheme.cream.withValues(alpha: 0.82),
              fontSize: 11,
              fontWeight: FontWeight.w600,
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
              height: 2,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(999),
                color: active
                    ? (filled >= 4 ? AppTheme.playerGreen : AppTheme.gold)
                    : AppTheme.steelBlue.withValues(alpha: 0.16),
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
    final height = width * 0.82;
    const seatW = 72.0;

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
      width: width + 16,
      height: height + 16,
      child: Stack(
        alignment: Alignment.center,
        children: [
          if (searching && !reduceMotion)
            AnimatedBuilder(
              animation: pulse,
              builder: (_, __) {
                return CustomPaint(
                  size: Size(width + 12, height + 12),
                  painter: _TablePulsePainter(t: pulse.value),
                );
              },
            ),
          CustomPaint(
            size: Size(width, height),
            painter: _FeltTablePainter(),
          ),
          Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              AppIcon(
                searching ? AppIcons.wifiFind : AppIcons.checkCircle,
                size: 20,
                color: searching ? AppTheme.gold : AppTheme.playerGreen,
                strokeWidth: AppIconTokens.strokeThin,
              ),
              const SizedBox(height: 7),
              Text.rich(
                TextSpan(
                  children: [
                    TextSpan(
                      text: '$filled',
                      style: GoogleFonts.cairo(
                        color: AppTheme.cream,
                        fontSize: 26,
                        fontWeight: FontWeight.w700,
                        height: 1,
                      ),
                    ),
                    TextSpan(
                      text: ' / 4',
                      style: GoogleFonts.cairo(
                        color: AppTheme.steelBlue,
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
                textDirection: TextDirection.ltr,
              ),
            ],
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

    final rail = Paint()..color = AppTheme.steelBlue.withValues(alpha: 0.22);
    canvas.drawRRect(r, rail);

    final inset = RRect.fromRectAndRadius(
      rect.deflate(2),
      Radius.circular(size.height / 2 - 2),
    );
    final felt = Paint()..color = AppTheme.surface2;
    canvas.drawRRect(inset, felt);

    final line = Paint()
      ..color = AppTheme.steelBlue.withValues(alpha: 0.1)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1;
    canvas.drawRRect(inset.deflate(14), line);
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
      ..color = AppTheme.gold.withValues(alpha: 0.12 * (1 - t))
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1;
    final rx = size.width / 2 * (0.9 + t * 0.08);
    final ry = size.height / 2 * (0.9 + t * 0.08);
    canvas.drawOval(
      Rect.fromCenter(center: center, width: rx * 2, height: ry * 2),
      paint,
    );
  }

  @override
  bool shouldRepaint(covariant _TablePulsePainter oldDelegate) =>
      oldDelegate.t != t;
}
