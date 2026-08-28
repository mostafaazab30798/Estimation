// lib/modes/basra/presentation/screens/basra_game_screen.dart

import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';

import 'package:estimation/core/icons/app_icons.dart';
import 'package:estimation/core/models/game_state.dart';
import 'package:estimation/modes/basra/domain/basra_constants.dart';
import 'package:estimation/modes/basra/presentation/providers/basra_game_provider.dart';
import 'package:estimation/modes/basra/presentation/widgets/basra_player_hand.dart';
import 'package:estimation/modes/basra/presentation/widgets/basra_player_info.dart';
import 'package:estimation/modes/basra/presentation/widgets/basra_table_area.dart';
import 'package:estimation/modes/basra/presentation/widgets/basra_top_hud.dart';
import 'package:estimation/providers/game_provider.dart';
import 'package:estimation/screens/game_screen.dart' show HiddenCardFan;
import 'package:estimation/services/history_service.dart';
import 'package:estimation/services/ranking_service.dart';
import 'package:estimation/theme/app_theme.dart';
import 'package:estimation/widgets/hud/casino_table.dart';
import 'package:estimation/widgets/hud/game_background.dart';
import 'package:estimation/widgets/hud/reaction_picker_sheet.dart';
import 'package:estimation/widgets/level_up_dialog.dart';

class BasraGameScreen extends StatefulWidget {
  const BasraGameScreen({super.key});

  @override
  State<BasraGameScreen> createState() => _BasraGameScreenState();
}

class _BasraGameScreenState extends State<BasraGameScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _basraFlash;
  String? _lastTurnKey;
  bool _hasSavedMatch = false;
  bool _delayingEndOverlay = false;
  int? _delayedEndRound;
  XpRewardBreakdown? _xp;

  @override
  void initState() {
    super.initState();
    _basraFlash = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    );
  }

  @override
  void dispose() {
    _basraFlash.dispose();
    super.dispose();
  }

  void _maybeFlashBasra(BasraGameProvider game) {
    final turn = game.lastTurnResult;
    if (turn == null || !turn.wasBasra) return;
    final key =
        '${turn.playerId}-${turn.playedCard.id}-${turn.tableBefore.length}';
    if (key == _lastTurnKey) return;
    _lastTurnKey = key;
    _basraFlash.forward(from: 0);
  }

  void _maybeDelayEndOverlay(BasraGameProvider game) {
    final ending = game.phase == BasraPhase.roundFinished ||
        game.phase == BasraPhase.finished;
    if (!ending) {
      _delayingEndOverlay = false;
      _delayedEndRound = null;
      return;
    }
    if (_delayedEndRound == game.currentRoundNumber) return;
    _delayedEndRound = game.currentRoundNumber;
    _delayingEndOverlay = true;
    Future<void>.delayed(const Duration(milliseconds: 1400), () {
      if (!mounted) return;
      setState(() => _delayingEndOverlay = false);
    });
  }

  @override
  Widget build(BuildContext context) {
    final game = context.watch<BasraGameProvider>();
    _maybeFlashBasra(game);
    _maybeDelayEndOverlay(game);

    final media = MediaQuery.of(context);
    final isPortrait = media.orientation == Orientation.portrait;
    final minDim = math.min(media.size.width, media.size.height);
    final tableSize = isPortrait
        ? (minDim * 0.52).clamp(170.0, 250.0)
        : (media.size.height * 0.44).clamp(160.0, 290.0);

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _confirmExit(context);
      },
      child: Scaffold(
        backgroundColor: Colors.black,
        body: Stack(
          children: [
            const Positioned.fill(
              child: RepaintBoundary(
                child: GameBackground(phase: GamePhase.trickTaking),
              ),
            ),
            const Positioned.fill(
              child: RepaintBoundary(
                child: CustomPaint(
                  painter: CasinoTablePainter(glowColor: AppTheme.phasePlay),
                ),
              ),
            ),
            SafeArea(
              child: Stack(
                children: [
                  Positioned(
                    top: 10,
                    left: 10,
                    right: 10,
                    child: BasraTopHud(
                      game: game,
                      onExitTap: () => _confirmExit(context),
                    ),
                  ),
                  ..._buildOpponents(context, game),
                  Align(
                    alignment: Alignment(0, isPortrait ? -0.32 : -0.25),
                    child: SizedBox(
                      width: tableSize,
                      height: tableSize,
                      child: RepaintBoundary(
                        child: BasraTableArea(game: game),
                      ),
                    ),
                  ),
                  _buildReactions(context, game),
                  Positioned(
                    bottom: 4,
                    left: 0,
                    right: 0,
                    child: _buildLocal(context, game),
                  ),
                ],
              ),
            ),
            AnimatedBuilder(
              animation: _basraFlash,
              builder: (context, _) {
                if (_basraFlash.value == 0 && !_basraFlash.isAnimating) {
                  return const SizedBox.shrink();
                }
                return FadeTransition(
                  opacity: Tween<double>(begin: 1, end: 0).animate(
                    CurvedAnimation(parent: _basraFlash, curve: Curves.easeOut),
                  ),
                  child: IgnorePointer(
                    child: Center(
                      child: Text(
                        game.lastTurnResult?.basraType ==
                                BasraType.sevenOfDiamonds
                            ? 'باصرة 7 ديناري!'
                            : 'باصرة!',
                        style: GoogleFonts.cairo(
                          color: AppTheme.gold,
                          fontSize: 42,
                          fontWeight: FontWeight.w900,
                          shadows: const [
                            Shadow(color: Colors.black, blurRadius: 18),
                          ],
                        ),
                      ),
                    ),
                  ),
                );
              },
            ),
            if (game.phase == BasraPhase.roundFinished && !_delayingEndOverlay)
              _buildRoundOverlay(context, game),
            if (game.phase == BasraPhase.finished &&
                game.matchWinner != null &&
                !_delayingEndOverlay)
              _buildMatchOverlay(context, game),
          ],
        ),
      ),
    );
  }

  List<Widget> _buildOpponents(BuildContext context, BasraGameProvider game) {
    final seated = game.seatedPlayers;
    if (seated.length < 2) return const [];
    final media = MediaQuery.of(context);
    final isPortrait = media.orientation == Orientation.portrait;
    final edge = isPortrait ? 4.0 : 14.0;
    final widgets = <Widget>[];

    for (var i = 1; i < seated.length; i++) {
      final player = seated[i];
      final isTurn = game.currentPlayer?.id == player.id;
      final isLeft = i == 1 && seated.length >= 3;
      final isRight = i == seated.length - 1 && seated.length >= 3;
      final info = BasraPlayerInfoWidget(
        player: player,
        isCurrentTurn: isTurn,
        compact: true,
      );
      final fan = HiddenCardFan(
        count: player.hand.length,
        isLeft: isLeft,
        isRight: isRight,
      );

      final Widget child;
      if (seated.length == 2 || i == 2) {
        child = Row(
          mainAxisSize: MainAxisSize.min,
          children: [info, const SizedBox(width: 6), fan],
        );
      } else {
        child = Column(
          mainAxisSize: MainAxisSize.min,
          children: [info, const SizedBox(height: 4), fan],
        );
      }

      if (seated.length == 2) {
        widgets.add(Positioned(
          top: isPortrait ? 128 : 64,
          left: 0,
          right: 0,
          child: Align(alignment: Alignment.topCenter, child: child),
        ));
      } else if (seated.length == 3) {
        widgets.add(i == 1
            ? Positioned(
                left: edge,
                top: 0,
                bottom: 0,
                child: Align(
                    alignment: isPortrait
                        ? const Alignment(-1, 0.15)
                        : Alignment.centerLeft,
                    child: child),
              )
            : Positioned(
                right: edge,
                top: 0,
                bottom: 0,
                child: Align(
                    alignment: isPortrait
                        ? const Alignment(1, 0.15)
                        : Alignment.centerRight,
                    child: child),
              ));
      } else if (i == 1) {
        widgets.add(Positioned(
          left: edge,
          top: 0,
          bottom: 0,
          child: Align(
              alignment:
                  isPortrait ? const Alignment(-1, 0.15) : Alignment.centerLeft,
              child: child),
        ));
      } else if (i == 2) {
        widgets.add(Positioned(
          top: isPortrait ? 128 : 64,
          left: 0,
          right: 0,
          child: Align(alignment: Alignment.topCenter, child: child),
        ));
      } else {
        widgets.add(Positioned(
          right: edge,
          top: 0,
          bottom: 0,
          child: Align(
              alignment:
                  isPortrait ? const Alignment(1, 0.15) : Alignment.centerRight,
              child: child),
        ));
      }
    }
    return widgets;
  }

  Widget _buildLocal(BuildContext context, BasraGameProvider game) {
    final local = game.localPlayer;
    if (local == null) return const SizedBox.shrink();
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        BasraPlayerHand(
          hand: local.hand,
          isMyTurn: game.isLocalPlayerTurn,
          phase: game.phase,
          onPlayCard: (card) => game.playCard(local.id, card),
        ),
        const SizedBox(height: 4),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            BasraPlayerInfoWidget(
              player: local,
              isCurrentTurn: game.isLocalPlayerTurn,
              isMe: true,
            ),
            const SizedBox(width: 8),
            IconButton(
              onPressed: () => ReactionPickerSheet.show(
                context,
                onSelectReaction: (emoji, [text]) =>
                    game.sendReaction(emoji, text),
              ),
              icon: const AppIcon(AppIcons.chatBubbleOutline,
                  color: AppTheme.gold, size: 22),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildReactions(BuildContext context, BasraGameProvider game) {
    if (game.activeReactions.isEmpty) return const SizedBox.shrink();
    return const SizedBox.shrink();
  }

  Widget _buildRoundOverlay(BuildContext context, BasraGameProvider game) {
    return Container(
      color: Colors.black87,
      alignment: Alignment.center,
      padding: const EdgeInsets.all(24),
      child: Container(
        padding: const EdgeInsets.all(22),
        decoration: BoxDecoration(
          color: const Color(0xF01D3348),
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: AppTheme.gold.withValues(alpha: 0.5)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('نهاية الجولة ${game.currentRoundNumber}',
                style: GoogleFonts.cairo(
                    color: Colors.white,
                    fontSize: 20,
                    fontWeight: FontWeight.w900)),
            if (game.lastRoundWasTwentySixTie)
              Text('تعادل 26-26 — ترحيل $kBasraMajorityPoints نقطة',
                  style: GoogleFonts.cairo(
                      color: AppTheme.gold, fontWeight: FontWeight.bold)),
            const SizedBox(height: 12),
            ...game.players.map((p) {
              final score = game.lastRoundScores
                  .where((s) => s.playerId == p.id)
                  .firstOrNull;
              return Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(p.name,
                          style: GoogleFonts.cairo(
                              color: Colors.white,
                              fontWeight: FontWeight.bold)),
                    ),
                    Text(
                      '${score?.capturedCount ?? p.capturedCards.length} ورقة • +${score?.roundScore ?? p.roundScore} → ${p.totalScore}',
                      style: GoogleFonts.cairo(
                          color: AppTheme.gold,
                          fontWeight: FontWeight.w800,
                          fontSize: 12),
                    ),
                  ],
                ),
              );
            }),
            const SizedBox(height: 16),
            if (context.watch<GameProvider>().isHost)
              ElevatedButton(
                onPressed: game.advanceToNextRound,
                child: Text('الجولة التالية',
                    style: GoogleFonts.cairo(fontWeight: FontWeight.bold)),
              ),
          ],
        ),
      ),
    );
  }

  void _award(BasraGameProvider game) {
    if (_hasSavedMatch) return;
    _hasSavedMatch = true;
    final winner = game.matchWinner;
    final local = game.localPlayer;
    if (winner == null || local == null) return;
    final won = winner.id == local.id;
    final breakdown = RankingService.instance.calculateBasraReward(
      won: won,
      roundsPlayed: game.currentRoundNumber,
    );
    setState(() => _xp = breakdown);
    HistoryService.saveMatchRecordDirect(MatchRecord(
      date: DateTime.now().toIso8601String(),
      winnerName: winner.name,
      winnerScore: winner.totalScore,
      gameType: 'basra',
      players: game.players
          .map((p) => PlayerResult(
                name: p.name,
                score: p.totalScore,
                rankTitle:
                    p.id == winner.id ? 'الفائز 👑' : '${p.totalScore} نقطة',
              ))
          .toList(),
    ));
    RankingService.instance.processMatchReward(breakdown).then((result) {
      if (mounted && result != null && result.didLevelUp) {
        LevelUpDialog.show(
          context,
          oldLevel: result.oldLevel,
          newLevel: result.newLevel,
          oldTier: result.oldTier,
          newTier: result.newTier,
        );
      }
    });
  }

  Widget _buildMatchOverlay(BuildContext context, BasraGameProvider game) {
    final winner = game.matchWinner!;
    _award(game);
    return Container(
      color: Colors.black.withValues(alpha: 0.92),
      alignment: Alignment.center,
      padding: const EdgeInsets.all(24),
      child: Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: const Color(0xF01D3348),
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: AppTheme.gold.withValues(alpha: 0.6)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('🏆', style: TextStyle(fontSize: 48)),
            Text('الفائز: ${winner.name}',
                style: GoogleFonts.cairo(
                    color: AppTheme.gold,
                    fontSize: 22,
                    fontWeight: FontWeight.w900)),
            Text('${winner.totalScore} نقطة',
                style: GoogleFonts.cairo(color: Colors.white, fontSize: 16)),
            if (_xp != null)
              Text(
                '+${_xp!.totalXp} XP',
                style: GoogleFonts.cairo(
                    color: AppTheme.gold, fontWeight: FontWeight.w900),
              ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: () {
                context.read<BasraGameProvider>().reset();
                context.read<GameProvider>().reset();
                Navigator.of(context, rootNavigator: true)
                    .pushNamedAndRemoveUntil('/', (route) => false);
              },
              child: Text('العودة للرئيسية',
                  style: GoogleFonts.cairo(fontWeight: FontWeight.bold)),
            ),
          ],
        ),
      ),
    );
  }

  void _confirmExit(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1D3348),
        title: Text('مغادرة اللعبة',
            style: GoogleFonts.cairo(
                color: Colors.white, fontWeight: FontWeight.bold)),
        content: Text(
          'هل تريد مغادرة غرفة الباصرة؟',
          style: GoogleFonts.cairo(color: Colors.white70),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx), child: const Text('إلغاء')),
          TextButton(
            onPressed: () {
              context.read<BasraGameProvider>().reset();
              context.read<GameProvider>().reset();
              Navigator.of(context, rootNavigator: true)
                  .pushNamedAndRemoveUntil('/', (route) => false);
            },
            child: const Text('مغادرة'),
          ),
        ],
      ),
    );
  }
}
