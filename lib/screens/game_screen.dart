// lib/screens/game_screen.dart
//
// Main game table. Renders the green felt table, all player positions,
// the current trick, the local player's hand, and phase-specific overlays.

import 'dart:math' as math;
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:google_fonts/google_fonts.dart';

import '../core/constants.dart';
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
import '../services/reconnection_manager.dart';
import 'scoring_screen.dart';
import 'match_end_screen.dart';

// ── Fix #4: Singleton painter — never re-allocated on rebuild ───────────────
final _kTablePainter = _PremiumTablePainter();

class GameScreen extends StatefulWidget {
  const GameScreen({super.key});

  @override
  State<GameScreen> createState() => _GameScreenState();
}

class _GameScreenState extends State<GameScreen> {
  bool _bidDialogOpen = false;
  bool _declarationDialogOpen = false;

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

  // ── Fix #1/#9: Dialog triggering moved out of build() ─────────────────────
  void _maybeShowDialogs(GameProvider provider, GameState state, bool isMyTurn) {
    final phase = state.phase;

    if (phase == _lastPhase && isMyTurn == _lastIsMyTurn) return;
    _lastPhase = phase;
    _lastIsMyTurn = isMyTurn;

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
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

    // Phase routing
    if (phase == GamePhase.scoring) {
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

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {
        if (didPop) return;
        _confirmExit(context, provider);
      },
      child: Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [AppTheme.navyDeep, AppTheme.navyDark],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: SafeArea(
          child: Stack(
            children: [
              // ── Table background painter ─────────────────────────
              Positioned.fill(
                child: RepaintBoundary(
                  child: CustomPaint(painter: _kTablePainter),
                ),
              ),

              // ── Top Bar ──────────────────────────────────────────────────
              Positioned(
                top: isPortrait ? 8 : 12,
                left: 12,
                right: 12,
                child: Consumer<GameProvider>(
                  builder: (ctx, prov, _) => _buildTopBar(ctx, prov.state!),
                ),
              ),

              // ── Center Trick Area ───────────────────────────────────────
              Align(
                alignment: Alignment(0, isPortrait ? -0.10 : -0.14),
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

              // ── Opponent: Left ──────────────────────────────────────────
              Positioned(
                left: isPortrait ? 6 : 16,
                top: 0,
                bottom: 0,
                child: Align(
                  alignment: isPortrait ? const Alignment(-1.0, -0.32) : Alignment.centerLeft,
                  child: Consumer<GameProvider>(
                    builder: (ctx, prov, _) {
                      final mySeat = prov.me?.seatIndex ?? 0;
                      final oppSeat = (mySeat + 3) % 4;
                      return KeyedSubtree(
                        key: _areaKeys[oppSeat],
                        child: _buildSideOpponent(prov.state!, oppSeat, prov, isLeft: true),
                      );
                    },
                  ),
                ),
              ),

              // ── Opponent: Right ─────────────────────────────────────────
              Positioned(
                right: isPortrait ? 6 : 16,
                top: 0,
                bottom: 0,
                child: Align(
                  alignment: isPortrait ? const Alignment(1.0, -0.32) : Alignment.centerRight,
                  child: Consumer<GameProvider>(
                    builder: (ctx, prov, _) {
                      final mySeat = prov.me?.seatIndex ?? 0;
                      final oppSeat = (mySeat + 1) % 4;
                      return KeyedSubtree(
                        key: _areaKeys[oppSeat],
                        child: _buildSideOpponent(prov.state!, oppSeat, prov, isLeft: false),
                      );
                    },
                  ),
                ),
              ),

              // ── Opponent: Top ───────────────────────────────────────────
              Positioned(
                top: isPortrait ? 104 : 12,
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
                        child: _buildOpponentStrip(prov.state!, oppSeat, prov),
                      );
                    },
                  ),
                ),
              ),

              // ── Local Player (Me) ───────────────────────────────────────
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
                              builder: (_) => TakenTricksDialog(takenTricks: me.takenTricks),
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

                      final readyBtn = prov.state!.phase == GamePhase.voidCheck
                          ? _buildMyReadyButton(ctx, prov.state!, prov)
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

              // ── Phase overlay labels ─────────────────────────────────────
              Consumer<GameProvider>(
                builder: (ctx, prov, _) =>
                    _buildPhaseOverlay(ctx, prov.state!, prov),
              ),

              // ── Reconnection banner overlay ───────────────────────────────
              // Transparent (SizedBox.shrink) when healthy; shows a slim top
              // spinner while reconnecting, or a full-screen modal on failure.
              Consumer<ReconnectionManager>(
                builder: (ctx, reconnect, _) => ReconnectionBanner(
                  reconnectionState: reconnect.reconnectionState,
                  onRetry: reconnect.retry,
                  onGoHome: () async {
                    await reconnect.dismissAndGoHome();
                    if (ctx.mounted) {
                      ctx.read<GameProvider>().reset();
                      Navigator.pushReplacementNamed(ctx, '/');
                    }
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    ),
  );
}

  // ── Top bar ────────────────────────────────────────────────────────────────

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
                'مغادرة اللعبة',
                style: Theme.of(context).textTheme.headlineMedium,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              Text(
                'هل أنت متأكد أنك تريد مغادرة اللعبة والعودة للرئيسية؟ سيتم فصلك من الغرفة.',
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

  Widget _buildTopBar(BuildContext context, GameState state) {
    // Fix #5: Compute under/over in a single O(n) pass; no intermediate list.
    final isTrickTaking = state.phase == GamePhase.trickTaking;
    int totalDeclared = 0;
    int declarers = 0;
    for (final p in state.players) {
      if (p.declared != null) {
        totalDeclared += p.declared!;
        declarers++;
      }
    }

    String? underOverText;
    Color underOverColor = Colors.grey;
    if (isTrickTaking && declarers == 4) {
      if (totalDeclared < 13) {
        underOverText = 'أندر ${13 - totalDeclared} ↓';
        underOverColor = Colors.lightBlueAccent;
      } else if (totalDeclared > 13) {
        underOverText = 'أوفر ${totalDeclared - 13} ↑';
        underOverColor = AppTheme.suitRed;
      }
    }

    String? bidderName;
    if (state.bidderPlayerId != null) {
      bidderName = state.playerById(state.bidderPlayerId!).name;
    }

    Widget buildPill(List<Widget> children) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(30),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: AppTheme.navyDark.withValues(alpha: 0.6),
              borderRadius: BorderRadius.circular(30),
              border: Border.all(
                  color: Colors.white.withValues(alpha: 0.15), width: 1.5),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.2),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                )
              ],
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: children,
            ),
          ),
        ),
      );
    }

    final isPortrait = MediaQuery.of(context).orientation == Orientation.portrait;

    final trumpWidget = state.trumpSuit != null
        ? Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
            decoration: BoxDecoration(
              color: AppTheme.surfaceCard.withValues(alpha: 0.5),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: AppTheme.gold.withValues(alpha: 0.3)),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text('القطوع: ',
                    style: TextStyle(color: AppTheme.textSecondary, fontSize: 10)),
                Text(
                  '${state.trumpSuit!.label} ${state.trumpSuit!.arabicName}',
                  style: TextStyle(
                    color: state.trumpSuit!.color == SuitColor.red
                        ? AppTheme.suitRed
                        : AppTheme.textPrimary,
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          )
        : null;

    if (isPortrait) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              buildPill([
                InkWell(
                  onTap: () => _confirmExit(context, context.read<GameProvider>()),
                  child: const Icon(Icons.exit_to_app_rounded,
                      color: AppTheme.errorRed, size: 18),
                ),
                const SizedBox(width: 6),
                _chip('الجولة ${state.roundNumber}', AppTheme.gold),
                const SizedBox(width: 4),
                _chip(_phaseArabic(state), Colors.lightBlueAccent),
              ]),
              if (trumpWidget != null) buildPill([trumpWidget]),
            ],
          ),
          if (bidderName != null || underOverText != null) ...[
            const SizedBox(height: 4),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                buildPill([
                  if (bidderName != null) ...[
                    _chip('الكار الكبير: $bidderName', AppTheme.gold),
                    const SizedBox(width: 4),
                  ],
                  if (underOverText != null)
                    _chip(underOverText, underOverColor),
                ]),
              ],
            ),
          ],
        ],
      );
    }

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      physics: const BouncingScrollPhysics(),
      child: SizedBox(
        width: math.max(MediaQuery.of(context).size.width - 32, 600),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Left side: Core game info & Exit
            buildPill([
              InkWell(
                onTap: () => _confirmExit(context, context.read<GameProvider>()),
                child: const Icon(Icons.exit_to_app_rounded,
                    color: AppTheme.errorRed, size: 18),
              ),
              const SizedBox(width: 8),
              _chip('الجولة ${state.roundNumber}', AppTheme.gold),
              const SizedBox(width: 4),
              _chip(_phaseArabic(state), Colors.lightBlueAccent),
            ]),

            // Right side: Bidder, Under/Over, Trump Suit
            if (bidderName != null || underOverText != null || state.trumpSuit != null)
              buildPill([
                if (bidderName != null) ...[
                  _chip('الكار الكبير: $bidderName', AppTheme.gold),
                  const SizedBox(width: 4),
                ],
                if (underOverText != null) ...[
                  _chip(underOverText, underOverColor),
                  const SizedBox(width: 4),
                ],
                if (trumpWidget != null) trumpWidget,
              ]),
          ],
        ),
      ),
    );
  }

  Widget _chip(String text, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: const BorderRadius.all(Radius.circular(20)),
        border: Border.all(color: color.withValues(alpha: 0.4)),
      ),
      child: Text(text,
          style: TextStyle(
              color: color, fontSize: 10, fontWeight: FontWeight.w600)),
    );
  }

  String _phaseArabic(GameState state) {
    switch (state.phase) {
      case GamePhase.voidCheck:
        return 'جاهزون: ${state.voidCheckPassed.length}/4';
      case GamePhase.auction:
        return 'المزاد';
      case GamePhase.declarations:
        return 'التصريح';
      case GamePhase.trickTaking:
        return 'اللعب';
      case GamePhase.scoring:
        return 'النتائج';
      default:
        return '';
    }
  }

  // ── Opponent strips ─────────────────────────────────────────────────────────

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
                trick: player.takenTricks.isNotEmpty ? player.takenTricks.last : null,
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
                trick: player.takenTricks.isNotEmpty ? player.takenTricks.last : null,
                playerName: player.name,
              ),
            );
          },
          child: HiddenCardFan(count: player.hand.length, isLeft: isLeft, isRight: !isLeft),
        ),
      ],
    );
  }

  // ── Phase overlays ──────────────────────────────────────────────────────────

  Widget _buildPhaseOverlay(
      BuildContext context, GameState state, GameProvider provider) {
    final isPortrait = MediaQuery.of(context).orientation == Orientation.portrait;
    final bottomOffset = isPortrait ? 190.0 : 130.0;

    if (state.phase == GamePhase.voidCheck) {
      if (state.voidDeclaringPlayerId != null) {
        final declarer = state.playerById(state.voidDeclaringPlayerId!);
        final hasRejected = state.voidRedealRejections.contains(provider.myPlayerId);

        return Positioned(
          bottom: bottomOffset,
          left: 16,
          right: 16,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _infoChip('${declarer.name} لديه سويتة فاضية!'),
              const SizedBox(height: 6),
              if (hasRejected)
                _infoChip("في انتظار باقي اللاعبين...")
              else
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    ElevatedButton(
                      onPressed: () => provider.rejectRedeal(),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.grey.shade800,
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                        textStyle: GoogleFonts.cairo(fontSize: 13, fontWeight: FontWeight.bold),
                      ),
                      child: const Text('إكمال اللعب'),
                    ),
                    const SizedBox(width: 12),
                    ElevatedButton(
                      onPressed: () => provider.approveRedeal(),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppTheme.errorRed,
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                        textStyle: GoogleFonts.cairo(fontSize: 13, fontWeight: FontWeight.bold),
                      ),
                      child: const Text('إعادة التوزيع'),
                    ),
                  ],
                ),
            ],
          ),
        );
      }

      return Positioned(
        bottom: bottomOffset,
        left: 16,
        right: 16,
        child: Center(
          child: _infoChip("اضغط على 'جاهز' للبدء"),
        ),
      );
    }
    return const SizedBox.shrink();
  }

  Widget _infoChip(String text) {
    return Text(
      text,
      textAlign: TextAlign.center,
      style: GoogleFonts.cairo(
        color: AppTheme.mintSoft,
        fontSize: 13,
        fontWeight: FontWeight.w700,
        shadows: const [
          Shadow(color: Colors.black87, blurRadius: 8, offset: Offset(0, 2)),
        ],
      ),
    );
  }

  Widget _buildMyReadyButton(
      BuildContext context, GameState state, GameProvider provider) {
    final isReady = state.voidCheckPassed.contains(provider.myPlayerId);
    return InkWell(
      onTap: () {
        if (isReady) {
          provider.unready();
        } else {
          provider.confirmNoVoid();
        }
      },
      borderRadius: BorderRadius.circular(20),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 220),
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
        decoration: BoxDecoration(
          color: isReady ? const Color(0xFF10B981) : AppTheme.gold,
          borderRadius: BorderRadius.circular(20),
          boxShadow: isReady
              ? AppTheme.neumorphicTurnGlow(const Color(0xFF10B981))
              : AppTheme.neumorphicTurnGlow(AppTheme.gold),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              isReady ? Icons.check_circle_rounded : Icons.play_arrow_rounded,
              size: 20,
              color: isReady ? Colors.white : AppTheme.navyDark,
            ),
            const SizedBox(width: 6),
            Text(
              isReady ? 'أنا جاهز ✓' : 'جاهز للعب',
              style: GoogleFonts.cairo(
                color: isReady ? Colors.white : AppTheme.navyDark,
                fontSize: 14,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── Dialog triggers ─────────────────────────────────────────────────────────

  void _maybeShowBidDialog(
      BuildContext context, GameProvider provider, GameState state) {
    if (state.phase != GamePhase.auction) {
      if (_bidDialogOpen) {
        Navigator.of(context, rootNavigator: true).pop();
        _bidDialogOpen = false;
      }
      return;
    }

    if (!provider.isMyTurn) {
      if (_bidDialogOpen) {
        Navigator.of(context, rootNavigator: true).pop();
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
    ).then((_) => _bidDialogOpen = false);
  }

  void _maybeShowDeclarationDialog(
      BuildContext context, GameProvider provider, GameState state) {
    if (state.phase != GamePhase.declarations || !provider.isMyTurn) {
      if (_declarationDialogOpen) {
        Navigator.of(context, rootNavigator: true).pop();
        _declarationDialogOpen = false;
      }
      return;
    }

    final me = provider.me;
    if (me == null || me.declared != null) {
      if (_declarationDialogOpen) {
        Navigator.of(context, rootNavigator: true).pop();
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
        forbiddenDeclaration: forbidden,
        minDeclaration: minDeclaration,
        onSubmit: (declared) {
          provider.submitDeclaration(declared);
        },
      ),
    ).then((_) => _declarationDialogOpen = false);
  }
}

class _PremiumTablePainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final isPortrait = size.height > size.width;

    final Rect tableRect;
    if (isPortrait) {
      final radius = size.width * 0.45;
      tableRect = Rect.fromCircle(
        center: Offset(size.width / 2, size.height * 0.42),
        radius: radius,
      );
    } else {
      tableRect = Rect.fromCenter(
        center: Offset(size.width / 2, size.height / 2),
        width: size.width * 0.75,
        height: size.height * 0.85,
      );
    }
    
    // Table shadow
    final shadowPaint = Paint()
      ..color = Colors.black.withValues(alpha: 0.6)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 20);
    canvas.drawOval(tableRect.translate(0, 10), shadowPaint);
    
    // Wooden Frame
    final framePaint = Paint()
      ..color = const Color(0xFF3E2723) // Dark Brown
      ..style = PaintingStyle.fill;
    canvas.drawOval(tableRect, framePaint);
    
    // Green Felt
    final feltRect = tableRect.deflate(12);
    
    final feltGradient = RadialGradient(
      colors: [
        AppTheme.navyDeep.withValues(alpha: 0.8),
        AppTheme.navyDark,
      ],
      stops: const [0.3, 1.0],
    ).createShader(feltRect);
    
    final feltPaint = Paint()
      ..shader = feltGradient
      ..style = PaintingStyle.fill;
    canvas.drawOval(feltRect, feltPaint);
    
    // Inner gold ring
    final goldPaint = Paint()
      ..color = AppTheme.gold.withValues(alpha: 0.2)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2;
    canvas.drawOval(feltRect.deflate(14), goldPaint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

// ── HiddenCardFan Widget ─────────────────────────────────────────────────────
class HiddenCardFan extends StatelessWidget {
  final int count;
  final bool isLeft;
  final bool isRight;

  const HiddenCardFan({super.key, required this.count, this.isLeft = false, this.isRight = false});

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
                    color: AppTheme.cardBack,
                    borderRadius: BorderRadius.circular(4),
                    border: Border.all(color: Colors.white24, width: 1),
                    boxShadow: const [
                      BoxShadow(color: Colors.black26, blurRadius: 4, offset: Offset(-2, 2)),
                    ],
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
        color: Colors.black45,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Text(
        '$count',
        style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold),
      ),
    );
  }
}
