// lib/widgets/player_hand.dart
//
// Two overlying palm-fan rows for the local player (full faces readable).
// Holding a card for 2 seconds triggers the once-per-round Earthquake Strike!

import 'dart:async';
import 'dart:io' show Platform;
import 'dart:math' as math;
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../core/models/card.dart';
import '../core/models/game_state.dart';
import '../core/models/player.dart';
import '../core/game_engine.dart';
import '../core/events/estimation_event_bus.dart';
import '../core/events/estimation_game_events.dart';
import 'earthquake/earthquake_strike_visuals.dart';
import 'earthquake/earthquake_timing.dart';
import 'playing_card_widget.dart';

typedef EarthquakeStrikeCallback = void Function(
  PlayingCard card, {
  Offset? flightOrigin,
  Size? cardSize,
});

class PlayerHand extends StatefulWidget {
  final List<PlayingCard> hand;
  final bool isMyTurn;
  final GameState? state;
  final Player? me;
  final void Function(PlayingCard card) onPlayCard;
  final EarthquakeStrikeCallback? onEarthquakeStrike;

  const PlayerHand({
    super.key,
    required this.hand,
    required this.isMyTurn,
    required this.onPlayCard,
    this.onEarthquakeStrike,
    this.state,
    this.me,
  });

  @override
  State<PlayerHand> createState() => _PlayerHandState();
}

class _PlayerHandState extends State<PlayerHand>
    with SingleTickerProviderStateMixin {
  // ValueNotifier — card highlight; no setState needed.
  final _selected = ValueNotifier<PlayingCard?>(null);

  // ── Earthquake Strike State ──────────────────────────────────────────────
  static const Duration _kEarthquakeHoldDuration = Duration(milliseconds: 2000);

  int? _lastEarthquakeRound;
  PlayingCard? _chargingCard;
  bool _isSlamming = false;
  final GlobalKey _chargingCardKey = GlobalKey();
  Timer? _impactPlayTimer;

  late final AnimationController _chargeCtrl;
  Timer? _hapticTimer;

  bool get canUseEarthquake =>
      widget.state != null &&
      _lastEarthquakeRound != widget.state!.roundNumber;

  @override
  void initState() {
    super.initState();

    _chargeCtrl = AnimationController(
      vsync: this,
      duration: _kEarthquakeHoldDuration,
    );

    _chargeCtrl.addStatusListener((status) {
      if (status == AnimationStatus.completed &&
          _chargingCard != null &&
          !_isSlamming) {
        _executeEarthquakeStrike(_chargingCard!);
      }
    });
  }

  // ── Drag & Swipe-to-Play State ──────────────────────────────────────────
  PlayingCard? _pointerDownCard;
  Offset? _pointerDownPos;
  DateTime? _pointerDownTime;
  PlayingCard? _draggedCard;
  final ValueNotifier<Offset> _dragOffsetNotifier =
      ValueNotifier<Offset>(Offset.zero);

  @override
  void dispose() {
    _hapticTimer?.cancel();
    _hapticTimer = null;
    _impactPlayTimer?.cancel();
    _impactPlayTimer = null;
    _chargeCtrl.stop(canceled: false);
    _chargeCtrl.dispose();
    _selected.dispose();
    _dragOffsetNotifier.dispose();
    super.dispose();
  }

  bool _isPlayable(PlayingCard card) {
    if (!widget.isMyTurn) return false;
    if (widget.state?.phase != GamePhase.trickTaking) return false;
    if (widget.me == null || widget.state == null) return false;
    return GameEngine.canPlayCard(widget.state!, widget.me!, card);
  }

  void _handleTap(PlayingCard card) {
    if (!widget.isMyTurn || widget.state?.phase != GamePhase.trickTaking) {
      return;
    }
    if (!_isPlayable(card)) return;

    if (_selected.value == card) {
      widget.onPlayCard(card);
      _selected.value = null;
    } else {
      _selected.value = card;
    }
  }

  void _onPointerDown(PointerDownEvent event, PlayingCard card) {
    if (!widget.isMyTurn ||
        widget.state?.phase != GamePhase.trickTaking ||
        !_isPlayable(card) ||
        _isSlamming) {
      return;
    }

    _pointerDownCard = card;
    _pointerDownPos = event.position;
    _pointerDownTime = DateTime.now();
    _draggedCard = card;
    _dragOffsetNotifier.value = Offset.zero;

    if (canUseEarthquake) {
      setState(() {
        _chargingCard = card;
      });

      _chargeCtrl.reset();
      _chargeCtrl.forward();

      _hapticTimer?.cancel();
      _hapticTimer = null;
      try {
        if (!kIsWeb && !Platform.environment.containsKey('FLUTTER_TEST')) {
          int pulseCount = 0;
          _hapticTimer =
              Timer.periodic(const Duration(milliseconds: 400), (timer) {
            if (!mounted || _chargingCard == null) {
              timer.cancel();
              _hapticTimer = null;
              return;
            }
            pulseCount++;
            if (pulseCount <= 2) {
              HapticFeedback.lightImpact();
            } else if (pulseCount <= 4) {
              HapticFeedback.mediumImpact();
            } else {
              HapticFeedback.heavyImpact();
            }
          });
        }
      } catch (_) {}
    }
  }

  void _onPointerMove(PointerMoveEvent event, PlayingCard card) {
    if (_pointerDownCard != card || _isSlamming) return;
    if (_pointerDownPos == null) return;

    final dx = event.position.dx - _pointerDownPos!.dx;
    final dy = event.position.dy - _pointerDownPos!.dy;

    if (dy < -10 || dx.abs() > 14) {
      if (_chargingCard != null) {
        _cancelCharge();
      }
    }

    final clampedDy = dy.clamp(-230.0, 10.0);
    final clampedDx = (dx * 0.45).clamp(-80.0, 80.0);
    _dragOffsetNotifier.value = Offset(clampedDx, clampedDy);
  }

  void _onPointerUp(PointerUpEvent event, PlayingCard card) {
    if (_isSlamming) return;

    final downCard = _pointerDownCard;
    _pointerDownCard = null;
    _pointerDownPos = null;
    final downTime = _pointerDownTime;
    _pointerDownTime = null;

    final currentDrag = _dragOffsetNotifier.value;
    final upwardDist = -currentDrag.dy;
    final elapsedMs = downTime != null
        ? DateTime.now().difference(downTime).inMilliseconds
        : 500;

    _dragOffsetNotifier.value = Offset.zero;
    _draggedCard = null;

    final bool isSwipeThrow =
        (upwardDist >= 35.0) || (upwardDist >= 18.0 && elapsedMs <= 350);

    if (isSwipeThrow && downCard == card && _isPlayable(card)) {
      _cancelCharge();
      HapticFeedback.mediumImpact();
      widget.onPlayCard(card);
      _selected.value = null;
      return;
    }

    if (_chargingCard != null) {
      final progress = _chargeCtrl.value;
      if (progress >= 0.95 || _chargeCtrl.isCompleted) {
        _executeEarthquakeStrike(_chargingCard!);
      } else {
        _cancelCharge();
        if (progress < 0.20) {
          _handleTap(card);
        }
      }
    } else if (downCard == card) {
      _handleTap(card);
    }
  }

  void _onPointerCancel(PointerCancelEvent event, PlayingCard card) {
    _pointerDownCard = null;
    _pointerDownPos = null;
    _pointerDownTime = null;
    _draggedCard = null;
    _dragOffsetNotifier.value = Offset.zero;
    if (_chargingCard != null && !_isSlamming) {
      _cancelCharge();
    }
  }

  void _cancelCharge() {
    _hapticTimer?.cancel();
    _hapticTimer = null;
    if (_chargeCtrl.isAnimating) {
      _chargeCtrl.stop(canceled: false);
    }
    _chargeCtrl.reset();
    if (mounted && _chargingCard != null) {
      setState(() {
        _chargingCard = null;
      });
    }
  }

  (Offset?, Size?) _measureChargingCard() {
    final ctx = _chargingCardKey.currentContext;
    if (ctx == null) return (null, null);
    final box = ctx.findRenderObject() as RenderBox?;
    if (box == null || !box.hasSize) return (null, null);
    final topLeft = box.localToGlobal(Offset.zero);
    final size = box.size;
    return (topLeft + Offset(size.width / 2, size.height / 2), size);
  }

  void _executeEarthquakeStrike(PlayingCard card) {
    _pointerDownCard = null;
    _pointerDownPos = null;
    _pointerDownTime = null;
    _hapticTimer?.cancel();
    _hapticTimer = null;
    if (_isSlamming) return;

    _chargeCtrl.stop();

    final measured = _measureChargingCard();
    final flightOrigin = measured.$1;
    final cardSize = measured.$2;

    setState(() {
      _isSlamming = true;
      _lastEarthquakeRound = widget.state?.roundNumber;
    });

    if (widget.onEarthquakeStrike != null) {
      widget.onEarthquakeStrike!(
        card,
        flightOrigin: flightOrigin,
        cardSize: cardSize,
      );
    } else {
      EstimationEventBus.instance.fire(
        EarthquakeStrikeUsed(
          playerId: widget.me?.id ?? '',
          playerName: widget.me?.name ?? 'Player',
          card: card,
          roundNumber: widget.state?.roundNumber ?? 1,
          flightOriginGlobal: flightOrigin,
          flightCardSize: cardSize,
        ),
      );
    }

    // Hand card hidden; overlay flies it. Commit to table on impact.
    _impactPlayTimer?.cancel();
    _impactPlayTimer = Timer(EarthquakeTiming.impactDelay, () {
      if (!mounted) return;
      EarthquakeStrikeVisuals.markSkipIntro(card.id);
      widget.onPlayCard(card);
      _selected.value = null;
      setState(() {
        _chargingCard = null;
        _isSlamming = false;
      });
    });
  }

  Widget _buildFanRow({
    required List<PlayingCard> cards,
    required List<int> originalIndices,
    required double cardWidth,
    required double cardHeight,
    required PlayingCard? selected,
    required List<bool> playable,
    required bool isTrickTurn,
    required double availableWidth,
    required bool isPortrait,
  }) {
    if (cards.isEmpty) return const SizedBox.shrink();

    final n = cards.length;
    final center = (n - 1) / 2.0;

    final fitted =
        n <= 1 ? cardWidth : (availableWidth - cardWidth) / (n - 1);
    final step = fitted.clamp(cardWidth * 0.78, cardWidth + 2.0);

    final halfAngle = (isPortrait ? 0.028 : 0.018) * (n - 1);
    final clampedHalf = halfAngle.clamp(
      isPortrait ? 0.06 : 0.04,
      isPortrait ? 0.22 : 0.14,
    );

    final arcHeight = isPortrait
        ? (4.0 + n * 0.5).clamp(4.0, 10.0)
        : (3.0 + n * 0.3).clamp(3.0, 7.0);

    final fanWidth = cardWidth + (n - 1) * step;
    final fanHeight = cardHeight;

    return SizedBox(
      width: fanWidth,
      height: fanHeight,
      child: Stack(
        clipBehavior: Clip.none,
        alignment: Alignment.bottomCenter,
        children: [
          for (int i = 0; i < n; i++)
            Builder(
              builder: (context) {
                final t = n > 1 ? (i - center) / center : 0.0;
                final fanAngle = t * clampedHalf;
                final arcY = (1.0 - t * t) * arcHeight;
                final oi = originalIndices[i];

                return _buildSingleCardItem(
                  card: cards[i],
                  left: i * step,
                  fanAngle: fanAngle,
                  arcY: arcY,
                  isPlayable: playable[oi],
                  dimmed: isTrickTurn && !playable[oi],
                  selected: selected == cards[i],
                  cardWidth: cardWidth,
                  cardHeight: cardHeight,
                );
              },
            ),
        ],
      ),
    );
  }

  Widget _buildSingleCardItem({
    required PlayingCard card,
    required double left,
    required double fanAngle,
    required double arcY,
    required bool isPlayable,
    required bool dimmed,
    required bool selected,
    required double cardWidth,
    required double cardHeight,
  }) {
    final isThisCardCharging = _chargingCard == card;
    final hideForFlight = isThisCardCharging && _isSlamming;

    return AnimatedBuilder(
      key: ValueKey(card.id),
      animation: Listenable.merge([_chargeCtrl, _dragOffsetNotifier]),
      builder: (context, _) {
        double offsetY = selected ? -14.0 : 0.0;
        double offsetX = 0.0;
        double scale = selected ? 1.05 : 1.0;
        double shakeX = 0.0;
        double shakeY = 0.0;
        double shakeAngle = 0.0;
        final baseAngle = selected ? fanAngle * 0.2 : fanAngle;

        final isThisCardDragging = _draggedCard == card;
        if (isThisCardDragging) {
          final dragOffset = _dragOffsetNotifier.value;
          offsetY += dragOffset.dy;
          offsetX += dragOffset.dx;
          shakeAngle += (dragOffset.dx / 220.0).clamp(-0.2, 0.2);
          if (dragOffset.dy < -10) {
            scale = 1.06;
          }
        }

        if (isThisCardCharging && !_isSlamming) {
          final progress = _chargeCtrl.value;
          final riseCurve = Curves.easeOutCubic.transform(progress);
          offsetY = -16.0 - riseCurve * 84.0;
          scale = 1.0 + riseCurve * 0.38;

          final time = progress * 75.0;
          final intensity = (2.0 + 8.5 * progress);
          shakeX = math.sin(time * 3.4) * intensity;
          shakeY = math.cos(time * 2.7) * (intensity * 0.7);
          shakeAngle = math.sin(time * 2.1) * (0.05 * progress);
        }

        final cardWidget = Opacity(
          opacity: hideForFlight ? 0.0 : 1.0,
          child: Stack(
            key: isThisCardCharging ? _chargingCardKey : null,
            clipBehavior: Clip.none,
            alignment: Alignment.center,
            children: [
              if (isThisCardCharging && !_isSlamming)
                Positioned(
                  left: -14,
                  right: -14,
                  top: -14,
                  bottom: -14,
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: [
                        BoxShadow(
                          color: const Color(0xFFFF9100).withValues(
                            alpha:
                                (0.4 + 0.6 * _chargeCtrl.value).clamp(0.0, 1.0),
                          ),
                          blurRadius: 28 * (0.8 + _chargeCtrl.value),
                          spreadRadius: 6 * (0.5 + _chargeCtrl.value),
                        ),
                        BoxShadow(
                          color: const Color(0xFFFFD700).withValues(
                            alpha: (0.5 * _chargeCtrl.value).clamp(0.0, 1.0),
                          ),
                          blurRadius: 16,
                          spreadRadius: 3,
                        ),
                      ],
                    ),
                  ),
                ),
              PlayingCardWidget(
                card: card,
                selected: selected || (isThisCardCharging && !_isSlamming),
                playable: isPlayable,
                dimmed: dimmed && !isThisCardCharging,
                width: cardWidth,
              ),
              if (isThisCardCharging && !_isSlamming)
                Positioned(
                  top: -38,
                  child: Material(
                    color: Colors.transparent,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [
                            Color(0xFFD50000),
                            Color(0xFFFF6D00),
                            Color(0xFFFFD600)
                          ],
                        ),
                        borderRadius: BorderRadius.circular(20),
                        boxShadow: [
                          BoxShadow(
                            color:
                                const Color(0xFFFF6D00).withValues(alpha: 0.8),
                            blurRadius: 12,
                            spreadRadius: 2,
                          ),
                        ],
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Text(
                            '⚡ زلزال ',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                              shadows: [
                                Shadow(color: Colors.black, blurRadius: 4),
                              ],
                            ),
                          ),
                          Text(
                            '${(2.0 * (1.0 - _chargeCtrl.value)).clamp(0.0, 2.0).toStringAsFixed(1)}s',
                            style: const TextStyle(
                              color: Color(0xFFFFF9C4),
                              fontSize: 12,
                              fontWeight: FontWeight.w900,
                              fontFeatures: [FontFeature.tabularFigures()],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
            ],
          ),
        );

        return Positioned(
          left: left,
          bottom: arcY,
          child: Listener(
            behavior: HitTestBehavior.opaque,
            onPointerDown: (e) => _onPointerDown(e, card),
            onPointerMove: (e) => _onPointerMove(e, card),
            onPointerUp: (e) => _onPointerUp(e, card),
            onPointerCancel: (e) => _onPointerCancel(e, card),
            child: SizedBox(
              width: cardWidth,
              height: cardHeight,
              child: Transform(
                alignment: Alignment.bottomCenter,
                transform: Matrix4.translationValues(
                    offsetX + shakeX, offsetY + shakeY, 0.0)
                  ..rotateZ(baseAngle + shakeAngle)
                  ..scale(scale, scale, 1.0),
                child: cardWidget,
              ),
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<PlayingCard?>(
      valueListenable: _selected,
      builder: (context, selected, _) {
        final cards = widget.hand;

        if (cards.isEmpty) return const SizedBox(height: 96);

        final media = MediaQuery.of(context);
        final screenWidth = media.size.width;
        final screenHeight = media.size.height;
        final isPortrait = media.orientation == Orientation.portrait;
        final isTablet = screenWidth >= 600;

        final availableWidth = isPortrait
            ? (screenWidth - 20).clamp(280.0, screenWidth * 0.97)
            : (screenWidth - 180).clamp(300.0, screenWidth * 0.80);

        final useTwoRows = cards.length > 7;
        final widestRow = useTwoRows ? (cards.length + 1) ~/ 2 : cards.length;

        double cardWidth = widestRow <= 1
            ? availableWidth * 0.22
            : (availableWidth - 2.0 * (widestRow - 1)) / widestRow;

        final maxW = isPortrait
            ? (isTablet ? 86.0 : 66.0)
            : (isTablet ? 78.0 : 58.0);
        final minW = isPortrait ? 48.0 : 44.0;
        cardWidth = cardWidth.clamp(minW, maxW);

        final nestFraction = 0.32;
        final maxHandHeight = screenHeight * (isPortrait ? 0.28 : 0.36);
        final rowsVisual = useTwoRows ? (2.0 - nestFraction) : 1.0;
        final maxCardHeight = (maxHandHeight - 8) / rowsVisual;
        final maxWidthFromHeight = maxCardHeight * playingCardAspectRatio;
        if (maxWidthFromHeight > 0 && cardWidth > maxWidthFromHeight) {
          cardWidth = maxWidthFromHeight.clamp(minW, maxW);
        }

        final cardHeight = cardWidth / playingCardAspectRatio;

        final isTrickTurn =
            widget.isMyTurn && widget.state?.phase == GamePhase.trickTaking;
        final playable = List<bool>.generate(
          cards.length,
          (i) => _isPlayable(cards[i]),
        );

        if (!useTwoRows) {
          return _buildFanRow(
            cards: cards,
            originalIndices: List<int>.generate(cards.length, (i) => i),
            cardWidth: cardWidth,
            cardHeight: cardHeight,
            selected: selected,
            playable: playable,
            isTrickTurn: isTrickTurn,
            availableWidth: availableWidth,
            isPortrait: isPortrait,
          );
        }

        final splitIndex = (cards.length + 1) ~/ 2;
        final row1 = cards.sublist(0, splitIndex);
        final row2 = cards.sublist(splitIndex);
        final row1Idx = List<int>.generate(row1.length, (i) => i);
        final row2Idx =
            List<int>.generate(row2.length, (i) => splitIndex + i);

        final nestPx = cardHeight * nestFraction;
        final topRow = _buildFanRow(
          cards: row1,
          originalIndices: row1Idx,
          cardWidth: cardWidth,
          cardHeight: cardHeight,
          selected: selected,
          playable: playable,
          isTrickTurn: isTrickTurn,
          availableWidth: availableWidth,
          isPortrait: isPortrait,
        );
        final bottomRow = _buildFanRow(
          cards: row2,
          originalIndices: row2Idx,
          cardWidth: cardWidth,
          cardHeight: cardHeight,
          selected: selected,
          playable: playable,
          isTrickTurn: isTrickTurn,
          availableWidth: availableWidth,
          isPortrait: isPortrait,
        );

        final totalH = cardHeight * 2 - nestPx;

        return SizedBox(
          width: availableWidth,
          height: totalH,
          child: Stack(
            clipBehavior: Clip.none,
            alignment: Alignment.topCenter,
            children: [
              Positioned(
                top: 0,
                child: topRow,
              ),
              Positioned(
                top: cardHeight - nestPx,
                child: bottomRow,
              ),
            ],
          ),
        );
      },
    );
  }
}
