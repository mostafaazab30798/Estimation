// lib/widgets/player_hand.dart
//
// Fanned/two-row hand for the local player.
// When cards > 6 (e.g. 13 cards), renders in two clear rows so the full card is visible.
// When cards <= 6, renders in a single spacious centered row.

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
  // ValueNotifier — card highlight; no setState needed.
  final _selected = ValueNotifier<PlayingCard?>(null);

  @override
  void dispose() {
    _selected.dispose();
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
      // Second tap = confirm play
      widget.onPlayCard(card);
      _selected.value = null;
    } else {
      _selected.value = card;
    }
  }

  Widget _buildCardRow({
    required List<PlayingCard> cards,
    required List<int> originalIndices,
    required double cardWidth,
    required double cardHeight,
    required PlayingCard? selected,
    required List<bool> playable,
    required bool isTrickTurn,
    required double availableWidth,
    required bool isPortrait,
    required bool isTablet,
  }) {
    if (cards.isEmpty) return const SizedBox.shrink();

    // Overlap calculation for this row
    final maxCardStep = cardWidth + 4.0;
    double step = maxCardStep;
    if (cards.length > 1) {
      final calculatedStep = (availableWidth - cardWidth) / (cards.length - 1);
      step = calculatedStep < maxCardStep ? calculatedStep : maxCardStep;
    }

    final rowWidth = cardWidth + (cards.length - 1) * step;

    return SizedBox(
      width: rowWidth,
      height: cardHeight + 10.0,
      child: Stack(
        clipBehavior: Clip.none,
        alignment: Alignment.centerLeft,
        children: [
          for (int i = 0; i < cards.length; i++)
            AnimatedPositioned(
              key: ValueKey(cards[i].id),
              duration: const Duration(milliseconds: 250),
              curve: Curves.easeOutCubic,
              left: i * step,
              bottom: selected == cards[i] ? 10.0 : 0.0,
              child: PlayingCardWidget(
                card: cards[i],
                selected: selected == cards[i],
                playable: playable[originalIndices[i]],
                dimmed: isTrickTurn && !playable[originalIndices[i]],
                width: cardWidth,
                onTap: () => _handleTap(cards[i]),
              ),
            ),
        ],
      ),
    );
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
            ? (screenWidth - 32).clamp(280.0, screenWidth * 0.94)
            : (screenWidth - 220).clamp(300.0, screenWidth * 0.75);

        final bool useTwoRows = cards.length > 6;

        // Card width calculation: with 2 rows, max cards per row is 7
        final cardWidth = isPortrait
            ? (useTwoRows
                ? (availableWidth / 7.2).clamp(44.0, isTablet ? 72.0 : 56.0)
                : (availableWidth / (cards.length + 0.5)).clamp(48.0, isTablet ? 84.0 : 66.0))
            : (useTwoRows
                ? (screenHeight * 0.16).clamp(42.0, isTablet ? 70.0 : 54.0)
                : (screenHeight * 0.18).clamp(46.0, isTablet ? 76.0 : 60.0));

        final cardHeight = cardWidth / playingCardAspectRatio;

        // Compute playability ONCE per card per build.
        final isTrickTurn =
            widget.isMyTurn && widget.state?.phase == GamePhase.trickTaking;
        final playable = List<bool>.generate(
          cards.length,
          (i) => _isPlayable(cards[i]),
        );

        Widget content;

        if (useTwoRows) {
          final splitIndex = (cards.length + 1) ~/ 2;
          final row1Cards = cards.sublist(0, splitIndex);
          final row2Cards = cards.sublist(splitIndex);

          final row1Indices = List<int>.generate(row1Cards.length, (i) => i);
          final row2Indices =
              List<int>.generate(row2Cards.length, (i) => splitIndex + i);

          content = Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              _buildCardRow(
                cards: row1Cards,
                originalIndices: row1Indices,
                cardWidth: cardWidth,
                cardHeight: cardHeight,
                selected: selected,
                playable: playable,
                isTrickTurn: isTrickTurn,
                availableWidth: availableWidth,
                isPortrait: isPortrait,
                isTablet: isTablet,
              ),
              const SizedBox(height: 2),
              _buildCardRow(
                cards: row2Cards,
                originalIndices: row2Indices,
                cardWidth: cardWidth,
                cardHeight: cardHeight,
                selected: selected,
                playable: playable,
                isTrickTurn: isTrickTurn,
                availableWidth: availableWidth,
                isPortrait: isPortrait,
                isTablet: isTablet,
              ),
            ],
          );
        } else {
          final allIndices = List<int>.generate(cards.length, (i) => i);
          content = _buildCardRow(
            cards: cards,
            originalIndices: allIndices,
            cardWidth: cardWidth,
            cardHeight: cardHeight,
            selected: selected,
            playable: playable,
            isTrickTurn: isTrickTurn,
            availableWidth: availableWidth,
            isPortrait: isPortrait,
            isTablet: isTablet,
          );
        }

        return content;
      },
    );
  }
}
