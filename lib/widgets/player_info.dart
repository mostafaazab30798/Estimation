// lib/widgets/player_info.dart
//
// Player name + score pill shown at each corner of the table.

import 'dart:ui';
import 'package:flutter/material.dart';

import '../core/models/player.dart';
import '../core/models/game_state.dart';
import '../theme/app_theme.dart';
import '../core/widgets/player_avatar.dart';

// Fix #14: Static const decorations — never re-allocated.
const _kBorderRadius = BorderRadius.all(Radius.circular(24));
const _kPillBorderRadius = BorderRadius.all(Radius.circular(12));

class PlayerInfoWidget extends StatefulWidget {
  final Player player;
  final bool isCurrentTurn;
  final bool isBidder;
  final bool isMe;
  final GameState state;

  const PlayerInfoWidget({
    super.key,
    required this.player,
    required this.state,
    this.isCurrentTurn = false,
    this.isBidder = false,
    this.isMe = false,
    this.compact = false,
  });

  final bool compact;

  @override
  State<PlayerInfoWidget> createState() => _PlayerInfoWidgetState();
}

class _PlayerInfoWidgetState extends State<PlayerInfoWidget> {
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

  // Fix #3: Compute rank once per build using a simple linear scan instead of
  // creating + sorting a full copy of the player list every single time.
  // O(n) with zero allocations beyond the loop variable.
  int _computeRankIndex() {
    int rankIndex = 0;
    for (final p in widget.state.players) {
      if (p.id != widget.player.id && p.totalScore > widget.player.totalScore) {
        rankIndex++;
      }
    }
    return rankIndex;
  }

  @override
  Widget build(BuildContext context) {
    final rankIndex = _computeRankIndex();
    const rankTitles = ['كينج 👑', 'صب كينج 🥈', 'صب كوز 🥉', 'كوز 🤡'];
    final rankText =
        rankIndex >= 0 && rankIndex < 4 ? ' - ${rankTitles[rankIndex]}' : '';
    final statusHint = _buildPhaseStatusHint();

    return ClipRRect(
      borderRadius: _kBorderRadius,
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 8, sigmaY: 8),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: EdgeInsets.symmetric(
            horizontal: widget.compact ? 8 : 12,
            vertical: widget.compact ? 4 : 8,
          ),
          decoration: BoxDecoration(
            color: widget.isCurrentTurn
                ? AppTheme.gold.withValues(alpha: 0.25)
                : AppTheme.navyMid.withValues(alpha: 0.85),
            borderRadius: _kBorderRadius,
            border: Border.all(
              color: widget.isCurrentTurn
                  ? AppTheme.gold
                  : Colors.white.withValues(alpha: 0.18),
              width: widget.isCurrentTurn ? 2.5 : 1.0,
            ),
            boxShadow: widget.isCurrentTurn
                ? AppTheme.neumorphicTurnGlow(AppTheme.gold)
                : AppTheme.neumorphicExtruded,
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Avatar
              if (widget.player.photo != null)
                PlayerAvatar(
                  photoData: widget.player.photo!,
                  size: widget.compact ? 24 : 40,
                  borderColor: widget.isCurrentTurn ? AppTheme.gold : Colors.white24,
                  borderWidth: widget.isCurrentTurn ? 2.0 : 1.0,
                  boxShadow: widget.isCurrentTurn
                      ? [
                          BoxShadow(
                            color: AppTheme.gold.withValues(alpha: 0.8),
                            blurRadius: 12,
                          )
                        ]
                      : [],
                )
              else
                Container(
                  width: widget.compact ? 24 : 40,
                  height: widget.compact ? 24 : 40,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: AppTheme.navyDark,
                    border: Border.all(
                      color: widget.isCurrentTurn ? AppTheme.gold : Colors.white24,
                      width: widget.isCurrentTurn ? 2.0 : 1.0,
                    ),
                    boxShadow: widget.isCurrentTurn
                        ? [
                            BoxShadow(
                              color: AppTheme.gold.withValues(alpha: 0.8),
                              blurRadius: 12,
                            )
                          ]
                        : [],
                  ),
                  alignment: Alignment.center,
                  child: Text(
                    widget.player.name.isNotEmpty ? widget.player.name[0].toUpperCase() : '?',
                    style: TextStyle(
                      fontSize: widget.compact ? 12 : 16,
                      fontWeight: FontWeight.bold,
                      color: AppTheme.textPrimary,
                    ),
                  ),
                ),
              SizedBox(width: widget.compact ? 6 : 10),
              // Info
              Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (widget.isBidder) ...[
                        Text('🔥',
                            style: TextStyle(fontSize: widget.compact ? 10 : 12)), // Bidder marker
                        SizedBox(width: widget.compact ? 2 : 4),
                      ],
                      Text(
                        widget.isMe
                            ? 'أنا$rankText'
                            : '${widget.player.name}$rankText',
                        style: TextStyle(
                          fontSize: widget.compact ? 10 : 13,
                          fontWeight: FontWeight.w600,
                          color: AppTheme.white,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                  SizedBox(height: widget.compact ? 2 : 4),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      _pill('${widget.player.totalScore} pts', AppTheme.gold, ''),
                      if (widget.player.declared != null) ...[
                        SizedBox(width: widget.compact ? 2 : 4),
                        _pill('$_displayActual/${widget.player.declared}',
                            Colors.lightBlueAccent, ''),
                      ],
                    ],
                  ),
                  if (statusHint != null) ...[
                    SizedBox(height: widget.compact ? 2 : 4),
                    statusHint,
                  ],
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget? _buildPhaseStatusHint() {
    switch (widget.state.phase) {
      case GamePhase.voidCheck:
        if (widget.isMe) return null;
        final isReady = widget.state.voidCheckPassed.contains(widget.player.id);
        return Text(
          isReady ? '✅ جاهز' : '⏳ ينتظر...',
          style: TextStyle(
            fontSize: widget.compact ? 9 : 11,
            color: isReady ? Colors.greenAccent : Colors.white70,
            fontWeight: FontWeight.w600,
          ),
        );

      case GamePhase.auction:
        final isTurn = widget.state.auctionTurnSeatIndex == widget.player.seatIndex;
        final isPassed = widget.player.hasPassed;
        final isHighBidder = widget.state.currentHighBidderPlayerId == widget.player.id;

        if (isPassed) {
          return Text(
            '❌ باس',
            style: TextStyle(
              fontSize: widget.compact ? 9 : 11,
              color: AppTheme.errorRed.withValues(alpha: 0.85),
              fontWeight: FontWeight.w600,
            ),
          );
        } else if (isTurn) {
          return Text(
            '⏳ دور المزايدة',
            style: TextStyle(
              fontSize: widget.compact ? 9 : 11,
              color: AppTheme.gold,
              fontWeight: FontWeight.bold,
            ),
          );
        } else if (isHighBidder && widget.state.currentHighBid != null) {
          return Text(
            '🔥 أعلى: ${widget.state.currentHighBid!.arabicLabel}',
            style: TextStyle(
              fontSize: widget.compact ? 9 : 11,
              color: AppTheme.gold,
              fontWeight: FontWeight.w600,
            ),
          );
        } else {
          return Text(
            '⏳ ينتظر...',
            style: TextStyle(
              fontSize: widget.compact ? 9 : 11,
              color: Colors.white70,
            ),
          );
        }

      case GamePhase.declarations:
        final isTurn = widget.state.currentPlayerSeatIndex == widget.player.seatIndex;
        if (widget.player.declared != null) {
          return Text(
            '✅ صرّح (${widget.player.declared})',
            style: TextStyle(
              fontSize: widget.compact ? 9 : 11,
              color: Colors.lightBlueAccent,
              fontWeight: FontWeight.w600,
            ),
          );
        } else if (isTurn) {
          return Text(
            '⏳ دور التصريح',
            style: TextStyle(
              fontSize: widget.compact ? 9 : 11,
              color: AppTheme.gold,
              fontWeight: FontWeight.bold,
            ),
          );
        } else {
          return Text(
            '⏳ ينتظر...',
            style: TextStyle(
              fontSize: widget.compact ? 9 : 11,
              color: Colors.white70,
            ),
          );
        }

      default:
        return null;
    }
  }
  Widget _pill(String value, Color color, String label) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: widget.compact ? 4 : 6, vertical: 0),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: _kPillBorderRadius,
        border: Border.all(color: color.withValues(alpha: 0.4)),
      ),
      child: Text(
        label.isEmpty ? value : '$value $label',
        style: TextStyle(
            fontSize: widget.compact ? 9 : 11, color: color, fontWeight: FontWeight.w600),
      ),
    );
  }
}
