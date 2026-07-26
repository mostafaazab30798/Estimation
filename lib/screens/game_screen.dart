// lib/screens/game_screen.dart
//
// Main game table — all existing game logic is UNCHANGED.
// Only the presentation layer is redesigned using the new hud/ components.

import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:google_fonts/google_fonts.dart';


import '../core/models/game_state.dart';
import '../providers/game_provider.dart';
import '../theme/app_theme.dart';
import '../widgets/player_hand.dart';
import '../widgets/trick_area.dart';
import '../widgets/player_info.dart';
import '../widgets/bid_dialog.dart';
import '../widgets/declaration_dialog.dart';
import '../widgets/tricks_dialog.dart';
import '../widgets/reconnection_banner.dart';
import '../widgets/hud/game_background.dart';
import '../widgets/hud/casino_table.dart';
import '../widgets/hud/top_hud.dart';
import '../widgets/hud/ready_phase_overlay.dart';
import '../widgets/hud/local_player_ready_button.dart';
import '../services/reconnection_manager.dart';
import 'scoring_screen.dart';
import 'match_end_screen.dart';

class GameScreen extends StatefulWidget {
  const GameScreen({super.key});

  @override
  State<GameScreen> createState() => _GameScreenState();
}

class _GameScreenState extends State<GameScreen> {
  bool _bidDialogOpen = false;
  bool _declarationDialogOpen = false;
  bool _delayingScoring = false;

  // Fix #1/#9: Track last-seen values so we only trigger dialog logic
  // when the relevant state actually changes, not on every rebuild.
  GamePhase? _lastPhase;
  bool _lastIsMyTurn = false;

  final Map<int, GlobalKey> _playerKeys = {
    0: GlobalKey(),
    1: GlobalKey(),
    2: GlobalKey(),
    3: GlobalKey(),
  };

  final Map<int, GlobalKey> _areaKeys = {
    0: GlobalKey(),
    1: GlobalKey(),
    2: GlobalKey(),
    3: GlobalKey(),
  };

  void _maybeShowDialogs(GameProvider provider, GameState state, bool isMyTurn) {
    final phase = state.phase;

    if (phase == _lastPhase && isMyTurn == _lastIsMyTurn) return;
    _lastPhase = phase;
    _lastIsMyTurn = isMyTurn;

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      if (provider.state == null || provider.status != ConnectionStatus.connected) return;
      _maybeShowBidDialog(context, provider, state);
      _maybeShowDeclarationDialog(context, provider, state);
    });
  }

  @override
  Widget build(BuildContext context) {
    final phase = context.select((GameProvider p) => p.state?.phase);
    final isStateNull = context.select((GameProvider p) => p.state == null);
    final isMyTurn = context.select((GameProvider p) => p.isMyTurn);

    if (isStateNull) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator(color: AppTheme.gold)),
      );
    }

    final provider = context.read<GameProvider>();
    final state = provider.state!;

    // If we just finished the trick-taking phase, delay the transition to the 
    // scoring screen so the 13th trick collection animation has time to play.
    if (phase == GamePhase.scoring && _lastPhase == GamePhase.trickTaking && !_delayingScoring) {
      _delayingScoring = true;
      Future.delayed(const Duration(milliseconds: 1400), () {
        if (mounted) {
          setState(() {
            _delayingScoring = false;
          });
        }
      });
    }

    // Phase routing
    if (phase == GamePhase.scoring && !_delayingScoring) {
      return ScoringScreen(state: state, provider: provider);
    }
    if (phase == GamePhase.matchEnd) {
      return MatchEndScreen(state: state, provider: provider);
    }

    _maybeShowDialogs(provider, state, isMyTurn);

    final media = MediaQuery.of(context);
    final isPortrait = media.orientation == Orientation.portrait;
    final minDim = math.min(media.size.width, media.size.height);
    final trickSize = isPortrait
        ? (minDim * 0.52).clamp(140.0, 250.0)
        : (media.size.height * 0.44).clamp(160.0, 290.0);

    // Phase-reactive glow color for the table
    final tableGlowColor = _phaseGlowColor(state.phase);

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {
        if (didPop) return;
        _confirmExit(context, provider);
      },
      child: Scaffold(
        body: Stack(
          children: [
            // ── 1. Animated layered background ──────────────────────
            Positioned.fill(
              child: RepaintBoundary(
                child: GameBackground(phase: state.phase),
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
                    top: isPortrait ? 6 : 10,
                    left: 10,
                    right: 10,
                    child: Consumer<GameProvider>(
                      builder: (ctx, prov, _) => TopHud(
                        state: prov.state!,
                        onExitTap: () =>
                            _confirmExit(ctx, prov),
                      ),
                    ),
                  ),

                  // ── Center Trick Area ─────────────────────────────
                  Align(
                    alignment: Alignment(0, isPortrait ? -0.32 : -0.25),
                    child: SizedBox(
                      width: trickSize,
                      height: trickSize,
                      child: Consumer<GameProvider>(
                        builder: (ctx, prov, _) => TrickArea(
                          state: prov.state!,
                          myPlayerId: prov.myPlayerId,
                          playerKeys: _playerKeys,
                          areaKeys: _areaKeys,
                        ),
                      ),
                    ),
                  ),

                  // ── Opponent: Left ────────────────────────────────
                  Positioned(
                    left: isPortrait ? 4 : 14,
                    top: 0,
                    bottom: 0,
                    child: Align(
                      alignment: isPortrait
                          ? const Alignment(-1.0, 0.15)
                          : Alignment.centerLeft,
                      child: Consumer<GameProvider>(
                        builder: (ctx, prov, _) {
                          final mySeat = prov.me?.seatIndex ?? 0;
                          final oppSeat = (mySeat + 3) % 4;
                          return KeyedSubtree(
                            key: _areaKeys[oppSeat],
                            child: _buildSideOpponent(
                                prov.state!, oppSeat, prov, isLeft: true),
                          );
                        },
                      ),
                    ),
                  ),

                  // ── Opponent: Right ───────────────────────────────
                  Positioned(
                    right: isPortrait ? 4 : 14,
                    top: 0,
                    bottom: 0,
                    child: Align(
                      alignment: isPortrait
                          ? const Alignment(1.0, 0.15)
                          : Alignment.centerRight,
                      child: Consumer<GameProvider>(
                        builder: (ctx, prov, _) {
                          final mySeat = prov.me?.seatIndex ?? 0;
                          final oppSeat = (mySeat + 1) % 4;
                          return KeyedSubtree(
                            key: _areaKeys[oppSeat],
                            child: _buildSideOpponent(
                                prov.state!, oppSeat, prov, isLeft: false),
                          );
                        },
                      ),
                    ),
                  ),

                  // ── Opponent: Top ─────────────────────────────────
                  Positioned(
                    top: isPortrait ? 128 : 64,
                    left: 0,
                    right: 0,
                    child: Align(
                      alignment: Alignment.topCenter,
                      child: Consumer<GameProvider>(
                        builder: (ctx, prov, _) {
                          final mySeat = prov.me?.seatIndex ?? 0;
                          final oppSeat = (mySeat + 2) % 4;
                          return KeyedSubtree(
                            key: _areaKeys[oppSeat],
                            child: _buildOpponentStrip(
                                prov.state!, oppSeat, prov),
                          );
                        },
                      ),
                    ),
                  ),

                  // ── Local Player ──────────────────────────────────
                  Positioned(
                    bottom: 4,
                    left: 0,
                    right: 0,
                    child: Align(
                      alignment: Alignment.bottomCenter,
                      child: Consumer<GameProvider>(
                        builder: (ctx, prov, _) {
                          final me = prov.me;
                          if (me == null) return const SizedBox();

                          final handWidget = PlayerHand(
                            hand: prov.myHand,
                            isMyTurn: prov.isMyTurn,
                            state: prov.state!,
                            me: prov.me,
                            onPlayCard: prov.playCard,
                          );

                          final playerInfoCard = KeyedSubtree(
                            key: _areaKeys[me.seatIndex],
                            child: InkWell(
                              onTap: () {
                                showDialog(
                                  context: context,
                                  builder: (_) => TakenTricksDialog(
                                      takenTricks: me.takenTricks),
                                );
                              },
                              child: PlayerInfoWidget(
                                key: _playerKeys[me.seatIndex],
                                player: me,
                                state: prov.state!,
                                isCurrentTurn: prov.isMyTurn,
                                isBidder: prov.amBidder,
                                isMe: true,
                                compact: !isPortrait,
                              ),
                            ),
                          );

                          final readyBtn =
                              prov.state!.phase == GamePhase.voidCheck
                                  ? LocalPlayerReadyButton(
                                      isReady: prov.state!.voidCheckPassed
                                          .contains(prov.myPlayerId),
                                      onTap: () {
                                        final isReady = prov.state!
                                            .voidCheckPassed
                                            .contains(prov.myPlayerId);
                                        if (isReady) {
                                          prov.unready();
                                        } else {
                                          prov.confirmNoVoid();
                                        }
                                      },
                                    )
                                  : null;

                          if (isPortrait) {
                            return Column(
                              mainAxisSize: MainAxisSize.min,
                              crossAxisAlignment: CrossAxisAlignment.center,
                              children: [
                                handWidget,
                                const SizedBox(height: 4),
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    playerInfoCard,
                                    if (readyBtn != null) ...[
                                      const SizedBox(width: 10),
                                      readyBtn,
                                    ],
                                  ],
                                ),
                              ],
                            );
                          }

                          return Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              Padding(
                                padding: const EdgeInsets.only(bottom: 6.0),
                                child: Column(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    playerInfoCard,
                                    if (readyBtn != null) ...[
                                      const SizedBox(height: 6),
                                      readyBtn,
                                    ],
                                  ],
                                ),
                              ),
                              const SizedBox(width: 14),
                              handWidget,
                            ],
                          );
                        },
                      ),
                    ),
                  ),

                  // ── Phase overlay ─────────────────────────────────
                  Consumer<GameProvider>(
                    builder: (ctx, prov, _) =>
                        _buildPhaseOverlay(ctx, prov.state!, prov),
                  ),

                  // ── Reconnection banner ───────────────────────────
                  Consumer<ReconnectionManager>(
                    builder: (ctx, reconnect, _) => ReconnectionBanner(
                      reconnectionState: reconnect.reconnectionState,
                      onRetry: reconnect.retry,
                      onGoHome: () async {
                        await reconnect.dismissAndGoHome();
                        if (ctx.mounted) {
                          ctx.read<GameProvider>().reset();
                          Navigator.of(ctx, rootNavigator: true)
                              .pushNamedAndRemoveUntil('/', (route) => false);
                        }
                      },
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── Phase glow helper ──────────────────────────────────────────────────

  Color _phaseGlowColor(GamePhase phase) {
    switch (phase) {
      case GamePhase.auction:
        return AppTheme.phaseAuction;
      case GamePhase.declarations:
        return AppTheme.phaseDeclarations;
      case GamePhase.trickTaking:
        return AppTheme.phasePlay;
      case GamePhase.scoring:
        return AppTheme.phaseScoring;
      case GamePhase.voidCheck:
        return AppTheme.phaseReady;
      default:
        return AppTheme.deepNavy;
    }
  }

  // ── Opponent builders ───────────────────────────────────────────────────

  bool _isTurn(GameState state, int seatIndex) {
    if (state.phase == GamePhase.auction) {
      return state.auctionTurnSeatIndex == seatIndex;
    }
    return state.currentPlayerSeatIndex == seatIndex;
  }

  Widget _buildOpponentStrip(
      GameState state, int seatIndex, GameProvider provider) {
    final player = state.playerBySeat(seatIndex);
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        PlayerInfoWidget(
          key: _playerKeys[seatIndex],
          player: player,
          state: state,
          isCurrentTurn: _isTurn(state, seatIndex),
          isBidder: state.bidderPlayerId == player.id,
          compact: true,
        ),
        const SizedBox(width: 8),
        InkWell(
          onTap: () {
            showDialog(
              context: context,
              builder: (_) => LatestTrickDialog(
                trick: player.takenTricks.isNotEmpty
                    ? player.takenTricks.last
                    : null,
                playerName: player.name,
              ),
            );
          },
          child: HiddenCardFan(count: player.hand.length),
        ),
      ],
    );
  }

  Widget _buildSideOpponent(
      GameState state, int seatIndex, GameProvider provider,
      {required bool isLeft}) {
    final player = state.playerBySeat(seatIndex);
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        PlayerInfoWidget(
          key: _playerKeys[seatIndex],
          player: player,
          state: state,
          isCurrentTurn: _isTurn(state, seatIndex),
          isBidder: state.bidderPlayerId == player.id,
          compact: true,
        ),
        const SizedBox(height: 8),
        InkWell(
          onTap: () {
            showDialog(
              context: context,
              builder: (_) => LatestTrickDialog(
                trick: player.takenTricks.isNotEmpty
                    ? player.takenTricks.last
                    : null,
                playerName: player.name,
              ),
            );
          },
          child: HiddenCardFan(
              count: player.hand.length,
              isLeft: isLeft,
              isRight: !isLeft),
        ),
      ],
    );
  }

  // ── Phase overlay ───────────────────────────────────────────────────────

  Widget _buildPhaseOverlay(
      BuildContext context, GameState state, GameProvider provider) {
    if (state.phase == GamePhase.voidCheck) {
      return Positioned.fill(
        child: Align(
          alignment: const Alignment(0, -0.15),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: ReadyPhaseOverlay(
              state: state,
              myPlayerId: provider.myPlayerId,
              onApproveRedeal: provider.approveRedeal,
              onRejectRedeal: provider.rejectRedeal,
            ),
          ),
        ),
      );
    }

    return const SizedBox.shrink();
  }

  // ── Exit dialog ─────────────────────────────────────────────────────────

  void _confirmExit(BuildContext context, GameProvider provider) {
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
                        provider.reset();
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

  // ── Dialog triggers — UNCHANGED LOGIC ──────────────────────────────────

  void _maybeShowBidDialog(
      BuildContext context, GameProvider provider, GameState state) {
    if (provider.state == null ||
        provider.status != ConnectionStatus.connected ||
        state.phase != GamePhase.auction ||
        !provider.isMyTurn) {
      if (_bidDialogOpen) {
        if (Navigator.of(context, rootNavigator: true).canPop()) {
          Navigator.of(context, rootNavigator: true).pop();
        }
        _bidDialogOpen = false;
      }
      return;
    }

    if (_bidDialogOpen) return;

    _bidDialogOpen = true;
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => BidDialog(
        currentHighBid: state.currentHighBid,
        bidderName: state.bidderPlayerId != null
            ? state.playerById(state.bidderPlayerId!).name
            : null,
        onBid: (bid) {
          provider.submitBid(bid);
        },
        onPass: () {
          provider.passBid();
        },
      ),
    ).then((_) {
      if (mounted) _bidDialogOpen = false;
    });
  }

  void _maybeShowDeclarationDialog(
      BuildContext context, GameProvider provider, GameState state) {
    if (provider.state == null ||
        provider.status != ConnectionStatus.connected ||
        state.phase != GamePhase.declarations ||
        !provider.isMyTurn) {
      if (_declarationDialogOpen) {
        if (Navigator.of(context, rootNavigator: true).canPop()) {
          Navigator.of(context, rootNavigator: true).pop();
        }
        _declarationDialogOpen = false;
      }
      return;
    }

    final me = provider.me;
    if (me == null || me.declared != null) {
      if (_declarationDialogOpen) {
        if (Navigator.of(context, rootNavigator: true).canPop()) {
          Navigator.of(context, rootNavigator: true).pop();
        }
        _declarationDialogOpen = false;
      }
      return;
    }

    if (_declarationDialogOpen) return;

    int? forbidden;
    int? minDeclaration;

    final decls = state.players
        .map((p) => p.declared)
        .where((d) => d != null)
        .toList();

    if (decls.length == 3) {
      final sum = decls.fold<int>(0, (a, b) => a + b!);
      forbidden = 13 - sum;
      if (forbidden < 0 || forbidden > 13) forbidden = null;
    }

    if (provider.amBidder && state.currentHighBid != null) {
      minDeclaration = state.currentHighBid!.trickCount;
    }

    _declarationDialogOpen = true;
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => DeclarationDialog(
        state: state,
        me: me,
        forbiddenDeclaration: forbidden,
        minDeclaration: minDeclaration,
        onSubmit: (declared) {
          provider.submitDeclaration(declared);
        },
      ),
    ).then((_) {
      if (mounted) _declarationDialogOpen = false;
    });
  }
}

// ── HiddenCardFan Widget — unchanged ────────────────────────────────────────
class HiddenCardFan extends StatelessWidget {
  final int count;
  final bool isLeft;
  final bool isRight;

  const HiddenCardFan(
      {super.key, required this.count, this.isLeft = false, this.isRight = false});

  @override
  Widget build(BuildContext context) {
    if (count == 0) return const SizedBox();

    final displayCount = count > 4 ? 4 : count;
    const cardW = 32.0;
    const cardH = cardW / 0.65;

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (!isRight) _buildRemainingText(),
        if (!isRight) const SizedBox(width: 8),
        SizedBox(
          width: cardW + (displayCount - 1) * 12.0,
          height: cardH,
          child: Stack(
            clipBehavior: Clip.none,
            children: List.generate(displayCount, (i) {
              return Positioned(
                left: i * 12.0,
                child: Container(
                  width: cardW,
                  height: cardH,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(4),
                    border: Border.all(
                        color: AppTheme.steelBlue.withValues(alpha: 0.3),
                        width: 1),
                    boxShadow: const [
                      BoxShadow(
                          color: Colors.black26,
                          blurRadius: 4,
                          offset: Offset(-2, 2)),
                    ],
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(3),
                    child: Image.asset('assets/back.png', fit: BoxFit.cover),
                  ),
                ),
              );
            }),
          ),
        ),
        if (isRight) const SizedBox(width: 8),
        if (isRight) _buildRemainingText(),
      ],
    );
  }

  Widget _buildRemainingText() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: AppTheme.deepNavy.withValues(alpha: 0.7),
        borderRadius: BorderRadius.circular(10),
        border:
            Border.all(color: AppTheme.steelBlue.withValues(alpha: 0.25), width: 0.8),
      ),
      child: Text(
        '$count',
        style: const TextStyle(
            color: AppTheme.cream, fontSize: 12, fontWeight: FontWeight.bold),
      ),
    );
  }
}
