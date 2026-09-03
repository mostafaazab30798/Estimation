import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:estimation/core/constants.dart';
import 'package:estimation/core/models/card.dart';
import 'package:estimation/core/utils/game_layout_metrics.dart';
import 'package:estimation/theme/app_theme.dart';
import 'package:estimation/widgets/playing_card_widget.dart';
import 'package:estimation/modes/ninety_nine/domain/ninety_nine_card_rules.dart';
import 'package:estimation/modes/ninety_nine/presentation/providers/ninety_nine_game_provider.dart';
import 'package:estimation/core/icons/app_icons.dart';

class NinetyNinePlayerHand extends StatefulWidget {
  final List<PlayingCard> hand;
  final bool isMyTurn;
  final NinetyNinePhase phase;
  final int groundTotal;
  final void Function(PlayingCard card) onPlayCard;

  const NinetyNinePlayerHand({
    super.key,
    required this.hand,
    required this.isMyTurn,
    required this.phase,
    required this.groundTotal,
    required this.onPlayCard,
  });

  @override
  State<NinetyNinePlayerHand> createState() => _NinetyNinePlayerHandState();
}

class _NinetyNinePlayerHandState extends State<NinetyNinePlayerHand>
    with SingleTickerProviderStateMixin {
  final _selected = ValueNotifier<PlayingCard?>(null);
  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;

  // ── Drag & Swipe-to-Play State ──
  PlayingCard? _pointerDownCard;
  Offset? _pointerDownPos;
  DateTime? _pointerDownTime;
  PlayingCard? _draggedCard;
  final ValueNotifier<Offset> _dragOffsetNotifier =
      ValueNotifier<Offset>(Offset.zero);

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    )..repeat(reverse: true);

    _pulseAnimation = Tween<double>(begin: 0.95, end: 1.05).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _pulseController.dispose();
    _selected.dispose();
    _dragOffsetNotifier.dispose();
    super.dispose();
  }

  bool _isPlayable(PlayingCard card) {
    if (!widget.isMyTurn) return false;
    if (widget.phase != NinetyNinePhase.playing) return false;
    return card.isLegalPlay(widget.groundTotal);
  }

  void _handleTap(PlayingCard card) {
    if (!widget.isMyTurn || widget.phase != NinetyNinePhase.playing) {
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
        widget.phase != NinetyNinePhase.playing ||
        !_isPlayable(card)) {
      return;
    }
    _pointerDownCard = card;
    _pointerDownPos = event.position;
    _pointerDownTime = DateTime.now();
    _draggedCard = card;
    _dragOffsetNotifier.value = Offset.zero;
  }

  void _onPointerMove(PointerMoveEvent event, PlayingCard card) {
    if (_pointerDownCard != card || _pointerDownPos == null) return;
    final dx = event.position.dx - _pointerDownPos!.dx;
    final dy = event.position.dy - _pointerDownPos!.dy;
    final clampedDy = dy.clamp(-230.0, 10.0);
    final clampedDx = (dx * 0.45).clamp(-80.0, 80.0);
    _dragOffsetNotifier.value = Offset(clampedDx, clampedDy);
  }

  void _onPointerUp(PointerUpEvent event, PlayingCard card) {
    final downCard = _pointerDownCard;
    _pointerDownCard = null;
    final downTime = _pointerDownTime;
    _pointerDownTime = null;
    _pointerDownPos = null;

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
      HapticFeedback.mediumImpact();
      widget.onPlayCard(card);
      _selected.value = null;
      return;
    }

    if (downCard == card) {
      _handleTap(card);
    }
  }

  void _onPointerCancel(PointerCancelEvent event, PlayingCard card) {
    _pointerDownCard = null;
    _pointerDownPos = null;
    _pointerDownTime = null;
    _draggedCard = null;
    _dragOffsetNotifier.value = Offset.zero;
  }

  void _confirmPlaySelected() {
    final card = _selected.value;
    if (card != null && _isPlayable(card)) {
      widget.onPlayCard(card);
      _selected.value = null;
    }
  }

  ({double step, double fanWidth, double arcHeight, double halfAngle})
      _fanGeometry({
    required int n,
    required double cardWidth,
    required double availableWidth,
    required bool isPortrait,
  }) {
    final fitted = n <= 1 ? cardWidth : (availableWidth - cardWidth) / (n - 1);
    final step = fitted.clamp(cardWidth * 0.78, cardWidth + 2.0);
    final fanWidth = n <= 1 ? cardWidth : cardWidth + (n - 1) * step;
    final halfAngle = ((isPortrait ? 0.028 : 0.018) * (n - 1)).clamp(
      isPortrait ? 0.06 : 0.04,
      isPortrait ? 0.22 : 0.14,
    );
    final arcHeight = isPortrait
        ? (4.0 + n * 0.5).clamp(4.0, 10.0)
        : (3.0 + n * 0.3).clamp(3.0, 7.0);
    return (
      step: step,
      fanWidth: fanWidth,
      arcHeight: arcHeight,
      halfAngle: halfAngle,
    );
  }

  Widget _buildFanRow({
    required List<PlayingCard> cards,
    required List<int> originalIndices,
    required double cardWidth,
    required double cardHeight,
    required PlayingCard? selected,
    required List<bool> playable,
    required bool isTrickTurn,
    required bool isAt99Danger,
    required double availableWidth,
    required bool isPortrait,
  }) {
    if (cards.isEmpty) return const SizedBox.shrink();

    final n = cards.length;
    final center = (n - 1) / 2.0;
    final geo = _fanGeometry(
      n: n,
      cardWidth: cardWidth,
      availableWidth: availableWidth,
      isPortrait: isPortrait,
    );
    final step = geo.step;
    final fanWidth = geo.fanWidth;
    final arcHeight = geo.arcHeight;
    final clampedHalf = geo.halfAngle;

    return SizedBox(
      width: fanWidth,
      height: cardHeight,
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
                return _buildFanCard(
                  card: cards[i],
                  left: i * step,
                  fanAngle: fanAngle,
                  arcY: arcY,
                  isPlayable: playable[oi],
                  selected: selected == cards[i],
                  cardWidth: cardWidth,
                  cardHeight: cardHeight,
                  isTrickTurn: isTrickTurn,
                  isAt99Danger: isAt99Danger,
                );
              },
            ),
        ],
      ),
    );
  }

  Widget _buildFanCard({
    required PlayingCard card,
    required double left,
    required double fanAngle,
    required double arcY,
    required bool isPlayable,
    required bool selected,
    required double cardWidth,
    required double cardHeight,
    required bool isTrickTurn,
    required bool isAt99Danger,
  }) {
    final isSafe = card.isSafeCard;
    final dimmed = isTrickTurn && !isPlayable;

    return AnimatedBuilder(
      key: ValueKey(card.id),
      animation: _dragOffsetNotifier,
      builder: (context, _) {
        double offsetY = selected ? -14.0 : 0.0;
        double offsetX = 0.0;
        double scale = selected ? 1.05 : 1.0;
        final baseAngle = selected ? fanAngle * 0.2 : fanAngle;
        double dragAngle = 0.0;

        final isDragged = _draggedCard == card;
        if (isDragged) {
          final dragOffset = _dragOffsetNotifier.value;
          offsetY += dragOffset.dy;
          offsetX += dragOffset.dx;
          dragAngle = (dragOffset.dx / 220.0).clamp(-0.2, 0.2);
          if (dragOffset.dy < -10) scale = 1.06;
        }

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
                transform: Matrix4.translationValues(offsetX, offsetY, 0)
                  ..rotateZ(baseAngle + dragAngle)
                  ..scaleByDouble(scale, scale, 1.0, 1.0),
                child: Stack(
                  clipBehavior: Clip.none,
                  alignment: Alignment.topCenter,
                  children: [
                    PlayingCardWidget(
                      card: card,
                      selected: selected,
                      playable: isPlayable,
                      dimmed: dimmed,
                      width: cardWidth,
                    ),
                    Positioned(
                      top: -11,
                      child: _buildCardEffectBadge(
                        card: card,
                        isSelected: selected,
                        isPlayable: isPlayable,
                        isAt99Danger: isAt99Danger,
                      ),
                    ),
                    if (isTrickTurn && isAt99Danger && isSafe)
                      Positioned.fill(
                        child: IgnorePointer(
                          child: AnimatedBuilder(
                            animation: _pulseAnimation,
                            builder: (context, _) {
                              return Container(
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(10),
                                  border: Border.all(
                                    color: const Color(0xFF10B981)
                                        .withValues(alpha: 0.9),
                                    width: 2.2,
                                  ),
                                  boxShadow: [
                                    BoxShadow(
                                      color: const Color(0xFF10B981).withValues(
                                        alpha: 0.45 * _pulseAnimation.value,
                                      ),
                                      blurRadius: 16 * _pulseAnimation.value,
                                      spreadRadius: 2.5,
                                    ),
                                  ],
                                ),
                              );
                            },
                          ),
                        ),
                      ),
                    if (isTrickTurn && !isPlayable)
                      Positioned.fill(
                        child: IgnorePointer(
                          child: Container(
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(10),
                              color: Colors.black.withValues(alpha: 0.55),
                            ),
                            child: const Center(
                              child: AppIcon(
                                AppIcons.lock,
                                color: Colors.white60,
                                size: 20,
                              ),
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
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

        return LayoutBuilder(
          builder: (context, constraints) {
            final media = MediaQuery.of(context);
            final screenHeight = media.size.height;
            final layout = GameLayoutMetrics.of(context);
            final isPortrait = layout.isPortrait;

            final maxParentWidth = constraints.maxWidth;
            final availableWidth = maxParentWidth.isFinite
                ? (maxParentWidth - 8).clamp(120.0, maxParentWidth)
                : layout.handAvailableWidth(media.size.width);

            final useTwoRows = cards.length > 7;
            final widestRow =
                useTwoRows ? (cards.length + 1) ~/ 2 : cards.length;

            double cardWidth = widestRow <= 1
                ? availableWidth * 0.22
                : (availableWidth - 2.0 * (widestRow - 1)) / widestRow;

            final maxW = layout.handMaxCardWidth;
            final minW = layout.handMinCardWidth;
            cardWidth = cardWidth.clamp(minW, maxW);

            const nestFraction = 0.32;
            final maxHandHeight = screenHeight * (isPortrait ? 0.28 : 0.36);
            final rowsVisual = useTwoRows ? (2.0 - nestFraction) : 1.0;
            final maxCardHeight = (maxHandHeight - 8) / rowsVisual;
            final maxWidthFromHeight = maxCardHeight * playingCardAspectRatio;
            if (maxWidthFromHeight > 0 && cardWidth > maxWidthFromHeight) {
              cardWidth = maxWidthFromHeight.clamp(minW, maxW);
            }

            final cardHeight = cardWidth / playingCardAspectRatio;
            final isTrickTurn =
                widget.isMyTurn && widget.phase == NinetyNinePhase.playing;
            final isAt99Danger = widget.groundTotal == 99;
            final playable = List<bool>.generate(
              cards.length,
              (i) => _isPlayable(cards[i]),
            );

            Widget handFan;
            if (!useTwoRows) {
              handFan = _buildFanRow(
                cards: cards,
                originalIndices: List<int>.generate(cards.length, (i) => i),
                cardWidth: cardWidth,
                cardHeight: cardHeight,
                selected: selected,
                playable: playable,
                isTrickTurn: isTrickTurn,
                isAt99Danger: isAt99Danger,
                availableWidth: availableWidth,
                isPortrait: isPortrait,
              );
            } else {
              final splitIndex = (cards.length + 1) ~/ 2;
              final row1 = cards.sublist(0, splitIndex);
              final row2 = cards.sublist(splitIndex);
              final nestPx = cardHeight * nestFraction;
              handFan = SizedBox(
                width: availableWidth,
                height: cardHeight * 2 - nestPx,
                child: Stack(
                  clipBehavior: Clip.none,
                  alignment: Alignment.topCenter,
                  children: [
                    Positioned(
                      top: 0,
                      child: _buildFanRow(
                        cards: row1,
                        originalIndices:
                            List<int>.generate(row1.length, (i) => i),
                        cardWidth: cardWidth,
                        cardHeight: cardHeight,
                        selected: selected,
                        playable: playable,
                        isTrickTurn: isTrickTurn,
                        isAt99Danger: isAt99Danger,
                        availableWidth: availableWidth,
                        isPortrait: isPortrait,
                      ),
                    ),
                    Positioned(
                      top: cardHeight - nestPx,
                      child: _buildFanRow(
                        cards: row2,
                        originalIndices: List<int>.generate(
                          row2.length,
                          (i) => splitIndex + i,
                        ),
                        cardWidth: cardWidth,
                        cardHeight: cardHeight,
                        selected: selected,
                        playable: playable,
                        isTrickTurn: isTrickTurn,
                        isAt99Danger: isAt99Danger,
                        availableWidth: availableWidth,
                        isPortrait: isPortrait,
                      ),
                    ),
                  ],
                ),
              );
            }

            final topRowCount = useTwoRows ? widestRow : cards.length;
            final geo = _fanGeometry(
              n: topRowCount,
              cardWidth: cardWidth,
              availableWidth: availableWidth,
              isPortrait: isPortrait,
            );
            final stackWidth = useTwoRows ? availableWidth : geo.fanWidth;
            final helperMaxWidth =
                (geo.fanWidth * 0.86).clamp(132.0, geo.fanWidth);
            // Keep a hard gap above the fan: badges (~11), arc lift, selected rise.
            final fanClearance = geo.arcHeight + 30;

            return SizedBox(
              width: stackWidth,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  _buildStatusBar(
                    context: context,
                    selected: selected,
                    isTrickTurn: isTrickTurn,
                    isAt99Danger: isAt99Danger,
                    hasOverflowLocks: isTrickTurn && playable.any((p) => !p),
                    maxWidth: helperMaxWidth,
                  ),
                  SizedBox(height: fanClearance),
                  handFan,
                ],
              ),
            );
          },
        );
      },
    );
  }

  // ── Status Banner & Floating Play Button ──────────────────────────────
  Widget _buildStatusBar({
    required BuildContext context,
    required PlayingCard? selected,
    required bool isTrickTurn,
    required bool isAt99Danger,
    required bool hasOverflowLocks,
    required double maxWidth,
  }) {
    Widget chip({
      required Widget child,
      required Color borderColor,
      Gradient? gradient,
      Color? color,
    }) {
      return Align(
        alignment: Alignment.center,
        child: ConstrainedBox(
          constraints: BoxConstraints(maxWidth: maxWidth),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
            decoration: BoxDecoration(
              color: color,
              gradient: gradient,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: borderColor, width: 1.2),
            ),
            child: child,
          ),
        ),
      );
    }

    if (!widget.isMyTurn) {
      return chip(
        color: Colors.black.withValues(alpha: 0.45),
        borderColor: Colors.white12,
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(
              width: 10,
              height: 10,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: Colors.white54,
              ),
            ),
            const SizedBox(width: 8),
            Flexible(
              child: Text(
                'في انتظار دور الخصم...',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: AppFonts.cooper(
                  color: Colors.white60,
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        ),
      );
    }

    if (selected != null) {
      final newTotal = selected.applyEffect(widget.groundTotal);
      String previewText;
      Color previewColor;

      if (selected.isReverseCard) {
        previewText = 'عكس اتجاه اللعب 🔄 (الأرض تبقى ${widget.groundTotal})';
        previewColor = const Color(0xFF38BDF8);
      } else if (selected.rank == Rank.jack) {
        previewText = 'خصم -10 🛡️ (المجموع سيصبح $newTotal)';
        previewColor = const Color(0xFF10B981);
      } else if (selected.rank == Rank.king) {
        previewText = widget.groundTotal == 99
            ? 'شايب آمن 👑 (+0 - الأرض تبقى 99)'
            : 'رفع الأرض لـ 99! 🔥';
        previewColor = const Color(0xFFEF4444);
      } else if (selected.rank == Rank.four) {
        previewText = 'ورقة آمنة 🛡️ (+0 - الأرض تبقى ${widget.groundTotal})';
        previewColor = AppTheme.gold;
      } else {
        previewText = 'المجموع سيصبح: $newTotal / 99';
        previewColor =
            newTotal >= 90 ? const Color(0xFFEF4444) : AppTheme.goldLight;
      }

      return Align(
        alignment: Alignment.center,
        child: ConstrainedBox(
          constraints: BoxConstraints(maxWidth: maxWidth),
          child: IntrinsicWidth(
            child: Wrap(
              alignment: WrapAlignment.center,
              crossAxisAlignment: WrapCrossAlignment.center,
              spacing: 6,
              runSpacing: 6,
              children: [
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.75),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: previewColor, width: 1.4),
                  ),
                  child: Text(
                    previewText,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: AppFonts.cooper(
                      color: Colors.white,
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                Material(
                  color: Colors.transparent,
                  child: InkWell(
                    onTap: _confirmPlaySelected,
                    borderRadius: BorderRadius.circular(16),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [Color(0xFF10B981), Color(0xFF059669)],
                        ),
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const AppIcon(AppIcons.playArrow,
                              color: Colors.white, size: 16),
                          const SizedBox(width: 4),
                          Text(
                            'إلعب الورقة',
                            style: AppFonts.cooper(
                              color: Colors.white,
                              fontSize: 11,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }

    if (isAt99Danger) {
      return AnimatedBuilder(
        animation: _pulseAnimation,
        builder: (context, child) {
          return Transform.scale(
            scale: 0.98 + (_pulseAnimation.value - 0.95) * 0.4,
            child: chip(
              gradient: const LinearGradient(
                colors: [Color(0xFF991B1B), Color(0xFF7F1D1D)],
              ),
              borderColor: const Color(0xFFFCA5A5),
              child: Text(
                '🚨 الأرض عند 99! اختر ورقة منقذة',
                textAlign: TextAlign.center,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: AppFonts.cooper(
                  color: Colors.white,
                  fontSize: 11,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ),
          );
        },
      );
    }

    return chip(
      color: Colors.black.withValues(alpha: 0.6),
      borderColor: (hasOverflowLocks ? const Color(0xFFEF4444) : AppTheme.gold)
          .withValues(alpha: 0.7),
      child: Text(
        hasOverflowLocks
            ? '🔒 الأوراق التي تتجاوز 99 مقفلة'
            : 'دورك للعب! انقر على الورقة لرميها 🎴',
        textAlign: TextAlign.center,
        maxLines: 2,
        overflow: TextOverflow.ellipsis,
        style: AppFonts.cooper(
          color: Colors.white,
          fontSize: 11,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  // ── Card Effect Top Badge ─────────────────────────────────────────────
  Widget _buildCardEffectBadge({
    required PlayingCard card,
    required bool isSelected,
    required bool isPlayable,
    required bool isAt99Danger,
  }) {
    final isSafe = card.isSafeCard;
    Color badgeBg;
    Color borderColor;
    Color textColor = Colors.white;

    if (isSafe) {
      if (card.rank == Rank.jack) {
        badgeBg = const Color(0xFF047857);
        borderColor = const Color(0xFF34D399);
      } else if (card.rank == Rank.seven) {
        badgeBg = const Color(0xFF0369A1);
        borderColor = const Color(0xFF38BDF8);
      } else if (card.rank == Rank.king) {
        badgeBg = const Color(0xFFB91C1C);
        borderColor = const Color(0xFFF87171);
      } else {
        badgeBg = const Color(0xFFB45309);
        borderColor = AppTheme.gold;
      }
    } else {
      badgeBg = Colors.black.withValues(alpha: 0.85);
      borderColor = isSelected ? AppTheme.gold : Colors.white24;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1.5),
      decoration: BoxDecoration(
        color: badgeBg,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: borderColor, width: 1.1),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.5),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
          if (isSafe)
            BoxShadow(
              color: borderColor.withValues(alpha: 0.4),
              blurRadius: 6,
            ),
        ],
      ),
      child: Text(
        card.badgeLabel,
        style: AppFonts.cooper(
          color: textColor,
          fontSize: 9.5,
          fontWeight: FontWeight.w900,
          height: 1.1,
        ),
      ),
    );
  }
}
