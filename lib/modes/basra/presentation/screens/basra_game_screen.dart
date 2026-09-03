// lib/modes/basra/presentation/screens/basra_game_screen.dart

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:estimation/core/icons/app_icons.dart';
import 'package:estimation/core/models/game_state.dart';
import 'package:estimation/core/utils/game_layout_metrics.dart';
import 'package:estimation/modes/basra/presentation/providers/basra_game_provider.dart';
import 'package:estimation/modes/basra/presentation/widgets/basra_player_hand.dart';
import 'package:estimation/modes/basra/presentation/widgets/basra_player_info.dart';
import 'package:estimation/modes/basra/presentation/widgets/basra_table_area.dart';
import 'package:estimation/modes/basra/presentation/widgets/basra_top_hud.dart';
import 'package:estimation/providers/game_provider.dart';
import 'package:estimation/services/online_play_gate.dart';
import 'package:estimation/screens/game_screen.dart' show HiddenCardFan;
import 'package:estimation/services/history_service.dart';
import 'package:estimation/services/ranking_service.dart';
import 'package:estimation/theme/app_theme.dart';
import 'package:estimation/widgets/hud/casino_table.dart';
import 'package:estimation/widgets/hud/game_background.dart';
import 'package:estimation/widgets/hud/reaction_picker_sheet.dart';
import 'package:estimation/widgets/level_up_dialog.dart';
import 'package:estimation/core/widgets/app_buttons.dart';
import 'package:estimation/core/widgets/leave_game_dialog.dart';
import 'package:estimation/modes/basra/presentation/widgets/basra_round_score_overlay.dart';

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

    final layout = GameLayoutMetrics.of(context);
    final tableSize = layout.trickAreaSize;

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
                    top: layout.topHudInset,
                    left: layout.topHudHorizontalInset,
                    right: layout.topHudHorizontalInset,
                    child: BasraTopHud(
                      game: game,
                      onExitTap: () => _confirmExit(context),
                    ),
                  ),
                  ..._buildOpponents(context, game),
                  Align(
                    alignment: layout.trickAreaAlignment,
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
                            ? 'بصرة 7 ديناري!'
                            : 'بصرة!',
                        style: AppFonts.cooper(
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
              BasraRoundScoreOverlay(
                game: game,
                isHost: context.watch<GameProvider>().isHost,
                onNextRound: game.advanceToNextRound,
              ),
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
    final layout = GameLayoutMetrics.of(context);
    final isPortrait = layout.isPortrait;
    final edge = layout.sideInset;
    final widgets = <Widget>[];

    for (var i = 1; i < seated.length; i++) {
      final player = seated[i];
      final isTurn = game.currentPlayer?.id == player.id;
      final isLeft = i == 1 && seated.length >= 3;
      final isRight = i == seated.length - 1 && seated.length >= 3;
      final info = BasraPlayerInfoWidget(
        player: player,
        isCurrentTurn: isTurn,
        compact: isLeft || isRight
            ? layout.sideOpponentCompact
            : layout.topOpponentCompact,
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
          top: layout.topOpponentTop,
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
          top: layout.topOpponentTop,
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
    final pad = GameLayoutMetrics.of(context).localPlayerInfoPadding;
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
        Padding(
          padding: EdgeInsets.symmetric(horizontal: pad.left),
          child: Row(
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
        ),
      ],
    );
  }

  Widget _buildReactions(BuildContext context, BasraGameProvider game) {
    if (game.activeReactions.isEmpty) return const SizedBox.shrink();
    return const SizedBox.shrink();
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
    final roomId = context.read<GameProvider>().currentRoom?.id;
    RankingService.instance
        .awardOnlineMatchXp(breakdown: breakdown, roomId: roomId)
        .then((result) {
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
    final layout = GameLayoutMetrics.of(context);
    final maxWidth = layout.isLargeTablet
        ? 520.0
        : (layout.isTablet ? 460.0 : 390.0);

    return Container(
      color: AppTheme.deepNavy.withValues(alpha: 0.88),
      alignment: Alignment.center,
      padding: EdgeInsets.all(layout.isTablet ? 32 : 24),
      child: Container(
        width: double.infinity,
        constraints: BoxConstraints(maxWidth: maxWidth),
        padding: EdgeInsets.all(layout.isTablet ? 28 : 24),
        decoration: AppTheme.dialogDecoration(accent: AppTheme.gold),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            AppIconWell(
              icon: AppIcons.emojiEvents,
              size: layout.isTablet ? 64 : 56,
              iconSize: layout.isTablet ? 30 : 26,
              color: AppTheme.gold,
              fill: AppTheme.gold.withValues(alpha: 0.14),
              borderColor: AppTheme.gold.withValues(alpha: 0.34),
            ),
            SizedBox(height: layout.isTablet ? 18 : 14),
            Text(
              'نهاية المباراة!',
              style: AppFonts.cooper(
                color: AppTheme.gold,
                fontSize: layout.isTablet ? 26 : 24,
                fontWeight: FontWeight.w900,
              ),
            ),
            SizedBox(height: layout.isTablet ? 10 : 8),
            Text(
              'الفائز: ${winner.name}',
              style: AppFonts.cooper(
                color: AppTheme.cream,
                fontSize: layout.isTablet ? 20 : 22,
                fontWeight: FontWeight.w900,
              ),
              textAlign: TextAlign.center,
            ),
            Text(
              '${winner.totalScore} نقطة',
              style: AppFonts.cooper(
                color: AppTheme.steelBlue,
                fontSize: layout.isTablet ? 17 : 16,
              ),
            ),
            if (_xp != null) ...[
              SizedBox(height: layout.isTablet ? 14 : 12),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                decoration: BoxDecoration(
                  color: AppTheme.deepNavy.withValues(alpha: 0.46),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                    color: AppTheme.gold.withValues(alpha: 0.32),
                  ),
                ),
                child: Text(
                  '+${_xp!.totalXp} XP',
                  style: AppFonts.cooper(
                    color: AppTheme.gold,
                    fontWeight: FontWeight.w900,
                    fontSize: layout.isTablet ? 16 : 15,
                  ),
                ),
              ),
            ],
            SizedBox(height: layout.isTablet ? 22 : 16),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: () {
                  context.read<BasraGameProvider>().reset();
                  context.read<GameProvider>().reset();
                  Navigator.of(context, rootNavigator: true)
                      .pushNamedAndRemoveUntil('/', (route) => false);
                },
                style: FilledButton.styleFrom(
                  backgroundColor: AppTheme.gold,
                  foregroundColor: AppTheme.navyDark,
                  padding: EdgeInsets.symmetric(vertical: layout.isTablet ? 14 : 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                  elevation: 0,
                ),
                child: Text(
                  'العودة للرئيسية',
                  style: AppFonts.cooper(
                    fontWeight: FontWeight.bold,
                    fontSize: layout.isTablet ? 16 : 15,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _confirmExit(BuildContext context) {
    LeaveGameDialog.show(
      context,
      onLeave: () async {
        final gate = context.read<OnlinePlayGate>();
        gate.stopPolling();
        gate.resumeAfterLeavingMatch();
        final gameProvider = context.read<GameProvider>();
        await gameProvider.temporarilyLeaveOngoingGame();
        if (!context.mounted) return;
        context.read<BasraGameProvider>().reset();
        Navigator.of(context, rootNavigator: true)
            .pushNamedAndRemoveUntil('/', (route) => false);
      },
    );
  }
}
