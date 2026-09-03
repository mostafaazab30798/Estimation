// lib/widgets/hud/turn_timer_badge.dart
//
// Authoritative Turn Timer Badge displaying active phase ('AUCTION', 'DECLARATION', 'YOUR TURN')
// and synchronized countdown ('15s', '10s' -> '⚠️ 5' alert state).

import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../core/models/game_state.dart';
import '../../theme/app_theme.dart';
import '../../services/settings_service.dart';
import 'package:estimation/core/icons/app_icons.dart';

class TurnTimerBadge extends StatefulWidget {
  final GameState? state;
  final bool isMyTurn;
  final String? activePlayerName;
  final int? explicitDeadlineEpochMs;
  final int? explicitDurationSeconds;
  final String? customPhaseLabel;
  final bool compact;

  const TurnTimerBadge({
    super.key,
    this.state,
    this.isMyTurn = false,
    this.activePlayerName,
    this.explicitDeadlineEpochMs,
    this.explicitDurationSeconds,
    this.customPhaseLabel,
    this.compact = false,
  });

  @override
  State<TurnTimerBadge> createState() => _TurnTimerBadgeState();
}

class _TurnTimerBadgeState extends State<TurnTimerBadge>
    with SingleTickerProviderStateMixin {
  Timer? _ticker;
  late AnimationController _pulseCtrl;
  late Animation<double> _pulseAnim;
  int _remainingSeconds = 60;
  int _totalDurationSeconds = 60;
  int? _lastWarnedSecond;

  @override
  void initState() {
    super.initState();
    _pulseCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    )..repeat(reverse: true);

    _pulseAnim = CurvedAnimation(parent: _pulseCtrl, curve: Curves.easeInOut);

    _calculateRemainingTime();
    _ticker = Timer.periodic(const Duration(milliseconds: 100), (_) {
      _calculateRemainingTime();
    });
  }

  @override
  void didUpdateWidget(covariant TurnTimerBadge oldWidget) {
    super.didUpdateWidget(oldWidget);
    _calculateRemainingTime();
  }

  @override
  void dispose() {
    _ticker?.cancel();
    _pulseCtrl.dispose();
    super.dispose();
  }

  void _calculateRemainingTime() {
    final deadline = widget.explicitDeadlineEpochMs ?? widget.state?.turnDeadlineEpochMs;
    final totalDuration = widget.explicitDurationSeconds ??
        widget.state?.turnDurationSeconds ??
        _defaultDurationForPhase(widget.state?.phase);

    _totalDurationSeconds = math.max(1, totalDuration);

    if (deadline != null) {
      final now = DateTime.now().millisecondsSinceEpoch;
      final diffMs = deadline - now;
      final remaining = (diffMs / 1000).ceil().clamp(0, _totalDurationSeconds);
      if (remaining != _remainingSeconds) {
        setState(() {
          _remainingSeconds = remaining;
        });
        _handleWarningHaptics(remaining);
      }
    } else {
      // Fallback if no server timestamp yet
      final fallback = _defaultDurationForPhase(widget.state?.phase);
      if (_remainingSeconds != fallback) {
        setState(() {
          _remainingSeconds = fallback;
        });
      }
    }
  }

  void _handleWarningHaptics(int remaining) {
    if (widget.isMyTurn && remaining > 0 && remaining <= 5 && _lastWarnedSecond != remaining) {
      _lastWarnedSecond = remaining;
      if (SettingsService.instance.hapticsEnabled) {
        try {
          HapticFeedback.selectionClick();
        } catch (_) {}
      }
    }
  }

  int _defaultDurationForPhase(GamePhase? phase) {
    return 60;
  }

  String _resolvePhaseLabel() {
    if (widget.customPhaseLabel != null) {
      final label = widget.customPhaseLabel!;
      if (label == 'AUCTION') return 'المزاد';
      if (label == 'DECLARATION') return 'التصريح';
      if (label == 'YOUR TURN') return 'دورك';
      return label;
    }
    final phase = widget.state?.phase;
    if (phase == GamePhase.auction) {
      return 'المزاد';
    } else if (phase == GamePhase.declarations) {
      return 'التصريح';
    } else if (phase == GamePhase.trickTaking || phase == GamePhase.dashCall) {
      if (widget.isMyTurn) {
        return 'دورك';
      } else if (widget.activePlayerName != null && widget.activePlayerName!.isNotEmpty) {
        return 'دور ${widget.activePlayerName!}';
      }
      return 'الدور';
    }
    return 'الدور';
  }

  @override
  Widget build(BuildContext context) {
    final phaseLabel = _resolvePhaseLabel();
    final isWarning = _remainingSeconds <= 5 && _remainingSeconds > 0;
    final isExpired = _remainingSeconds == 0;

    final progress = (_remainingSeconds / _totalDurationSeconds).clamp(0.0, 1.0);

    // Color styling
    Color primaryColor;
    Color glowColor;

    if (isExpired) {
      primaryColor = AppTheme.errorRed;
      glowColor = AppTheme.errorRed.withValues(alpha: 0.35);
    } else if (isWarning) {
      primaryColor = const Color(0xFFFF4848); // Warning Red / Crimson
      glowColor = const Color(0xFFFF5252).withValues(alpha: 0.65);
    } else if (widget.state?.phase == GamePhase.auction) {
      primaryColor = AppTheme.gold;
      glowColor = AppTheme.gold.withValues(alpha: 0.35);
    } else if (widget.state?.phase == GamePhase.declarations) {
      primaryColor = const Color(0xFF64B5F6); // Soft Cyan/Blue
      glowColor = const Color(0xFF42A5F5).withValues(alpha: 0.35);
    } else {
      primaryColor = widget.isMyTurn ? AppTheme.gold : const Color(0xFF81D4FA);
      glowColor = widget.isMyTurn
          ? AppTheme.gold.withValues(alpha: 0.4)
          : const Color(0xFF0288D1).withValues(alpha: 0.25);
    }

    final double badgeHeight = widget.compact ? 36.0 : 44.0;
    final double fontSize = widget.compact ? 12.5 : 14.5;
    final double timerFontSize = widget.compact ? 13.0 : 15.0;

    return AnimatedBuilder(
      animation: _pulseAnim,
      builder: (context, _) {
        final scale = isWarning ? 1.0 + (0.04 * _pulseAnim.value) : 1.0;
        final glowAlpha = isWarning ? (0.4 + 0.35 * _pulseAnim.value) : 0.25;

        return Transform.scale(
          scale: scale,
          child: Container(
            height: badgeHeight,
            padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 4),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  (isWarning ? const Color(0xFF3F1015) : const Color(0xFF1E3348))
                      .withValues(alpha: 0.94),
                  (isWarning ? const Color(0xFF280B0F) : AppTheme.deepNavy)
                      .withValues(alpha: 0.97),
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(badgeHeight / 2),
              border: Border.all(
                color: isWarning
                    ? primaryColor.withValues(alpha: 0.75 + 0.25 * _pulseAnim.value)
                    : primaryColor.withValues(alpha: 0.40),
                width: isWarning ? 1.5 : 1.1,
              ),
              boxShadow: [
                BoxShadow(
                  color: glowColor.withValues(alpha: glowAlpha),
                  blurRadius: isWarning ? 16 + 8 * _pulseAnim.value : 12,
                  spreadRadius: isWarning ? 1.5 : 0,
                ),
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.38),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                // ── Animated Mini Progress Ring ──────────────────────
                SizedBox(
                  width: widget.compact ? 16 : 20,
                  height: widget.compact ? 16 : 20,
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      CircularProgressIndicator(
                        value: progress,
                        strokeWidth: widget.compact ? 2.2 : 2.8,
                        backgroundColor: primaryColor.withValues(alpha: 0.2),
                        valueColor: AlwaysStoppedAnimation<Color>(primaryColor),
                      ),
                      if (isWarning)
                        const AppIcon(
                          AppIcons.priorityHigh,
                          size: 11,
                          color: Color(0xFFFFD700),
                        ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),

                // ── Phase Label Header (Arabic) ────────────────────────
                Text(
                  phaseLabel,
                  style: AppFonts.cooper(
                    color: isWarning ? Colors.white : AppTheme.cream,
                    fontSize: fontSize,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(width: 10),

                // ── Separator Dot ─────────────────────────────────────
                Container(
                  width: 3.5,
                  height: 3.5,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: primaryColor.withValues(alpha: 0.6),
                  ),
                ),
                const SizedBox(width: 10),

                // ── Countdown Timer Display ───────────────────────────
                _buildCountdownText(isWarning, timerFontSize, primaryColor),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildCountdownText(bool isWarning, double fontSize, Color primaryColor) {
    if (isWarning) {
      return Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text(
            '⚠️ ',
            style: TextStyle(fontSize: 13),
          ),
          Text(
            '$_remainingSeconds',
            style: AppFonts.cooper(
              color: const Color(0xFFFFE082), // Amber Warning text
              fontSize: fontSize + 1.0,
              fontWeight: FontWeight.w900,
            ),
          ),
        ],
      );
    }

    return Text(
      '$_remainingSeconds ث',
      style: AppFonts.cooper(
        color: primaryColor,
        fontSize: fontSize,
        fontWeight: FontWeight.w800,
      ),
    );
  }
}
