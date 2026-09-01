import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import 'package:estimation/core/icons/app_icons.dart';
import 'package:estimation/core/utils/game_layout_metrics.dart';
import 'package:estimation/core/widgets/app_buttons.dart';
import 'package:estimation/core/widgets/round_advance_timer.dart';
import 'package:estimation/modes/basra/domain/basra_constants.dart';
import 'package:estimation/modes/basra/presentation/providers/basra_game_provider.dart';
import 'package:estimation/theme/app_theme.dart';
import 'package:estimation/widgets/performance_blur.dart';

class BasraRoundScoreOverlay extends StatefulWidget {
  final BasraGameProvider game;
  final bool isHost;
  final VoidCallback onNextRound;

  const BasraRoundScoreOverlay({
    super.key,
    required this.game,
    required this.isHost,
    required this.onNextRound,
  });

  @override
  State<BasraRoundScoreOverlay> createState() => _BasraRoundScoreOverlayState();
}

class _BasraRoundScoreOverlayState extends State<BasraRoundScoreOverlay>
    with SingleTickerProviderStateMixin {
  static const _autoAdvanceDelay = Duration(seconds: 5);

  late final AnimationController _entrance;
  late final Animation<double> _fade;
  late final Animation<double> _scale;
  late final RoundAdvanceTimer _advanceTimer;
  int _secondsRemaining = _autoAdvanceDelay.inSeconds;
  double _advanceProgress = 0;
  bool _advanceTriggered = false;

  @override
  void initState() {
    super.initState();
    _entrance = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 520),
    );
    _fade = CurvedAnimation(parent: _entrance, curve: Curves.easeOut);
    _scale = Tween<double>(begin: 0.96, end: 1).animate(
      CurvedAnimation(parent: _entrance, curve: Curves.easeOutCubic),
    );
    _advanceTimer = RoundAdvanceTimer(
      duration: _autoAdvanceDelay,
      onTick: (seconds) {
        if (!mounted) return;
        setState(() {
          _secondsRemaining = seconds;
          _advanceProgress = _advanceTimer.progress;
        });
      },
      onComplete: _handleAutoAdvance,
    );
    _entrance.forward().whenComplete(() {
      if (!mounted) return;
      _advanceTimer.start();
    });
  }

  void _handleAutoAdvance() {
    if (!mounted || _advanceTriggered) return;
    _advanceTriggered = true;
    if (widget.isHost) {
      widget.onNextRound();
    }
  }

  void _handleManualAdvance() {
    if (_advanceTriggered) return;
    _advanceTriggered = true;
    _advanceTimer.cancel();
    widget.onNextRound();
  }

  @override
  void dispose() {
    _advanceTimer.cancel();
    _entrance.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final game = widget.game;
    final players = game.players;
    final scores = game.lastRoundScores;
    final layout = GameLayoutMetrics.of(context);
    final isLargeScreen = layout.isTablet;
    final maxWidth = layout.isLargeTablet
        ? 920.0
        : (layout.isTablet ? 680.0 : 440.0);
    final roundLeaderId = scores.isEmpty
        ? null
        : scores.reduce((a, b) => a.roundScore >= b.roundScore ? a : b).playerId;

    return Container(
      color: Colors.black.withValues(alpha: 0.78),
      alignment: Alignment.center,
      padding: EdgeInsets.all(layout.isLargeTablet ? 28 : 20),
      child: FadeTransition(
        opacity: _fade,
        child: ScaleTransition(
          scale: _scale,
          child: ConstrainedBox(
            constraints: BoxConstraints(maxWidth: maxWidth),
            child: PerformanceBlur(
              sigmaX: isLargeScreen ? 20 : 16,
              sigmaY: isLargeScreen ? 20 : 16,
              borderRadius: BorderRadius.circular(isLargeScreen ? 32 : 28),
              fallbackColor: AppTheme.surface2.withValues(alpha: 0.96),
              blurColor: AppTheme.deepNavy.withValues(alpha: 0.32),
              child: Container(
                decoration: AppTheme.glassDecoration(
                  borderRadius: isLargeScreen ? 32 : 28,
                  borderColor: AppTheme.gold.withValues(alpha: 0.28),
                ),
                padding: EdgeInsets.fromLTRB(
                  isLargeScreen ? 28 : 20,
                  isLargeScreen ? 28 : 20,
                  isLargeScreen ? 28 : 20,
                  isLargeScreen ? 22 : 18,
                ),
                child: _buildStackedLayout(
                        game: game,
                        players: players,
                        scores: scores,
                        roundLeaderId: roundLeaderId,
                        layout: layout,
                      ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildStackedLayout({
    required BasraGameProvider game,
    required List players,
    required List scores,
    required String? roundLeaderId,
    required GameLayoutMetrics layout,
  }) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _Header(roundNumber: game.currentRoundNumber, largeScreen: layout.isTablet),
        ..._buildNoticeBanners(game),
        SizedBox(height: layout.isLargeTablet ? 18 : 14),
        _buildLegend(layout),
        SizedBox(height: layout.isLargeTablet ? 18 : 14),
        ..._buildPlayerRows(
          players: players,
          scores: scores,
          roundLeaderId: roundLeaderId,
          layout: layout,
        ),
        SizedBox(height: layout.isLargeTablet ? 22 : 18),
        if (layout.isTablet)
          Align(
            alignment: Alignment.center,
            child: ConstrainedBox(
              constraints: BoxConstraints(
                maxWidth: layout.isLargeTablet ? 420 : 380,
              ),
              child: _buildActionSection(),
            ),
          )
        else
          _buildActionSection(),
      ],
    );
  }

  List<Widget> _buildNoticeBanners(BasraGameProvider game) {
    if (game.lastRoundWasTwentySixTie) {
      return [
        const SizedBox(height: 12),
        const _NoticeBanner(
          icon: AppIcons.swapHorizontalCircle,
          color: AppTheme.playerOrange,
          text:
              'تعادل 26-26 — لا أحد حصل على 27+ ورقة. تُرحَّل $kBasraMajorityPoints نقطة للجولة القادمة.',
        ),
      ];
    }
    if (game.carriedMajorityPoints > 0) {
      return [
        const SizedBox(height: 12),
        _NoticeBanner(
          icon: AppIcons.layers,
          color: AppTheme.gold,
          text:
              'نقاط مُرحَّلة من جولة سابقة: $kBasraMajorityPoints (تُمنح لمن يحصل على 27+ ورقة)',
        ),
      ];
    }
    return const [];
  }

  Widget _buildLegend(GameLayoutMetrics layout) {
    return Text(
      'الورق الملتقط + J/A + 2♠ + 10♦ + باصرة + 27+ ورقة',
      style: GoogleFonts.cairo(
        color: AppTheme.steelBlue,
        fontSize: layout.isLargeTablet ? 12.5 : 11,
        height: 1.35,
      ),
      textAlign: TextAlign.center,
    );
  }

  List<Widget> _buildPlayerRows({
    required List players,
    required List scores,
    required String? roundLeaderId,
    required GameLayoutMetrics layout,
  }) {
    return players
        .map((player) {
          final score = scores.where((s) => s.playerId == player.id).firstOrNull;
          return _PlayerScoreRow(
            name: player.name,
            score: score,
            isRoundLeader:
                player.id == roundLeaderId && (score?.roundScore ?? 0) > 0,
            matchTarget: kBasraMatchTarget,
            largeScreen: layout.isTablet,
          );
        })
        .toList(growable: false);
  }

  Widget _buildActionSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (widget.isHost)
          FilledButton(
            onPressed: _handleManualAdvance,
            style: FilledButton.styleFrom(
              backgroundColor: AppTheme.gold,
              foregroundColor: AppTheme.deepNavy,
              minimumSize: const Size.fromHeight(48),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
            ),
            child: Text(
              'الجولة التالية',
              style: GoogleFonts.cairo(
                fontWeight: FontWeight.w800,
                fontSize: 15,
              ),
            ),
          )
        else
          Container(
            padding: const EdgeInsets.symmetric(
              horizontal: 14,
              vertical: 12,
            ),
            decoration: BoxDecoration(
              color: AppTheme.steelBlue.withValues(alpha: 0.10),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: AppTheme.steelBlue.withValues(alpha: 0.22),
              ),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: AppTheme.gold.withValues(alpha: 0.85),
                  ),
                ),
                const SizedBox(width: 10),
                Text(
                  'بانتظار المضيف لبدء الجولة التالية',
                  style: GoogleFonts.cairo(
                    color: AppTheme.steelBlue,
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        const SizedBox(height: 10),
        ClipRRect(
          borderRadius: BorderRadius.circular(999),
          child: LinearProgressIndicator(
            value: _advanceProgress.clamp(0.0, 1.0),
            minHeight: 4,
            backgroundColor: Colors.white.withValues(alpha: 0.08),
            valueColor: AlwaysStoppedAnimation<Color>(
              AppTheme.gold.withValues(alpha: 0.85),
            ),
          ),
        ),
        if (_secondsRemaining > 0) ...[
          const SizedBox(height: 6),
          Text(
            widget.isHost
                ? 'تبدأ الجولة التالية تلقائياً خلال $_secondsRemaining ث'
                : 'يبدأ المضيف الجولة التالية خلال $_secondsRemaining ث',
            textAlign: TextAlign.center,
            style: GoogleFonts.cairo(
              color: AppTheme.steelBlue,
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ],
    );
  }
}

class _Header extends StatelessWidget {
  final int roundNumber;
  final bool largeScreen;

  const _Header({
    required this.roundNumber,
    this.largeScreen = false,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            AppIconWell(
              icon: AppIcons.flagCircle,
              size: largeScreen ? 52 : 44,
              iconSize: largeScreen ? 24 : 20,
              color: AppTheme.goldLight,
              fill: AppTheme.gold.withValues(alpha: 0.14),
              borderColor: AppTheme.gold.withValues(alpha: 0.32),
            ),
            const SizedBox(width: 12),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'الجولة $roundNumber',
                  style: GoogleFonts.cairo(
                    color: AppTheme.steelBlue,
                    fontSize: largeScreen ? 14 : 12,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.4,
                  ),
                ),
                Text(
                  'ملخص النقاط',
                  style: GoogleFonts.cairo(
                    color: AppTheme.cream,
                    fontSize: largeScreen ? 28 : 22,
                    fontWeight: FontWeight.w900,
                    height: 1.1,
                  ),
                ),
              ],
            ),
          ],
        ),
      ],
    );
  }
}

class _NoticeBanner extends StatelessWidget {
  final AppIconData icon;
  final Color color;
  final String text;

  const _NoticeBanner({
    required this.icon,
    required this.color,
    required this.text,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: color.withValues(alpha: 0.32)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          AppIcon(icon, size: 18, color: color, strokeWidth: AppIconTokens.stroke),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              text,
              style: GoogleFonts.cairo(
                color: AppTheme.cream,
                fontSize: 12,
                height: 1.4,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _PlayerScoreRow extends StatelessWidget {
  final String name;
  final BasraPlayerScore? score;
  final bool isRoundLeader;
  final int matchTarget;
  final bool largeScreen;

  const _PlayerScoreRow({
    required this.name,
    required this.score,
    required this.isRoundLeader,
    required this.matchTarget,
    this.largeScreen = false,
  });

  @override
  Widget build(BuildContext context) {
    final total = score?.totalScore ?? 0;
    final round = score?.roundScore ?? 0;
    final progress = (total / matchTarget).clamp(0.0, 1.0);

    return Container(
      margin: EdgeInsets.only(bottom: largeScreen ? 12 : 10),
      padding: EdgeInsets.all(largeScreen ? 14 : 12),
      decoration: BoxDecoration(
        color: isRoundLeader
            ? AppTheme.gold.withValues(alpha: 0.08)
            : Colors.white.withValues(alpha: 0.04),
        borderRadius: BorderRadius.circular(largeScreen ? 18 : 16),
        border: Border.all(
          color: isRoundLeader
              ? AppTheme.gold.withValues(alpha: 0.42)
              : AppTheme.steelBlue.withValues(alpha: 0.14),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: Row(
                  children: [
                    if (isRoundLeader) ...[
                      const AppIcon(
                        AppIcons.emojiEvents,
                        size: 16,
                        color: AppTheme.gold,
                        strokeWidth: AppIconTokens.stroke,
                      ),
                      const SizedBox(width: 6),
                    ],
                    Flexible(
                      child: Text(
                        name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: GoogleFonts.cairo(
                          color: AppTheme.cream,
                          fontSize: largeScreen ? 17 : 15,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              Text(
                '+$round',
                style: GoogleFonts.cairo(
                  color: AppTheme.playerGreen,
                  fontSize: 16,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(width: 8),
              Text(
                '$total',
                style: GoogleFonts.cairo(
                  color: AppTheme.gold,
                  fontSize: 15,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          ClipRRect(
            borderRadius: BorderRadius.circular(999),
            child: LinearProgressIndicator(
              value: progress,
              minHeight: 5,
              backgroundColor: AppTheme.steelBlue.withValues(alpha: 0.14),
              valueColor: AlwaysStoppedAnimation<Color>(
                total >= matchTarget ? AppTheme.playerGreen : AppTheme.midBlue,
              ),
            ),
          ),
          const SizedBox(height: 4),
          Text(
            '$total / $matchTarget للفوز',
            style: GoogleFonts.cairo(
              color: AppTheme.steelBlue,
              fontSize: 10.5,
              height: 1.1,
            ),
          ),
          if (score != null) ...[
            const SizedBox(height: 8),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: _breakdownChips(score!),
            ),
          ],
        ],
      ),
    );
  }

  List<Widget> _breakdownChips(BasraPlayerScore s) {
    final chips = <Widget>[
      _chip('${s.capturedCount} ورقة', AppTheme.steelBlue),
    ];
    if (s.majorityPoints > 0) {
      chips.add(_chip('27+ (+${s.majorityPoints})', AppTheme.gold));
    }
    if (s.basraPoints > 0) {
      chips.add(_chip('باصرة ×${s.basraCount} (+${s.basraPoints})', AppTheme.gold));
    }
    if (s.jackPoints > 0) {
      chips.add(_chip('J (+${s.jackPoints})', AppTheme.midBlue));
    }
    if (s.acePoints > 0) {
      chips.add(_chip('A (+${s.acePoints})', AppTheme.midBlue));
    }
    if (s.twoOfSpadesPoints > 0) {
      chips.add(_chip('2♠ (+${s.twoOfSpadesPoints})', AppTheme.playerOrange));
    }
    if (s.tenOfDiamondsPoints > 0) {
      chips.add(_chip('10♦ (+${s.tenOfDiamondsPoints})', AppTheme.suitRed));
    }
    if (s.carryOverPoints > 0) {
      chips.add(_chip('ترحيل (+${s.carryOverPoints})', AppTheme.playerOrange));
    }
    return chips;
  }

  Widget _chip(String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: color.withValues(alpha: 0.28)),
      ),
      child: Text(
        label,
        style: GoogleFonts.cairo(
          color: AppTheme.cream,
          fontSize: 10.5,
          fontWeight: FontWeight.w700,
          height: 1,
        ),
      ),
    );
  }
}
