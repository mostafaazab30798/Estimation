// lib/widgets/hud/glass_player_card.dart
//
// Floating glass card container for player HUD entries.
// Handles the ambient breathing glow when it is the player's turn.

import 'package:flutter/material.dart';
import '../../theme/app_theme.dart';

/// A premium floating glass panel used as the base of every PlayerInfoWidget.
///
/// When [isCurrentTurn] is true an ambient breathing glow pulses around the
/// card using a sine-wave animation — giving the impression of a "live" card
/// without being distracting.
class GlassPlayerCard extends StatefulWidget {
  final Widget child;
  final bool isCurrentTurn;
  final Color accentColor;
  final bool compact;

  const GlassPlayerCard({
    super.key,
    required this.child,
    this.isCurrentTurn = false,
    this.accentColor = AppTheme.midBlue,
    this.compact = false,
  });

  @override
  State<GlassPlayerCard> createState() => _GlassPlayerCardState();
}

class _GlassPlayerCardState extends State<GlassPlayerCard>
    with SingleTickerProviderStateMixin {
  late final AnimationController _glowCtrl;
  late final Animation<double> _glowAnim;

  @override
  void initState() {
    super.initState();
    // Slow 2-second breathe cycle for the ambient glow.
    _glowCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2000),
    )..repeat(reverse: true);

    _glowAnim = CurvedAnimation(parent: _glowCtrl, curve: Curves.easeInOut);
  }

  @override
  void dispose() {
    _glowCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _glowAnim,
      builder: (context, child) {
        // Only animate shadows when it is the current turn — avoids
        // unnecessary repaints for idle player cards.
        final glowIntensity = widget.isCurrentTurn
            ? 0.3 + 0.3 * _glowAnim.value // 0.30 → 0.60
            : 0.0;

        final shadows = widget.isCurrentTurn
            ? [
                BoxShadow(
                  color: widget.accentColor.withValues(alpha: glowIntensity),
                  blurRadius: 24 + 12 * _glowAnim.value,
                  spreadRadius: 1 + 2 * _glowAnim.value,
                ),
                BoxShadow(
                  color: widget.accentColor.withValues(alpha: glowIntensity * 0.4),
                  blurRadius: 40 + 16 * _glowAnim.value,
                  spreadRadius: 3,
                ),
                ...AppTheme.cardShadow,
              ]
            : AppTheme.cardShadow;

        final radius = widget.compact ? 18.0 : 22.0;

        return AnimatedContainer(
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                const Color(0xE82F4A64),
                const Color(0xE81A3044),
                if (widget.isCurrentTurn)
                  widget.accentColor.withValues(alpha: 0.12)
                else
                  const Color(0xE8162838),
              ],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              stops: const [0.0, 0.55, 1.0],
            ),
            borderRadius: BorderRadius.circular(radius),
            border: Border.all(
              color: widget.isCurrentTurn
                  ? widget.accentColor.withValues(alpha: 0.6)
                  : AppTheme.cream.withValues(alpha: 0.08),
              width: widget.isCurrentTurn ? 1.35 : 1.0,
            ),
            boxShadow: shadows,
          ),
          child: child,
        );
      },
      child: ClipRRect(
        borderRadius: BorderRadius.circular(widget.compact ? 18 : 22),
        child: Stack(
          children: [
            // Soft top specular highlight
            Positioned(
              top: 0,
              left: 12,
              right: 12,
              height: 1.2,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      Colors.transparent,
                      AppTheme.cream.withValues(alpha: 0.22),
                      Colors.transparent,
                    ],
                  ),
                ),
              ),
            ),

            // Left accent rail
            Positioned(
              left: 0,
              top: 8,
              bottom: 8,
              width: 2.5,
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 400),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(2),
                  gradient: LinearGradient(
                    colors: [
                      widget.accentColor.withValues(alpha: 0.0),
                      widget.accentColor.withValues(
                          alpha: widget.isCurrentTurn ? 0.95 : 0.55),
                      widget.accentColor.withValues(alpha: 0.0),
                    ],
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                  ),
                ),
              ),
            ),

            Padding(
              padding: EdgeInsets.only(
                left: widget.compact ? 8 : 14,
                right: widget.compact ? 7 : 12,
                top: widget.compact ? 5 : 10,
                bottom: widget.compact ? 5 : 10,
              ),
              child: widget.child,
            ),
          ],
        ),
      ),
    );
  }
}
