// lib/screens/match_end_screen.dart
//
// Final match results screen.

import 'package:flutter/material.dart';
import '../core/models/game_state.dart';
import '../providers/game_provider.dart';
import '../theme/app_theme.dart';
import '../services/history_service.dart';

class MatchEndScreen extends StatefulWidget {
  final GameState state;
  final GameProvider provider;

  const MatchEndScreen({
    super.key,
    required this.state,
    required this.provider,
  });

  @override
  State<MatchEndScreen> createState() => _MatchEndScreenState();
}

class _MatchEndScreenState extends State<MatchEndScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<double> _scale;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 600));
    _scale = CurvedAnimation(parent: _ctrl, curve: Curves.elasticOut);
    _ctrl.forward();
    
    if (widget.provider.isHost) {
      HistoryService.saveMatch(widget.state);
    }
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final winner = widget.state.matchWinner;
    final sortedPlayers = [...widget.state.players]
      ..sort((a, b) => b.totalScore.compareTo(a.totalScore));

    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: RadialGradient(
            colors: [Color(0xFF2E4730), AppTheme.feltGreenDark],
            radius: 1.5,
          ),
        ),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
            child: SingleChildScrollView(
              child: Column(
                children: [
                  const SizedBox(height: 12),
                  // Trophy animation
                  ScaleTransition(
                    scale: _scale,
                    child: const Text('🏆', style: TextStyle(fontSize: 70)),
                  ),
                  const SizedBox(height: 12),
                  if (winner != null) ...[
                    ShaderMask(
                      shaderCallback: (bounds) => const LinearGradient(
                        colors: [AppTheme.gold, Color(0xFFFFF9C4)],
                      ).createShader(bounds),
                      child: Text(
                        'الفائز: ${winner.name}!',
                        style: const TextStyle(
                          fontSize: 28,
                          fontWeight: FontWeight.w900,
                          color: Colors.white,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      '${winner.totalScore} نقطة',
                      style: const TextStyle(
                          color: AppTheme.gold,
                          fontSize: 18,
                          fontWeight: FontWeight.bold),
                    ),
                  ],
                  const SizedBox(height: 24),
                  // Final standings
                  Text('الترتيب النهائي',
                      style: Theme.of(context).textTheme.headlineMedium),
                  const SizedBox(height: 12),
                  ...sortedPlayers.asMap().entries.map((e) {
                    final rank = e.key + 1;
                    final player = e.value;
                    final ranks = ['كينج 👑', 'صب كينج 🥈', 'صب كوز 🥉', 'كوز 🤡'];
                    final rankName = ranks[e.key];
                    return Container(
                      margin: const EdgeInsets.only(bottom: 8),
                      padding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 12),
                      decoration: BoxDecoration(
                        color: rank == 1
                            ? AppTheme.gold.withValues(alpha: 0.15)
                            : AppTheme.surfaceCard,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: rank == 1
                              ? AppTheme.gold.withValues(alpha: 0.5)
                              : Colors.white10,
                        ),
                        boxShadow: rank == 1 ? AppTheme.neumorphicTurnGlow(AppTheme.gold) : [],
                      ),
                      child: Row(
                        children: [
                          SizedBox(
                            width: 85,
                            child: Text(rankName,
                                style: TextStyle(
                                  fontSize: 15,
                                  fontWeight: FontWeight.bold,
                                  color: rank == 1 ? AppTheme.gold : AppTheme.textPrimary,
                                )),
                          ),
                          Expanded(
                            child: Text(
                              player.name,
                              style: TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.bold,
                                color: rank == 1
                                    ? AppTheme.gold
                                    : AppTheme.textPrimary,
                              ),
                            ),
                          ),
                          Text(
                            '${player.totalScore} نقطة',
                            style: TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.bold,
                              color: rank == 1
                                  ? AppTheme.gold
                                  : AppTheme.textSecondary,
                            ),
                          ),
                        ],
                      ),
                    );
                  }),
                  const SizedBox(height: 24),
                  // Back to home
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: () {
                        widget.provider.reset();
                        Navigator.pushNamedAndRemoveUntil(
                            context, '/', (r) => false);
                      },
                      child: const Text('العودة للقائمة الرئيسية'),
                    ),
                  ),
                  const SizedBox(height: 12),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

