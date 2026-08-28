import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';

import '../providers/game_provider.dart';
import '../services/reconnection_manager.dart';
import '../theme/app_theme.dart';

/// Returns true when a still-active game blocked the requested new-game action.
Future<bool> guardAgainstOngoingGame(BuildContext context) async {
  final reconnect = context.read<ReconnectionManager>();
  final session = await reconnect.getPendingSession();
  if (!context.mounted || session == null) return false;
  final returnNow = await showDialog<bool>(
        context: context,
        barrierDismissible: false,
        builder: (dialogContext) => AlertDialog(
          backgroundColor: AppTheme.navyDark,
          title: Text('لديك مباراة جارية',
              style: GoogleFonts.cairo(
                  color: AppTheme.gold, fontWeight: FontWeight.w800)),
          content: Text(
            'لا يمكنك إنشاء غرفة، الانضمام إلى غرفة، أو بدء طابور جديد حتى تنتهي مباراتك الحالية. عد إلى مقعدك لمتابعة اللعب؛ وإذا انتهت مهلة 60 ثانية فسيترك البوت المقعد فور عودتك.',
            style: GoogleFonts.cairo(color: AppTheme.cream, height: 1.5),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: Text('لاحقاً', style: GoogleFonts.cairo()),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(dialogContext, true),
              child: Text('العودة إلى المباراة', style: GoogleFonts.cairo()),
            ),
          ],
        ),
      ) ??
      false;
  if (!returnNow || !context.mounted) return true;
  final result = await reconnect.recoverPendingSession();
  if (!context.mounted || result != ReconnectionState.reconnected) return true;
  final provider = context.read<GameProvider>();
  final room = provider.currentRoom;
  final route = room?.status.name == 'playing'
      ? room?.gameType == 'ninety_nine'
          ? '/ninety_nine/game'
          : room?.gameType == 'basra'
              ? '/basra/game'
              : '/game'
      : '/lobby';
  Navigator.pushReplacementNamed(context, route);
  return true;
}
