// lib/widgets/trick_area.dart
//
// Center table area showing the 4 card slots for the current trick.

import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../core/models/game_state.dart';
import '../core/models/card.dart';
import '../theme/app_theme.dart';
import 'playing_card_widget.dart';

class TrickArea extends StatefulWidget {
  final GameState state;
  final String myPlayerId;
  final Map<int, GlobalKey> playerKeys;
  final Map<int, GlobalKey> areaKeys;

  const TrickArea({
    super.key,
    required this.state,
    required this.myPlayerId,
    required this.playerKeys,
    required this.areaKeys,
  });

  @override
  State<TrickArea> createState() => _TrickAreaState();
}

class _TrickAreaState extends State<TrickArea>
    with SingleTickerProviderStateMixin {
  List<TrickCard>? _sweepingTrick;
  int? _winnerSeat;
  bool _isSweeping = false;
  List<TrickCard> _trickCache = [];
  final GlobalKey _trickAreaKey = GlobalKey();

  // Native animation controller for the pile-fly Phase 3.
  late final AnimationController _sweepCtrl;

  @override
  void initState() {
    super.initState();
    _trickCache = List.from(widget.state.currentTrick);
    _sweepCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 650),
    );
  }

  @override
  void dispose() {
    _sweepCtrl.dispose();
    super.dispose();
  }

  @override
  void didUpdateWidget(TrickArea oldWidget) {
    super.didUpdateWidget(oldWidget);

    if (_trickCache.length == 4 && widget.state.currentTrick.isEmpty) {
      final winnerSeat = widget.state.trickLeaderSeatIndex;

      // Compute the screen-geometry direction vector for the winning player.
      // We use MediaQuery here (screen size is available without a context)
      // and derive the direction purely from relSeat so there is zero chance
      // of horizontal / vertical axis confusion.
      //
      //  relSeat 0 → me (bottom)  → pile flies DOWN    (+dy)
      //  relSeat 1 → right opp.   → pile flies RIGHT   (+dx)
      //  relSeat 2 → top opp.     → pile flies UP      (-dy)
      //  relSeat 3 → left opp.    → pile flies LEFT    (-dx)
      // (relSeat is computed fresh inside build() from _winnerSeat + mySeat)

      setState(() {
        _sweepingTrick = List.from(_trickCache);
        _winnerSeat = winnerSeat;
        _isSweeping = true;
      });

      // Reset and start the Phase 3 controller after Phase 1 finishes (200 ms).
      _sweepCtrl.reset();
      Future.delayed(const Duration(milliseconds: 200), () {
        if (mounted) _sweepCtrl.forward();
      });

      // Clear sweep state after the full animation.
      Future.delayed(const Duration(milliseconds: 1050), () {
        if (mounted) {
          setState(() {
            _isSweeping = false;
            _sweepingTrick = null;
          });
          _sweepCtrl.reset();
        }
      });
    }
    _trickCache = List.from(widget.state.currentTrick);
  }

  /// Maps a relative seat index to a directional offset vector.
  /// [screenSize] is used when available; otherwise a unit placeholder is
  /// returned and the caller must multiply by actual screen dimensions.
  static Offset _relSeatToOffset(int relSeat, Size? screenSize) {
    // Fractions of screen dimension to travel in the winner's direction.
    const double vertFrac = 0.45; // fraction of screen height for up/down
    const double horizFrac = 0.45; // fraction of screen width  for left/right
    final h = screenSize?.height ?? 1.0;
    final w = screenSize?.width ?? 1.0;
    switch (relSeat) {
      case 0:
        return Offset(0, h * vertFrac);   // ↓ bottom (me)
      case 1:
        return Offset(w * horizFrac, 0);  // → right
      case 2:
        return Offset(0, -h * vertFrac);  // ↑ top
      case 3:
        return Offset(-w * horizFrac, 0); // ← left
      default:
        return Offset.zero;
    }
  }

  @override
  Widget build(BuildContext context) {
    final trickToDisplay =
        _isSweeping ? _sweepingTrick! : widget.state.currentTrick;

    final played = <int, TrickCard>{};
    for (final tc in trickToDisplay) {
      final seat = widget.state.playerById(tc.playerId).seatIndex;
      played[seat] = tc;
    }

    final me = widget.state.players.firstWhere(
      (p) => p.id == widget.myPlayerId,
      orElse: () => widget.state.players.first,
    );
    final mySeat = me.seatIndex;

    return RepaintBoundary(
      child: AspectRatio(
        aspectRatio: 1.0,
        child: LayoutBuilder(
          builder: (context, constraints) {
            final size = constraints.maxWidth;
            final isPortrait = MediaQuery.of(context).orientation == Orientation.portrait;
            final cardW = size * (isPortrait ? 0.27 : 0.31);
            final cardH = cardW / playingCardAspectRatio;

            Widget animatedCardFor(int relativeSeat) {
              final absSeat = (mySeat + relativeSeat) % 4;
              final tc = played[absSeat];
              
              Widget cardWidget = _AnimatedCard(
                trickCard: tc,
                width: cardW,
                relativeSeat: relativeSeat,
                isSweeping: _isSweeping,
              );

              if (tc != null) {
                final rand = math.Random(tc.card.id.hashCode);
                final rotOffset = (rand.nextDouble() * 24 - 12) * math.pi / 180.0;
                final dx = rand.nextDouble() * 20 - 10;
                final dy = rand.nextDouble() * 20 - 10;

                cardWidget = Transform.translate(
                  offset: Offset(dx, dy),
                  child: Transform.rotate(
                    angle: rotOffset,
                    child: cardWidget,
                  ),
                );
              }

              return cardWidget;
            }

            // ── Phase 1 offsets (cards collapse from their slot to center) ──
            final dyOffset = (size / 2) - (size * 0.02 + cardH / 2);
            final dxOffset = (size / 2) - (size * 0.02 + cardW / 2);

            // ── Phase 3 target: recompute with real screen size ──────────────
            // We re-derive relSeat here so the vector is always fresh.
            final screenSize = MediaQuery.of(context).size;
            Offset phase3Target = Offset.zero;
            if (_isSweeping && _winnerSeat != null) {
              final relSeat = (_winnerSeat! - mySeat + 4) % 4;
              phase3Target = _relSeatToOffset(relSeat, screenSize);
            }

            // ── Sweep pile widget (Phase 1 + Phase 2 via flutter_animate) ───
            Widget buildSweepPile() {
              Widget sweepingCardFor(int relativeSeat, double dx, double dy) {
                final absSeat = (mySeat + relativeSeat) % 4;
                final tc = played[absSeat] ?? played.values.first;
                final card = _AnimatedCard(
                  trickCard: tc,
                  width: cardW,
                  relativeSeat: relativeSeat,
                  isSweeping: true,
                );

                final rand = math.Random(tc.hashCode);
                final rotOffset =
                    (rand.nextDouble() * 4 - 2) * math.pi / 180.0;
                final pileOffsetDx = (rand.nextDouble() * 6 - 3);
                final pileOffsetDy = (rand.nextDouble() * 6 - 3);

                return card
                    .animate()
                    // Phase 1: each card slides to center (200 ms)
                    .move(
                      begin: Offset(dx, dy),
                      end: const Offset(0, 0),
                      duration: 200.ms,
                      curve: Curves.easeInOutCubic,
                    )
                    // Phase 2: tiny random pile scatter + tilt (instant)
                    .then()
                    .move(
                      end: Offset(pileOffsetDx, pileOffsetDy),
                      duration: 1.ms,
                    )
                    .rotate(
                      end: rotOffset,
                      duration: 1.ms,
                    );
              }

              return Stack(
                alignment: Alignment.center,
                clipBehavior: Clip.none,
                children: [
                  sweepingCardFor(2, 0, -dyOffset),
                  sweepingCardFor(3, -dxOffset, 0),
                  sweepingCardFor(1, dxOffset, 0),
                  sweepingCardFor(0, 0, dyOffset),
                ],
              );
            }

            return SizedBox(
              key: _trickAreaKey,
              width: size,
              height: size,
              child: Stack(
                alignment: Alignment.center,
                clipBehavior: Clip.none,
                children: [
                  // Trump indicator
                  if (widget.state.trumpSuit != null)
                    Positioned(
                      child: Text(
                        widget.state.trumpSuit!.label,
                        style: TextStyle(
                          fontSize: size * 0.15,
                          color: AppTheme.gold.withValues(alpha: 0.3),
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),

                  // 2. Cards — normal play OR sweep
                  if (!_isSweeping)
                    Stack(
                      alignment: Alignment.center,
                      clipBehavior: Clip.none,
                      children: [
                        Positioned(
                            top: size * 0.02, child: animatedCardFor(2)),
                        Positioned(
                            left: size * 0.02, child: animatedCardFor(3)),
                        Positioned(
                            right: size * 0.02, child: animatedCardFor(1)),
                        Positioned(
                            bottom: size * 0.02, child: animatedCardFor(0)),
                      ],
                    )
                  else
                    // Phase 3: AnimationController drives the pile to the winner.
                    // We use a CurvedAnimation + AnimatedBuilder so we own every
                    // pixel of dx and dy — no flutter_animate involved here.
                    AnimatedBuilder(
                      animation: _sweepCtrl,
                      builder: (ctx, child) {
                        final curve = CurvedAnimation(
                          parent: _sweepCtrl,
                          curve: Curves.easeOutCubic,
                        );
                        final t = curve.value;

                        // Translate the pile toward the winner
                        final dx = phase3Target.dx * t;
                        final dy = phase3Target.dy * t;

                        // Subtle rotation and scale during flight
                        final rotation = t * 10 * math.pi / 180.0;
                        final scale = 1.0 - 0.15 * t;

                        // Fade out in the last 20% of the animation
                        final opacity = t >= 0.80
                            ? (1.0 - (t - 0.80) / 0.20).clamp(0.0, 1.0)
                            : 1.0;

                        return Opacity(
                          opacity: opacity,
                          child: Transform.translate(
                            offset: Offset(dx, dy),
                            child: Transform.rotate(
                              angle: rotation,
                              alignment: Alignment.center,
                              child: Transform.scale(
                                scale: scale,
                                alignment: Alignment.center,
                                child: child,
                              ),
                            ),
                          ),
                        );
                      },
                      child: buildSweepPile(),
                    ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }
}

class _AnimatedCard extends StatelessWidget {
  final TrickCard? trickCard;
  final double width;
  final int relativeSeat;
  final bool isSweeping;

  const _AnimatedCard({
    this.trickCard,
    required this.width,
    required this.relativeSeat,
    this.isSweeping = false,
  });

  @override
  Widget build(BuildContext context) {
    if (trickCard == null) {
      return SizedBox(
        width: width,
        height: width / playingCardAspectRatio,
      );
    }

    if (isSweeping) {
      return PlayingCardWidget(
        card: trickCard!.card,
        width: width,
        playable: false,
      );
    }

    // Slide-in animation when the card is first played
    return TweenAnimationBuilder<double>(
      key: ValueKey(trickCard!.card.id),
      tween: Tween(begin: 0.0, end: 1.0),
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeOutCubic,
      builder: (context, val, child) {
        double dx = 0;
        double dy = 0;
        final offsetDist = 50.0 * (1 - val);
        switch (relativeSeat) {
          case 0:
            dy = offsetDist;
            break; // slide up from bottom
          case 1:
            dx = offsetDist;
            break; // slide left from right
          case 2:
            dy = -offsetDist;
            break; // slide down from top
          case 3:
            dx = -offsetDist;
            break; // slide right from left
        }
        return Transform.translate(
          offset: Offset(dx, dy),
          child: Opacity(
            opacity: val,
            child: child,
          ),
        );
      },
      child: PlayingCardWidget(
        card: trickCard!.card,
        width: width,
        playable: false,
      ),
    );
  }
}
