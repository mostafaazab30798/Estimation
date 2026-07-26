// lib/widgets/player_info.dart
//
// AAA-quality PlayerInfoWidget — premium HUD card for each player position.
// Preserves the exact same public API and game logic from the original.
// Visual presentation is completely redesigned.

import 'package:flutter/material.dart';
import '../core/models/player.dart';
import '../core/models/game_state.dart';
import '../theme/app_theme.dart';
import 'hud/glass_player_card.dart';
import 'hud/player_avatar_ring.dart';
import 'hud/rank_ribbon.dart';
import 'hud/score_display.dart';
import 'hud/trick_progress_indicator.dart';
import 'hud/status_badge.dart';

class PlayerInfoWidget extends StatefulWidget {
  final Player player;
  final bool isCurrentTurn;
  final bool isBidder;
  final bool isMe;
  final GameState state;
  final bool compact;

  const PlayerInfoWidget({
    super.key,
    required this.player,
    required this.state,
    this.isCurrentTurn = false,
    this.isBidder = false,
    this.isMe = false,
    this.compact = false,
  });

  @override
  State<PlayerInfoWidget> createState() => _PlayerInfoWidgetState();
}

class _PlayerInfoWidgetState extends State<PlayerInfoWidget> {
  // Delayed trick counter — lets the trick-win animation play before
  // the score bar updates (same logic as the original widget).
  late int _displayActual;
  bool _isWaitingToUpdate = false;

  @override
  void initState() {
    super.initState();
    _displayActual = widget.player.actual;
  }

  @override
  void didUpdateWidget(covariant PlayerInfoWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.player.actual > _displayActual && !_isWaitingToUpdate) {
      _isWaitingToUpdate = true;
      Future.delayed(const Duration(milliseconds: 1000), () {
        if (mounted) {
          setState(() {
            _displayActual = widget.player.actual;
            _isWaitingToUpdate = false;
          });
        }
      });
    } else if (widget.player.actual < _displayActual) {
      _displayActual = widget.player.actual;
      _isWaitingToUpdate = false;
    }
  }

  // O(n) rank computation — same logic as original, zero extra allocations.
  int _computeRankIndex() {
    int rankIndex = 0;
    for (final p in widget.state.players) {
      if (p.id != widget.player.id && p.totalScore > widget.player.totalScore) {
        rankIndex++;
      }
    }
    return rankIndex;
  }

  Color _resolveAccentColor() {
    return AppTheme.avatarRingColor(
      isCurrentTurn: widget.isCurrentTurn,
      actual: _displayActual,
      declared: widget.player.declared,
      tricksPlayedThisRound: widget.state.tricksPlayedThisRound,
    );
  }

  @override
  Widget build(BuildContext context) {
    final rankIndex = _computeRankIndex();
    final accentColor = _resolveAccentColor();
    final isDealer = widget.state.dealerSeatIndex == widget.player.seatIndex;

    return RepaintBoundary(
      child: GlassPlayerCard(
        isCurrentTurn: widget.isCurrentTurn,
        accentColor: accentColor,
        compact: widget.compact,
        child: widget.compact
            ? _buildCompact(rankIndex, accentColor, isDealer)
            : _buildFull(rankIndex, accentColor, isDealer),
      ),
    );
  }

  // ── Full layout (portrait / local player) ─────────────────────────────────

  Widget _buildFull(int rankIndex, Color accentColor, bool isDealer) {
    if (widget.isMe) {
      return Row(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          // Avatar with animated ring and Rank Tag
          Stack(
            clipBehavior: Clip.none,
            children: [
              PlayerAvatarRing(
                photoData: widget.player.photo,
                playerName: widget.player.name,
                size: 40,
                ringColor: accentColor,
                isCurrentTurn: widget.isCurrentTurn,
                compact: false,
              ),
              if (rankIndex >= 0 && rankIndex <= 3)
                Positioned(
                  bottom: -2,
                  left: -2,
                  child: RankRibbon(rankIndex: rankIndex, compact: false),
                ),
            ],
          ),
          const SizedBox(width: 10),
          // Points
          ScoreDisplay(
            score: widget.player.totalScore,
            compact: false,
          ),
          if (widget.state.phase == GamePhase.trickTaking ||
              widget.player.declared != null) ...[
            const SizedBox(width: 10),
            TrickProgressIndicator(
              actual: _displayActual,
              declared: widget.player.declared,
              tricksPlayedThisRound: widget.state.tricksPlayedThisRound,
              compact: false,
            ),
          ],
        ],
      );
    }

    return Row(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        // Avatar with animated ring
        Stack(
          clipBehavior: Clip.none,
          children: [
            PlayerAvatarRing(
              photoData: widget.player.photo,
              playerName: widget.player.name,
              size: 40,
              ringColor: accentColor,
              isCurrentTurn: widget.isCurrentTurn,
              compact: false,
            ),
            if (rankIndex >= 0 && rankIndex <= 3)
              Positioned(
                bottom: -2,
                left: -2,
                child: RankRibbon(rankIndex: rankIndex, compact: false),
              ),
          ],
        ),

        const SizedBox(width: 10),

        // Info column
        Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Name row ─────────────────────────────────────────────
            _buildNameRow(rankIndex, isDealer, compact: false),

            const SizedBox(height: 5),

            // ── Score + trick progress ────────────────────────────────
            Row(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                ScoreDisplay(
                  score: widget.player.totalScore,
                  compact: false,
                ),
                if (widget.state.phase == GamePhase.trickTaking ||
                    widget.player.declared != null) ...[
                  const SizedBox(width: 10),
                  TrickProgressIndicator(
                    actual: _displayActual,
                    declared: widget.player.declared,
                    tricksPlayedThisRound: widget.state.tricksPlayedThisRound,
                    compact: false,
                  ),
                ],
              ],
            ),

            const SizedBox(height: 5),

            // ── Status badge ─────────────────────────────────────────
            StatusBadge(
              phase: widget.state.phase,
              player: widget.player,
              state: widget.state,
              isCurrentTurn: widget.isCurrentTurn,
              compact: false,
            ),
          ],
        ),
      ],
    );
  }

  // ── Compact layout (opponents, landscape) ─────────────────────────────────

  Widget _buildCompact(int rankIndex, Color accentColor, bool isDealer) {
    if (widget.isMe) {
      return Row(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          // Smaller avatar ring
          Stack(
            clipBehavior: Clip.none,
            children: [
              PlayerAvatarRing(
                photoData: widget.player.photo,
                playerName: widget.player.name,
                size: 26,
                ringColor: accentColor,
                isCurrentTurn: widget.isCurrentTurn,
                compact: true,
              ),
              if (rankIndex >= 0 && rankIndex <= 3)
                Positioned(
                  bottom: -2,
                  left: -2,
                  child: RankRibbon(rankIndex: rankIndex, compact: true),
                ),
            ],
          ),
          const SizedBox(width: 6),
          ScoreDisplay(
            score: widget.player.totalScore,
            compact: true,
          ),
          if (widget.state.phase == GamePhase.trickTaking ||
              widget.player.declared != null) ...[
            const SizedBox(width: 6),
            TrickProgressIndicator(
              actual: _displayActual,
              declared: widget.player.declared,
              tricksPlayedThisRound: widget.state.tricksPlayedThisRound,
              compact: true,
            ),
          ],
        ],
      );
    }

    return Row(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        // Smaller avatar ring
        Stack(
          clipBehavior: Clip.none,
          children: [
            PlayerAvatarRing(
              photoData: widget.player.photo,
              playerName: widget.player.name,
              size: 26,
              ringColor: accentColor,
              isCurrentTurn: widget.isCurrentTurn,
              compact: true,
            ),
            if (rankIndex >= 0 && rankIndex <= 3)
              Positioned(
                bottom: -2,
                left: -2,
                child: RankRibbon(rankIndex: rankIndex, compact: true),
              ),
          ],
        ),

        const SizedBox(width: 6),

        Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildNameRow(rankIndex, isDealer, compact: true),
            const SizedBox(height: 3),
            Row(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                ScoreDisplay(
                  score: widget.player.totalScore,
                  compact: true,
                ),
                if (widget.player.declared != null) ...[
                  const SizedBox(width: 6),
                  TrickProgressIndicator(
                    actual: _displayActual,
                    declared: widget.player.declared,
                    tricksPlayedThisRound: widget.state.tricksPlayedThisRound,
                    compact: true,
                  ),
                ],
              ],
            ),
            const SizedBox(height: 3),
            StatusBadge(
              phase: widget.state.phase,
              player: widget.player,
              state: widget.state,
              isCurrentTurn: widget.isCurrentTurn,
              compact: true,
            ),
          ],
        ),
      ],
    );
  }

  // ── Shared name row ───────────────────────────────────────────────────────

  Widget _buildNameRow(int rankIndex, bool isDealer, {required bool compact}) {
    final fontSize = compact ? 10.0 : 12.5;
    final iconSize = compact ? 10.0 : 12.0;
    final displayName = widget.isMe ? 'أنا' : widget.player.name;

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Name text — capped for long strings
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

        const SizedBox(width: 4),

        // Dealer icon
        if (isDealer)
          Tooltip(
            message: 'الموزع',
            child: Icon(Icons.style_rounded,
                color: AppTheme.steelBlue, size: iconSize),
          ),

        // Bidder icon
        if (widget.isBidder)
          Padding(
            padding: const EdgeInsets.only(left: 2),
            child: Tooltip(
              message: 'الكار الكبير',
              child: Icon(Icons.emoji_events_rounded,
                  color: AppTheme.playerGold, size: iconSize),
            ),
          ),
      ],
    );
  }
}
