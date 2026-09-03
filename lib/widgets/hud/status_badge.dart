// lib/widgets/hud/status_badge.dart
//
// Floating gradient badge that visually communicates the current player
// status during each game phase. Replaces plain text status hints.

import 'package:flutter/material.dart';
import '../../theme/app_theme.dart';
import '../../core/models/game_state.dart';
import '../../core/models/player.dart';
import 'package:estimation/core/icons/app_icons.dart';

enum _PlayerStatus {
  waiting,
  currentTurn,
  passed,
  declaring,
  auctionTurn,
  highBidder,
  ready,
  declared,
  none,
}

/// Computes the visual [_PlayerStatus] from the game state.
_PlayerStatus _resolveStatus({
  required GamePhase phase,
  required Player player,
  required GameState state,
  required bool isCurrentTurn,
}) {
  switch (phase) {
    case GamePhase.voidCheck:
      final isReady = state.voidCheckPassed.contains(player.id);
      return isReady ? _PlayerStatus.ready : _PlayerStatus.waiting;

    case GamePhase.dashCall:
      if (player.isDashCall) return _PlayerStatus.declared;
      if (state.currentPlayerSeatIndex == player.seatIndex) {
        return _PlayerStatus.declaring;
      }
      return _PlayerStatus.waiting;

    case GamePhase.auction:
      if (player.hasPassed) return _PlayerStatus.passed;
      if (state.auctionTurnSeatIndex == player.seatIndex) {
        return _PlayerStatus.auctionTurn;
      }
      if (state.currentHighBidderPlayerId == player.id) {
        return _PlayerStatus.highBidder;
      }
      return _PlayerStatus.waiting;

    case GamePhase.declarations:
      if (player.declared != null) return _PlayerStatus.declared;
      if (state.currentPlayerSeatIndex == player.seatIndex) {
        return _PlayerStatus.declaring;
      }
      return _PlayerStatus.waiting;

    case GamePhase.trickTaking:
      if (isCurrentTurn) return _PlayerStatus.currentTurn;
      return _PlayerStatus.none;

    default:
      return _PlayerStatus.none;
  }
}

class _BadgeConfig {
  final Color color;
  final AppIconData icon;
  final String label;
  const _BadgeConfig(this.color, this.icon, this.label);
}

const _kConfigs = <_PlayerStatus, _BadgeConfig>{
  _PlayerStatus.waiting:     _BadgeConfig(AppTheme.steelBlue,      AppIcons.hourglassEmpty, 'ينتظر...'),
  _PlayerStatus.currentTurn: _BadgeConfig(AppTheme.playerGold,     AppIcons.playCircle,     'دوره'),
  _PlayerStatus.passed:      _BadgeConfig(AppTheme.playerRed,       AppIcons.block,           'باس'),
  _PlayerStatus.declaring:   _BadgeConfig(AppTheme.playerBlue,      AppIcons.touchApp,       'يصرّح'),
  _PlayerStatus.auctionTurn: _BadgeConfig(AppTheme.phaseAuction,   AppIcons.gavel,           'يزايد'),
  _PlayerStatus.highBidder:  _BadgeConfig(AppTheme.playerGold,     AppIcons.emojiEvents,    'أعلى عطاء'),
  _PlayerStatus.ready:       _BadgeConfig(AppTheme.playerGreen,    AppIcons.checkCircle,    'جاهز'),
  _PlayerStatus.declared:    _BadgeConfig(AppTheme.playerBlue,     AppIcons.assignmentTurnedIn, 'صرّح'),
  _PlayerStatus.none:        _BadgeConfig(AppTheme.steelBlue,      AppIcons.remove,          ''),
};

/// A floating colored badge that replaces plain text status hints.
///
/// Transitions between states with [AnimatedSwitcher] fade.
class StatusBadge extends StatelessWidget {
  final GamePhase phase;
  final Player player;
  final GameState state;
  final bool isCurrentTurn;
  final bool compact;

  const StatusBadge({
    super.key,
    required this.phase,
    required this.player,
    required this.state,
    this.isCurrentTurn = false,
    this.compact = false,
  });

  @override
  Widget build(BuildContext context) {
    final status = _resolveStatus(
      phase: phase,
      player: player,
      state: state,
      isCurrentTurn: isCurrentTurn,
    );

    if (status == _PlayerStatus.none) return const SizedBox.shrink();

    final cfg = _kConfigs[status]!;
    final fontSize = compact ? 8.0 : 9.5;
    final iconSize = compact ? 9.0 : 10.0;
    final hPad = compact ? 5.0 : 7.0;
    final vPad = compact ? 2.0 : 3.0;

    // Extra label for high bidder showing bid value
    String label = cfg.label;
    if (status == _PlayerStatus.highBidder && state.currentHighBid != null) {
      label = '🔥 ${state.currentHighBid!.arabicLabel}';
    }
    if (status == _PlayerStatus.declared && player.declared != null) {
      label = 'صرّح ${player.declared}';
    }

    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 300),
      transitionBuilder: (child, anim) => FadeTransition(
        opacity: anim,
        child: ScaleTransition(scale: anim, child: child),
      ),
      child: Container(
        key: ValueKey(status),
        padding: EdgeInsets.symmetric(horizontal: hPad, vertical: vPad),
        decoration: BoxDecoration(
          color: cfg.color.withValues(alpha: 0.14),
          borderRadius: BorderRadius.circular(999),
          border: Border.all(color: cfg.color.withValues(alpha: 0.40), width: 0.9),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            AppIcon(cfg.icon, color: cfg.color, size: iconSize),
            if (label.isNotEmpty) ...[
              const SizedBox(width: 3),
              Text(
                label,
                style: AppFonts.cooper(
                  color: cfg.color,
                  fontSize: fontSize,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
