import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:estimation/core/constants.dart';
import 'package:estimation/core/models/card.dart';
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
  final ValueNotifier<Offset> _dragOffsetNotifier = ValueNotifier<Offset>(Offset.zero);

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
    if (widget.groundTotal == 99) {
      return card.isSafeCard;
    }
    return true;
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
    if (!widget.isMyTurn || widget.phase != NinetyNinePhase.playing || !_isPlayable(card)) {
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

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<PlayingCard?>(
      valueListenable: _selected,
      builder: (context, selected, _) {
        final cards = widget.hand;
        if (cards.isEmpty) return const SizedBox(height: 120);

        final media = MediaQuery.of(context);
        final screenWidth = media.size.width;
        final screenHeight = media.size.height;
        final isPortrait = media.orientation == Orientation.portrait;
        final isTablet = screenWidth >= 600;

        final availableWidth = isPortrait
            ? (screenWidth - 24).clamp(280.0, screenWidth * 0.96)
            : (screenWidth - 180).clamp(320.0, screenWidth * 0.76);

        // Generous card width for excellent visibility
        final cardWidth = isPortrait
            ? (screenWidth * 0.175).clamp(62.0, isTablet ? 110.0 : 86.0)
            : (screenHeight * 0.175).clamp(52.0, isTablet ? 88.0 : 72.0);
        final cardHeight = cardWidth / playingCardAspectRatio;

        double overlap = 0.0;
        if (cards.length > 1) {
          overlap = (availableWidth - cardWidth) / (cards.length - 1);
        }

        final maxOverlap = isTablet ? 56.0 : (isPortrait ? 44.0 : 38.0);
        double actualOverlap = overlap < maxOverlap ? overlap : maxOverlap;

        final needsScroll = (cardWidth + (cards.length - 1) * maxOverlap) > availableWidth;
        if (needsScroll) {
          actualOverlap = maxOverlap;
        }

        final totalWidth = cardWidth + (cards.length - 1) * actualOverlap;
        final isPlayingPhase = widget.phase == NinetyNinePhase.playing;
        final isTrickTurn = widget.isMyTurn && isPlayingPhase;
        final isAt99Danger = widget.groundTotal == 99;

        final playable = List<bool>.generate(
          cards.length,
          (i) => _isPlayable(cards[i]),
        );

        final centerIndex = (cards.length - 1) / 2.0;

        Widget cardsContent = SizedBox(
          width: totalWidth,
          height: cardHeight + 36,
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              for (int i = 0; i < cards.length; i++)
                Builder(
                  builder: (context) {
                    final card = cards[i];
                    final isCardSelected = selected == card;
                    final isCardPlayable = playable[i];
                    final isSafe = card.isSafeCard;
                    final normPos = cards.length > 1
                        ? (i - centerIndex) / (cards.length / 2.0)
                        : 0.0;
                    final rotationAngle = isPortrait ? (normPos * 0.16) : (normPos * 0.05);
                    final arcOffsetY = isPortrait ? ((1.0 - normPos * normPos) * 10.0) : 0.0;

                    return AnimatedPositioned(
                      key: ValueKey(card.id),
                      duration: const Duration(milliseconds: 250),
                      curve: Curves.easeOutCubic,
                      left: i * actualOverlap,
                      bottom: isCardSelected ? 24.0 : arcOffsetY,
                      child: AnimatedBuilder(
                        animation: _dragOffsetNotifier,
                        builder: (context, _) {
                          final isDragged = _draggedCard == card;
                          final dragOffset = isDragged ? _dragOffsetNotifier.value : Offset.zero;
                          final dragAngle = (dragOffset.dx / 240.0).clamp(-0.2, 0.2);

                          return Transform.translate(
                            offset: dragOffset,
                            child: Transform.rotate(
                              angle: isCardSelected ? 0 : (rotationAngle + dragAngle),
                              alignment: Alignment.bottomCenter,
                              child: AnimatedScale(
                                scale: isCardSelected ? 1.08 : (isDragged && dragOffset.dy < -10 ? 1.05 : 1.0),
                                duration: const Duration(milliseconds: 200),
                                curve: Curves.easeOutBack,
                                child: Listener(
                                  behavior: HitTestBehavior.opaque,
                                  onPointerDown: (e) => _onPointerDown(e, card),
                                  onPointerMove: (e) => _onPointerMove(e, card),
                                  onPointerUp: (e) => _onPointerUp(e, card),
                                  onPointerCancel: (e) => _onPointerCancel(e, card),
                                  child: Stack(
                                    clipBehavior: Clip.none,
                                    alignment: Alignment.topCenter,
                                    children: [
                                      // ── Card Base ──
                                      PlayingCardWidget(
                                        card: card,
                                        selected: isCardSelected,
                                        playable: isCardPlayable,
                                        dimmed: isTrickTurn && !isCardPlayable,
                                        width: cardWidth,
                                      ),

                              // ── 99 Special Effect Badge ──
                              Positioned(
                                top: -11,
                                child: _buildCardEffectBadge(
                                  card: card,
                                  isSelected: isCardSelected,
                                  isPlayable: isCardPlayable,
                                  isAt99Danger: isAt99Danger,
                                ),
                              ),

                              // ── Pulsing Safe Card Aura when at 99 ──
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
                                                color: const Color(0xFF10B981)
                                                    .withValues(alpha: 0.45 * _pulseAnimation.value),
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

                              // ── Lock Overlay for Non-Safe Cards when at 99 ──
                              if (isTrickTurn && isAt99Danger && !isSafe)
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
                      ),
                    );
                  },
                ),
            ],
          ),
        );

        if (needsScroll) {
          cardsContent = SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            physics: const BouncingScrollPhysics(),
            padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 4.0),
            child: cardsContent,
          );
        }

        return Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            // ── Top Action / Turn Status Bar ──
            _buildStatusBar(
              context: context,
              selected: selected,
              isTrickTurn: isTrickTurn,
              isAt99Danger: isAt99Danger,
            ),
            const SizedBox(height: 6),

            // ── Cards Fan Surface ──
            Container(
              constraints: BoxConstraints(maxWidth: screenWidth),
              padding: const EdgeInsets.only(top: 12, bottom: 4),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    Colors.black.withValues(alpha: isTrickTurn ? 0.45 : 0.25),
                    Colors.black.withValues(alpha: isTrickTurn ? 0.65 : 0.40),
                  ],
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                ),
                borderRadius: const BorderRadius.vertical(top: Radius.circular(22)),
                border: Border(
                  top: BorderSide(
                    color: isTrickTurn
                        ? (isAt99Danger ? const Color(0xFFEF4444) : AppTheme.gold)
                            .withValues(alpha: 0.4)
                        : Colors.white.withValues(alpha: 0.08),
                    width: 1.2,
                  ),
                ),
              ),
              child: Center(
                child: SizedBox(
                  width: needsScroll ? availableWidth : totalWidth,
                  child: cardsContent,
                ),
              ),
            ),
          ],
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
  }) {
    if (!widget.isMyTurn) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
        decoration: BoxDecoration(
          color: Colors.black.withValues(alpha: 0.35),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: Colors.white12),
        ),
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
            Text(
              'في انتظار دور الخصم...',
              style: GoogleFonts.cairo(
                color: Colors.white60,
                fontSize: 11,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
      );
    }

    // ── When a Card is Selected ──
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
        previewColor = newTotal >= 90 ? const Color(0xFFEF4444) : AppTheme.goldLight;
      }

      return Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Impact Badge
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 5),
            decoration: BoxDecoration(
              color: Colors.black.withValues(alpha: 0.75),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: previewColor, width: 1.4),
              boxShadow: [
                BoxShadow(
                  color: previewColor.withValues(alpha: 0.3),
                  blurRadius: 12,
                ),
              ],
            ),
            child: Text(
              previewText,
              style: GoogleFonts.cairo(
                color: Colors.white,
                fontSize: 12,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          const SizedBox(width: 8),

          // Quick Play Action Button
          Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: _confirmPlaySelected,
              borderRadius: BorderRadius.circular(16),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFF10B981), Color(0xFF059669)],
                  ),
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFF10B981).withValues(alpha: 0.5),
                      blurRadius: 10,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const AppIcon(AppIcons.playArrow, color: Colors.white, size: 18),
                    const SizedBox(width: 4),
                    Text(
                      'إلعب الورقة',
                      style: GoogleFonts.cairo(
                        color: Colors.white,
                        fontSize: 12,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      );
    }

    // ── Turn Banner when No Card is Selected ──
    if (isAt99Danger) {
      return AnimatedBuilder(
        animation: _pulseAnimation,
        builder: (context, child) {
          return Transform.scale(
            scale: _pulseAnimation.value,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 5),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFF991B1B), Color(0xFF7F1D1D)],
                ),
                borderRadius: BorderRadius.circular(18),
                border: Border.all(color: const Color(0xFFFCA5A5), width: 1.5),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFFEF4444).withValues(alpha: 0.5),
                    blurRadius: 16,
                  ),
                ],
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text('🚨', style: TextStyle(fontSize: 14)),
                  const SizedBox(width: 6),
                  Text(
                    'الأرض عند 99! اختر ورقة منقذة (🛡️ 4, 7, ولد, شايب)',
                    style: GoogleFonts.cairo(
                      color: Colors.white,
                      fontSize: 11,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      );
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 5),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.6),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppTheme.gold.withValues(alpha: 0.7), width: 1.2),
        boxShadow: [
          BoxShadow(
            color: AppTheme.gold.withValues(alpha: 0.25),
            blurRadius: 10,
          ),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const AppIcon(AppIcons.touchApp, color: AppTheme.goldLight, size: 15),
          const SizedBox(width: 6),
          Text(
            'دورك للعب! انقر على الورقة لرميها 🎴',
            style: GoogleFonts.cairo(
              color: Colors.white,
              fontSize: 11,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
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
        style: GoogleFonts.cairo(
          color: textColor,
          fontSize: 9.5,
          fontWeight: FontWeight.w900,
          height: 1.1,
        ),
      ),
    );
  }
}
