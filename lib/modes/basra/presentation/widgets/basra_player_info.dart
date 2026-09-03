// lib/modes/basra/presentation/widgets/basra_player_info.dart

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:estimation/modes/basra/domain/models/basra_game_state.dart';
import 'package:estimation/theme/app_theme.dart';
import 'package:estimation/widgets/hud/glass_player_card.dart';
import 'package:estimation/widgets/hud/player_avatar_ring.dart';
import 'package:estimation/widgets/hud/score_display.dart';

class BasraPlayerInfoWidget extends StatelessWidget {
  final BasraPlayer player;
  final bool isCurrentTurn;
  final bool isMe;
  final bool compact;

  const BasraPlayerInfoWidget({
    super.key,
    required this.player,
    this.isCurrentTurn = false,
    this.isMe = false,
    this.compact = false,
  });

  @override
  Widget build(BuildContext context) {
    final accent = isCurrentTurn ? AppTheme.gold : AppTheme.steelBlue;
    return RepaintBoundary(
      child: GlassPlayerCard(
        isCurrentTurn: isCurrentTurn,
        accentColor: accent,
        compact: true,
        child: compact ? _buildCompact(accent) : _buildMe(accent),
      ),
    );
  }

  Widget _buildCompact(Color accent) {
    final name = player.name.length > 8
        ? '${player.name.substring(0, 8)}…'
        : player.name;
    return ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 78),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          PlayerAvatarRing(
            photoData: player.isBot ? null : player.avatarId,
            playerName: player.name,
            fallbackAvatarKey: player.id,
            size: 22,
            ringColor: accent,
            isCurrentTurn: isCurrentTurn,
            compact: true,
          ),
          const SizedBox(width: 5),
          Flexible(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.cairo(
                    color: AppTheme.cream,
                    fontSize: 9.5,
                    fontWeight: FontWeight.w700,
                    height: 1.1,
                  ),
                ),
                const SizedBox(height: 1),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    ScoreDisplay(score: player.totalScore, compact: true),
                    const SizedBox(width: 4),
                    _miniChip('${player.capturedCards.length}'),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMe(Color accent) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        PlayerAvatarRing(
          photoData: player.isBot ? null : player.avatarId,
          playerName: player.name,
          fallbackAvatarKey: player.id,
          size: 26,
          ringColor: accent,
          isCurrentTurn: isCurrentTurn,
          compact: true,
        ),
        const SizedBox(width: 6),
        ScoreDisplay(score: player.totalScore, compact: true),
        const SizedBox(width: 6),
        _miniChip('${player.capturedCards.length} ورقة'),
        if (player.basraCount > 0) ...[
          const SizedBox(width: 4),
          _miniChip('باصرة ${player.basraCount}', gold: true),
        ],
      ],
    );
  }

  Widget _miniChip(String label, {bool gold = false}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
      decoration: BoxDecoration(
        color: AppTheme.navyDark.withValues(alpha: 0.7),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: (gold ? AppTheme.gold : Colors.white24).withValues(alpha: 0.5),
        ),
      ),
      child: Text(
        label,
        style: GoogleFonts.cairo(
          color: gold ? AppTheme.gold : AppTheme.cream,
          fontSize: 8.5,
          fontWeight: FontWeight.w800,
          height: 1.2,
        ),
      ),
    );
  }
}
