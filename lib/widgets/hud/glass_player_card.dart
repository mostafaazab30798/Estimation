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

        return AnimatedContainer(
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [Color(0xFF2A4560), Color(0xFF1D3348)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(widget.compact ? 16 : 22),
            border: Border.all(
              color: widget.isCurrentTurn
                  ? widget.accentColor.withValues(alpha: 0.55)
                  : AppTheme.steelBlue.withValues(alpha: 0.14),
              width: widget.isCurrentTurn ? 1.4 : 1.0,
            ),
            boxShadow: shadows,
          ),
          child: child,
        );
      },
      child: ClipRRect(
        borderRadius: BorderRadius.circular(widget.compact ? 16 : 22),
        child: Stack(
          children: [
            // ── Subtle inner highlight line at top ─────────────────
            Positioned(
              top: 0,
              left: 0,
              right: 0,
              height: 1,
              child: Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      Colors.transparent,
                      AppTheme.steelBlue.withValues(alpha: 0.25),
                      Colors.transparent,
                    ],
                  ),
                ),
              ),
            ),

            // ── Left accent strip ──────────────────────────────────
            Positioned(
              left: 0,
              top: 0,
              bottom: 0,
              width: 3,
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 400),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      widget.accentColor.withValues(alpha: 0.0),
                      widget.accentColor.withValues(alpha: 0.8),
                      widget.accentColor.withValues(alpha: 0.0),
                    ],
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                  ),
                ),
              ),
            ),

            // ── Content ────────────────────────────────────────────
            Padding(
              padding: EdgeInsets.only(
                left: widget.compact ? 10 : 14,
                right: widget.compact ? 8 : 12,
                top: widget.compact ? 6 : 10,
                bottom: widget.compact ? 6 : 10,
              ),
              child: widget.child,
            ),
          ],
        ),
      ),
    );
  }
}
