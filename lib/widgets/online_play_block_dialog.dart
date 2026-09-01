import 'dart:async';

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';

import '../features/lobby/domain/models/online_play_status.dart';
import '../core/widgets/app_dialog.dart';
import '../providers/game_provider.dart';
import '../services/online_play_gate.dart';
import '../services/reconnection_manager.dart';
import '../theme/app_theme.dart';

/// Shows a blocking dialog when online play is gated by grace or ban.
///
/// Returns `true` when the requested new-online action must be cancelled.
Future<bool> showOnlinePlayBlockDialog(
  BuildContext context, {
  required OnlinePlayStatus status,
}) async {
  final canReturn = status.canReturnToOngoingGame;
  final reconnect = context.read<ReconnectionManager>();

  final result = await showDialog<_OnlinePlayBlockChoice>(
        context: context,
        barrierDismissible: false,
        builder: (dialogContext) {
          return _OnlinePlayBlockDialog(
            status: status,
            canReturnToGame: canReturn,
          );
        },
      ) ??
      _OnlinePlayBlockChoice.wait;

  if (!context.mounted) return true;

  if (result == _OnlinePlayBlockChoice.returnToGame && canReturn) {
    final recovery = await reconnect.recoverPendingSession();
    if (!context.mounted) return true;
    if (recovery == ReconnectionState.reconnected) {
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
    } else {
      await context.read<OnlinePlayGate>().refresh();
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'تعذر العودة — المباراة لم تعد متاحة.',
              style: GoogleFonts.cairo(),
            ),
          ),
        );
      }
    }
    return true;
  }

  return true;
}

enum _OnlinePlayBlockChoice { wait, returnToGame }

class _OnlinePlayBlockDialog extends StatefulWidget {
  final OnlinePlayStatus status;
  final bool canReturnToGame;

  const _OnlinePlayBlockDialog({
    required this.status,
    required this.canReturnToGame,
  });

  @override
  State<_OnlinePlayBlockDialog> createState() => _OnlinePlayBlockDialogState();
}

class _OnlinePlayBlockDialogState extends State<_OnlinePlayBlockDialog> {
  late Duration _remaining;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _remaining = widget.status.remainingBlock(DateTime.now().toUtc());
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted) return;
      setState(() {
        _remaining = widget.status.remainingBlock(DateTime.now().toUtc());
      });
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  String get _countdownLabel {
    final total = _remaining.inSeconds.clamp(0, 9999);
    final minutes = total ~/ 60;
    final seconds = total % 60;
    return '${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    return AppAlertDialog(
      title: Text(
        'لا يمكن بدء مباراة جديدة الآن',
        style: GoogleFonts.cairo(
          color: AppTheme.gold,
          fontWeight: FontWeight.w800,
        ),
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            widget.canReturnToGame
                ? 'لديك مباراة ما زالت جارية. بعد 30 ثانية يلعب البوت مكانك. لديك حتى 5 دقائق للعودة واستعادة مقعدك قبل أن تُفصل تلقائياً.'
                : 'تم فصلك من مباراة سابقة. انتظر حتى ينتهي الحظر قبل دخول طابور أونلاين جديد.',
            style: GoogleFonts.cairo(color: AppTheme.cream, height: 1.5),
          ),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
            decoration: BoxDecoration(
              color: AppTheme.navyDark.withValues(alpha: 0.55),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppTheme.gold.withValues(alpha: 0.35)),
            ),
            child: Column(
              children: [
                Text(
                  'الوقت المتبقي',
                  style: GoogleFonts.cairo(
                    color: AppTheme.steelBlue,
                    fontSize: 13,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  _countdownLabel,
                  style: GoogleFonts.cairo(
                    color: AppTheme.gold,
                    fontSize: 28,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 2,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () =>
              Navigator.pop(context, _OnlinePlayBlockChoice.wait),
          child: Text('انتظر', style: GoogleFonts.cairo()),
        ),
        if (widget.canReturnToGame)
          FilledButton(
            onPressed: () =>
                Navigator.pop(context, _OnlinePlayBlockChoice.returnToGame),
            child: Text('العودة إلى المباراة', style: GoogleFonts.cairo()),
          ),
      ],
    );
  }
}

/// Returns true when online matchmaking must be blocked.
Future<bool> guardOnlineMatchmaking(BuildContext context) async {
  final gate = context.read<OnlinePlayGate>();
  final status = await gate.refresh();
  if (!context.mounted) return true;
  if (status.canJoinNewOnline) return false;

  gate.startPolling();
  await showOnlinePlayBlockDialog(context, status: status);
  return true;
}
