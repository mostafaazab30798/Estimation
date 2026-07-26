// lib/widgets/hud/local_player_ready_button.dart
//
// Premium animated ready button for the local player during voidCheck phase.

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../theme/app_theme.dart';

/// Toggle-ready button for the local player.
/// [isReady] controls whether the button shows "جاهز للعب" or "أنا جاهز ✓".
class LocalPlayerReadyButton extends StatelessWidget {
  final bool isReady;
  final VoidCallback onTap;

  const LocalPlayerReadyButton({
    super.key,
    required this.isReady,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final color = isReady ? AppTheme.playerGreen : AppTheme.gold;
    final icon = isReady ? Icons.check_circle_rounded : Icons.play_arrow_rounded;
    final label = isReady ? 'أنا جاهز ✓' : 'جاهز للعب';

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 280),
        curve: Curves.easeOut,
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [
              color,
              Color.lerp(color, AppTheme.deepNavy, 0.3)!,
            ],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: color.withValues(alpha: 0.45),
              blurRadius: 14,
              spreadRadius: 1,
              offset: const Offset(0, 3),
            ),
            BoxShadow(
              color: color.withValues(alpha: 0.2),
              blurRadius: 28,
              spreadRadius: 3,
            ),
          ],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            AnimatedSwitcher(
              duration: const Duration(milliseconds: 250),
              child: Icon(
                icon,
                key: ValueKey(isReady),
                size: 18,
                color: isReady ? Colors.white : AppTheme.deepNavy,
              ),
            ),
            const SizedBox(width: 6),
            AnimatedSwitcher(
              duration: const Duration(milliseconds: 250),
              child: Text(
                label,
                key: ValueKey(isReady),
                style: GoogleFonts.cairo(
                  color: isReady ? Colors.white : AppTheme.deepNavy,
                  fontSize: 13,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
