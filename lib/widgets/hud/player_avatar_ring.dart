// lib/widgets/hud/player_avatar_ring.dart
//
// Premium circular avatar with an animated colored ring and turn countdown visual.
// Ring color is driven by the player's trick-taking state.

import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../../theme/app_theme.dart';
import '../../core/widgets/player_avatar.dart';

/// Wraps [PlayerAvatar] (or an initials fallback) in an animated
/// colored ring that communicates player state and active turn timer at a glance:
///
/// - 🟡 Gold pulsing arc & countdown sweep → current turn
/// - 🟢 Green solid ring                  → exactly reached declaration
/// - 🔴 Red ring                          → exceeded declaration
/// - 🟠 Orange ring                       → under target, near round-end
/// - 🔵 Blue ring                         → default / before declaration
class PlayerAvatarRing extends StatefulWidget {
  final String? photoData;
  final String playerName;
  final double size;
  final Color ringColor;
  final bool isCurrentTurn;
  final bool compact;

  const PlayerAvatarRing({
    super.key,
    this.photoData,
    required this.playerName,
    this.size = 44,
    this.ringColor = AppTheme.playerBlue,
    this.isCurrentTurn = false,
    this.compact = false,
  });

  @override
  State<PlayerAvatarRing> createState() => _PlayerAvatarRingState();
}

class _PlayerAvatarRingState extends State<PlayerAvatarRing>
    with TickerProviderStateMixin {
  late final AnimationController _pulseCtrl;
  late final Animation<double> _pulseAnim;

  late final AnimationController _turnTimerCtrl;

  @override
  void initState() {
    super.initState();
    _pulseCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1800),
    )..repeat(reverse: true);

    _pulseAnim = CurvedAnimation(parent: _pulseCtrl, curve: Curves.easeInOut);

    // 45s turn timeout visual timer
    _turnTimerCtrl = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 45),
    );

    if (widget.isCurrentTurn) {
      _turnTimerCtrl.forward(from: 0.0);
    }
  }

  @override
  void didUpdateWidget(covariant PlayerAvatarRing oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isCurrentTurn && !oldWidget.isCurrentTurn) {
      _turnTimerCtrl.forward(from: 0.0);
    } else if (!widget.isCurrentTurn && oldWidget.isCurrentTurn) {
      _turnTimerCtrl.stop();
      _turnTimerCtrl.reset();
    }
  }

  @override
  void dispose() {
    _pulseCtrl.dispose();
    _turnTimerCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final avatarSize = widget.size;
    final ringThickness = widget.compact ? 2.5 : 3.0;
    final ringPadding = widget.compact ? 2.5 : 3.5;
    final totalSize = avatarSize + (ringThickness + ringPadding) * 2;

    return AnimatedBuilder(
      animation: Listenable.merge([_pulseAnim, _turnTimerCtrl]),
      builder: (context, child) {
        final glowAlpha = widget.isCurrentTurn
            ? 0.4 + 0.35 * _pulseAnim.value
            : 0.2;

        Color activeColor = widget.ringColor;
        if (widget.isCurrentTurn) {
          // Progressively shift from gold -> orange -> red when turn time is running low (< 10s remaining)
          final progress = _turnTimerCtrl.value;
          if (progress > 0.77) {
            activeColor = AppTheme.errorRed;
          } else if (progress > 0.55) {
            activeColor = AppTheme.playerOrange;
          } else {
            activeColor = AppTheme.gold;
          }
        }

        return SizedBox(
          width: totalSize,
          height: totalSize,
          child: Stack(
            alignment: Alignment.center,
            children: [
              // ── Animated glow behind the ring ─────────────────────
              Container(
                width: totalSize,
                height: totalSize,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: activeColor.withValues(alpha: glowAlpha),
                      blurRadius: widget.isCurrentTurn
                          ? 12 + 8 * _pulseAnim.value
                          : 8,
                      spreadRadius: widget.isCurrentTurn
                          ? 1.5 + 2 * _pulseAnim.value
                          : 1,
                    ),
                  ],
                ),
              ),

              // ── Turn Countdown Sweep / Base Ring ──────────────────
              if (widget.isCurrentTurn)
                CustomPaint(
                  size: Size(totalSize, totalSize),
                  painter: _TurnProgressPainter(
                    progress: (1.0 - _turnTimerCtrl.value).clamp(0.0, 1.0),
                    color: activeColor,
                    strokeWidth: ringThickness,
                  ),
                )
              else
                AnimatedContainer(
                  duration: const Duration(milliseconds: 400),
                  width: totalSize,
                  height: totalSize,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: widget.ringColor,
                      width: ringThickness,
                    ),
                  ),
                ),

              // ── Avatar ─────────────────────────────────────────────
              child!,
            ],
          ),
        );
      },
      child: _buildAvatar(avatarSize),
    );
  }

  Widget _buildAvatar(double size) {
    final photo = widget.photoData;
    if (photo != null && photo.isNotEmpty) {
      return PlayerAvatar(
        photoData: photo,
        size: size,
        hasBorder: false,
        boxShadow: const [],
      );
    }

    // Initials fallback
    final initial = widget.playerName.isNotEmpty
        ? widget.playerName[0].toUpperCase()
        : '?';

    return Container(
      width: size,
      height: size,
      decoration: const BoxDecoration(
        shape: BoxShape.circle,
        gradient: LinearGradient(
          colors: [AppTheme.midBlue, AppTheme.deepNavy],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      alignment: Alignment.center,
      child: Text(
        initial,
        style: TextStyle(
          fontSize: size * 0.4,
          fontWeight: FontWeight.bold,
          color: AppTheme.cream,
        ),
      ),
    );
  }
}

class _TurnProgressPainter extends CustomPainter {
  final double progress;
  final Color color;
  final double strokeWidth;

  const _TurnProgressPainter({
    required this.progress,
    required this.color,
    required this.strokeWidth,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = (size.width - strokeWidth) / 2;

    // Dim background circle
    final basePaint = Paint()
      ..color = color.withValues(alpha: 0.18)
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth;

    canvas.drawCircle(center, radius, basePaint);

    // Active sweep arc
    final sweepPaint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeWidth = strokeWidth + 0.5;

    const startAngle = -math.pi / 2;
    final sweepAngle = 2 * math.pi * progress;

    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      startAngle,
      sweepAngle,
      false,
      sweepPaint,
    );
  }

  @override
  bool shouldRepaint(covariant _TurnProgressPainter oldDelegate) =>
      oldDelegate.progress != progress || oldDelegate.color != color;
}
