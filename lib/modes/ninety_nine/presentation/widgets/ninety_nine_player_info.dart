// lib/modes/ninety_nine/presentation/widgets/ninety_nine_player_info.dart

import 'package:flutter/material.dart';
import 'package:estimation/theme/app_theme.dart';
import 'package:estimation/widgets/hud/glass_player_card.dart';
import 'package:estimation/widgets/hud/player_avatar_ring.dart';
import 'package:estimation/modes/ninety_nine/presentation/providers/ninety_nine_game_provider.dart';

class NinetyNinePlayerInfoWidget extends StatelessWidget {
  final NinetyNinePlayer player;
  final int losses;
  final bool isCurrentTurn;
  final bool isMe;
  final bool compact;
  final bool isRight;
  final NinetyNinePhase phase;

  const NinetyNinePlayerInfoWidget({
    super.key,
    required this.player,
    required this.losses,
    required this.phase,
    this.isCurrentTurn = false,
    this.isMe = false,
    this.compact = false,
    this.isRight = false,
  });

  Color _resolveAccentColor() {
    if (isCurrentTurn) return AppTheme.gold;
    if (losses >= 4) return AppTheme.playerRed; // Danger zone
    return AppTheme.steelBlue;
  }

  @override
  Widget build(BuildContext context) {
    final accentColor = _resolveAccentColor();

    return RepaintBoundary(
      child: GlassPlayerCard(
        isCurrentTurn: isCurrentTurn,
        accentColor: accentColor,
        compact: compact,
        child: compact
            ? _buildCompact(accentColor)
            : _buildFull(accentColor),
      ),
    );
  }

  Widget _buildFull(Color accentColor) {
    if (isMe) {
      return Row(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          PlayerAvatarRing(
            photoData: null,
            playerName: player.name,
            size: 40,
            ringColor: accentColor,
            isCurrentTurn: isCurrentTurn,
            compact: false,
          ),
          const SizedBox(width: 10),
          _buildLossesDisplay(compact: false),
        ],
      );
    }

    return Row(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        PlayerAvatarRing(
          photoData: null,
          playerName: player.name,
          size: 40,
          ringColor: accentColor,
          isCurrentTurn: isCurrentTurn,
          compact: false,
        ),
        const SizedBox(width: 10),
        Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildNameRow(compact: false),
            const SizedBox(height: 5),
            _buildLossesDisplay(compact: false),
          ],
        ),
      ],
    );
  }

  Widget _buildCompact(Color accentColor) {
    if (isMe) {
      return Row(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          PlayerAvatarRing(
            photoData: null,
            playerName: player.name,
            size: 26,
            ringColor: accentColor,
            isCurrentTurn: isCurrentTurn,
            compact: true,
          ),
          const SizedBox(width: 6),
          _buildLossesDisplay(compact: true),
        ],
      );
    }

    return Row(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        PlayerAvatarRing(
          photoData: null,
          playerName: player.name,
          size: 26,
          ringColor: accentColor,
          isCurrentTurn: isCurrentTurn,
          compact: true,
        ),
        const SizedBox(width: 6),
        Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildNameRow(compact: true),
            const SizedBox(height: 3),
            _buildLossesDisplay(compact: true),
          ],
        ),
      ],
    );
  }

  Widget _buildNameRow({required bool compact}) {
    final fontSize = compact ? 10.0 : 12.5;
    final displayName = isMe ? 'أنا' : player.name;

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Flexible(
          child: Text(
            displayName,
            style: TextStyle(
              fontFamily: 'Cairo',
              fontSize: fontSize,
              fontWeight: FontWeight.w700,
              color: AppTheme.cream,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }

  Widget _buildLossesDisplay({required bool compact}) {
    final fontSize = compact ? 12.0 : 16.0;
    final heartSize = compact ? 10.0 : 14.0;
    
    return Row(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.baseline,
      textBaseline: TextBaseline.alphabetic,
      children: [
        Text(
          '💔',
          style: TextStyle(fontSize: heartSize),
        ),
        const SizedBox(width: 4),
        Text(
          '$losses/5',
          style: TextStyle(
            fontFamily: 'Cairo',
            fontSize: fontSize,
            fontWeight: FontWeight.w900,
            color: losses >= 4 ? AppTheme.playerRed : AppTheme.gold,
            shadows: [
              if (losses >= 4)
                BoxShadow(
                  color: AppTheme.playerRed.withValues(alpha: 0.5),
                  blurRadius: 6,
                )
            ],
          ),
        ),
      ],
    );
  }
}
