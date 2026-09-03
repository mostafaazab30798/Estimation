// lib/screens/scoring_screen.dart
//
// End-of-round score display.

import 'package:flutter/material.dart';
import '../core/models/game_state.dart';
import '../core/models/comeback_event.dart';
import '../core/utils/game_layout_metrics.dart';
import '../core/widgets/leave_game_dialog.dart';
import '../core/widgets/player_avatar.dart';
import '../core/widgets/round_advance_timer.dart';
import '../providers/game_provider.dart';
import '../theme/app_theme.dart';
import '../widgets/score_table.dart';
import '../widgets/performance_blur.dart';
import '../widgets/perfect_estimate_overlay.dart';
import '../widgets/comeback_overlay.dart';
import '../services/audio_service.dart';
import 'package:estimation/core/icons/app_icons.dart';

class ScoringScreen extends StatefulWidget {
  final GameState state;
  final GameProvider provider;

  const ScoringScreen({
    super.key,
    required this.state,
    required this.provider,
  });

  @override
  State<ScoringScreen> createState() => _ScoringScreenState();
}

class _ScoringScreenState extends State<ScoringScreen> with SingleTickerProviderStateMixin {
  static const _autoAdvanceDelay = Duration(seconds: 5);

  late final AnimationController _entrance;
  late final Animation<double> _headerFade;
  late final Animation<Offset> _headerSlide;
  late final Animation<double> _tableFade;
  late final Animation<double> _tableScale;
  late final RoundAdvanceTimer _advanceTimer;
  bool _showPerfectEstimate = false;
  ComebackEvent? _activeComeback;
  int _secondsRemaining = _autoAdvanceDelay.inSeconds;
  double _advanceProgress = 0;
  bool _advanceTriggered = false;

  bool get _celebrationActive =>
      _activeComeback != null || _showPerfectEstimate;

  @override
  void initState() {
    super.initState();
    _entrance = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 620),
    );

    _headerFade = CurvedAnimation(
      parent: _entrance,
      curve: const Interval(0.0, 0.6, curve: Curves.easeOut),
    );
    _headerSlide = Tween<Offset>(begin: const Offset(0, -0.08), end: Offset.zero).animate(
      CurvedAnimation(parent: _entrance, curve: const Interval(0.0, 0.6, curve: Curves.easeOutCubic)),
    );
    _tableFade = CurvedAnimation(
      parent: _entrance,
      curve: const Interval(0.25, 1.0, curve: Curves.easeOut),
    );
    _tableScale = Tween<double>(begin: 0.97, end: 1.0).animate(
      CurvedAnimation(parent: _entrance, curve: const Interval(0.25, 1.0, curve: Curves.easeOutCubic)),
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
      if (!mounted || _celebrationActive) return;
      _advanceTimer.start();
    });

    final me = widget.provider.me;
    if (me != null) {
      if (me.declared != null && me.actual == me.declared) {
        _showPerfectEstimate = true;
        if (me.isDashCall) {
          AudioService.instance.playRiskWin();
        }
      }

      // Check for round comeback for current player
      final roundComebacks = ComebackDetector.detectRoundComebacks(
        state: widget.state,
        roundNumber: widget.state.roundNumber,
      );
      final myEvent = roundComebacks.where((c) => c.playerId == me.id).firstOrNull;
      if (myEvent != null) {
        _activeComeback = myEvent;
      }
    }
  }

  void _resumeAdvanceTimer() {
    if (_advanceTriggered || _celebrationActive) return;
    _advanceTimer.start();
  }

  void _handleAutoAdvance() {
    if (!mounted || _advanceTriggered) return;
    _advanceTriggered = true;
    if (widget.provider.isHost) {
      widget.provider.nextRound();
    }
  }

  void _handleManualAdvance() {
    if (_advanceTriggered) return;
    _advanceTriggered = true;
    _advanceTimer.cancel();
    widget.provider.nextRound();
  }

  void _onCelebrationDismissed(VoidCallback dismiss) {
    if (!mounted) return;
    setState(dismiss);
    _resumeAdvanceTimer();
  }

  @override
  void dispose() {
    _advanceTimer.cancel();
    _entrance.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = widget.state;
    final provider = widget.provider;
    final layout = GameLayoutMetrics.of(context);
    final isLargeScreen = layout.isTablet;
    final titleSize = layout.isLargeTablet ? 42.0 : (layout.isTablet ? 38.0 : 34.0);
    final contentPadding = layout.isLargeTablet
        ? const EdgeInsets.all(32)
        : (layout.isTablet ? const EdgeInsets.all(26) : const EdgeInsets.all(20));
    final cardMaxWidth = layout.isLargeTablet
        ? 980.0
        : (layout.isTablet ? 760.0 : double.infinity);

    final headerSection = SlideTransition(
      position: _headerSlide,
      child: FadeTransition(
        opacity: _headerFade,
        child: Column(
          crossAxisAlignment: isLargeScreen ? CrossAxisAlignment.stretch : CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              mainAxisAlignment:
                  isLargeScreen && layout.isPortrait ? MainAxisAlignment.center : MainAxisAlignment.start,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Container(
                  padding: EdgeInsets.all(layout.isLargeTablet ? 11 : 9),
                  decoration: BoxDecoration(
                    color: AppTheme.gold.withValues(alpha: 0.15),
                    shape: BoxShape.circle,
                    border: Border.all(color: AppTheme.gold.withValues(alpha: 0.4)),
                  ),
                  child: AppIcon(
                    AppIcons.flagCircle,
                    color: AppTheme.gold,
                    size: layout.isLargeTablet ? 24 : 20,
                  ),
                ),
                const SizedBox(width: 12),
                Text(
                  'الجولة ${state.roundNumber}',
                  style: AppFonts.cooper(
                    color: AppTheme.accentLight.withValues(alpha: 0.9),
                    fontSize: layout.isLargeTablet ? 16 : 14,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.4,
                  ),
                ),
              ],
            ),
            SizedBox(height: layout.isLargeTablet ? 10 : 6),
            Align(
              alignment: isLargeScreen && layout.isPortrait
                  ? Alignment.center
                  : AlignmentDirectional.centerStart,
              child: ShaderMask(
                shaderCallback: (bounds) => const LinearGradient(
                  colors: [AppTheme.gold, AppTheme.cardWhite, AppTheme.goldLight],
                ).createShader(bounds),
                child: Text(
                  'نهاية الجولة',
                  textAlign: isLargeScreen && layout.isPortrait ? TextAlign.center : TextAlign.start,
                  style: AppFonts.dg(
                    fontSize: titleSize,
                    fontWeight: FontWeight.w900,
                    color: Colors.white,
                    height: 1.1,
                  ),
                ),
              ),
            ),
            SizedBox(height: layout.isLargeTablet ? 20 : 16),
            if (state.bidder != null)
              Align(
                alignment: isLargeScreen && layout.isPortrait
                    ? Alignment.center
                    : AlignmentDirectional.centerStart,
                child: _buildBidderChip(state, layout),
              ),
          ],
        ),
      ),
    );

    Widget buildScoreTable({required bool compact}) => ScaleTransition(
      scale: _tableScale,
      child: FadeTransition(
        opacity: _tableFade,
        child: ScoreTable(
          players: [...state.players]..sort((a, b) => b.totalScore.compareTo(a.totalScore)),
          lastRoundDeltas: state.lastRoundScoreDeltas,
          bidderPlayerId: state.bidderPlayerId,
          largeScreen: isLargeScreen,
          compact: compact,
        ),
      ),
    );

    final actionSection = FadeTransition(
      opacity: _headerFade,
      child: provider.isHost
          ? _PrimaryActionButton(
              label: state.isMatchOver ? 'إنهاء اللعبة' : 'الجولة التالية',
              isFinal: state.isMatchOver,
              secondsRemaining: _secondsRemaining,
              progress: _advanceProgress,
              onPressed: _handleManualAdvance,
            )
          : _WaitingForHostChip(
              secondsRemaining: _secondsRemaining,
              progress: _advanceProgress,
            ),
    );

    Widget buildBody(BoxConstraints constraints) {
      final availableHeight = constraints.maxHeight;
      final compact = availableHeight < (isLargeScreen ? 680 : 560);
      final sectionGap = compact
          ? 12.0
          : (layout.isLargeTablet ? 24.0 : (layout.isTablet ? 20.0 : 16.0));
      final actionGap = compact
          ? 10.0
          : (layout.isLargeTablet ? 28.0 : (layout.isTablet ? 24.0 : 12.0));
      final table = buildScoreTable(compact: compact);

      Widget scaledTable({required double width, bool expand = true}) {
        final child = Align(
          alignment: Alignment.center,
          child: FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.center,
            child: SizedBox(
              width: width,
              child: table,
            ),
          ),
        );
        return expand ? Expanded(child: child) : child;
      }

      // Tablets use a single stacked column in both orientations.
      if (layout.isPortrait || isLargeScreen) {
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            headerSection,
            SizedBox(height: sectionGap),
            scaledTable(width: constraints.maxWidth),
            SizedBox(height: actionGap),
            if (isLargeScreen)
              Align(
                alignment: Alignment.center,
                child: ConstrainedBox(
                  constraints: BoxConstraints(
                    maxWidth: layout.isLargeTablet ? 440 : 400,
                  ),
                  child: actionSection,
                ),
              )
            else
              actionSection,
          ],
        );
      }

      // Phone landscape: side-by-side, no scrolling.
      return Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(
            flex: 4,
            child: Padding(
              padding: const EdgeInsets.only(right: 24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  FittedBox(
                    fit: BoxFit.scaleDown,
                    alignment: AlignmentDirectional.centerStart,
                    child: SizedBox(
                      width: constraints.maxWidth * 0.34,
                      child: headerSection,
                    ),
                  ),
                  const Spacer(),
                  const SizedBox(height: 16),
                  actionSection,
                ],
              ),
            ),
          ),
          Container(
            width: 1.5,
            margin: const EdgeInsets.symmetric(vertical: 20),
            color: Colors.white.withValues(alpha: 0.12),
          ),
          const SizedBox(width: 24),
          Expanded(
            flex: 6,
            child: Align(
              alignment: Alignment.center,
              child: FittedBox(
                fit: BoxFit.scaleDown,
                alignment: Alignment.center,
                child: SizedBox(
                  width: constraints.maxWidth * 0.56,
                  child: table,
                ),
              ),
            ),
          ),
        ],
      );
    }

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {
        if (didPop) return;
        _confirmExit(context, provider);
      },
      child: Scaffold(
        backgroundColor: Colors.black,
        body: Stack(
          fit: StackFit.expand,
          children: [
            // Background Wallpaper
            Positioned.fill(
              child: Image.asset(
                'assets/wallpapers/w2.jpg',
                fit: BoxFit.cover,
                alignment: Alignment.center,
                filterQuality: FilterQuality.medium,
              ),
            ),
            // Dark Gradient Overlay
            Positioned.fill(
              child: Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      AppTheme.navyDark.withValues(alpha: 0.55),
                      AppTheme.navyDark.withValues(alpha: 0.82),
                    ],
                  ),
                ),
              ),
            ),
            // Glass Blur
            Positioned.fill(
              child: PerformanceBlur(
                sigmaX: 6,
                sigmaY: 6,
                fallbackColor: Colors.black.withValues(alpha: 0.2),
                child: const SizedBox.expand(),
              ),
            ),
            // Content
            SafeArea(
              child: LayoutBuilder(
                builder: (context, constraints) {
                  final body = buildBody(constraints);
                  return Padding(
                    padding: contentPadding,
                    child: isLargeScreen
                        ? Center(
                            child: ConstrainedBox(
                              constraints: BoxConstraints(
                                maxWidth: cardMaxWidth,
                                maxHeight: constraints.maxHeight,
                              ),
                              child: PerformanceBlur(
                                sigmaX: 18,
                                sigmaY: 18,
                                borderRadius: BorderRadius.circular(32),
                                fallbackColor: AppTheme.surface2.withValues(alpha: 0.94),
                                blurColor: AppTheme.deepNavy.withValues(alpha: 0.28),
                                child: Container(
                                  decoration: AppTheme.glassDecoration(
                                    borderRadius: 32,
                                    borderColor: AppTheme.gold.withValues(alpha: 0.24),
                                  ),
                                  padding: EdgeInsets.all(
                                    layout.isLargeTablet ? 24 : 20,
                                  ),
                                  child: body,
                                ),
                              ),
                            ),
                          )
                        : SizedBox(
                            height: constraints.maxHeight,
                            width: constraints.maxWidth,
                            child: body,
                          ),
                  );
                },
              ),
            ),
            // Comeback Celebration Overlay (highest priority celebration)
            if (_activeComeback != null)
              Positioned.fill(
                child: ComebackOverlay(
                  event: _activeComeback!,
                  onDismissed: () => _onCelebrationDismissed(() {
                    _activeComeback = null;
                  }),
                ),
              )
            // Perfect Estimation Celebration Overlay (shows after comeback or on its own)
            else if (_showPerfectEstimate &&
                widget.provider.me != null &&
                widget.provider.me!.declared != null)
              Positioned.fill(
                child: PerfectEstimateOverlay(
                  declared: widget.provider.me!.declared!,
                  won: widget.provider.me!.actual,
                  isDashCall: widget.provider.me!.isDashCall,
                  onDismissed: () => _onCelebrationDismissed(() {
                    _showPerfectEstimate = false;
                  }),
                ),
              ),
          ],
        ),
      ),
    );
  }

  void _confirmExit(BuildContext context, GameProvider provider) {
    LeaveGameDialog.show(
      context,
      onLeave: () async {
        provider.reset();
        if (!context.mounted) return;
        Navigator.of(context, rootNavigator: true)
            .pushNamedAndRemoveUntil('/', (route) => false);
      },
    );
  }

  Widget _buildBidderChip(GameState state, GameLayoutMetrics layout) {
    final bidder = state.bidder!;
    final bid = state.currentHighBid;

    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: layout.isLargeTablet ? 20 : 16,
        vertical: layout.isLargeTablet ? 14 : 12,
      ),
      decoration: BoxDecoration(
        color: AppTheme.navyDark.withValues(alpha: 0.85),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: AppTheme.gold.withValues(alpha: 0.5),
          width: 1.4,
        ),
        boxShadow: [
          BoxShadow(
            color: AppTheme.gold.withValues(alpha: 0.2),
            blurRadius: 18,
            spreadRadius: 1,
            offset: const Offset(0, 4),
          ),
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.35),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Glowing Crown + Avatar Stack
          Stack(
            clipBehavior: Clip.none,
            children: [
              PlayerAvatar(
                photoData: bidder.photo ?? '',
                size: layout.isLargeTablet ? 48 : 42,
                borderWidth: 2,
                borderColor: AppTheme.gold,
              ),
              Positioned(
                top: -8,
                right: -6,
                child: Container(
                  padding: const EdgeInsets.all(3),
                  decoration: BoxDecoration(
                    color: AppTheme.navyDark,
                    shape: BoxShape.circle,
                    border: Border.all(color: AppTheme.gold, width: 1),
                    boxShadow: [
                      BoxShadow(
                        color: AppTheme.gold.withValues(alpha: 0.5),
                        blurRadius: 6,
                      ),
                    ],
                  ),
                  child: const Text('👑', style: TextStyle(fontSize: 12)),
                ),
              ),
            ],
          ),
          const SizedBox(width: 14),
          // Info Section
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    'صاحب المزاد',
                    style: AppFonts.cooper(
                      color: AppTheme.gold.withValues(alpha: 0.85),
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      height: 1.1,
                    ),
                  ),
                  const SizedBox(width: 4),
                  const Text('🔥', style: TextStyle(fontSize: 11)),
                ],
              ),
              const SizedBox(height: 2),
              Text(
                bidder.name,
                style: AppFonts.cooper(
                  color: AppTheme.cream,
                  fontSize: 15,
                  fontWeight: FontWeight.w800,
                  height: 1.2,
                ),
              ),
            ],
          ),
          if (bid != null) ...[
            const SizedBox(width: 16),
            Container(
              height: 28,
              width: 1,
              color: Colors.white.withValues(alpha: 0.15),
            ),
            const SizedBox(width: 16),
            // Bid Pill
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: AppTheme.gold.withValues(alpha: 0.18),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: AppTheme.gold.withValues(alpha: 0.5),
                  width: 1.0,
                ),
              ),
              child: Text(
                bid.arabicLabel,
                style: AppFonts.cooper(
                  color: AppTheme.gold,
                  fontSize: 13,
                  fontWeight: FontWeight.w800,
                  height: 1.1,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

// ── Primary CTA with press feedback ──────────────────────────────────────
class _PrimaryActionButton extends StatefulWidget {
  final String label;
  final bool isFinal;
  final int secondsRemaining;
  final double progress;
  final VoidCallback onPressed;

  const _PrimaryActionButton({
    required this.label,
    required this.isFinal,
    required this.secondsRemaining,
    required this.progress,
    required this.onPressed,
  });

  @override
  State<_PrimaryActionButton> createState() => _PrimaryActionButtonState();
}

class _PrimaryActionButtonState extends State<_PrimaryActionButton> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        GestureDetector(
          onTapDown: (_) => setState(() => _pressed = true),
          onTapUp: (_) {
            setState(() => _pressed = false);
            widget.onPressed();
          },
          onTapCancel: () => setState(() => _pressed = false),
          child: AnimatedScale(
            scale: _pressed ? 0.97 : 1.0,
            duration: const Duration(milliseconds: 120),
            curve: Curves.easeOut,
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 17),
              decoration: BoxDecoration(
                color: AppTheme.gold,
                borderRadius: BorderRadius.circular(14),
                boxShadow: [
                  BoxShadow(
                    color: AppTheme.gold.withValues(alpha: _pressed ? 0.18 : 0.35),
                    blurRadius: _pressed ? 8 : 18,
                    offset: const Offset(0, 6),
                  ),
                ],
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    widget.label,
                    style: const TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.w900,
                      color: AppTheme.navyDark,
                      letterSpacing: 0.2,
                    ),
                  ),
                  const SizedBox(width: 8),
                  AppIcon(
                    widget.isFinal ? AppIcons.emojiEvents : AppIcons.arrowForwardIos,
                    size: 17,
                    color: AppTheme.navyDark,
                  ),
                ],
              ),
            ),
          ),
        ),
        const SizedBox(height: 10),
        ClipRRect(
          borderRadius: BorderRadius.circular(999),
          child: LinearProgressIndicator(
            value: widget.progress.clamp(0.0, 1.0),
            minHeight: 4,
            backgroundColor: Colors.white.withValues(alpha: 0.08),
            valueColor: AlwaysStoppedAnimation<Color>(
              AppTheme.gold.withValues(alpha: 0.85),
            ),
          ),
        ),
        const SizedBox(height: 6),
        Text(
          widget.secondsRemaining > 0
              ? 'تبدأ الجولة التالية تلقائياً خلال ${widget.secondsRemaining} ث'
              : 'جاري بدء الجولة التالية...',
          textAlign: TextAlign.center,
          style: AppFonts.cooper(
            color: AppTheme.steelBlue,
            fontSize: 12,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }
}

// ── Waiting-for-host state ───────────────────────────────────────────────
class _WaitingForHostChip extends StatefulWidget {
  final int secondsRemaining;
  final double progress;

  const _WaitingForHostChip({
    required this.secondsRemaining,
    required this.progress,
  });

  @override
  State<_WaitingForHostChip> createState() => _WaitingForHostChipState();
}

class _WaitingForHostChipState extends State<_WaitingForHostChip> with SingleTickerProviderStateMixin {
  late final AnimationController _dotsController;

  @override
  void initState() {
    super.initState();
    _dotsController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1100),
    )..repeat();
  }

  @override
  void dispose() {
    _dotsController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          padding: const EdgeInsets.symmetric(vertical: 15, horizontal: 16),
          decoration: BoxDecoration(
            color: AppTheme.navyDeep.withValues(alpha: 0.5),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: Colors.white24),
          ),
          child: Row(
            children: [
              AnimatedBuilder(
                animation: _dotsController,
                builder: (context, _) {
                  return Row(
                    mainAxisSize: MainAxisSize.min,
                    children: List.generate(3, (i) {
                      final t = ((_dotsController.value - i * 0.2) % 1.0 + 1.0) % 1.0;
                      final opacity = 0.25 + 0.75 * (1 - (t - 0.5).abs() * 2).clamp(0.0, 1.0);
                      return Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 2),
                        child: Container(
                          width: 6,
                          height: 6,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: AppTheme.gold.withValues(alpha: opacity),
                          ),
                        ),
                      );
                    }),
                  );
                },
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Text(
                  'في انتظار المضيف للانتقال للجولة التالية...',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: AppTheme.textSecondary),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 10),
        ClipRRect(
          borderRadius: BorderRadius.circular(999),
          child: LinearProgressIndicator(
            value: widget.progress.clamp(0.0, 1.0),
            minHeight: 4,
            backgroundColor: Colors.white.withValues(alpha: 0.08),
            valueColor: AlwaysStoppedAnimation<Color>(
              AppTheme.gold.withValues(alpha: 0.65),
            ),
          ),
        ),
        if (widget.secondsRemaining > 0) ...[
          const SizedBox(height: 6),
          Text(
            'يبدأ المضيف الجولة التالية خلال ${widget.secondsRemaining} ث',
            textAlign: TextAlign.center,
            style: AppFonts.cooper(
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
