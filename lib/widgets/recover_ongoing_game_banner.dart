import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';

import '../providers/game_provider.dart';
import '../services/online_play_gate.dart';
import '../services/reconnection_manager.dart';
import '../theme/app_theme.dart';

/// Prominent card to return to a live online match from the home screen.
class RecoverOngoingGameBanner extends StatelessWidget {
  const RecoverOngoingGameBanner({super.key});

  Future<void> _returnToMatch(BuildContext context) async {
    final reconnect = context.read<ReconnectionManager>();
    final result = await reconnect.recoverPendingSession();
    if (!context.mounted) return;
    if (result != ReconnectionState.reconnected) {
      await context.read<OnlinePlayGate>().refresh();
      return;
    }
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
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<OnlinePlayGate>(
      builder: (context, gate, _) {
        if (!gate.canReturnToOngoingGame) return const SizedBox.shrink();

        return Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: Material(
            color: AppTheme.navyDark.withValues(alpha: 0.92),
            borderRadius: BorderRadius.circular(18),
            child: InkWell(
              onTap: () => _returnToMatch(context),
              borderRadius: BorderRadius.circular(18),
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(
                    color: AppTheme.gold.withValues(alpha: 0.45),
                  ),
                ),
                child: Row(
                  children: [
                    Icon(Icons.replay_circle_filled_rounded,
                        color: AppTheme.gold, size: 32),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'مباراة جارية',
                            style: GoogleFonts.cairo(
                              color: AppTheme.gold,
                              fontWeight: FontWeight.w800,
                              fontSize: 15,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            'اضغط للعودة واستعادة مقعدك (${gate.remainingLabel})',
                            style: GoogleFonts.cairo(
                              color: AppTheme.cream.withValues(alpha: 0.85),
                              fontSize: 12,
                              height: 1.3,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Icon(Icons.arrow_back_ios_new_rounded,
                        color: AppTheme.gold.withValues(alpha: 0.8), size: 16),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

/// Shown when the user is blocked only by a post-abandon ban (no live game).
class OnlineBanNotice extends StatelessWidget {
  const OnlineBanNotice({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<OnlinePlayGate>(
      builder: (context, gate, _) {
        if (!gate.isBanOnlyBlock) return const SizedBox.shrink();

        return Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: AppTheme.navyDark.withValues(alpha: 0.85),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: AppTheme.steelBlue.withValues(alpha: 0.35),
              ),
            ),
            child: Text(
              'المباراة السابقة انتهت. انتظر ${gate.remainingLabel} قبل دخول طابور أونلاين جديد.',
              style: GoogleFonts.cairo(
                color: AppTheme.cream.withValues(alpha: 0.9),
                fontSize: 13,
                height: 1.4,
              ),
              textAlign: TextAlign.center,
            ),
          ),
        );
      },
    );
  }
}
