// lib/widgets/playing_card_widget.dart
//
// Widget for displaying a single playing card using custom assets.

import 'package:flutter/material.dart';
import '../core/models/card.dart' as game;
import 'package:provider/provider.dart';
import '../providers/game_provider.dart';
import '../theme/app_theme.dart';

import '../core/utils/card_assets.dart';

// Fix #14: Shared const decorations ───────────────────────────────────────────

const _kCardBorderRadius = BorderRadius.all(Radius.circular(10));

// ── Widget ────────────────────────────────────────────────────────────────────

class PlayingCardWidget extends StatelessWidget {
  final game.PlayingCard? card; // null = face-down
  final bool faceDown;
  final bool selected;
  final bool playable;
  final bool dimmed;
  final double width;
  final VoidCallback? onTap;

  const PlayingCardWidget({
    super.key,
    this.card,
    this.faceDown = false,
    this.selected = false,
    this.playable = true,
    this.dimmed = false,
    this.width = 60,
    this.onTap,
  });

  double get height => width / playingCardAspectRatio;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: playable && !dimmed ? onTap : null,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        width: width,
        height: height,
        transform: selected
            ? Matrix4.translationValues(0, -14, 0)
            : Matrix4.identity(),
        child: Stack(
          children: [
            _buildCardContent(context),
            // Selection glow overlay
            if (selected)
              Positioned.fill(
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    borderRadius: _kCardBorderRadius,
                    border: Border.all(
                        color: AppTheme.gold.withValues(alpha: 0.8),
                        width: 2.0),
                    boxShadow: [
                      BoxShadow(
                        color: AppTheme.gold.withValues(alpha: 0.4),
                        blurRadius: 20,
                        spreadRadius: 4,
                      ),
                    ],
                  ),
                ),
              ),
            // Dimming overlay (not playable)
            if (dimmed)
              Positioned.fill(
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    borderRadius: _kCardBorderRadius,
                    color: Colors.black.withValues(alpha: 0.48),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildCardContent(BuildContext context) {
    final theme = context.select((GameProvider p) => p.state?.cardTheme ?? 'theme_1');
    final showBack = faceDown || card == null;
    final imagePath =
        showBack ? 'assets/back.png' : getCardAssetPath(card, theme);

    // Fix #6: cacheWidth / cacheHeight tells Flutter's image cache to decode
    // the PNG at the widget's actual pixel size, not at the full PNG resolution.
    // At 3x DPR a 65-wide card → 195 px; at 2x → 130 px.
    // We use a safe upper bound of 256 to cover all densities while still
    // dramatically reducing memory vs loading a full 338×489 card image.
    const int kCacheWidth = 256;
    final int cacheHeight = (kCacheWidth / playingCardAspectRatio).round();

    return Container(
      decoration: BoxDecoration(
        borderRadius: _kCardBorderRadius,
        boxShadow: selected
            ? [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.6),
                  blurRadius: 16,
                  spreadRadius: 2,
                  offset: const Offset(0, 10),
                ),
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.2),
                  blurRadius: 4,
                  offset: const Offset(0, 4),
                ),
              ]
            : [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.3),
                  blurRadius: 8,
                  offset: const Offset(0, 4),
                ),
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.1),
                  blurRadius: 2,
                  offset: const Offset(0, 2),
                ),
              ],
      ),
      child: ClipRRect(
        borderRadius: _kCardBorderRadius,
        child: Image.asset(
          imagePath,
          width: width,
          height: height,
          fit: BoxFit.contain,
          cacheWidth: kCacheWidth,
          cacheHeight: cacheHeight,
        ),
      ),
    );
  }
}

/// Custom PNG aspect ratio (338x489)
const double playingCardAspectRatio = 338.0 / 489.0;
