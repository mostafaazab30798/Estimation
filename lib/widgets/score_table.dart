// lib/widgets/score_table.dart
//
// Round score breakdown table.

import 'package:flutter/material.dart';
import '../core/models/player.dart';
import '../theme/app_theme.dart';

class ScoreTable extends StatelessWidget {
  final List<Player> players;
  final Map<String, int> lastRoundDeltas;
  final String? bidderPlayerId;

  const ScoreTable({
    super.key,
    required this.players,
    required this.lastRoundDeltas,
    this.bidderPlayerId,
  });

  @override
  Widget build(BuildContext context) {
    final rankTitles = ['كينج 👑', 'صب كينج 🥈', 'صب كوز 🥉', 'كوز 🤡'];

    return Container(
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppTheme.gold.withValues(alpha: 0.4), width: 1.5),
        boxShadow: AppTheme.neumorphicTurnGlow(AppTheme.navyDeep),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Header
          Container(
            padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 14),
            decoration: BoxDecoration(
              color: AppTheme.gold.withValues(alpha: 0.15),
              borderRadius:
                  const BorderRadius.vertical(top: Radius.circular(18)),
            ),
            child: Row(
              children: [
                Expanded(
                    flex: 3,
                    child: Align(
                      alignment: Alignment.centerRight,
                      child: _header('اللاعب'),
                    )),
                Expanded(child: _header('صرّح')),
                Expanded(child: _header('ربح')),
                Expanded(flex: 1, child: _header('الجولة')),
                Expanded(flex: 1, child: _header('المجموع')),
              ],
            ),
          ),
          // Rows
          ...players.asMap().entries.map((e) {
            final rankIndex = e.key;
            final p = e.value;
            final delta = lastRoundDeltas[p.id] ?? 0;
            final isBidder = p.id == bidderPlayerId;
            final positive = delta >= 0;
            final rankTitle = rankIndex >= 0 && rankIndex < 4 ? rankTitles[rankIndex] : '';

            return Container(
              padding:
                  const EdgeInsets.symmetric(vertical: 10, horizontal: 14),
              decoration: BoxDecoration(
                color: rankIndex == 0 ? AppTheme.gold.withValues(alpha: 0.05) : null,
                border: Border(
                  top: BorderSide(
                      color: Colors.white.withValues(alpha: 0.08), width: 1),
                ),
              ),
              child: Row(
                children: [
                  Expanded(
                    flex: 3,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Row(
                          children: [
                            if (isBidder)
                              const Padding(
                                padding: EdgeInsets.only(left: 4),
                                child: Text('🔥', style: TextStyle(fontSize: 12)),
                              ),
                            Flexible(
                              child: Text(
                                p.name,
                                style: TextStyle(
                                  color: rankIndex == 0 ? AppTheme.gold : AppTheme.textPrimary,
                                  fontSize: 14,
                                  fontWeight: FontWeight.bold,
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                        if (rankTitle.isNotEmpty) ...[
                          const SizedBox(height: 2),
                          Text(
                            rankTitle,
                            style: TextStyle(
                              color: rankIndex == 0
                                  ? AppTheme.gold.withValues(alpha: 0.85)
                                  : AppTheme.textSecondary,
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                  Expanded(child: _cell('${p.declared ?? '-'}')),
                  Expanded(child: _cell('${p.actual}')),
                  Expanded(
                    flex: 1,
                    child: Text(
                      positive ? '+$delta' : '$delta',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color:
                            positive ? Colors.greenAccent : AppTheme.errorRed,
                        fontWeight: FontWeight.bold,
                        fontSize: 13,
                      ),
                    ),
                  ),
                  Expanded(
                    flex: 1,
                    child: Text(
                      '${p.totalScore}',
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        color: AppTheme.gold,
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                      ),
                    ),
                  ),
                ],
              ),
            );
          }),
        ],
      ),
    );
  }

  Widget _header(String text) => Text(
        text,
        textAlign: TextAlign.center,
        style: const TextStyle(
          color: AppTheme.gold,
          fontWeight: FontWeight.bold,
          fontSize: 12,
        ),
      );

  Widget _cell(String text) => Text(
        text,
        textAlign: TextAlign.center,
        style: const TextStyle(color: AppTheme.textSecondary, fontSize: 13),
      );
}

