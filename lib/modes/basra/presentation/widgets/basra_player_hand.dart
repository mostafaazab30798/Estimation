// lib/modes/basra/presentation/widgets/basra_player_hand.dart

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:estimation/core/icons/app_icons.dart';
import 'package:estimation/core/models/card.dart';
import 'package:estimation/core/utils/game_layout_metrics.dart';
import 'package:estimation/modes/basra/domain/basra_card_rules.dart';
import 'package:estimation/modes/basra/domain/models/basra_game_state.dart';
import 'package:estimation/theme/app_theme.dart';
import 'package:estimation/widgets/playing_card_widget.dart';

class BasraPlayerHand extends StatefulWidget {
  final List<PlayingCard> hand;
  final bool isMyTurn;
  final BasraPhase phase;
  final void Function(PlayingCard card) onPlayCard;

  const BasraPlayerHand({
    super.key,
    required this.hand,
    required this.isMyTurn,
    required this.phase,
    required this.onPlayCard,
  });

  @override
  State<BasraPlayerHand> createState() => _BasraPlayerHandState();
}

class _BasraPlayerHandState extends State<BasraPlayerHand> {
  final _selected = ValueNotifier<PlayingCard?>(null);
  PlayingCard? _pointerDownCard;
  Offset? _pointerDownPos;
  DateTime? _pointerDownTime;
  PlayingCard? _draggedCard;
  final _dragOffsetNotifier = ValueNotifier<Offset>(Offset.zero);

  bool get _canPlay =>
      widget.isMyTurn && widget.phase == BasraPhase.playing;

  @override
  void dispose() {
    _selected.dispose();
    _dragOffsetNotifier.dispose();
    super.dispose();
  }

  void _handleTap(PlayingCard card) {
    if (!_canPlay) return;
    if (_selected.value == card) {
      widget.onPlayCard(card);
      _selected.value = null;
    } else {
      _selected.value = card;
    }
  }

  void _onPointerUp(PointerUpEvent event, PlayingCard card) {
    final downCard = _pointerDownCard;
    final downTime = _pointerDownTime;
    final currentDrag = _dragOffsetNotifier.value;
    _pointerDownCard = null;
    _pointerDownTime = null;
    _pointerDownPos = null;
    _dragOffsetNotifier.value = Offset.zero;
    _draggedCard = null;

    final upwardDist = -currentDrag.dy;
    final elapsedMs = downTime != null
        ? DateTime.now().difference(downTime).inMilliseconds
        : 500;
    final isSwipeThrow = upwardDist >= 35.0 || (upwardDist >= 18.0 && elapsedMs <= 350);
    if (isSwipeThrow && downCard == card && _canPlay) {
      HapticFeedback.mediumImpact();
      widget.onPlayCard(card);
      _selected.value = null;
      return;
    }
    if (downCard == card) _handleTap(card);
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<PlayingCard?>(
      valueListenable: _selected,
      builder: (context, selected, _) {
        final cards = widget.hand;
        if (cards.isEmpty) return const SizedBox(height: 120);

        final media = MediaQuery.of(context);
        final screenWidth = media.size.width;
        final layout = GameLayoutMetrics.of(context);
        final cardWidth = (screenWidth * 0.175)
            .clamp(62.0, layout.handMaxCardWidth + 4);
        final cardHeight = cardWidth / playingCardAspectRatio;
        final availableWidth = layout.handAvailableWidth(screenWidth);
        var actualOverlap = cards.length > 1
            ? (availableWidth - cardWidth) / (cards.length - 1)
            : 0.0;
        actualOverlap = actualOverlap.clamp(0.0, layout.handMaxOverlap);
        final totalWidth = cardWidth + (cards.length - 1) * actualOverlap;

        return Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _statusBar(selected),
            const SizedBox(height: 6),
            SizedBox(
              width: totalWidth,
              height: cardHeight + 36,
              child: Stack(
                clipBehavior: Clip.none,
                children: [
                  for (var i = 0; i < cards.length; i++)
                    AnimatedPositioned(
                      key: ValueKey(cards[i].id),
                      duration: const Duration(milliseconds: 220),
                      left: i * actualOverlap,
                      bottom: selected == cards[i] ? 22 : 0,
                      child: Listener(
                        behavior: HitTestBehavior.opaque,
                        onPointerDown: (e) {
                          if (!_canPlay) return;
                          _pointerDownCard = cards[i];
                          _pointerDownPos = e.position;
                          _pointerDownTime = DateTime.now();
                          _draggedCard = cards[i];
                        },
                        onPointerMove: (e) {
                          if (_pointerDownCard != cards[i] || _pointerDownPos == null) {
                            return;
                          }
                          final dx = e.position.dx - _pointerDownPos!.dx;
                          final dy = e.position.dy - _pointerDownPos!.dy;
                          _dragOffsetNotifier.value = Offset(
                            (dx * 0.45).clamp(-80.0, 80.0),
                            dy.clamp(-230.0, 10.0),
                          );
                        },
                        onPointerUp: (e) => _onPointerUp(e, cards[i]),
                        onPointerCancel: (_) {
                          _pointerDownCard = null;
                          _draggedCard = null;
                          _dragOffsetNotifier.value = Offset.zero;
                        },
                        child: AnimatedBuilder(
                          animation: _dragOffsetNotifier,
                          builder: (context, _) {
                            final drag = _draggedCard == cards[i]
                                ? _dragOffsetNotifier.value
                                : Offset.zero;
                            return Transform.translate(
                              offset: drag,
                              child: Stack(
                                clipBehavior: Clip.none,
                                alignment: Alignment.topCenter,
                                children: [
                                  PlayingCardWidget(
                                    card: cards[i],
                                    selected: selected == cards[i],
                                    playable: _canPlay,
                                    dimmed: widget.isMyTurn && !_canPlay,
                                    width: cardWidth,
                                  ),
                                  if (cards[i].isJack || cards[i].isSevenOfDiamonds)
                                    Positioned(
                                      top: -10,
                                      child: _badge(
                                        cards[i].isJack ? 'ولد كنس' : '7 ديناري',
                                      ),
                                    ),
                                ],
                              ),
                            );
                          },
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _badge(String text) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
      decoration: BoxDecoration(
        color: const Color(0xFFB45309),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppTheme.gold),
      ),
      child: Text(
        text,
        style: AppFonts.cooper(
          color: Colors.white,
          fontSize: 9,
          fontWeight: FontWeight.w900,
        ),
      ),
    );
  }

  Widget _statusBar(PlayingCard? selected) {
    if (!widget.isMyTurn) {
      return Text(
        'في انتظار دور الخصم...',
        style: AppFonts.cooper(color: Colors.white60, fontSize: 11, fontWeight: FontWeight.bold),
      );
    }
    if (selected != null) {
      return Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            selected.isJack
                ? 'كنس الطاولة'
                : selected.isSevenOfDiamonds
                    ? '7 ديناري — كنس خاص'
                    : 'إلعب الورقة',
            style: AppFonts.cooper(color: AppTheme.gold, fontWeight: FontWeight.bold, fontSize: 12),
          ),
          const SizedBox(width: 8),
          InkWell(
            onTap: () {
              widget.onPlayCard(selected);
              _selected.value = null;
            },
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: const Color(0xFF0F766E),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Row(
                children: [
                  const AppIcon(AppIcons.playArrow, color: Colors.white, size: 16),
                  const SizedBox(width: 4),
                  Text('إلعب', style: AppFonts.cooper(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 12)),
                ],
              ),
            ),
          ),
        ],
      );
    }
    return Text(
      'دورك — اختر ورقة من يدك',
      style: AppFonts.cooper(color: AppTheme.gold, fontWeight: FontWeight.bold, fontSize: 12),
    );
  }
}
