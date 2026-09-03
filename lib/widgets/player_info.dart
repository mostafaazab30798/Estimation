// lib/widgets/player_info.dart
//
// Premium HUD card for each player position.

import 'package:flutter/material.dart';
import '../core/constants.dart';
import '../core/models/player.dart';
import '../core/models/game_state.dart';
import '../theme/app_theme.dart';
import 'hud/glass_player_card.dart';
import 'hud/player_avatar_ring.dart';
import 'hud/rank_ribbon.dart';
import 'hud/score_display.dart';
import 'hud/trick_progress_indicator.dart';
import 'hud/status_badge.dart';
import 'package:estimation/core/icons/app_icons.dart';
import '../services/auth_service.dart';
import '../widgets/user_safety_sheet.dart';

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
  late final _displayActual = ValueNotifier<int>(0);
  bool _isWaitingToUpdate = false;

  @override
  void initState() {
    super.initState();
    _displayActual.value = widget.player.actual;
  }

  @override
  void dispose() {
    _displayActual.dispose();
    super.dispose();
  }

  @override
  void didUpdateWidget(covariant PlayerInfoWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.player.actual > _displayActual.value && !_isWaitingToUpdate) {
      _isWaitingToUpdate = true;
      Future.delayed(const Duration(milliseconds: 1000), () {
        if (mounted) {
          _displayActual.value = widget.player.actual;
          _isWaitingToUpdate = false;
        }
      });
    } else if (widget.player.actual < _displayActual.value) {
      _displayActual.value = widget.player.actual;
      _isWaitingToUpdate = false;
    }
  }

  int _computeRankIndex() {
    int rankIndex = 0;
    for (final p in widget.state.players) {
      if (p.id != widget.player.id && p.totalScore > widget.player.totalScore) {
        rankIndex++;
      }
    }
    return rankIndex;
  }

  Color _resolveAccentColor(int displayActual) {
    return AppTheme.avatarRingColor(
      isCurrentTurn: widget.isCurrentTurn,
      actual: displayActual,
      declared: widget.player.declared,
      tricksPlayedThisRound: widget.state.tricksPlayedThisRound,
    );
  }

  bool get _showTrumpOnBidder =>
      widget.isBidder && widget.state.trump != null;

  List<Widget> _buildBidderIndicators({required bool compact}) {
    if (!_showTrumpOnBidder) return const [];

    return [
      SizedBox(width: compact ? 4 : 6),
      _BidderTrumpChip(trump: widget.state.trump!, compact: compact),
    ];
  }

  List<Widget> _buildDealerIndicator({
    required bool isDealer,
    required bool compact,
  }) {
    if (!isDealer) return const [];

    final iconSize = compact ? 10.0 : 12.0;

    return [
      SizedBox(width: compact ? 4 : 6),
      Tooltip(
        message: 'الموزع',
        child: AppIcon(
          AppIcons.style,
          color: AppTheme.steelBlue,
          size: iconSize,
        ),
      ),
    ];
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<int>(
      valueListenable: _displayActual,
      builder: (context, displayActual, _) {
        final rankIndex = _computeRankIndex();
        final accentColor = _resolveAccentColor(displayActual);
        final isDealer = widget.state.dealerSeatIndex == widget.player.seatIndex;

        return RepaintBoundary(
          child: GestureDetector(
            onLongPress: (!widget.isMe &&
                    widget.player.id.length > 20 &&
                    AuthService.instance.isAuthenticated)
                ? () => showUserSafetySheet(
                      context,
                      reportedUserId: widget.player.id,
                      displayName: widget.player.name,
                      contextType: 'estimation_match',
                    )
                : null,
            child: GlassPlayerCard(
            isCurrentTurn: widget.isCurrentTurn,
            accentColor: accentColor,
            compact: widget.compact,
            child: widget.compact
                ? _buildCompact(rankIndex, accentColor, isDealer, displayActual)
                : _buildFull(rankIndex, accentColor, isDealer, displayActual),
          ),
          ),
        );
      },
    );
  }

  // ── Full layout ───────────────────────────────────────────────────────────

  Widget _buildFull(int rankIndex, Color accentColor, bool isDealer, int displayActual) {
    if (widget.isMe) {
      return Row(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          PlayerAvatarRing(
            photoData:
                widget.player.id.startsWith('bot_') ? null : widget.player.photo,
            playerName: widget.player.name,
            fallbackAvatarKey: widget.player.id,
            fallbackAvatarIndex: widget.player.seatIndex,
            size: 40,
            ringColor: accentColor,
            isCurrentTurn: widget.isCurrentTurn,
            compact: false,
            turnDurationSeconds: widget.state.turnDurationSeconds,
            turnDeadlineEpochMs: widget.state.turnDeadlineEpochMs,
          ),
          const SizedBox(width: 10),
          ScoreDisplay(score: widget.player.totalScore, compact: false),
          if (widget.state.phase == GamePhase.trickTaking ||
              widget.player.declared != null) ...[
            const SizedBox(width: 10),
            TrickProgressIndicator(
              actual: displayActual,
              declared: widget.player.declared,
              tricksPlayedThisRound: widget.state.tricksPlayedThisRound,
              compact: false,
            ),
          ],
          ..._buildDealerIndicator(isDealer: isDealer, compact: false),
          ..._buildBidderIndicators(compact: false),
          if (rankIndex >= 0 && rankIndex <= 3) ...[
            const SizedBox(width: 8),
            RankRibbon(rankIndex: rankIndex, compact: false),
          ],
        ],
      );
    }

    return Row(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        PlayerAvatarRing(
          photoData:
              widget.player.id.startsWith('bot_') ? null : widget.player.photo,
          playerName: widget.player.name,
          fallbackAvatarKey: widget.player.id,
          fallbackAvatarIndex: widget.player.seatIndex,
          size: 40,
          ringColor: accentColor,
          isCurrentTurn: widget.isCurrentTurn,
          compact: false,
          turnDurationSeconds: widget.state.turnDurationSeconds,
          turnDeadlineEpochMs: widget.state.turnDeadlineEpochMs,
        ),
        const SizedBox(width: 10),
        Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildNameRow(rankIndex, compact: false),
            const SizedBox(height: 5),
            Row(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                ScoreDisplay(score: widget.player.totalScore, compact: false),
                if (widget.state.phase == GamePhase.trickTaking ||
                    widget.player.declared != null) ...[
                  const SizedBox(width: 10),
                  TrickProgressIndicator(
                    actual: displayActual,
                    declared: widget.player.declared,
                    tricksPlayedThisRound: widget.state.tricksPlayedThisRound,
                    compact: false,
                  ),
                ],
                ..._buildDealerIndicator(isDealer: isDealer, compact: false),
                ..._buildBidderIndicators(compact: false),
              ],
            ),
            const SizedBox(height: 5),
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

  // ── Compact layout (side / landscape opponents) ───────────────────────────

  Widget _buildCompact(int rankIndex, Color accentColor, bool isDealer, int displayActual) {
    if (widget.isMe) {
      return Row(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          PlayerAvatarRing(
            photoData:
                widget.player.id.startsWith('bot_') ? null : widget.player.photo,
            playerName: widget.player.name,
            fallbackAvatarKey: widget.player.id,
            fallbackAvatarIndex: widget.player.seatIndex,
            size: 24,
            ringColor: accentColor,
            isCurrentTurn: widget.isCurrentTurn,
            compact: true,
            turnDurationSeconds: widget.state.turnDurationSeconds,
            turnDeadlineEpochMs: widget.state.turnDeadlineEpochMs,
          ),
          const SizedBox(width: 5),
          ScoreDisplay(score: widget.player.totalScore, compact: true),
          if (widget.state.phase == GamePhase.trickTaking ||
              widget.player.declared != null) ...[
            const SizedBox(width: 5),
            TrickProgressIndicator(
              actual: displayActual,
              declared: widget.player.declared,
              tricksPlayedThisRound: widget.state.tricksPlayedThisRound,
              compact: true,
            ),
          ],
          ..._buildDealerIndicator(isDealer: isDealer, compact: true),
          ..._buildBidderIndicators(compact: true),
          if (rankIndex >= 0 && rankIndex <= 3) ...[
            const SizedBox(width: 4),
            RankRibbon(rankIndex: rankIndex, compact: true),
          ],
        ],
      );
    }

    // Side cards: avatar + rank stacked, narrow info column.
    return Row(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            PlayerAvatarRing(
              photoData: widget.player.id.startsWith('bot_')
                  ? null
                  : widget.player.photo,
              playerName: widget.player.name,
              fallbackAvatarKey: widget.player.id,
              fallbackAvatarIndex: widget.player.seatIndex,
              size: 24,
              ringColor: accentColor,
              isCurrentTurn: widget.isCurrentTurn,
              compact: true,
              turnDurationSeconds: widget.state.turnDurationSeconds,
              turnDeadlineEpochMs: widget.state.turnDeadlineEpochMs,
            ),
            if (rankIndex >= 0 && rankIndex <= 3) ...[
              const SizedBox(height: 3),
              RankRibbon(rankIndex: rankIndex, compact: true),
            ],
          ],
        ),
        const SizedBox(width: 5),
        ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 84),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildCompactNameRow(),
              const SizedBox(height: 2),
              Row(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  ScoreDisplay(score: widget.player.totalScore, compact: true),
                  if (widget.player.declared != null) ...[
                    const SizedBox(width: 4),
                    Flexible(
                      child: TrickProgressIndicator(
                        actual: displayActual,
                        declared: widget.player.declared,
                        tricksPlayedThisRound: widget.state.tricksPlayedThisRound,
                        compact: true,
                      ),
                    ),
                  ],
                  ..._buildDealerIndicator(isDealer: isDealer, compact: true),
                  ..._buildBidderIndicators(compact: true),
                ],
              ),
              const SizedBox(height: 2),
              FittedBox(
                fit: BoxFit.scaleDown,
                alignment: AlignmentDirectional.centerStart,
                child: StatusBadge(
                  phase: widget.state.phase,
                  player: widget.player,
                  state: widget.state,
                  isCurrentTurn: widget.isCurrentTurn,
                  compact: true,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildCompactNameRow() {
    final displayName = widget.isMe ? 'أنا' : widget.player.name;

    return Row(
      children: [
        Expanded(
          child: Text(
            displayName,
            style: const TextStyle(
              fontFamily: 'Cairo',
              fontSize: 10,
              fontWeight: FontWeight.w700,
              color: AppTheme.cream,
              height: 1.1,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }

  // ── Full name row ─────────────────────────────────────────────────────────

  Widget _buildNameRow(int rankIndex, {required bool compact}) {
    final fontSize = compact ? 10.0 : 12.5;
    final displayName = widget.isMe ? 'أنا' : widget.player.name;

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
        if (rankIndex >= 0 && rankIndex <= 3) ...[
          SizedBox(width: compact ? 4 : 6),
          RankRibbon(rankIndex: rankIndex, compact: compact),
        ],
      ],
    );
  }
}

/// Compact trump indicator shown on the bid-winner card.
class _BidderTrumpChip extends StatelessWidget {
  final Trump trump;
  final bool compact;

  const _BidderTrumpChip({required this.trump, required this.compact});

  @override
  Widget build(BuildContext context) {
    final isSans = trump == Trump.sans;
    final Color accent;
    final String symbol;

    if (isSans) {
      accent = const Color(0xFFA78BFA);
      symbol = '🚫';
    } else {
      final isRed = trump.color == SuitColor.red;
      accent = isRed ? AppTheme.suitRed : AppTheme.steelBlue;
      symbol = trump.label;
    }

    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: compact ? 4 : 5,
        vertical: compact ? 1.5 : 2,
      ),
      decoration: BoxDecoration(
        color: accent.withValues(alpha: 0.16),
        borderRadius: BorderRadius.circular(compact ? 7 : 8),
        border: Border.all(color: accent.withValues(alpha: 0.45)),
      ),
      child: Text(
        symbol,
        style: TextStyle(
          fontSize: compact ? 11 : 12,
          color: accent,
          fontWeight: FontWeight.bold,
          height: 1,
        ),
      ),
    );
  }
}
