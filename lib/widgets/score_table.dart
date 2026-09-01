// lib/widgets/score_table.dart
//
// Modern floating rank cards score breakdown — no heavy back container box.

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../core/models/player.dart';
import '../core/widgets/player_avatar.dart';
import '../models/match_rank.dart';
import '../theme/app_theme.dart';
import 'hud/match_rank_badge.dart';

class ScoreTable extends StatelessWidget {
  final List<Player> players;
  final Map<String, int> lastRoundDeltas;
  final String? bidderPlayerId;
  final bool largeScreen;
  final bool compact;

  const ScoreTable({
    super.key,
    required this.players,
    required this.lastRoundDeltas,
    this.bidderPlayerId,
    this.largeScreen = false,
    this.compact = false,
  });

  @override
  Widget build(BuildContext context) {
    final headerSize = largeScreen ? (compact ? 13.0 : 14.5) : (compact ? 11.5 : 13.0);
    final rowPadding = largeScreen
        ? EdgeInsets.symmetric(
            horizontal: compact ? 14 : 18,
            vertical: compact ? 10 : 14,
          )
        : EdgeInsets.symmetric(
            horizontal: compact ? 10 : 14,
            vertical: compact ? 8 : 12,
          );
    final rowGap = largeScreen
        ? (compact ? 6.0 : 12.0)
        : (compact ? 5.0 : 10.0);
    final headerPadV = largeScreen ? (compact ? 6.0 : 10.0) : (compact ? 4.0 : 8.0);

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Column Headers (floating directly above cards, no container box)
        Padding(
          padding: EdgeInsets.symmetric(
            horizontal: largeScreen ? (compact ? 14 : 18) : (compact ? 10 : 14),
            vertical: headerPadV,
          ),
          child: Row(
            children: [
              Expanded(
                flex: 5,
                child: Text(
                  'اللاعب',
                  textAlign: TextAlign.right,
                  style: GoogleFonts.cairo(
                    color: AppTheme.gold,
                    fontSize: headerSize,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              Expanded(flex: 2, child: _header('صرّح', headerSize)),
              Expanded(flex: 2, child: _header('ربح', headerSize)),
              Expanded(flex: 2, child: _header('الجولة', headerSize)),
              Expanded(flex: 3, child: _header('المجموع', headerSize)),
            ],
          ),
        ),

        SizedBox(height: largeScreen ? (compact ? 4 : 8) : (compact ? 2 : 4)),

        // Floating Individual Player Cards
        ...players.asMap().entries.map((e) {
          final rankIndex = e.key;
          final p = e.value;
          final delta = lastRoundDeltas[p.id] ?? 0;
          final isBidder = p.id == bidderPlayerId;
          final positive = delta >= 0;

          return Padding(
            padding: EdgeInsets.only(bottom: rowGap),
            child: _buildPlayerCard(
              rankIndex: rankIndex,
              player: p,
              delta: delta,
              isBidder: isBidder,
              positive: positive,
              rowPadding: rowPadding,
              compact: compact,
            ),
          );
        }),
      ],
    );
  }

  Widget _buildPlayerCard({
    required int rankIndex,
    required Player player,
    required int delta,
    required bool isBidder,
    required bool positive,
    required EdgeInsets rowPadding,
    required bool compact,
  }) {
    final matchRank = MatchRank.fromIndex(rankIndex);
    final borderColor = matchRank?.accentColor ?? AppTheme.steelBlue;
    final avatarSize = largeScreen
        ? (compact ? 34.0 : 42.0)
        : (compact ? 28.0 : 36.0);
    final nameSize = largeScreen
        ? (compact ? 14.0 : 16.0)
        : (compact ? 12.5 : 14.5);
    final cellSize = largeScreen
        ? (compact ? 13.0 : 15.0)
        : (compact ? 12.0 : 14.0);
    final deltaSize = largeScreen
        ? (compact ? 12.0 : 14.0)
        : (compact ? 11.0 : 13.0);
    final totalSize = largeScreen
        ? (compact ? 15.0 : 18.0)
        : (compact ? 13.5 : 16.0);

    return Container(
      padding: rowPadding,
      decoration: BoxDecoration(
        color: AppTheme.navyDark.withValues(alpha: 0.75),
        borderRadius: BorderRadius.circular(largeScreen ? (compact ? 16 : 20) : (compact ? 14 : 18)),
        border: Border.all(
          color: borderColor.withValues(alpha: rankIndex == 0 ? 0.8 : 0.5),
          width: rankIndex == 0 ? 1.6 : 1.2,
        ),
        boxShadow: [
          BoxShadow(
            color: borderColor.withValues(alpha: rankIndex == 0 ? 0.25 : 0.12),
            blurRadius: rankIndex == 0 ? 16 : 8,
            spreadRadius: rankIndex == 0 ? 1 : 0,
          ),
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.35),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          // Player Avatar & Name & Rank (Flex 5)
          Expanded(
            flex: 5,
            child: Row(
              children: [
                PlayerAvatar(
                  photoData: player.photo ?? '',
                  size: avatarSize,
                  borderWidth: 1.5,
                ),
                SizedBox(width: compact ? 8 : 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Row(
                        children: [
                          if (isBidder)
                            const Padding(
                              padding: EdgeInsets.only(left: 4),
                              child: Text('👑', style: TextStyle(fontSize: 13)),
                            ),
                          if (player.isDashCall)
                            const Padding(
                              padding: EdgeInsets.only(left: 4),
                              child: Text('🔥', style: TextStyle(fontSize: 13)),
                            ),
                          if (player.isRisk)
                            const Padding(
                              padding: EdgeInsets.only(left: 4),
                              child: Text('⚡', style: TextStyle(fontSize: 13)),
                            ),
                          Expanded(
                            child: FittedBox(
                              fit: BoxFit.scaleDown,
                              alignment: Alignment.centerRight,
                              child: Text(
                                player.name,
                                style: GoogleFonts.cairo(
                                  color: rankIndex == 0 ? AppTheme.gold : AppTheme.cream,
                                  fontSize: nameSize,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                      if (matchRank != null && !compact)
                        Padding(
                          padding: EdgeInsets.only(top: compact ? 2 : 4),
                          child: Align(
                            alignment: AlignmentDirectional.centerStart,
                            child: MatchRankChip(
                              rankIndex: rankIndex,
                              compact: true,
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          // Declared (Flex 2)
          Expanded(
            flex: 2,
            child: _cell('${player.declared ?? '-'}', cellSize),
          ),

          // Won / Actual (Flex 2)
          Expanded(
            flex: 2,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                _cell(
                  '${player.actual}',
                  cellSize,
                  color: (player.declared != null && player.declared == player.actual)
                      ? const Color(0xFF00E676)
                      : null,
                ),
                if (player.declared != null && player.declared == player.actual) ...[
                  const SizedBox(width: 3),
                  const Text('🎯', style: TextStyle(fontSize: 10)),
                ],
              ],
            ),
          ),

          // Round Score Delta Pill (Flex 2)
          Expanded(
            flex: 2,
            child: Center(
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: (positive ? const Color(0xFF00E676) : AppTheme.errorRed)
                      .withValues(alpha: 0.18),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: (positive ? const Color(0xFF00E676) : AppTheme.errorRed)
                        .withValues(alpha: 0.45),
                    width: 0.9,
                  ),
                ),
                child: Text(
                  positive ? '+$delta' : '$delta',
                  textAlign: TextAlign.center,
                  style: GoogleFonts.cairo(
                    color: positive ? const Color(0xFF00E676) : AppTheme.errorRed,
                    fontWeight: FontWeight.bold,
                    fontSize: deltaSize,
                  ),
                ),
              ),
            ),
          ),

          // Total Score (Flex 3)
          Expanded(
            flex: 3,
            child: Text(
              '${player.totalScore}',
              textAlign: TextAlign.center,
              style: GoogleFonts.cairo(
                color: AppTheme.gold,
                fontWeight: FontWeight.w900,
                fontSize: totalSize,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _header(String text, double fontSize) => Text(
        text,
        textAlign: TextAlign.center,
        style: GoogleFonts.cairo(
          color: AppTheme.gold,
          fontWeight: FontWeight.bold,
          fontSize: fontSize,
        ),
      );

  Widget _cell(String text, double fontSize, {Color? color}) => Text(
        text,
        textAlign: TextAlign.center,
        style: GoogleFonts.cairo(
          color: color ?? AppTheme.cream.withValues(alpha: 0.9),
          fontSize: fontSize,
          fontWeight: FontWeight.w600,
        ),
      );
}

