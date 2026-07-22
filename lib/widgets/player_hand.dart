// lib/widgets/player_hand.dart
//
// Fanned/overlapping hand for the local player.
// Cards are displayed 2 → A left to right so Ace is rightmost (most visible).
// The underlying sorted list is [A, K, ... 2]; we render reversed so Ace is on top/right.

import 'package:flutter/material.dart';
import '../core/models/card.dart';
import '../core/models/game_state.dart';
import '../core/models/player.dart';
import '../core/game_engine.dart';
import 'playing_card_widget.dart';

class PlayerHand extends StatefulWidget {
  final List<PlayingCard> hand;
  final bool isMyTurn;
  final GameState? state;
  final Player? me;
  final void Function(PlayingCard card) onPlayCard;

  const PlayerHand({
    super.key,
    required this.hand,
    required this.isMyTurn,
    required this.onPlayCard,
    this.state,
    this.me,
  });

  @override
  State<PlayerHand> createState() => _PlayerHandState();
}

class _PlayerHandState extends State<PlayerHand> {
  PlayingCard? _selected;

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

    if (_selected == card) {
      // Second tap = confirm play
      widget.onPlayCard(card);
      setState(() => _selected = null);
    } else {
      setState(() => _selected = card);
    }
  }

  @override
  Widget build(BuildContext context) {
    final cards = widget.hand;

    if (cards.isEmpty) return const SizedBox(height: 110);

    final media = MediaQuery.of(context);
    final screenWidth = media.size.width;
    final screenHeight = media.size.height;
    final isPortrait = media.orientation == Orientation.portrait;
    final isTablet = screenWidth >= 600;

    // Responsive available width & card dimensions for both orientations
    final availableWidth = isPortrait
        ? (screenWidth - 48).clamp(260.0, screenWidth * 0.88)
        : (screenWidth - 240).clamp(260.0, screenWidth * 0.70);

    final cardWidth = isPortrait
        ? (screenWidth * 0.155).clamp(50.0, isTablet ? 82.0 : 66.0)
        : (screenHeight * 0.155).clamp(40.0, isTablet ? 70.0 : 55.0);
    final cardHeight = cardWidth / playingCardAspectRatio;

    // Calculate overlap dynamically so they always fit perfectly
    double overlap = 0.0;
    if (cards.length > 1) {
      overlap = (availableWidth - cardWidth) / (cards.length - 1);
    }

    // Limit maximum overlap so cards don't spread too far when few are left
    final maxOverlap = isTablet ? 48.0 : (isPortrait ? 38.0 : 34.0);
    final actualOverlap = overlap < maxOverlap ? overlap : maxOverlap;

    final totalWidth = cardWidth + (cards.length - 1) * actualOverlap;
    final stackHeight = cardHeight + (isPortrait ? 32.0 : 16.0);

    // Fix #7: Compute playability ONCE per card per build.
    final isTrickTurn =
        widget.isMyTurn && widget.state?.phase == GamePhase.trickTaking;
    final playable = List<bool>.generate(
      cards.length,
      (i) => _isPlayable(cards[i]),
    );

    final centerIndex = (cards.length - 1) / 2.0;

    return SizedBox(
      height: stackHeight,
      width: totalWidth,
      child: Center(
        child: SizedBox(
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
                          selected: _selected == cards[i],
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
        ),
      ),
    );
  }
}
