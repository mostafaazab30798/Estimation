// lib/screens/scoring_screen.dart
//
// End-of-round score display.

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../core/models/game_state.dart';
import '../core/widgets/player_avatar.dart';
import '../providers/game_provider.dart';
import '../theme/app_theme.dart';
import '../widgets/score_table.dart';
import '../widgets/performance_blur.dart';
import '../services/audio_service.dart';

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
  late final AnimationController _entrance;
  late final Animation<double> _headerFade;
  late final Animation<Offset> _headerSlide;
  late final Animation<double> _tableFade;
  late final Animation<double> _tableScale;

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

    _entrance.forward();

    final me = widget.provider.me;
    if (me != null) {
      final delta = widget.state.lastRoundScoreDeltas[me.id] ?? 0;
      if ((me.isRisk || me.isDashCall) && me.actual == me.declared) {
        AudioService.instance.playRiskWin();
      } else if (delta < 0) {
        AudioService.instance.playDefeat();
      }
    }
  }

  @override
  void dispose() {
    _entrance.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = widget.state;
    final provider = widget.provider;
    final isPortrait = MediaQuery.of(context).orientation == Orientation.portrait;

    final headerSection = SlideTransition(
      position: _headerSlide,
      child: FadeTransition(
        opacity: _headerFade,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Container(
                  padding: const EdgeInsets.all(9),
                  decoration: BoxDecoration(
                    color: AppTheme.gold.withValues(alpha: 0.15),
                    shape: BoxShape.circle,
                    border: Border.all(color: AppTheme.gold.withValues(alpha: 0.4)),
                  ),
                  child: const Icon(Icons.flag_circle_rounded, color: AppTheme.gold, size: 20),
                ),
                const SizedBox(width: 12),
                Text(
                  'الجولة ${state.roundNumber}',
                  style: GoogleFonts.cairo(
                    color: AppTheme.accentLight.withValues(alpha: 0.9),
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.4,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            ShaderMask(
              shaderCallback: (bounds) => const LinearGradient(
                colors: [AppTheme.gold, AppTheme.cardWhite, AppTheme.goldLight],
              ).createShader(bounds),
              child: Text(
                'نهاية الجولة',
                style: GoogleFonts.cairo(
                  fontSize: 34,
                  fontWeight: FontWeight.w900,
                  color: Colors.white,
                  height: 1.1,
                ),
              ),
            ),
            const SizedBox(height: 16),
            if (state.bidder != null) _buildBidderChip(state),
          ],
        ),
      ),
    );

    final scoreTableWidget = ScaleTransition(
      scale: _tableScale,
      child: FadeTransition(
        opacity: _tableFade,
        child: ScoreTable(
          players: [...state.players]..sort((a, b) => b.totalScore.compareTo(a.totalScore)),
          lastRoundDeltas: state.lastRoundScoreDeltas,
          bidderPlayerId: state.bidderPlayerId,
        ),
      ),
    );

    final actionSection = FadeTransition(
      opacity: _headerFade,
      child: provider.isHost
          ? _PrimaryActionButton(
              label: state.isMatchOver ? 'إنهاء اللعبة' : 'الجولة التالية',
              isFinal: state.isMatchOver,
              onPressed: () => provider.nextRound(),
            )
          : const _WaitingForHostChip(),
    );

    return Scaffold(
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
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: isPortrait
                  ? Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Expanded(
                          child: SingleChildScrollView(
                            physics: const BouncingScrollPhysics(),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                headerSection,
                                const SizedBox(height: 18),
                                scoreTableWidget,
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(height: 14),
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
                        Container(
                          width: 1.5,
                          margin: const EdgeInsets.symmetric(vertical: 24),
                          color: Colors.white.withValues(alpha: 0.12),
                        ),
                        const SizedBox(width: 24),
                        Expanded(
                          flex: 6,
                          child: Center(
                            child: SingleChildScrollView(
                              physics: const BouncingScrollPhysics(),
                              child: scoreTableWidget,
                            ),
                          ),
                        ),
                      ],
                    ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBidderChip(GameState state) {
    final bidder = state.bidder!;
    final bid = state.currentHighBid;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
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
                size: 42,
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
                    style: GoogleFonts.cairo(
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
                style: GoogleFonts.cairo(
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
                style: GoogleFonts.cairo(
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
  final VoidCallback onPressed;

  const _PrimaryActionButton({
    required this.label,
    required this.isFinal,
    required this.onPressed,
  });

  @override
  State<_PrimaryActionButton> createState() => _PrimaryActionButtonState();
}

class _PrimaryActionButtonState extends State<_PrimaryActionButton> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
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
              Icon(
                widget.isFinal ? Icons.emoji_events_rounded : Icons.arrow_back_ios_new_rounded,
                size: 17,
                color: AppTheme.navyDark,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Waiting-for-host state ───────────────────────────────────────────────
class _WaitingForHostChip extends StatefulWidget {
  const _WaitingForHostChip();

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
    return Container(
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
    );
  }
}