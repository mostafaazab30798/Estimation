// lib/screens/scoring_screen.dart
//
// End-of-round score display.

import 'package:flutter/material.dart';
import '../core/models/game_state.dart';
import '../providers/game_provider.dart';
import '../theme/app_theme.dart';
import '../widgets/score_table.dart';

class ScoringScreen extends StatelessWidget {
  final GameState state;
  final GameProvider provider;

  const ScoringScreen({
    super.key,
    required this.state,
    required this.provider,
  });

  @override
  Widget build(BuildContext context) {
    final isPortrait = MediaQuery.of(context).orientation == Orientation.portrait;

    final headerSection = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        ShaderMask(
          shaderCallback: (bounds) => const LinearGradient(
            colors: [AppTheme.gold, AppTheme.cardWhite],
          ).createShader(bounds),
          child: Text(
            'نهاية الجولة ${state.roundNumber}',
            style: const TextStyle(
              fontSize: 32,
              fontWeight: FontWeight.w900,
              color: Colors.white,
            ),
          ),
        ),
        const SizedBox(height: 12),
        if (state.bidder != null)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            decoration: BoxDecoration(
              color: AppTheme.gold.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: AppTheme.gold.withValues(alpha: 0.3)),
            ),
            child: Text(
              '👑 صاحب المزاد: ${state.bidder!.name}\n${state.currentHighBid?.arabicLabel ?? ""}',
              style: const TextStyle(
                  color: AppTheme.gold, fontSize: 15, height: 1.4),
              textAlign: TextAlign.start,
            ),
          ),
      ],
    );

    final actionSection = provider.isHost
        ? SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 16),
                backgroundColor: AppTheme.gold,
                foregroundColor: AppTheme.navyDark,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                elevation: 4,
              ),
              onPressed: () => provider.nextRound(),
              child: Text(
                state.isMatchOver ? 'إنهاء اللعبة' : 'الجولة التالية →',
                style: const TextStyle(fontSize: 17, fontWeight: FontWeight.bold),
              ),
            ),
          )
        : Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: AppTheme.navyDeep.withValues(alpha: 0.5),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.white24),
            ),
            child: Row(
              children: [
                const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: AppTheme.gold)),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'في انتظار المضيف للانتقال للجولة التالية...',
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: AppTheme.textSecondary),
                  ),
                ),
              ],
            ),
          );

    final scoreTableWidget = ScoreTable(
      players: [...state.players]..sort((a, b) => b.totalScore.compareTo(a.totalScore)),
      lastRoundDeltas: state.lastRoundScoreDeltas,
      bidderPlayerId: state.bidderPlayerId,
    );

    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [AppTheme.feltGreenDark, AppTheme.feltGreen],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
        ),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: isPortrait
                ? Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Expanded(
                        child: SingleChildScrollView(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              headerSection,
                              const SizedBox(height: 16),
                              scoreTableWidget,
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),
                      actionSection,
                    ],
                  )
                : Row(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Expanded(
                        flex: 4,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            headerSection,
                            const Spacer(),
                            actionSection,
                          ],
                        ),
                      ),
                      const SizedBox(width: 24),
                      Expanded(
                        flex: 6,
                        child: Center(
                          child: SingleChildScrollView(
                            child: scoreTableWidget,
                          ),
                        ),
                      ),
                    ],
                  ),
          ),
        ),
      ),
    );
  }
}

