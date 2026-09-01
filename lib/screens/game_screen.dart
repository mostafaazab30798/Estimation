// lib/screens/game_screen.dart
//
// Main game table — all existing game logic is UNCHANGED.
// Only the presentation layer is redesigned using the new hud/ components.

import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:google_fonts/google_fonts.dart';

import '../core/models/game_state.dart';
import '../core/game_engine.dart';
import '../core/utils/game_layout_metrics.dart';
import '../core/utils/stale_game_route.dart';
import '../providers/game_provider.dart';
import '../theme/app_theme.dart';
import '../widgets/player_hand.dart';
import '../widgets/trick_area.dart';
import '../widgets/player_info.dart';
import '../widgets/bid_dialog.dart';
import '../widgets/dash_call_dialog.dart';
import '../widgets/declaration_dialog.dart';
import '../widgets/tricks_dialog.dart';
import '../widgets/double_round_overlay.dart';
import '../widgets/fixed_trump_round_overlay.dart';
import '../widgets/earthquake/earthquake_effect_overlay.dart';
import '../widgets/reconnection_banner.dart';
import '../widgets/hud/game_background.dart';
import '../widgets/hud/casino_table.dart';
import '../core/widgets/leave_game_dialog.dart';
import '../widgets/hud/top_hud.dart';
import '../widgets/hud/ready_phase_overlay.dart';
import '../widgets/hud/turn_timer_badge.dart';
import '../widgets/hud/reaction_bubble_widget.dart';
import '../widgets/hud/reaction_picker_sheet.dart';
import '../services/reconnection_manager.dart';
import 'scoring_screen.dart';
import 'match_end_screen.dart';
import 'package:estimation/core/icons/app_icons.dart';

class GameScreen extends StatefulWidget {
  const GameScreen({super.key});

  @override
  State<GameScreen> createState() => _GameScreenState();
}

class _GameScreenState extends State<GameScreen> {
  bool _dashCallDialogOpen = false;
  bool _bidDialogOpen = false;
  bool _declarationDialogOpen = false;
  bool _delayingScoring = false;
  bool _showDoubleRoundOverlay = false;
  int? _lastAnnouncedDoubleRound;
  bool _showFixedTrumpOverlay = false;
  int? _lastAnnouncedFixedRound;
  GameProvider? _observedProvider;
  Timer? _scoringDelayTimer;

  GamePhase? _lastObservedPhase;
  GamePhase? _lastDialogPhase;
  bool? _lastDialogIsMyTurn;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final provider = context.read<GameProvider>();
    if (identical(provider, _observedProvider)) return;

    _observedProvider?.removeListener(_handleProviderChange);
    _observedProvider = provider;
    _lastObservedPhase = provider.state?.phase;
    provider.addListener(_handleProviderChange);

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && identical(provider, _observedProvider)) {
        _handleProviderChange();
      }
    });
  }

  @override
  void dispose() {
    _scoringDelayTimer?.cancel();
    _observedProvider?.removeListener(_handleProviderChange);
    super.dispose();
  }

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

  void _maybeShowDialogs(
      GameProvider provider, GameState state, bool isMyTurn) {
    final phase = state.phase;

    if (phase == _lastDialogPhase && isMyTurn == _lastDialogIsMyTurn) return;
    _lastDialogPhase = phase;
    _lastDialogIsMyTurn = isMyTurn;

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      if (provider.state == null ||
          provider.status != ConnectionStatus.connected) {
        return;
      }
      _maybeShowDashCallDialog(context, provider, state);
      _maybeShowBidDialog(context, provider, state);
      _maybeShowDeclarationDialog(context, provider, state);
    });
  }

  void _handleProviderChange() {
    final provider = _observedProvider;
    final state = provider?.state;
    if (!mounted || provider == null || state == null) return;

    final previousPhase = _lastObservedPhase;
    _lastObservedPhase = state.phase;

    var needsRebuild = false;

    if (state.phase == GamePhase.scoring &&
        previousPhase == GamePhase.trickTaking &&
        !_delayingScoring) {
      _scoringDelayTimer?.cancel();
      _delayingScoring = true;
      needsRebuild = true;
      _scoringDelayTimer = Timer(const Duration(milliseconds: 1400), () {
        if (!mounted) return;
        setState(() => _delayingScoring = false);
      });
    }

    if (state.isDoubleRound && _lastAnnouncedDoubleRound != state.roundNumber) {
      _lastAnnouncedDoubleRound = state.roundNumber;
      _showDoubleRoundOverlay = true;
      needsRebuild = true;
    }

    if (state.fixedTrump != null &&
        _lastAnnouncedFixedRound != state.roundNumber) {
      _lastAnnouncedFixedRound = state.roundNumber;
      _showFixedTrumpOverlay = true;
      needsRebuild = true;
    }

    if (needsRebuild) setState(() {});
    _maybeShowDialogs(provider, state, provider.isMyTurn);
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.read<GameProvider>();
    final frameState =
        context.select<GameProvider, ({GamePhase? phase, String? trumpName})>(
      (value) => (
        phase: value.state?.phase,
        trumpName: value.state?.trump?.name,
      ),
    );
    final state = provider.state;

    if (state == null) {
      if (StaleGameRoute.isStaleKotchinaGame(provider)) {
        StaleGameRoute.redirectToModeHome(context);
      }
      return const Scaffold(
        body: Center(child: CircularProgressIndicator(color: AppTheme.gold)),
      );
    }

    final phase = frameState.phase!;

    // Phase routing
    if (phase == GamePhase.scoring && !_delayingScoring) {
      return ScoringScreen(state: state, provider: provider);
    }
    if (phase == GamePhase.matchEnd) {
      return MatchEndScreen(state: state, provider: provider);
    }

    final layout = GameLayoutMetrics.of(context);
    final isPortrait = layout.isPortrait;
    final trickSize = layout.trickAreaSize;

    // Phase-reactive glow color for the table
    final tableGlowColor = _phaseGlowColor(state.phase);

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {
        if (didPop) return;
        _confirmExit(context, provider);
      },
      child: Scaffold(
        body: EarthquakeEffectOverlay(
          child: Stack(
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
                    painter: CasinoTablePainter(
                      glowColor: tableGlowColor,
                      trump: state.trump,
                    ),
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
                      child: Consumer<GameProvider>(
                        builder: (ctx, prov, _) => TopHud(
                          state: prov.state!,
                          onExitTap: () => _confirmExit(ctx, prov),
                        ),
                      ),
                    ),

                    // ── Center Trick Area ─────────────────────────────
                    Align(
                      alignment: layout.trickAreaAlignment,
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
                      left: layout.sideInset,
                      top: 0,
                      bottom: 0,
                      child: Align(
                        alignment: isPortrait
                            ? const Alignment(-1.0, 0.15)
                            : Alignment.centerLeft,
                        child: Consumer<GameProvider>(
                          builder: (ctx, prov, _) {
                            final total = prov.state?.players.length ?? 4;
                            final mySeat = prov.me?.seatIndex ?? 0;
                            final oppSeat = total == 4
                                ? (mySeat + 3) % 4
                                : total == 3
                                    ? (mySeat + 2) % 3
                                    : -1;
                            if (oppSeat == -1) return const SizedBox.shrink();
                            return KeyedSubtree(
                              key: _areaKeys[oppSeat],
                              child: _buildSideOpponent(
                                  prov.state!, oppSeat, prov,
                                  isLeft: true),
                            );
                          },
                        ),
                      ),
                    ),

                    // ── Opponent: Right ───────────────────────────────
                    Positioned(
                      right: layout.sideInset,
                      top: 0,
                      bottom: 0,
                      child: Align(
                        alignment: isPortrait
                            ? const Alignment(1.0, 0.15)
                            : Alignment.centerRight,
                        child: Consumer<GameProvider>(
                          builder: (ctx, prov, _) {
                            final total = prov.state?.players.length ?? 4;
                            final mySeat = prov.me?.seatIndex ?? 0;
                            final oppSeat = total == 4
                                ? (mySeat + 1) % 4
                                : total == 3
                                    ? (mySeat + 1) % 3
                                    : -1;
                            if (oppSeat == -1) return const SizedBox.shrink();
                            return KeyedSubtree(
                              key: _areaKeys[oppSeat],
                              child: _buildSideOpponent(
                                  prov.state!, oppSeat, prov,
                                  isLeft: false),
                            );
                          },
                        ),
                      ),
                    ),

                    // ── Opponent: Top ─────────────────────────────────
                    Positioned(
                      top: layout.topOpponentTop,
                      left: 0,
                      right: 0,
                      child: Align(
                        alignment: Alignment.topCenter,
                        child: Consumer<GameProvider>(
                          builder: (ctx, prov, _) {
                            final total = prov.state?.players.length ?? 4;
                            final mySeat = prov.me?.seatIndex ?? 0;
                            final oppSeat = total == 2
                                ? (mySeat + 1) % 2
                                : total == 4
                                    ? (mySeat + 2) % 4
                                    : -1;
                            if (oppSeat == -1) return const SizedBox.shrink();
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
                              onEarthquakeStrike: prov.triggerEarthquakeStrike,
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
                                  compact: layout.localPlayerCompact,
                                ),
                              ),
                            );

                            final bool showTurnTimer =
                                prov.state?.phase == GamePhase.trickTaking &&
                                    prov.isMyTurn;

                            final infoPad = layout.localPlayerInfoPadding;

                            if (isPortrait) {
                              return Column(
                                mainAxisSize: MainAxisSize.min,
                                crossAxisAlignment: CrossAxisAlignment.center,
                                children: [
                                  if (showTurnTimer) ...[
                                    TurnTimerBadge(
                                      state: prov.state!,
                                      isMyTurn: true,
                                      compact: true,
                                    ),
                                    const SizedBox(height: 6),
                                  ],
                                  handWidget,
                                  const SizedBox(height: 4),
                                  Padding(
                                    padding: EdgeInsets.symmetric(
                                        horizontal: infoPad.left),
                                    child: playerInfoCard,
                                  ),
                                ],
                              );
                            }

                            final handColumn = Column(
                              mainAxisSize: MainAxisSize.min,
                              crossAxisAlignment: CrossAxisAlignment.center,
                              children: [
                                if (showTurnTimer) ...[
                                  TurnTimerBadge(
                                    state: prov.state!,
                                    isMyTurn: true,
                                    compact: true,
                                  ),
                                  const SizedBox(height: 6),
                                ],
                                handWidget,
                              ],
                            );

                            if (infoPad == EdgeInsets.zero) {
                              return Row(
                                crossAxisAlignment: CrossAxisAlignment.end,
                                children: [
                                  Padding(
                                    padding: const EdgeInsets.only(bottom: 6.0),
                                    child: playerInfoCard,
                                  ),
                                  const SizedBox(width: 8),
                                  Expanded(child: handColumn),
                                ],
                              );
                            }

                            return Stack(
                              alignment: Alignment.bottomCenter,
                              clipBehavior: Clip.none,
                              children: [
                                handColumn,
                                Align(
                                  alignment: Alignment.bottomLeft,
                                  child: Padding(
                                    padding: infoPad,
                                    child: playerInfoCard,
                                  ),
                                ),
                              ],
                            );
                          },
                        ),
                      ),
                    ),

                    // ── Reactions Overlay (Bubbles over player seats) ───────
                    Consumer<GameProvider>(
                      builder: (ctx, prov, _) =>
                          _buildReactionsOverlay(prov, layout),
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

              // ── Double Round Overlay (All-Pass Presentation) ──────────
              if (_showDoubleRoundOverlay)
                Positioned.fill(
                  child: DoubleRoundOverlay(
                    onDismissed: () {
                      if (mounted) {
                        setState(() {
                          _showDoubleRoundOverlay = false;
                        });
                      }
                    },
                  ),
                ),

              // ── Fixed Trump Round Overlay (Championship Rounds 14-18) ───
              if (_showFixedTrumpOverlay && state.fixedTrump != null)
                Positioned.fill(
                  child: FixedTrumpRoundOverlay(
                    roundNumber: state.roundNumber,
                    fixedTrump: state.fixedTrump!,
                    onDismissed: () {
                      if (mounted) {
                        setState(() {
                          _showFixedTrumpOverlay = false;
                        });
                      }
                    },
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildReactionsOverlay(GameProvider prov, GameLayoutMetrics layout) {
    if (prov.activeReactions.isEmpty) return const SizedBox.shrink();

    final state = prov.state;
    if (state == null) return const SizedBox.shrink();

    final isPortrait = layout.isPortrait;
    final reactions = layout.reactionLayout(isPortrait: isPortrait);

    final total = state.players.length;
    final mySeat = prov.me?.seatIndex ?? 0;

    final leftSeat =
        total == 4 ? (mySeat + 3) % 4 : (total == 3 ? (mySeat + 2) % 3 : -1);
    final rightSeat =
        total == 4 ? (mySeat + 1) % 4 : (total == 3 ? (mySeat + 1) % 3 : -1);
    final topSeat = total == 4 ? (mySeat + 2) % 4 : -1;

    final leftPlayer =
        state.players.where((p) => p.seatIndex == leftSeat).firstOrNull;
    final rightPlayer =
        state.players.where((p) => p.seatIndex == rightSeat).firstOrNull;
    final topPlayer =
        state.players.where((p) => p.seatIndex == topSeat).firstOrNull;
    final myPlayer = prov.me;

    return Stack(
      children: [
        // My reaction (bottom)
        if (myPlayer != null && prov.activeReactions.containsKey(myPlayer.id))
          Positioned(
            bottom: reactions.myBottom,
            left: reactions.myLeft,
            child: ReactionBubbleWidget(
              key: ValueKey(prov.activeReactions[myPlayer.id]!.id),
              reaction: prov.activeReactions[myPlayer.id]!,
              anchorAlignment: Alignment.bottomLeft,
            ),
          ),

        // Left opponent reaction
        if (leftPlayer != null &&
            prov.activeReactions.containsKey(leftPlayer.id))
          Positioned(
            left: reactions.sideInset,
            bottom: reactions.sideBottom,
            child: ReactionBubbleWidget(
              key: ValueKey(prov.activeReactions[leftPlayer.id]!.id),
              reaction: prov.activeReactions[leftPlayer.id]!,
              anchorAlignment: Alignment.centerLeft,
            ),
          ),

        // Right opponent reaction
        if (rightPlayer != null &&
            prov.activeReactions.containsKey(rightPlayer.id))
          Positioned(
            right: reactions.sideInset,
            bottom: reactions.sideBottom,
            child: ReactionBubbleWidget(
              key: ValueKey(prov.activeReactions[rightPlayer.id]!.id),
              reaction: prov.activeReactions[rightPlayer.id]!,
              anchorAlignment: Alignment.centerRight,
            ),
          ),

        // Top opponent reaction
        if (topPlayer != null && prov.activeReactions.containsKey(topPlayer.id))
          Positioned(
            top: reactions.topOffset,
            left: 0,
            right: 0,
            child: Center(
              child: ReactionBubbleWidget(
                key: ValueKey(prov.activeReactions[topPlayer.id]!.id),
                reaction: prov.activeReactions[topPlayer.id]!,
                anchorAlignment: Alignment.topCenter,
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildReactionTriggerButton(
      BuildContext context, GameProvider provider, bool isPortrait) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () {
          ReactionPickerSheet.show(
            context,
            onSelectReaction: (emoji, [text]) {
              provider.sendReaction(emoji, text);
            },
          );
        },
        borderRadius: BorderRadius.circular(20),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 8),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                AppTheme.navyDark.withValues(alpha: 0.88),
                AppTheme.surface2.withValues(alpha: 0.82),
              ],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: AppTheme.gold.withValues(alpha: 0.45),
              width: 1.1,
            ),
            boxShadow: [
              BoxShadow(
                color: AppTheme.gold.withValues(alpha: 0.18),
                blurRadius: 12,
                offset: const Offset(0, 2),
              ),
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.35),
                blurRadius: 8,
                offset: const Offset(0, 3),
              ),
            ],
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              AppIcon(
                AppIcons.chatBubbleOutline,
                color: AppTheme.goldLight,
                size: 16,
              ),
              const SizedBox(width: 5),
              Text(
                'تفاعل',
                style: GoogleFonts.cairo(
                  color: AppTheme.cream,
                  fontSize: 11.5,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
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
    final int idx = state.players.indexWhere((p) => p.seatIndex == seatIndex);
    if (idx == -1) return const SizedBox.shrink();
    final player = state.players[idx];

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        PlayerInfoWidget(
          key: _playerKeys[seatIndex],
          player: player,
          state: state,
          isCurrentTurn: _isTurn(state, seatIndex),
          isBidder: state.bidderPlayerId == player.id,
          compact: GameLayoutMetrics.of(context).topOpponentCompact,
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
    final int idx = state.players.indexWhere((p) => p.seatIndex == seatIndex);
    if (idx == -1) return const SizedBox.shrink();
    final player = state.players[idx];

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        PlayerInfoWidget(
          key: _playerKeys[seatIndex],
          player: player,
          state: state,
          isCurrentTurn: _isTurn(state, seatIndex),
          isBidder: state.bidderPlayerId == player.id,
          compact: GameLayoutMetrics.of(context).sideOpponentCompact,
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
              count: player.hand.length, isLeft: isLeft, isRight: !isLeft),
        ),
        const SizedBox(height: 10),
        if (!isLeft)
          _buildReactionTriggerButton(context, provider,
              MediaQuery.of(context).orientation == Orientation.portrait)
        else
          Visibility(
            maintainSize: true,
            maintainAnimation: true,
            maintainState: true,
            visible: false,
            child: _buildReactionTriggerButton(context, provider,
                MediaQuery.of(context).orientation == Orientation.portrait),
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
    LeaveGameDialog.show(
      context,
      onLeave: () async {
        if (provider.isTestMode || provider.isLocal) {
          await provider.reset();
        } else {
          await provider.temporarilyLeaveOngoingGame();
        }
        if (!context.mounted) return;
        Navigator.of(context, rootNavigator: true)
            .pushNamedAndRemoveUntil('/', (route) => false);
      },
    );
  }

  // ── Dialog triggers — UNCHANGED LOGIC ──────────────────────────────────

  // ── Dialog triggers ──────────────────────────────────────────────────

  void _maybeShowDashCallDialog(
      BuildContext context, GameProvider provider, GameState state) {
    if (provider.state == null ||
        provider.status != ConnectionStatus.connected ||
        state.phase != GamePhase.dashCall ||
        !provider.isMyTurn) {
      if (_dashCallDialogOpen) {
        if (Navigator.of(context, rootNavigator: true).canPop()) {
          Navigator.of(context, rootNavigator: true).pop();
        }
        _dashCallDialogOpen = false;
      }
      return;
    }

    final me = provider.me;
    if (me == null || state.dashCallPassed.contains(me.id)) {
      if (_dashCallDialogOpen) {
        if (Navigator.of(context, rootNavigator: true).canPop()) {
          Navigator.of(context, rootNavigator: true).pop();
        }
        _dashCallDialogOpen = false;
      }
      return;
    }

    if (_dashCallDialogOpen) return;

    _dashCallDialogOpen = true;
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => DashCallDialog(
        onDecision: (wantsDashCall) {
          provider.submitDashCall(wantsDashCall);
        },
      ),
    ).then((_) {
      if (mounted) _dashCallDialogOpen = false;
    });
  }

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
        fixedTrump: state.fixedTrump,
        roundNumber: state.roundNumber,
        isDoubleRound: state.isDoubleRound,
        deadlineEpochMs: state.turnDeadlineEpochMs,
        durationSeconds: state.turnDurationSeconds,
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

    final forbidden = GameEngine.getForbiddenDeclaration(state, me.id);
    final maxDeclaration = GameEngine.getMaxAllowedDeclaration(state, me.id);

    int? minDeclaration;
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
        maxDeclaration: maxDeclaration,
        onSubmit: (declared) {
          provider.submitDeclaration(declared);
        },
      ),
    ).then((_) {
      if (mounted) _declarationDialogOpen = false;
    });
  }
}

// ── HiddenCardFan Widget — presentation only ────────────────────────────────
class HiddenCardFan extends StatelessWidget {
  final int count;
  final bool isLeft;
  final bool isRight;

  const HiddenCardFan(
      {super.key,
      required this.count,
      this.isLeft = false,
      this.isRight = false});

  @override
  Widget build(BuildContext context) {
    if (count == 0) return const SizedBox();

    final layout = GameLayoutMetrics.of(context);
    final displayCount = count > 4 ? 4 : count;
    final cardW = layout.hiddenCardWidth;
    final cardH = cardW / 0.65;
    final overlap = layout.hiddenCardOverlap;

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (!isRight) _buildRemainingText(layout),
        if (!isRight)
          SizedBox(width: layout.screenSize == GameScreenSize.phone ? 7 : 9),
        SizedBox(
          width: cardW + (displayCount - 1) * overlap,
          height: cardH,
          child: Stack(
            clipBehavior: Clip.none,
            children: List.generate(displayCount, (i) {
              return Positioned(
                left: i * overlap,
                child: Transform.rotate(
                  angle: (i - (displayCount - 1) / 2) * 0.04,
                  child: Container(
                    width: cardW,
                    height: cardH,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(5),
                      border: Border.all(
                        color: AppTheme.cream.withValues(alpha: 0.14),
                        width: 1,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.35),
                          blurRadius: 5,
                          offset: const Offset(-1.5, 2),
                        ),
                      ],
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(4),
                      child: Image.asset('assets/back.png', fit: BoxFit.cover),
                    ),
                  ),
                ),
              );
            }),
          ),
        ),
        if (isRight)
          SizedBox(width: layout.screenSize == GameScreenSize.phone ? 7 : 9),
        if (isRight) _buildRemainingText(layout),
      ],
    );
  }

  Widget _buildRemainingText(GameLayoutMetrics layout) {
    final fontSize = layout.screenSize == GameScreenSize.phone ? 11.5 : 13.0;
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: layout.screenSize == GameScreenSize.phone ? 7 : 9,
        vertical: 3,
      ),
      decoration: BoxDecoration(
        color: AppTheme.deepNavy.withValues(alpha: 0.78),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(
          color: AppTheme.cream.withValues(alpha: 0.12),
          width: 0.9,
        ),
      ),
      child: Text(
        '$count',
        style: GoogleFonts.cairo(
          color: AppTheme.cream,
          fontSize: fontSize,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }
}
