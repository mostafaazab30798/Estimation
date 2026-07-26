// lib/widgets/hud/player_avatar_ring.dart
//
// Premium circular avatar with an animated colored ring.
// Ring color is driven by the player's trick-taking state.

import 'package:flutter/material.dart';
import '../../theme/app_theme.dart';
import '../../core/widgets/player_avatar.dart';

/// Wraps [PlayerAvatar] (or an initials fallback) in an animated
/// colored ring that communicates player state at a glance:
///
/// - 🟡 Gold pulsing arc   → current turn
/// - 🟢 Green solid ring   → exactly reached declaration
/// - 🔴 Red ring           → exceeded declaration
/// - 🟠 Orange ring        → under target, near round-end
/// - 🔵 Blue ring          → default / before declaration
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
    with SingleTickerProviderStateMixin {
  late final AnimationController _ringCtrl;
  late final Animation<double> _ringAnim;

  @override
  void initState() {
    super.initState();
    _ringCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1800),
    )..repeat(reverse: true);

    _ringAnim = CurvedAnimation(parent: _ringCtrl, curve: Curves.easeInOut);
  }

  @override
  void dispose() {
    _ringCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final avatarSize = widget.size;
    final ringThickness = widget.compact ? 2.0 : 2.5;
    final ringPadding = widget.compact ? 2.0 : 3.0;
    final totalSize = avatarSize + (ringThickness + ringPadding) * 2;

    return AnimatedBuilder(
      animation: _ringAnim,
      builder: (context, child) {
        // Only animate the shadow when it is the current player's turn.
        final glowAlpha = widget.isCurrentTurn
            ? 0.35 + 0.35 * _ringAnim.value
            : 0.2;

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
                      color: widget.ringColor.withValues(alpha: glowAlpha),
                      blurRadius: widget.isCurrentTurn
                          ? 12 + 8 * _ringAnim.value
                          : 8,
                      spreadRadius: widget.isCurrentTurn
                          ? 1 + 2 * _ringAnim.value
                          : 1,
                    ),
                  ],
                ),
              ),

              // ── Ring border ────────────────────────────────────────
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
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: const LinearGradient(
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
