import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../../theme/app_theme.dart';

class MatchmakingPlayerSlot extends StatelessWidget {
  final String? playerName;
  final bool isBot;

  const MatchmakingPlayerSlot({super.key, this.playerName, this.isBot = false});

  @override
  Widget build(BuildContext context) {
    final occupied = playerName != null || isBot;
    return AnimatedContainer(
      duration: const Duration(milliseconds: 250),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppTheme.navyDark.withValues(alpha: 0.75),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: occupied
              ? AppTheme.gold
              : AppTheme.steelBlue.withValues(alpha: .35),
        ),
      ),
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        CircleAvatar(
          radius: 27,
          backgroundColor:
              occupied ? AppTheme.gold.withValues(alpha: .18) : Colors.white10,
          child: Text(
            isBot ? '🤖' : (playerName?.trim().characters.firstOrNull ?? '…'),
            style: const TextStyle(fontSize: 22, color: AppTheme.cream),
          ),
        ),
        const SizedBox(height: 8),
        Text(
          isBot ? 'لاعب بوت' : (playerName ?? 'جاري البحث'),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: GoogleFonts.cairo(
              color: occupied ? AppTheme.cream : AppTheme.steelBlue,
              fontSize: 12),
        ),
      ]),
    );
  }
}
