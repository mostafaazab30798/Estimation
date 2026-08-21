// lib/modes/ninety_nine/presentation/screens/ninety_nine_game_screen.dart

import 'dart:math';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';

// Removed unused import
import 'package:estimation/core/models/game_state.dart';
import 'package:estimation/theme/app_theme.dart';
import 'package:estimation/widgets/playing_card_widget.dart';
import 'package:estimation/widgets/hud/game_background.dart';
import 'package:estimation/widgets/hud/casino_table.dart';
import 'package:estimation/screens/game_screen.dart' show HiddenCardFan;

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
                    top: 10,
                    left: 10,
                    right: 10,
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

                  // ── Local Player ─────────────────────────────────
                  Positioned(
                    bottom: 4,
                    left: 0,
                    right: 0,
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
  List<Widget> _buildOpponents(BuildContext context, NinetyNineGameProvider game) {
    final players = game.players;
    if (players.length < 2) return [];

    final total = players.length;
    final List<Widget> widgets = [];

    final media = MediaQuery.of(context);
    final isPortrait = media.orientation == Orientation.portrait;
    final edgePadding = isPortrait ? 4.0 : 14.0;

    // Map relative indices (1 to total - 1) to table anchor positions
    for (int i = 1; i < total; i++) {
      final player = players[i];
      final isTurn = game.currentPlayerIndex == i;
      final losses = game.getPlayerLosses(player.id);

      Positioned positionedWidget;

      if (total == 2) {
        positionedWidget = Positioned(
          top: 140,
          left: 0,
          right: 0,
          child: Align(
            alignment: Alignment.topCenter,
            child: _buildOpponentWidget(context, game, player, isTurn, losses, compact: true),
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
              child: _buildOpponentWidget(context, game, player, isTurn, losses, compact: true, isLeft: true),
            ),
          );
        } else {
          positionedWidget = Positioned(
            right: edgePadding,
            top: 0,
            bottom: 0,
            child: Align(
              alignment: const Alignment(1.0, 0.0),
              child: _buildOpponentWidget(context, game, player, isTurn, losses, compact: true, isRight: true),
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
              child: _buildOpponentWidget(context, game, player, isTurn, losses, compact: true, isLeft: true),
            ),
          );
        } else if (i == 2) {
          positionedWidget = Positioned(
            top: 100,
            left: 0,
            right: 0,
            child: Align(
              alignment: Alignment.topCenter,
              child: _buildOpponentWidget(context, game, player, isTurn, losses, compact: true),
            ),
          );
        } else {
          positionedWidget = Positioned(
            right: edgePadding,
            top: 0,
            bottom: 0,
            child: Align(
              alignment: const Alignment(1.0, 0.15),
              child: _buildOpponentWidget(context, game, player, isTurn, losses, compact: true, isRight: true),
            ),
          );
        }
      } else {
        // For 5, 6, 7 players, position them dynamically along an ellipse
        final int opponentCount = total - 1;
        final double angleStep = pi / (opponentCount + 1);
        final double angle = pi + (i * angleStep);

        final radiusX = isPortrait ? media.size.width * 0.44 : media.size.width * 0.42;
        final radiusY = isPortrait ? media.size.height * 0.35 : media.size.height * 0.40;

        // Offset center up a bit
        final centerY = isPortrait ? media.size.height * 0.48 : media.size.height * 0.54;
        final centerX = media.size.width / 2;

        // Use a custom cubic polynomial to push the middle players outwards (near x=0.5)
        // without pushing the bottom players outwards (near x=0.866).
        // f(x) = 1.45x - 0.6x^3
        double origX = cos(angle);
        double normalizedX = 1.45 * origX - 0.6 * pow(origX, 3);

        // Use a power curve to evenly distribute the vertical spacing
        // (angles near the top of the ellipse naturally cluster vertically; this pushes them down)
        double origY = sin(angle);
        double normalizedY = origY.sign * pow(origY.abs(), 2.5);

        final double dx = centerX + radiusX * normalizedX;
        final double dy = centerY + radiusY * normalizedY;

        positionedWidget = Positioned(
          left: dx - 100,
          width: 200,
          top: dy,
          child: Align(
            alignment: Alignment.topCenter,
            child: _buildOpponentWidget(
              context, game, player, isTurn, losses,
              compact: true,
              isLeft: cos(angle) < -0.3,
              isRight: cos(angle) > 0.3,
            ),
          ),
        );
      }

      widgets.add(positionedWidget);
    }

    return widgets;
  }

  Widget _buildOpponentWidget(BuildContext context, NinetyNineGameProvider game, NinetyNinePlayer player, bool isTurn, int losses, {bool compact = true, bool isLeft = false, bool isRight = false}) {
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
      ],
    );
  }

  // ── Central Play Area & Messy Card Stack ────────────────────────────────
  Widget _buildCenterHud(NinetyNineGameProvider game) {
    final moves = game.moveHistory;
    final visibleMoves = moves.length > 10
        ? moves.sublist(moves.length - 10)
        : moves;

    final total = game.groundTotal;
    Color totalColor;
    if (total >= 91) {
      totalColor = const Color(0xFFEF4444);
    } else if (total >= 75) {
      totalColor = const Color(0xFFF59E0B);
    } else {
      totalColor = const Color(0xFF10B981);
    }

    return FittedBox(
      fit: BoxFit.scaleDown,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // 1. Messy Card Pile Container
          SizedBox(
            width: 170,
            height: 120,
            child: Stack(
              alignment: Alignment.center,
              clipBehavior: Clip.none,
              children: [
                if (visibleMoves.isEmpty)
                  Container(
                    width: 58,
                    height: 82,
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
                                  offset: Offset(isTopCard ? 2 : 1, isTopCard ? 4 : 2),
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
                              width: 56,
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
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.6),
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(
                      color: totalColor,
                      width: total >= 90 ? 2.0 : 1.2,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: totalColor.withValues(alpha: total >= 90 ? 0.4 : 0.15),
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
    final media = MediaQuery.of(context);
    final isPortrait = media.orientation == Orientation.portrait;

    final playerInfoCard = NinetyNinePlayerInfoWidget(
      player: localP,
      losses: losses,
      phase: game.phase,
      isCurrentTurn: isMyTurn,
      isMe: true,
      compact: !isPortrait,
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
          const SizedBox(height: 4),
          playerInfoCard,
        ],
      );
    }

    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        Padding(
          padding: const EdgeInsets.only(bottom: 6.0),
          child: playerInfoCard,
        ),
        const SizedBox(width: 14),
        handWidget,
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
          border: Border.all(color: const Color(0xFFEF4444).withValues(alpha: 0.6), width: 1.5),
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
                          color: losses >= 4 ? const Color(0xFFEF4444) : AppTheme.gold,
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
              icon: const Icon(Icons.arrow_forward_rounded, size: 18),
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
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 10),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                  side: BorderSide(color: AppTheme.steelBlue.withValues(alpha: 0.6)),
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
    RankingService.instance.processMatchReward(breakdown).then((result) {
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

    return Container(
      color: Colors.black.withValues(alpha: 0.92),
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
          border: Border.all(color: AppTheme.gold.withValues(alpha: 0.6), width: 1.5),
          boxShadow: [
            BoxShadow(
              color: AppTheme.gold.withValues(alpha: 0.3),
              blurRadius: 35,
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('🏆', style: TextStyle(fontSize: 54)),
            const SizedBox(height: 12),
            Text(
              'نهاية المباراة!',
              style: GoogleFonts.cairo(
                color: AppTheme.gold,
                fontSize: 24,
                fontWeight: FontWeight.w900,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'الفائز البطل: ${winner.name} 🎉',
              style: GoogleFonts.cairo(
                color: Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            Text(
              'استبعد بخسارة 5 جولات: ${loser.name} 💔',
              style: GoogleFonts.cairo(
                color: const Color(0xFFEF4444),
                fontSize: 14,
              ),
            ),
            if (_ninetyNineXp != null) ...[
              const SizedBox(height: 14),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                decoration: BoxDecoration(
                  color: AppTheme.gold.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppTheme.gold.withValues(alpha: 0.4)),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.auto_awesome_rounded, color: AppTheme.gold, size: 18),
                    const SizedBox(width: 6),
                    Text(
                      '+${_ninetyNineXp!.totalXp} XP مكافأة 99',
                      style: GoogleFonts.cairo(
                        color: AppTheme.gold,
                        fontSize: 14,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    if (profile != null) ...[
                      const SizedBox(width: 10),
                      RankTierBadge(tier: profile.rankTier, level: profile.level, compact: true),
                    ],
                  ],
                ),
              ),
            ],
            const SizedBox(height: 18),
            ElevatedButton(
              onPressed: () {
                context.read<NinetyNineGameProvider>().reset();
                context.read<GameProvider>().reset();
                Navigator.of(context, rootNavigator: true)
                    .pushNamedAndRemoveUntil('/', (route) => false);
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.gold.withValues(alpha: 0.2),
                foregroundColor: AppTheme.gold,
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                  side: BorderSide(color: AppTheme.gold.withValues(alpha: 0.5)),
                ),
              ),
              child: Text(
                'العودة للرئيسية 🏠',
                style: GoogleFonts.cairo(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _confirmExit(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => Dialog(
        backgroundColor: Colors.transparent,
        child: Container(
          width: 380,
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [Color(0xF02A4560), Color(0xF01D3348)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(24),
            border: Border.all(
              color: AppTheme.steelBlue.withValues(alpha: 0.2),
              width: 1.2,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.5),
                blurRadius: 32,
                spreadRadius: 4,
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 56,
                height: 56,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: AppTheme.playerRed.withValues(alpha: 0.15),
                  border: Border.all(
                      color: AppTheme.playerRed.withValues(alpha: 0.3)),
                ),
                child: const Icon(Icons.exit_to_app_rounded,
                    color: AppTheme.playerRed, size: 28),
              ),
              const SizedBox(height: 16),
              Text(
                'مغادرة اللعبة',
                style: GoogleFonts.cairo(
                  color: AppTheme.cream,
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              Text(
                'هل أنت متأكد أنك تريد مغادرة اللعبة والعودة للرئيسية؟ سيتم فصلك من الغرفة.',
                style: GoogleFonts.cairo(
                  color: AppTheme.steelBlue,
                  fontSize: 12,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 24),
              Row(
                children: [
                  Expanded(
                    child: InkWell(
                      onTap: () => Navigator.pop(ctx),
                      borderRadius: BorderRadius.circular(12),
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        decoration: BoxDecoration(
                          color: AppTheme.steelBlue.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                              color: AppTheme.steelBlue.withValues(alpha: 0.3)),
                        ),
                        child: Text(
                          'إلغاء',
                          style: GoogleFonts.cairo(
                            color: AppTheme.cream,
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: InkWell(
                      onTap: () {
                        context.read<NinetyNineGameProvider>().reset();
                        context.read<GameProvider>().reset();
                        Navigator.of(context, rootNavigator: true)
                            .pushNamedAndRemoveUntil('/', (route) => false);
                      },
                      borderRadius: BorderRadius.circular(12),
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(
                            colors: [AppTheme.playerRed, Color(0xFFB03050)],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                          borderRadius: BorderRadius.circular(12),
                          boxShadow: [
                            BoxShadow(
                              color: AppTheme.playerRed.withValues(alpha: 0.35),
                              blurRadius: 12,
                            ),
                          ],
                        ),
                        child: Text(
                          'مغادرة',
                          style: GoogleFonts.cairo(
                            color: Colors.white,
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                          ),
                          textAlign: TextAlign.center,
                        ),
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
