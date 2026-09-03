// lib/widgets/round_scores_dialog.dart
//
// In-game scoreboard — baize-ledger aesthetic: clear total points hero
// numbers, labeled current-round stats, and a readable round history.

import 'package:flutter/material.dart';
import 'package:estimation/core/icons/app_icons.dart';

import '../core/constants.dart';
import '../core/models/game_state.dart';
import '../core/models/player.dart';
import '../core/widgets/player_avatar.dart';
import '../models/match_rank.dart';
import '../theme/app_theme.dart';
import 'hud/match_rank_badge.dart';

class RoundScoresDialog extends StatelessWidget {
  final GameState state;

  const RoundScoresDialog({super.key, required this.state});

  static String _firstName(String fullName) {
    final trimmed = fullName.trim();
    if (trimmed.isEmpty) return 'Player';
    return trimmed.split(RegExp(r'\s+')).first;
  }

  static Future<void> show(BuildContext context, GameState state) {
    return showGeneralDialog(
      context: context,
      barrierDismissible: true,
      barrierLabel: 'نتائج الجولات',
      barrierColor: Colors.black.withValues(alpha: 0.62),
      transitionDuration: const Duration(milliseconds: 280),
      pageBuilder: (ctx, anim1, anim2) => RoundScoresDialog(state: state),
      transitionBuilder: (ctx, anim, secondaryAnim, child) {
        return FadeTransition(
          opacity: CurvedAnimation(parent: anim, curve: Curves.easeOutCubic),
          child: SlideTransition(
            position: Tween<Offset>(
              begin: const Offset(0, 0.04),
              end: Offset.zero,
            ).animate(
                CurvedAnimation(parent: anim, curve: Curves.easeOutCubic)),
            child: child,
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final media = MediaQuery.of(context);
    final isPortrait = media.orientation == Orientation.portrait;
    final dialogWidth =
        (media.size.width * (isPortrait ? 0.94 : 0.72)).clamp(320.0, 560.0);
    final maxHeight = media.size.height * 0.88;

    final sortedPlayers = List<Player>.from(state.players)
      ..sort((a, b) => b.totalScore.compareTo(a.totalScore));

    return Center(
      child: Material(
        color: Colors.transparent,
        child: Container(
          width: dialogWidth,
          constraints: BoxConstraints(maxHeight: maxHeight),
          margin: const EdgeInsets.symmetric(horizontal: 14, vertical: 18),
          decoration: AppTheme.dialogDecoration(accent: AppTheme.gold),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(AppTheme.dialogRadius),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                _buildHeader(context),
                _buildRoundProgress(),
                Flexible(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.fromLTRB(14, 12, 14, 18),
                    physics: const BouncingScrollPhysics(),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        _SectionLabel(
                          title: 'الترتيب ومجموع النقاط',
                          subtitle: 'النقاط الكلية حتى الآن',
                        ),
                        const SizedBox(height: 10),
                        _buildColumnHeaders(),
                        const SizedBox(height: 6),
                        _buildStandingsList(sortedPlayers),
                        const SizedBox(height: 20),
                        _SectionLabel(
                          title: 'سجل الجولات',
                          subtitle: state.roundHistory.isEmpty
                              ? 'لم تُحسب أي جولة بعد'
                              : '${state.roundHistory.length} جولة مكتملة',
                        ),
                        const SizedBox(height: 10),
                        if (state.roundHistory.isEmpty)
                          _buildEmptyHistoryCard()
                        else
                          _buildRoundHistoryList(),
                      ],
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

  Widget _buildHeader(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(8, 10, 16, 6),
      child: Row(
        children: [
          IconButton(
            onPressed: () => Navigator.of(context).pop(),
            icon: const AppIcon(AppIcons.close,
                color: AppTheme.steelBlue, size: 22),
            splashRadius: 20,
            tooltip: 'إغلاق',
          ),
          const Spacer(),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                'لوحة النتائج',
                style: AppFonts.dg(
                  fontSize: 19,
                  fontWeight: FontWeight.w900,
                  color: AppTheme.cream,
                  height: 1.15,
                ),
              ),
              Text(
                'الجولة ${state.roundNumber} من ${state.totalRounds}',
                style: AppFonts.cooper(
                  fontSize: 11.5,
                  color: AppTheme.gold,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
          const SizedBox(width: 10),
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: LinearGradient(
                colors: [
                  AppTheme.gold.withValues(alpha: 0.28),
                  AppTheme.goldDark.withValues(alpha: 0.12),
                ],
              ),
              border: Border.all(color: AppTheme.gold.withValues(alpha: 0.45)),
            ),
            child: const Center(
              child:
                  AppIcon(AppIcons.leaderboard, color: AppTheme.gold, size: 20),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRoundProgress() {
    final progress =
        (state.roundNumber / state.totalRounds).clamp(0.0, 1.0).toDouble();
    return Padding(
      padding: const EdgeInsets.fromLTRB(18, 0, 18, 10),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(4),
        child: LinearProgressIndicator(
          value: progress,
          minHeight: 3.5,
          backgroundColor: Colors.white.withValues(alpha: 0.08),
          valueColor: const AlwaysStoppedAnimation(AppTheme.gold),
        ),
      ),
    );
  }

  Widget _buildColumnHeaders() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 6),
      child: Row(
        children: [
          SizedBox(
            width: 72,
            child: Text(
              'المجموع',
              textAlign: TextAlign.center,
              style: AppFonts.cooper(
                color: AppTheme.gold,
                fontSize: 11,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
          const SizedBox(width: 6),
          SizedBox(
            width: 78,
            child: Text(
              'هذه الجولة',
              textAlign: TextAlign.center,
              style: AppFonts.cooper(
                color: AppTheme.steelBlue,
                fontSize: 11,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          const Spacer(),
          Text(
            'اللاعب',
            style: AppFonts.cooper(
              color: AppTheme.steelBlue,
              fontSize: 11,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStandingsList(List<Player> sortedPlayers) {
    return Column(
      children: sortedPlayers.asMap().entries.map((entry) {
        final rank = entry.key;
        final p = entry.value;
        final isLeader = rank == 0;
        final matchRank = MatchRank.fromIndex(rank);
        final accent = matchRank?.accentColor ?? AppTheme.steelBlue;
        final lastDelta = state.lastRoundScoreDeltas[p.id];
        final hasRoundStats = p.declared != null;

        return Container(
          margin: const EdgeInsets.only(bottom: 8),
          padding: const EdgeInsets.fromLTRB(8, 10, 10, 10),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            gradient: LinearGradient(
              begin: Alignment.centerRight,
              end: Alignment.centerLeft,
              colors: [
                accent.withValues(alpha: isLeader ? 0.18 : 0.08),
                AppTheme.deepNavy.withValues(alpha: 0.72),
              ],
            ),
            border: Border.all(
              color: accent.withValues(alpha: isLeader ? 0.75 : 0.32),
              width: isLeader ? 1.5 : 1.0,
            ),
            boxShadow: isLeader
                ? [
                    BoxShadow(
                      color: accent.withValues(alpha: 0.18),
                      blurRadius: 14,
                    ),
                  ]
                : null,
          ),
          child: Row(
            children: [
              // ── Total points (hero) ────────────────────────────────
              _TotalPointsPill(score: p.totalScore, highlight: isLeader),

              const SizedBox(width: 8),

              // ── Current round ─────────────────────────────────────
              SizedBox(
                width: 78,
                child: hasRoundStats
                    ? _CurrentRoundCell(
                        declared: p.declared!,
                        actual: p.actual,
                        lastDelta: lastDelta,
                      )
                    : lastDelta != null
                        ? _DeltaChip(delta: lastDelta)
                        : Text(
                            '—',
                            textAlign: TextAlign.center,
                            style: AppFonts.cooper(
                              color: AppTheme.steelBlue.withValues(alpha: 0.55),
                              fontSize: 13,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
              ),

              const Spacer(),

              // ── Player identity ───────────────────────────────────
              Flexible(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (p.id == state.bidderPlayerId)
                          Padding(
                            padding: const EdgeInsets.only(left: 4),
                            child: AppIcon(
                              AppIcons.flagCircle,
                              color: AppTheme.gold,
                              size: 12,
                            ),
                          ),
                        if (p.isDashCall)
                          Padding(
                            padding: const EdgeInsets.only(left: 3),
                            child: Text(
                              'داش',
                              style: AppFonts.cooper(
                                color: AppTheme.warningGlow,
                                fontSize: 9,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          ),
                        if (p.isRisk)
                          Padding(
                            padding: const EdgeInsets.only(left: 3),
                            child: Text(
                              'ريسك',
                              style: AppFonts.cooper(
                                color: AppTheme.playerRed,
                                fontSize: 9,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          ),
                        Flexible(
                          child: FittedBox(
                            fit: BoxFit.scaleDown,
                            alignment: AlignmentDirectional.centerEnd,
                            child: Text(
                              _firstName(p.name),
                              maxLines: 1,
                              style: AppFonts.cooper(
                                color:
                                    isLeader ? AppTheme.gold : AppTheme.cream,
                                fontWeight: FontWeight.w800,
                                fontSize: 13.5,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                    if (matchRank != null)
                      Padding(
                        padding: const EdgeInsets.only(top: 2),
                        child: MatchRankChip(rankIndex: rank, compact: true),
                      ),
                  ],
                ),
              ),

              const SizedBox(width: 8),

              Stack(
                clipBehavior: Clip.none,
                children: [
                  PlayerAvatar(
                    photoData: p.photo ?? '',
                    size: 36,
                    borderColor: accent,
                    borderWidth: 1.6,
                  ),
                  if (matchRank != null)
                    Positioned(
                      left: -4,
                      bottom: -4,
                      child: MatchRankBadge(
                        rankIndex: rank,
                        size: MatchRankBadgeSize.tiny,
                        glow: isLeader,
                      ),
                    ),
                ],
              ),
            ],
          ),
        );
      }).toList(),
    );
  }

  Widget _buildEmptyHistoryCard() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 18),
      decoration: BoxDecoration(
        color: AppTheme.deepNavy.withValues(alpha: 0.55),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.white.withValues(alpha: 0.07)),
      ),
      child: Row(
        children: [
          const AppIcon(AppIcons.infoOutline,
              color: AppTheme.steelBlue, size: 18),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              'بعد انتهاء أول جولة، هتظهر هنا نقاط كل جولة والمجموع بعد كل جولة.',
              textAlign: TextAlign.right,
              style: AppFonts.cooper(
                color: AppTheme.textSecondary,
                fontSize: 12,
                height: 1.45,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRoundHistoryList() {
    final reversedHistory = state.roundHistory.reversed.toList();

    return Column(
      children: reversedHistory.map((record) {
        final trump = record.trump;
        Color trumpColor = AppTheme.gold;
        if (trump != null) {
          switch (trump) {
            case Trump.heart:
            case Trump.diamond:
              trumpColor = const Color(0xFFFF5252);
            case Trump.spade:
            case Trump.club:
              trumpColor = const Color(0xFFE2E8F0);
            case Trump.sans:
              trumpColor = AppTheme.gold;
          }
        }

        return Container(
          margin: const EdgeInsets.only(bottom: 10),
          decoration: BoxDecoration(
            color: AppTheme.deepNavy.withValues(alpha: 0.62),
            borderRadius: BorderRadius.circular(14),
            border:
                Border.all(color: AppTheme.steelBlue.withValues(alpha: 0.22)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.04),
                  borderRadius:
                      const BorderRadius.vertical(top: Radius.circular(13)),
                ),
                child: Row(
                  children: [
                    if (trump != null)
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 7, vertical: 3),
                        decoration: BoxDecoration(
                          color: trumpColor.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(7),
                          border: Border.all(
                              color: trumpColor.withValues(alpha: 0.35)),
                        ),
                        child: Text(
                          trump.isSans
                              ? 'سانس'
                              : '${trump.arabicName}${record.winningBid != null ? ' ${record.winningBid!.trickCount}' : ''}',
                          style: AppFonts.cooper(
                            color: trumpColor,
                            fontSize: 10.5,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      )
                    else
                      const SizedBox.shrink(),
                    const Spacer(),
                    Text(
                      'الجولة ${record.roundNumber}',
                      style: AppFonts.cooper(
                        color: AppTheme.gold,
                        fontWeight: FontWeight.w800,
                        fontSize: 12.5,
                      ),
                    ),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(10, 8, 10, 10),
                child: Column(
                  children: [
                    Padding(
                      padding:
                          const EdgeInsets.only(bottom: 6, left: 2, right: 2),
                      child: Row(
                        children: [
                          _historyColHeader('المجموع', width: 56),
                          const SizedBox(width: 6),
                          _historyColHeader('نقاط الجولة', width: 64),
                          const Spacer(),
                          _historyColHeader('صرّح / ربح'),
                          const SizedBox(width: 8),
                          _historyColHeader('اللاعب'),
                        ],
                      ),
                    ),
                    ...record.playerRecords.map((pr) {
                      return Padding(
                        padding: const EdgeInsets.symmetric(vertical: 4),
                        child: Row(
                          children: [
                            SizedBox(
                              width: 56,
                              child: Text(
                                '${pr.totalScoreAfterRound}',
                                textAlign: TextAlign.center,
                                style: AppFonts.cooper(
                                  color: AppTheme.cream,
                                  fontWeight: FontWeight.w900,
                                  fontSize: 13,
                                ),
                              ),
                            ),
                            const SizedBox(width: 6),
                            SizedBox(
                              width: 64,
                              child: _DeltaChip(
                                  delta: pr.scoreDelta, compact: true),
                            ),
                            const Spacer(),
                            Text(
                              '${pr.declared} / ${pr.actual}',
                              style: AppFonts.cooper(
                                color: pr.isSuccess
                                    ? AppTheme.playerGreen
                                    : AppTheme.textSecondary,
                                fontSize: 11.5,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            const SizedBox(width: 10),
                            ConstrainedBox(
                              constraints: const BoxConstraints(maxWidth: 90),
                              child: FittedBox(
                                fit: BoxFit.scaleDown,
                                alignment: AlignmentDirectional.centerEnd,
                                child: Text(
                                  _firstName(pr.playerName),
                                  maxLines: 1,
                                  textAlign: TextAlign.right,
                                  style: AppFonts.cooper(
                                    color: AppTheme.cream,
                                    fontWeight: FontWeight.w700,
                                    fontSize: 12,
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      );
                    }),
                  ],
                ),
              ),
            ],
          ),
        );
      }).toList(),
    );
  }

  Widget _historyColHeader(String label, {double? width}) {
    final text = Text(
      label,
      textAlign: TextAlign.center,
      style: AppFonts.cooper(
        color: AppTheme.steelBlue.withValues(alpha: 0.85),
        fontSize: 9.5,
        fontWeight: FontWeight.w700,
      ),
    );
    if (width == null) return text;
    return SizedBox(width: width, child: text);
  }
}

// ── Section label ───────────────────────────────────────────────────────────

class _SectionLabel extends StatelessWidget {
  final String title;
  final String subtitle;

  const _SectionLabel({required this.title, required this.subtitle});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        Text(
          title,
          style: AppFonts.cooper(
            fontSize: 14,
            fontWeight: FontWeight.w900,
            color: AppTheme.cream,
          ),
        ),
        Text(
          subtitle,
          style: AppFonts.cooper(
            fontSize: 11,
            fontWeight: FontWeight.w600,
            color: AppTheme.steelBlue,
          ),
        ),
      ],
    );
  }
}

// ── Total points pill ───────────────────────────────────────────────────────

class _TotalPointsPill extends StatelessWidget {
  final int score;
  final bool highlight;

  const _TotalPointsPill({required this.score, this.highlight = false});

  @override
  Widget build(BuildContext context) {
    final positive = score >= 0;
    final color = positive ? AppTheme.playerGreen : AppTheme.playerRed;

    return Container(
      width: 72,
      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        color: AppTheme.deepNavy.withValues(alpha: 0.9),
        border: Border.all(
          color: color.withValues(alpha: highlight ? 0.55 : 0.28),
          width: highlight ? 1.4 : 1.0,
        ),
        boxShadow: highlight
            ? [BoxShadow(color: color.withValues(alpha: 0.18), blurRadius: 10)]
            : null,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            'نقاط',
            style: AppFonts.cooper(
              color: AppTheme.steelBlue,
              fontSize: 9,
              fontWeight: FontWeight.w700,
              height: 1,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            '$score',
            textAlign: TextAlign.center,
            style: AppFonts.cooper(
              color: color,
              fontWeight: FontWeight.w900,
              fontSize: 18,
              height: 1.05,
            ),
          ),
        ],
      ),
    );
  }
}

// ── Current round cell ──────────────────────────────────────────────────────

class _CurrentRoundCell extends StatelessWidget {
  final int declared;
  final int actual;
  final int? lastDelta;

  const _CurrentRoundCell({
    required this.declared,
    required this.actual,
    this.lastDelta,
  });

  @override
  Widget build(BuildContext context) {
    final onTrack = actual == declared;
    final over = actual > declared;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.05),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Directionality(
            textDirection: TextDirection.ltr,
            child: RichText(
              textAlign: TextAlign.center,
              text: TextSpan(
                children: [
                  TextSpan(
                    text: '$declared',
                    style: AppFonts.cooper(
                      color: AppTheme.steelBlue,
                      fontSize: 12,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  TextSpan(
                    text: ' / ',
                    style: AppFonts.cooper(
                      color: AppTheme.steelBlue.withValues(alpha: 0.55),
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  TextSpan(
                    text: '$actual',
                    style: AppFonts.cooper(
                      color: onTrack
                          ? AppTheme.playerGreen
                          : over
                              ? AppTheme.playerRed
                              : AppTheme.cream,
                      fontSize: 12,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
        if (lastDelta != null) ...[
          const SizedBox(height: 3),
          _DeltaChip(delta: lastDelta!, compact: true),
        ],
      ],
    );
  }
}

// ── Delta chip ──────────────────────────────────────────────────────────────

class _DeltaChip extends StatelessWidget {
  final int delta;
  final bool compact;

  const _DeltaChip({required this.delta, this.compact = false});

  @override
  Widget build(BuildContext context) {
    final positive = delta >= 0;
    final color = positive ? AppTheme.playerGreen : AppTheme.playerRed;

    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: compact ? 5 : 8,
        vertical: compact ? 2 : 4,
      ),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(7),
        border: Border.all(color: color.withValues(alpha: 0.28)),
      ),
      child: Text(
        '${positive ? '+' : ''}$delta',
        textAlign: TextAlign.center,
        style: AppFonts.cooper(
          color: color,
          fontWeight: FontWeight.w900,
          fontSize: compact ? 11 : 12.5,
        ),
      ),
    );
  }
}
