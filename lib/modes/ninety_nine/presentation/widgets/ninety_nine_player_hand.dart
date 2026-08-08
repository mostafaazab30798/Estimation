// lib/modes/ninety_nine/presentation/widgets/ninety_nine_player_hand.dart

import 'package:flutter/material.dart';
import 'package:estimation/core/models/card.dart';
import 'package:estimation/widgets/playing_card_widget.dart';
import 'package:estimation/modes/ninety_nine/presentation/providers/ninety_nine_game_provider.dart';

class NinetyNinePlayerHand extends StatefulWidget {
  final List<PlayingCard> hand;
  final bool isMyTurn;
  final NinetyNinePhase phase;
  final void Function(PlayingCard card) onPlayCard;

  const NinetyNinePlayerHand({
    super.key,
    required this.hand,
    required this.isMyTurn,
    required this.phase,
    required this.onPlayCard,
  });

  @override
  State<NinetyNinePlayerHand> createState() => _NinetyNinePlayerHandState();
}

class _NinetyNinePlayerHandState extends State<NinetyNinePlayerHand> {
  final _selected = ValueNotifier<PlayingCard?>(null);

  @override
  void dispose() {
    _selected.dispose();
    super.dispose();
  }

  bool _isPlayable(PlayingCard card) {
    if (!widget.isMyTurn) return false;
    if (widget.phase != NinetyNinePhase.playing) return false;
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

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<PlayingCard?>(
      valueListenable: _selected,
      builder: (context, selected, _) {
        final cards = widget.hand;

        if (cards.isEmpty) return const SizedBox(height: 110);

        final media = MediaQuery.of(context);
        final screenWidth = media.size.width;
        final screenHeight = media.size.height;
        final isPortrait = media.orientation == Orientation.portrait;
        final isTablet = screenWidth >= 600;

        final availableWidth = isPortrait
            ? (screenWidth - 48).clamp(260.0, screenWidth * 0.88)
            : (screenWidth - 240).clamp(260.0, screenWidth * 0.70);

        final cardWidth = isPortrait
            ? (screenWidth * 0.18).clamp(65.0, isTablet ? 110.0 : 85.0)
            : (screenHeight * 0.18).clamp(55.0, isTablet ? 90.0 : 70.0);
        final cardHeight = cardWidth / playingCardAspectRatio;

        double overlap = 0.0;
        if (cards.length > 1) {
          overlap = (availableWidth - cardWidth) / (cards.length - 1);
        }

        final maxOverlap = isTablet ? 55.0 : (isPortrait ? 45.0 : 38.0);
        double actualOverlap = overlap < maxOverlap ? overlap : maxOverlap;

        final needsScroll = (cardWidth + (cards.length - 1) * maxOverlap) > availableWidth;
        if (needsScroll) {
          actualOverlap = maxOverlap; // Maintain a readable overlap when scrolling
        }

        final totalWidth = cardWidth + (cards.length - 1) * actualOverlap;
        final stackHeight = cardHeight + (isPortrait ? 32.0 : 16.0);

        final isTrickTurn = widget.isMyTurn && widget.phase == NinetyNinePhase.playing;
        final playable = List<bool>.generate(
          cards.length,
          (i) => _isPlayable(cards[i]),
        );

        final centerIndex = (cards.length - 1) / 2.0;

        Widget content = SizedBox(
          width: totalWidth,
          child: Stack(
                clipBehavior: Clip.none,
                children: [
                  for (int i = 0; i < cards.length; i++)
                    Builder(
                      builder: (context) {
                        final normPos = cards.length > 1
                            ? (i - centerIndex) / (cards.length / 2.0)
                            : 0.0;
                        final rotationAngle = isPortrait ? (normPos * 0.24) : (normPos * 0.06);
                        final arcOffsetY = isPortrait ? ((1.0 - normPos * normPos) * 12.0) : 0.0;

                        return AnimatedPositioned(
                          key: ValueKey(cards[i].id),
                          duration: const Duration(milliseconds: 300),
                          curve: Curves.easeOutCubic,
                          left: i * actualOverlap,
                          bottom: arcOffsetY,
                          child: Transform.rotate(
                            angle: rotationAngle,
                            alignment: Alignment.bottomCenter,
                            child: PlayingCardWidget(
                              card: cards[i],
                              selected: selected == cards[i],
                              playable: playable[i],
                              dimmed: isTrickTurn && !playable[i],
                              width: cardWidth,
                              onTap: () => _handleTap(cards[i]),
                            ),
                          ),
                        );
                      },
                    ),
                ],
              ),
        );

        if (needsScroll) {
          content = SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            physics: const BouncingScrollPhysics(),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16.0),
              child: content,
            ),
          );
        }

        return SizedBox(
          height: stackHeight,
          width: needsScroll ? availableWidth : totalWidth,
          child: Center(
            child: content,
          ),
        );
      },
    );
  }
}
