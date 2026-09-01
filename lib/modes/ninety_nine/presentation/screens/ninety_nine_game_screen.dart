// lib/modes/ninety_nine/presentation/screens/ninety_nine_game_screen.dart

import 'dart:math';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';

// Removed unused import
import 'package:estimation/core/models/game_state.dart';
import 'package:estimation/core/utils/game_layout_metrics.dart';
import 'package:estimation/theme/app_theme.dart';
import 'package:estimation/widgets/playing_card_widget.dart';
import 'package:estimation/widgets/hud/game_background.dart';
import 'package:estimation/widgets/hud/casino_table.dart';
import 'package:estimation/screens/game_screen.dart' show HiddenCardFan;

import 'package:estimation/core/widgets/leave_game_dialog.dart';
import 'package:estimation/providers/game_provider.dart';
import 'package:estimation/modes/ninety_nine/presentation/providers/ninety_nine_game_provider.dart';
import 'package:estimation/modes/ninety_nine/presentation/widgets/ninety_nine_top_hud.dart';
import 'package:estimation/modes/ninety_nine/presentation/widgets/ninety_nine_player_info.dart';
import 'package:estimation/modes/ninety_nine/presentation/widgets/ninety_nine_player_hand.dart';
import 'package:estimation/services/ranking_service.dart';
import 'package:estimation/services/history_service.dart';
import 'package:estimation/services/auth_service.dart';
import 'package:estimation/widgets/level_up_dialog.dart';
import 'package:estimation/widgets/rank_tier_badge.dart';
import 'package:estimation/widgets/hud/reaction_bubble_widget.dart';
import 'package:estimation/widgets/hud/reaction_picker_sheet.dart';
import 'package:estimation/core/icons/app_icons.dart';
import 'package:estimation/core/widgets/app_buttons.dart';

class NinetyNineGameScreen extends StatefulWidget {
  const NinetyNineGameScreen({super.key});

  @override
  State<NinetyNineGameScreen> createState() => _NinetyNineGameScreenState();
}

class _NinetyNineGameScreenState extends State<NinetyNineGameScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _pulseController;
  late Animation<double> _pulseScale;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1000),
    )..repeat(reverse: true);

    _pulseScale = Tween<double>(begin: 0.96, end: 1.04).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  GamePhase _mapNinetyNinePhaseToGamePhase(NinetyNinePhase phase) {
    switch (phase) {
      case NinetyNinePhase.waiting:
        return GamePhase.voidCheck;
      case NinetyNinePhase.playing:
        return GamePhase.trickTaking;
      case NinetyNinePhase.roundFinished:
      case NinetyNinePhase.finished:
        return GamePhase.scoring;
    }
  }

  @override
  Widget build(BuildContext context) {
    final game = context.watch<NinetyNineGameProvider>();
    final isRoundFinished = game.phase == NinetyNinePhase.roundFinished;
    final isMatchFinished = game.phase == NinetyNinePhase.finished;

    final gamePhase = _mapNinetyNinePhaseToGamePhase(game.phase);
    final tableGlowColor = gamePhase == GamePhase.trickTaking
        ? AppTheme.phasePlay
        : AppTheme.deepNavy;
    final layout = GameLayoutMetrics.of(context);

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {
        if (didPop) return;
        _confirmExit(context);
      },
      child: Scaffold(
        backgroundColor: Colors.black,
        body: Stack(
          children: [
            // ── 1. Animated layered background ──────────────────────
            Positioned.fill(
              child: RepaintBoundary(
                child: GameBackground(phase: gamePhase),
              ),
            ),

            // ── 2. Casino table ──────────────────────────────────────
            Positioned.fill(
              child: RepaintBoundary(
                child: CustomPaint(
                  painter: CasinoTablePainter(glowColor: tableGlowColor),
                ),
              ),
            ),

            // ── 3. SafeArea content ──────────────────────────────────
            SafeArea(
              child: Stack(
                children: [
                  // ── Top HUD ──────────────────────────────────────
                  Positioned(
                    top: layout.topHudInset,
                    left: layout.topHudHorizontalInset,
                    right: layout.topHudHorizontalInset,
                    child: NinetyNineTopHud(
                      game: game,
                      onExitTap: () => _confirmExit(context),
                    ),
                  ),

                  // ── Opponents Positioning (Indices 1 to N-1) ─────
                  ..._buildOpponents(context, game),

                  // ── Center Area (Messy Pile & Ground Total) ──────
                  Align(
                    alignment: const Alignment(0, -0.15),
                    child: _buildCenterHud(game),
                  ),

                  // ── Reactions Overlay ────────────────────────────
                  _buildReactionsOverlay(context, game),

                  // ── Local Player ─────────────────────────────────
                  Positioned(
                    bottom: layout.isPortrait ? 10 : 8,
                    left: 10,
                    right: 10,
                    child: _buildLocalPlayerHand(context, game),
                  ),
                ],
              ),
            ),

            // ── Round Outcome Modal Overlay ────────────────────────────────
            if (isRoundFinished && game.roundLoser != null)
              _buildRoundOutcomeOverlay(context, game),

            // ── Match Outcome Celebration Overlay ─────────────────────────
            if (isMatchFinished && game.matchWinner != null)
              _buildMatchOutcomeOverlay(context, game),
          ],
        ),
      ),
    );
  }

  // ── Dynamic Opponents Positioning ───────────────────────────────────────
  List<Widget> _buildOpponents(
      BuildContext context, NinetyNineGameProvider game) {
    final players = game.players;
    if (players.length < 2) return [];

    final total = players.length;
    final List<Widget> widgets = [];

    final layout = GameLayoutMetrics.of(context);
    final edgePadding = layout.sideInset;

    // Map relative indices (1 to total - 1) to table anchor positions
    for (int i = 1; i < total; i++) {
      final player = players[i];
      final isTurn = game.currentPlayerIndex == i;
      final losses = game.getPlayerLosses(player.id);

      Positioned positionedWidget;

      if (total == 2) {
        positionedWidget = Positioned(
          top: layout.topOpponentTop,
          left: 0,
          right: 0,
          child: Align(
            alignment: Alignment.topCenter,
            child: _buildOpponentWidget(
              context,
              game,
              player,
              isTurn,
              losses,
              compact: layout.topOpponentCompact,
            ),
          ),
        );
      } else if (total == 3) {
        if (i == 1) {
          positionedWidget = Positioned(
            left: edgePadding,
            top: 0,
            bottom: 0,
            child: Align(
              alignment: const Alignment(-1.0, 0.0),
              child: _buildOpponentWidget(
                context,
                game,
                player,
                isTurn,
                losses,
                compact: layout.sideOpponentCompact,
                isLeft: true,
              ),
            ),
          );
        } else {
          positionedWidget = Positioned(
            right: edgePadding,
            top: 0,
            bottom: 0,
            child: Align(
              alignment: const Alignment(1.0, 0.0),
              child: _buildOpponentWidget(
                context,
                game,
                player,
                isTurn,
                losses,
                compact: layout.sideOpponentCompact,
                isRight: true,
              ),
            ),
          );
        }
      } else if (total == 4) {
        if (i == 1) {
          positionedWidget = Positioned(
            left: edgePadding,
            top: 0,
            bottom: 0,
            child: Align(
              alignment: const Alignment(-1.0, 0.15),
              child: _buildOpponentWidget(
                context,
                game,
                player,
                isTurn,
                losses,
                compact: layout.sideOpponentCompact,
                isLeft: true,
              ),
            ),
          );
        } else if (i == 2) {
          positionedWidget = Positioned(
            top: layout.topOpponentTop,
            left: 0,
            right: 0,
            child: Align(
              alignment: Alignment.topCenter,
              child: _buildOpponentWidget(
                context,
                game,
                player,
                isTurn,
                losses,
                compact: layout.topOpponentCompact,
              ),
            ),
          );
        } else {
          positionedWidget = Positioned(
            right: edgePadding,
            top: 0,
            bottom: 0,
            child: Align(
              alignment: const Alignment(1.0, 0.15),
              child: _buildOpponentWidget(
                context,
                game,
                player,
                isTurn,
                losses,
                compact: layout.sideOpponentCompact,
                isRight: true,
              ),
            ),
          );
        }
      } else {
        // For 5, 6, 7 players, position them dynamically along an ellipse
        final int opponentCount = total - 1;
        final double angleStep = pi / (opponentCount + 1);
        final double angle = pi + (i * angleStep);

        final ellipse = layout.ellipseLayout();

        // Offset center up a bit
        final centerY = ellipse.centerY;
        final centerX = layout.width / 2;

        // Use a custom cubic polynomial to push the middle players outwards (near x=0.5)
        // without pushing the bottom players outwards (near x=0.866).
        // f(x) = 1.45x - 0.6x^3
        double origX = cos(angle);
        double normalizedX = 1.45 * origX - 0.6 * pow(origX, 3);

        // Use a power curve to evenly distribute the vertical spacing
        // (angles near the top of the ellipse naturally cluster vertically; this pushes them down)
        double origY = sin(angle);
        double normalizedY = origY.sign * pow(origY.abs(), 2.5);

        final double dx = centerX + ellipse.radiusX * normalizedX;
        final double dy = centerY + ellipse.radiusY * normalizedY;
        final isLeftSide = cos(angle) < -0.3;
        final isRightSide = cos(angle) > 0.3;

        positionedWidget = Positioned(
          left: dx - ellipse.widgetWidth / 2,
          width: ellipse.widgetWidth,
          top: dy,
          child: Align(
            alignment: Alignment.topCenter,
            child: _buildOpponentWidget(
              context,
              game,
              player,
              isTurn,
              losses,
              compact: isLeftSide || isRightSide
                  ? layout.sideOpponentCompact
                  : layout.topOpponentCompact,
              isLeft: isLeftSide,
              isRight: isRightSide,
            ),
          ),
        );
      }

      widgets.add(positionedWidget);
    }

    return widgets;
  }

  Widget _buildOpponentWidget(BuildContext context, NinetyNineGameProvider game,
      NinetyNinePlayer player, bool isTurn, int losses,
      {bool compact = true, bool isLeft = false, bool isRight = false}) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        NinetyNinePlayerInfoWidget(
          player: player,
          losses: losses,
          phase: game.phase,
          isCurrentTurn: isTurn,
          compact: compact,
          isRight: isRight,
        ),
        const SizedBox(height: 8),
        HiddenCardFan(
          count: player.hand.length,
          isLeft: isLeft,
          isRight: isRight,
        ),
        const SizedBox(height: 10),
        if (isRight ||
            (game.players.length == 2 && player == game.players.last))
          _buildReactionTriggerButton(context, game)
        else if (isLeft)
          Visibility(
            maintainSize: true,
            maintainAnimation: true,
            maintainState: true,
            visible: false,
            child: _buildReactionTriggerButton(context, game),
          ),
      ],
    );
  }

  // ── Central Play Area & Messy Card Stack ────────────────────────────────
  Widget _buildCenterHud(NinetyNineGameProvider game) {
    final moves = game.moveHistory;
    final visibleMoves =
        moves.length > 10 ? moves.sublist(moves.length - 10) : moves;

    final total = game.groundTotal;
    Color totalColor;
    if (total >= 91) {
      totalColor = const Color(0xFFEF4444);
    } else if (total >= 75) {
      totalColor = const Color(0xFFF59E0B);
    } else {
      totalColor = const Color(0xFF10B981);
    }

    final layout = GameLayoutMetrics.of(context);
    final pile = layout.centerPileSize;

    return FittedBox(
      fit: BoxFit.scaleDown,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // 1. Messy Card Pile Container
          SizedBox(
            width: pile.width,
            height: pile.height,
            child: Stack(
              alignment: Alignment.center,
              clipBehavior: Clip.none,
              children: [
                if (visibleMoves.isEmpty)
                  Container(
                    width: pile.cardWidth,
                    height: pile.cardWidth / playingCardAspectRatio,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(9),
                      border: Border.all(
                        color: Colors.white.withValues(alpha: 0.18),
                        width: 1.5,
                      ),
                      color: Colors.black.withValues(alpha: 0.25),
                    ),
                    child: Center(
                      child: Text(
                        'الأرض 🎴',
                        style: GoogleFonts.cairo(
                          color: Colors.white38,
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                for (int i = 0; i < visibleMoves.length; i++) ...[
                  Builder(
                    builder: (context) {
                      final move = visibleMoves[i];
                      final isTopCard = i == visibleMoves.length - 1;

                      final angleRad = (sin(i * 3.7 + 1.2) * 22.0) * pi / 180.0;
                      final dx = cos(i * 2.3 + 0.8) * 12.0;
                      final dy = sin(i * 1.9 + 2.1) * 9.0;

                      return Transform.translate(
                        offset: Offset(dx, dy),
                        child: Transform.rotate(
                          angle: angleRad,
                          child: Container(
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(9),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withValues(alpha: 0.5),
                                  blurRadius: isTopCard ? 12 : 6,
                                  offset: Offset(
                                      isTopCard ? 2 : 1, isTopCard ? 4 : 2),
                                ),
                                if (isTopCard)
                                  BoxShadow(
                                    color: totalColor.withValues(alpha: 0.7),
                                    blurRadius: 16,
                                    spreadRadius: 1.5,
                                  ),
                              ],
                            ),
                            child: PlayingCardWidget(
                              card: move.card,
                              width: pile.cardWidth - 2,
                              playable: false,
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                ],
              ],
            ),
          ),

          const SizedBox(height: 16),

          // 2. Floating Ground Total Glass Badge
          AnimatedBuilder(
            animation: _pulseController,
            builder: (context, child) {
              final scale = total >= 90 ? _pulseScale.value : 1.0;
              return Transform.scale(
                scale: scale,
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.6),
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(
                      color: totalColor,
                      width: total >= 90 ? 2.0 : 1.2,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: totalColor.withValues(
                            alpha: total >= 90 ? 0.4 : 0.15),
                        blurRadius: total >= 90 ? 20 : 10,
                        spreadRadius: total >= 90 ? 2 : 1,
                      ),
                    ],
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            'مجموع الأرض: ',
                            style: GoogleFonts.cairo(
                              color: Colors.white70,
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          Text(
                            '$total',
                            style: GoogleFonts.cairo(
                              color: totalColor,
                              fontSize: 22,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                          Text(
                            ' / 99',
                            style: GoogleFonts.cairo(
                              color: Colors.white54,
                              fontSize: 13,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                      if (game.lastPlayedCard != null)
                        Text(
                          '${game.lastPlayedPlayerName ?? ''}: ${game.lastPlayedCard!.rank.label}',
                          style: GoogleFonts.cairo(
                            color: AppTheme.goldLight,
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                    ],
                  ),
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  // ── Local Player Controls & Hand Bar ────────────────────────────────────
  Widget _buildLocalPlayerHand(
    BuildContext context,
    NinetyNineGameProvider game,
  ) {
    final localP = game.localPlayer;
    if (localP == null) return const SizedBox.shrink();

    final isMyTurn = game.isLocalPlayerTurn;
    final hand = localP.hand;
    final losses = game.getPlayerLosses(localP.id);
    final layout = GameLayoutMetrics.of(context);
    final isPortrait = layout.isPortrait;

    final playerInfoCard = NinetyNinePlayerInfoWidget(
      player: localP,
      losses: losses,
      phase: game.phase,
      isCurrentTurn: isMyTurn,
      isMe: true,
      compact: layout.localPlayerCompact,
    );

    final handWidget = NinetyNinePlayerHand(
      hand: hand,
      isMyTurn: isMyTurn,
      phase: game.phase,
      groundTotal: game.groundTotal,
      onPlayCard: (card) {
        game.playCard(localP.id, card);
      },
    );

    if (isPortrait) {
      return Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          handWidget,
          const SizedBox(height: 10),
          Padding(
            padding: const EdgeInsets.only(bottom: 6),
            child: playerInfoCard,
          ),
        ],
      );
    }

    return Row(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(4, 0, 12, 8),
          child: playerInfoCard,
        ),
        Expanded(child: handWidget),
      ],
    );
  }

  // ── Round Outcome Modal Overlay ─────────────────────────────────────────
  Widget _buildRoundOutcomeOverlay(
    BuildContext context,
    NinetyNineGameProvider game,
  ) {
    final loser = game.roundLoser!;
    return Container(
      color: Colors.black87,
      alignment: Alignment.center,
      padding: const EdgeInsets.all(24),
      child: Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [Color(0xCC2A4560), Color(0xCC1D3348)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(24),
          border: Border.all(
              color: const Color(0xFFEF4444).withValues(alpha: 0.6),
              width: 1.5),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFFEF4444).withValues(alpha: 0.2),
              blurRadius: 30,
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('🛑', style: TextStyle(fontSize: 48)),
            const SizedBox(height: 12),
            Text(
              'الجولة ${game.currentRoundNumber} انتهت!',
              style: GoogleFonts.cairo(
                color: Colors.white,
                fontSize: 22,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'خسر الجولة: ${loser.name} 💔',
              style: GoogleFonts.cairo(
                color: const Color(0xFFEF4444),
                fontSize: 17,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
            const Divider(color: Colors.white24),
            const SizedBox(height: 8),

            // Scoreboard table
            Text(
              'جدول الخسائر في المباراة (الخاسر في 5 جولات يستبعد):',
              style: GoogleFonts.cairo(color: Colors.white70, fontSize: 12),
            ),
            const SizedBox(height: 12),
            Column(
              children: game.players.map((p) {
                final losses = game.getPlayerLosses(p.id);
                return Padding(
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        p.name,
                        style: GoogleFonts.cairo(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Text(
                        '💔 $losses / 5 جولات خسرها',
                        style: GoogleFonts.cairo(
                          color: losses >= 4
                              ? const Color(0xFFEF4444)
                              : AppTheme.gold,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                );
              }).toList(),
            ),

            const SizedBox(height: 20),

            ElevatedButton.icon(
              onPressed: () => game.advanceToNextRound(),
              icon: const AppIcon(AppIcons.arrowForward, size: 18),
              label: Text(
                'الجولة التالية',
                style: GoogleFonts.cairo(
                  fontSize: 15,
                  fontWeight: FontWeight.bold,
                ),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.steelBlue.withValues(alpha: 0.4),
                foregroundColor: Colors.white,
                padding:
                    const EdgeInsets.symmetric(horizontal: 24, vertical: 10),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                  side: BorderSide(
                      color: AppTheme.steelBlue.withValues(alpha: 0.6)),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  bool _hasSaved99Match = false;
  XpRewardBreakdown? _ninetyNineXp;

  void _awardNinetyNineRewards(NinetyNineGameProvider game) {
    if (_hasSaved99Match) return;
    _hasSaved99Match = true;

    final winner = game.matchWinner;
    final localPlayer = game.localPlayer;
    if (winner == null || localPlayer == null) return;

    final isWinner = winner.id == localPlayer.id;
    final roundsSurvived = game.currentRoundNumber;

    final breakdown = RankingService.instance.calculateNinetyNineReward(
      won: isWinner,
      roundsSurvived: roundsSurvived,
    );

    setState(() {
      _ninetyNineXp = breakdown;
    });

    // Save match record to Supabase history
    final record = MatchRecord(
      date: DateTime.now().toIso8601String(),
      winnerName: winner.name,
      winnerScore: 0,
      gameType: 'ninety_nine',
      players: game.players.map((p) {
        final losses = game.getPlayerLosses(p.id);
        final rank = p.id == winner.id ? 'الفائز 👑' : 'خسائر: $losses';
        return PlayerResult(name: p.name, score: losses, rankTitle: rank);
      }).toList(),
    );
    HistoryService.saveMatchRecordDirect(record);

    // Process XP & Level Up
    final roomId = context.read<GameProvider>().currentRoom?.id;
    RankingService.instance
        .awardOnlineMatchXp(breakdown: breakdown, roomId: roomId)
        .then((result) {
      if (mounted && result != null && result.didLevelUp) {
        Future.delayed(const Duration(milliseconds: 800), () {
          if (mounted) {
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
    });
  }

  // ── Match Outcome Celebration Overlay ───────────────────────────────────
  Widget _buildMatchOutcomeOverlay(
    BuildContext context,
    NinetyNineGameProvider game,
  ) {
    final winner = game.matchWinner!;
    final loser = game.matchLoser!;
    _awardNinetyNineRewards(game);

    final auth = AuthService.instance;
    final profile = auth.currentProfile;

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
              style: GoogleFonts.cairo(
                color: AppTheme.gold,
                fontSize: layout.isTablet ? 26 : 24,
                fontWeight: FontWeight.w900,
              ),
            ),
            SizedBox(height: layout.isTablet ? 12 : 8),
            Text(
              'الفائز البطل: ${winner.name}',
              style: GoogleFonts.cairo(
                color: AppTheme.cream,
                fontSize: layout.isTablet ? 19 : 18,
                fontWeight: FontWeight.bold,
              ),
              textAlign: TextAlign.center,
            ),
            Text(
              'استبعد بخسارة 5 جولات: ${loser.name}',
              style: GoogleFonts.cairo(
                color: AppTheme.playerRed,
                fontSize: layout.isTablet ? 15 : 14,
              ),
              textAlign: TextAlign.center,
            ),
            if (_ninetyNineXp != null) ...[
              SizedBox(height: layout.isTablet ? 16 : 14),
              Container(
                padding: EdgeInsets.symmetric(
                  horizontal: layout.isTablet ? 18 : 16,
                  vertical: layout.isTablet ? 10 : 8,
                ),
                decoration: BoxDecoration(
                  color: AppTheme.deepNavy.withValues(alpha: 0.46),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                    color: AppTheme.gold.withValues(alpha: 0.32),
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const AppIcon(
                      AppIcons.autoAwesome,
                      color: AppTheme.gold,
                      size: 18,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      '+${_ninetyNineXp!.totalXp} XP مكافأة 99',
                      style: GoogleFonts.cairo(
                        color: AppTheme.gold,
                        fontSize: layout.isTablet ? 15 : 14,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    if (profile != null) ...[
                      const SizedBox(width: 10),
                      RankTierBadge(
                        tier: profile.rankTier,
                        level: profile.level,
                        compact: true,
                      ),
                    ],
                  ],
                ),
              ),
            ],
            SizedBox(height: layout.isTablet ? 22 : 18),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: () {
                  context.read<NinetyNineGameProvider>().reset();
                  context.read<GameProvider>().reset();
                  Navigator.of(context, rootNavigator: true)
                      .pushNamedAndRemoveUntil('/', (route) => false);
                },
                style: FilledButton.styleFrom(
                  backgroundColor: AppTheme.gold,
                  foregroundColor: AppTheme.navyDark,
                  padding: EdgeInsets.symmetric(
                    horizontal: layout.isTablet ? 28 : 24,
                    vertical: layout.isTablet ? 14 : 12,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                  elevation: 0,
                ),
                child: Text(
                  'العودة للرئيسية',
                  style: GoogleFonts.cairo(
                    fontSize: layout.isTablet ? 17 : 16,
                    fontWeight: FontWeight.bold,
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
        final gameProvider = context.read<GameProvider>();
        await gameProvider.temporarilyLeaveOngoingGame();
        if (!context.mounted) return;
        context.read<NinetyNineGameProvider>().reset();
        Navigator.of(context, rootNavigator: true)
            .pushNamedAndRemoveUntil('/', (route) => false);
      },
    );
  }

  Widget _buildReactionsOverlay(
      BuildContext context, NinetyNineGameProvider game) {
    if (game.activeReactions.isEmpty) return const SizedBox.shrink();

    final isPortrait =
        MediaQuery.of(context).orientation == Orientation.portrait;
    final players = game.players;
    final localP = game.localPlayer;

    final List<Widget> bubbles = [];

    // Local player reaction
    if (localP != null && game.activeReactions.containsKey(localP.id)) {
      bubbles.add(
        Positioned(
          bottom: isPortrait ? 138 : 88,
          left: isPortrait ? 20 : 110,
          child: ReactionBubbleWidget(
            key: ValueKey(game.activeReactions[localP.id]!.id),
            reaction: game.activeReactions[localP.id]!,
            anchorAlignment: Alignment.bottomLeft,
          ),
        ),
      );
    }

    // Opponent reactions
    for (int i = 1; i < players.length; i++) {
      final player = players[i];
      if (game.activeReactions.containsKey(player.id)) {
        final reaction = game.activeReactions[player.id]!;
        Positioned bubble;
        if (players.length == 2) {
          bubble = Positioned(
            top: 200,
            left: 0,
            right: 0,
            child: Center(
              child: ReactionBubbleWidget(
                key: ValueKey(reaction.id),
                reaction: reaction,
                anchorAlignment: Alignment.topCenter,
              ),
            ),
          );
        } else if (players.length == 3) {
          if (i == 1) {
            bubble = Positioned(
              left: 16,
              bottom: 240,
              child: ReactionBubbleWidget(
                key: ValueKey(reaction.id),
                reaction: reaction,
                anchorAlignment: Alignment.centerLeft,
              ),
            );
          } else {
            bubble = Positioned(
              right: 16,
              bottom: 240,
              child: ReactionBubbleWidget(
                key: ValueKey(reaction.id),
                reaction: reaction,
                anchorAlignment: Alignment.centerRight,
              ),
            );
          }
        } else {
          if (i == 1) {
            bubble = Positioned(
              left: 16,
              bottom: 250,
              child: ReactionBubbleWidget(
                key: ValueKey(reaction.id),
                reaction: reaction,
                anchorAlignment: Alignment.centerLeft,
              ),
            );
          } else if (i == players.length - 1) {
            bubble = Positioned(
              right: 16,
              bottom: 250,
              child: ReactionBubbleWidget(
                key: ValueKey(reaction.id),
                reaction: reaction,
                anchorAlignment: Alignment.centerRight,
              ),
            );
          } else {
            bubble = Positioned(
              top: 150,
              left: 0,
              right: 0,
              child: Center(
                child: ReactionBubbleWidget(
                  key: ValueKey(reaction.id),
                  reaction: reaction,
                  anchorAlignment: Alignment.topCenter,
                ),
              ),
            );
          }
        }
        bubbles.add(bubble);
      }
    }

    return Stack(children: bubbles);
  }

  Widget _buildReactionTriggerButton(
      BuildContext context, NinetyNineGameProvider game) {
    return GestureDetector(
      onTap: () {
        ReactionPickerSheet.show(
          context,
          onSelectReaction: (emoji, [text]) {
            game.sendReaction(emoji, text);
          },
        );
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        decoration: BoxDecoration(
          color: AppTheme.navyDark.withValues(alpha: 0.88),
          borderRadius: BorderRadius.circular(22),
          border: Border.all(
            color: AppTheme.gold.withValues(alpha: 0.6),
            width: 1.5,
          ),
          boxShadow: [
            BoxShadow(
              color: AppTheme.gold.withValues(alpha: 0.25),
              blurRadius: 10,
              offset: const Offset(0, 2),
            ),
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.4),
              blurRadius: 8,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const AppIcon(
              AppIcons.chatBubbleOutline,
              color: AppTheme.gold,
              size: 18,
            ),
            const SizedBox(width: 6),
            Text(
              'تفاعل 🔥',
              style: GoogleFonts.cairo(
                color: AppTheme.white,
                fontSize: 12,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
