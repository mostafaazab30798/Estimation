// lib/widgets/hud/top_hud.dart
//
// Floating glass top HUD bar — replaces the original _buildTopBar.
// Preserves all existing data (round, phase, trump, bidder, under/over).
// Visual layout is completely redesigned into a premium floating glass panel.

import 'package:flutter/material.dart';
import '../../core/utils/game_layout_metrics.dart';
import '../../core/models/game_state.dart';
import '../../core/constants.dart';
import '../../core/widgets/app_buttons.dart';
import '../../theme/app_theme.dart';
import '../performance_blur.dart';
import '../game_guide_dialog.dart';
import '../settings_dialog.dart';
import '../round_scores_dialog.dart';
import 'split_hud_panel.dart';
import 'package:estimation/core/icons/app_icons.dart';

class TopHud extends StatelessWidget {
  final GameState state;
  final VoidCallback onExitTap;

  const TopHud({super.key, required this.state, required this.onExitTap});

  // ── Data helpers ─────────────────────────────────────────────────────────

  String _phaseArabic() {
    switch (state.phase) {
      case GamePhase.voidCheck:
        if (state.voidDeclaringPlayerId != null) {
          return 'سويتة فاضية ${state.voidRedealRejections.length}/${state.players.length}';
        }
        return 'جاهزون ${state.voidCheckPassed.length}/${state.players.length}';
      case GamePhase.dashCall:
        return 'داش كول';
      case GamePhase.auction:
        return 'المزاد';
      case GamePhase.declarations:
        return 'التصريح';
      case GamePhase.trickTaking:
        return 'اللعب';
      case GamePhase.scoring:
        return 'النتائج';
      default:
        return '';
    }
  }

  Color _phaseColor() {
    switch (state.phase) {
      case GamePhase.voidCheck:
        return AppTheme.phaseReady;
      case GamePhase.dashCall:
        return Colors.orangeAccent;
      case GamePhase.auction:
        return AppTheme.phaseAuction;
      case GamePhase.declarations:
        return AppTheme.phaseDeclarations;
      case GamePhase.trickTaking:
        return AppTheme.phasePlay;
      case GamePhase.scoring:
        return AppTheme.phaseScoring;
      default:
        return AppTheme.steelBlue;
    }
  }

  _UnderOverData? _underOverData() {
    if (state.phase != GamePhase.trickTaking) return null;
    int total = 0, declarers = 0;
    for (final p in state.players) {
      if (p.declared != null) {
        total += p.declared!;
        declarers++;
      }
    }
    if (declarers != 4) return null;
    if (total < 13) {
      return _UnderOverData(
        statusText: 'أندر ${13 - total}',
        funnyText: 'هتلبسو بعض 💀',
        color: Colors.lightBlueAccent,
        icon: AppIcons.keyboardDoubleArrowDown,
      );
    }
    if (total > 13) {
      return _UnderOverData(
        statusText: 'أوفر ${total - 13}',
        funnyText: 'هتتخانقو ⚔️',
        color: AppTheme.playerRed,
        icon: AppIcons.keyboardDoubleArrowUp,
      );
    }
    return _UnderOverData(
      statusText: 'مقفولة 🎯',
      funnyText: null,
      color: AppTheme.cream,
      icon: AppIcons.checkCircleOutline,
    );
  }

  // ── Build ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final layout = GameLayoutMetrics.of(context);
        final useSplitHud = layout.shouldUseSplitHud(constraints.maxWidth);
        final isPortrait = layout.isPortrait;
        final phaseColor = _phaseColor();
        final underOver = _underOverData();
        final bidderName = state.bidderPlayerId != null
            ? state.playerById(state.bidderPlayerId!).name
            : null;

        if (useSplitHud) {
          return _buildTabletSplit(
            phaseColor: phaseColor,
            underOver: underOver,
            bidderName: bidderName,
            layout: layout,
          );
        }

        return PerformanceBlur(
      borderRadius: BorderRadius.circular(24),
      sigmaX: 16,
      sigmaY: 16,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 500),
        curve: Curves.easeOut,
        padding: EdgeInsets.symmetric(
          horizontal: isPortrait ? 12 : 14,
          vertical: isPortrait ? 9 : 10,
        ),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [
              const Color(0xD22F4A64),
              const Color(0xD21A3044),
              phaseColor.withValues(alpha: 0.08),
            ],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            stops: const [0.0, 0.65, 1.0],
          ),
          borderRadius: BorderRadius.circular(24),
          border: Border.all(
            color: AppTheme.cream.withValues(alpha: 0.10),
            width: 1.0,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.38),
              blurRadius: 24,
              offset: const Offset(0, 10),
            ),
            BoxShadow(
              color: phaseColor.withValues(alpha: 0.10),
              blurRadius: 28,
              spreadRadius: 1,
            ),
          ],
        ),
        child: isPortrait
            ? _buildPortrait(phaseColor, underOver, bidderName, context)
            : _buildLandscape(phaseColor, underOver, bidderName, context),
      ),
    );
      },
    );
  }

  Widget _buildPortrait(
    Color phaseColor,
    _UnderOverData? underOver,
    String? bidderName,
    BuildContext context,
  ) {
    final isFixedRound = state.isFixedTrumpRound;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          children: [
            _ExitButton(onTap: onExitTap),
            const SizedBox(width: 4),
            _ScoresButton(state: state),
            const SizedBox(width: 4),
            const _GuideButton(),
            const SizedBox(width: 4),
            const _SettingsButton(),
            const SizedBox(width: 8),
            Expanded(
              child: FittedBox(
                fit: BoxFit.scaleDown,
                alignment: Alignment.center,
                child: _RoundPhaseCenter(
                  state: state,
                  phaseColor: phaseColor,
                  phaseText: _phaseArabic(),
                  isFixedRound: isFixedRound,
                ),
              ),
            ),
            if (state.trump != null) ...[
              const SizedBox(width: 6),
              Flexible(
                flex: 0,
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.centerRight,
                  child: _TrumpBadge(state: state, isFixedRound: isFixedRound),
                ),
              ),
            ],
          ],
        ),
        if (bidderName != null || underOver != null) ...[
          const SizedBox(height: 7),
          Container(
            height: 1,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  Colors.transparent,
                  AppTheme.cream.withValues(alpha: 0.12),
                  Colors.transparent,
                ],
              ),
            ),
          ),
          const SizedBox(height: 7),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.center,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                if (bidderName != null) _BidderBadge(name: bidderName),
                if (bidderName != null && underOver != null) const SizedBox(width: 10),
                if (underOver != null) _UnderOverBadge(data: underOver),
              ],
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildLandscape(
    Color phaseColor,
    _UnderOverData? underOver,
    String? bidderName,
    BuildContext context,
  ) {
    final isFixedRound = state.isFixedTrumpRound;
    return Row(
      children: [
        _ExitButton(onTap: onExitTap),
        const SizedBox(width: 6),
        _ScoresButton(state: state),
        const SizedBox(width: 6),
        const _GuideButton(),
        const SizedBox(width: 6),
        const _SettingsButton(),
        const SizedBox(width: 10),
        Flexible(
          child: FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: _RoundPhaseCenter(
              state: state,
              phaseColor: phaseColor,
              phaseText: _phaseArabic(),
              isFixedRound: isFixedRound,
            ),
          ),
        ),
        if (state.trump != null) ...[
          const SizedBox(width: 8),
          _TrumpBadge(state: state, isFixedRound: isFixedRound),
        ],
        const Spacer(),
        if (bidderName != null) ...[
          Flexible(
            child: FittedBox(
              fit: BoxFit.scaleDown,
              child: _BidderBadge(name: bidderName),
            ),
          ),
          const SizedBox(width: 8),
        ],
        if (underOver != null)
          Flexible(
            child: FittedBox(
              fit: BoxFit.scaleDown,
              child: _UnderOverBadge(data: underOver),
            ),
          ),
      ],
    );
  }

  Widget _buildTabletSplit({
    required Color phaseColor,
    required _UnderOverData? underOver,
    required String? bidderName,
    required GameLayoutMetrics layout,
  }) {
    final isFixedRound = state.isFixedTrumpRound;
    final iconGap = layout.screenSize == GameScreenSize.largeTablet ? 8.0 : 6.0;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SplitHudPanel(
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              _ExitButton(onTap: onExitTap),
              SizedBox(width: iconGap),
              _ScoresButton(state: state),
              SizedBox(width: iconGap),
              const _GuideButton(),
              SizedBox(width: iconGap),
              const _SettingsButton(),
            ],
          ),
        ),
        const Expanded(child: SizedBox.shrink()),
        SplitHudPanel(
          glowColor: phaseColor,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 11),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              _RoundPhaseCenter(
                state: state,
                phaseColor: phaseColor,
                phaseText: _phaseArabic(),
                isFixedRound: isFixedRound,
                enlarged: true,
              ),
              if (state.trump != null) ...[
                const SizedBox(height: 8),
                _TrumpBadge(state: state, isFixedRound: isFixedRound),
              ],
              if (bidderName != null || underOver != null) ...[
                const SizedBox(height: 8),
                Wrap(
                  alignment: WrapAlignment.end,
                  spacing: 8,
                  runSpacing: 6,
                  children: [
                    if (bidderName != null) _BidderBadge(name: bidderName),
                    if (underOver != null) _UnderOverBadge(data: underOver),
                  ],
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }
}

// ── Supporting Badges ──────────────────────────────────────────────────────

class _HudIconButton extends StatelessWidget {
  final VoidCallback onTap;
  final AppIconData icon;
  final Color accent;

  const _HudIconButton({
    required this.onTap,
    required this.icon,
    required this.accent,
  });

  @override
  Widget build(BuildContext context) {
    return AppIconButton(
      icon: icon,
      onTap: onTap,
      color: accent,
      size: AppIconButtonSize.sm,
    );
  }
}

class _ScoresButton extends StatelessWidget {
  final GameState state;
  const _ScoresButton({required this.state});

  @override
  Widget build(BuildContext context) {
    return _HudIconButton(
      onTap: () => RoundScoresDialog.show(context, state),
      icon: AppIcons.leaderboard,
      accent: AppTheme.accentLight,
    );
  }
}

class _ExitButton extends StatelessWidget {
  final VoidCallback onTap;
  const _ExitButton({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return _HudIconButton(
      onTap: onTap,
      icon: AppIcons.arrowBack,
      accent: AppTheme.cream,
    );
  }
}

class _GuideButton extends StatelessWidget {
  const _GuideButton();

  @override
  Widget build(BuildContext context) {
    return _HudIconButton(
      onTap: () => GameGuideDialog.show(context),
      icon: AppIcons.helpOutline,
      accent: AppTheme.mintSoft,
    );
  }
}

class _SettingsButton extends StatelessWidget {
  const _SettingsButton();

  @override
  Widget build(BuildContext context) {
    return _HudIconButton(
      onTap: () => SettingsDialog.show(context),
      icon: AppIcons.settingsOutlined,
      accent: AppTheme.gold,
    );
  }
}

class _RoundPhaseCenter extends StatelessWidget {
  final GameState state;
  final Color phaseColor;
  final String phaseText;
  final bool isFixedRound;
  final bool enlarged;

  const _RoundPhaseCenter({
    required this.state,
    required this.phaseColor,
    required this.phaseText,
    this.isFixedRound = false,
    this.enlarged = false,
  });

  @override
  Widget build(BuildContext context) {
    final roundSize = enlarged ? 16.0 : 13.5;
    final phaseSize = enlarged ? 12.0 : 10.5;
    final phasePadH = enlarged ? 10.0 : 8.0;
    final phasePadV = enlarged ? 4.0 : 3.0;

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          'الجولة ${state.roundNumber}',
          style: AppFonts.cooper(
            color: AppTheme.goldLight,
            fontSize: roundSize,
            fontWeight: FontWeight.w800,
            letterSpacing: 0.2,
          ),
        ),
        if (state.isDoubleRound) ...[
          SizedBox(width: enlarged ? 7 : 5),
          const _DoubleRoundBadge(),
        ],
        SizedBox(width: enlarged ? 8 : 6),
        Container(
          padding: EdgeInsets.symmetric(horizontal: phasePadH, vertical: phasePadV),
          decoration: BoxDecoration(
            color: phaseColor.withValues(alpha: 0.14),
            borderRadius: BorderRadius.circular(999),
            border: Border.all(color: phaseColor.withValues(alpha: 0.38)),
          ),
          child: Text(
            phaseText,
            style: AppFonts.cooper(
              color: phaseColor,
              fontSize: phaseSize,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
      ],
    );
  }
}

class _TrumpBadge extends StatelessWidget {
  final GameState state;
  final bool isFixedRound;
  const _TrumpBadge({required this.state, this.isFixedRound = false});

  @override
  Widget build(BuildContext context) {
    if (isFixedRound && state.fixedTrump != null) {
      return _FixedTrumpBadge(
        roundNumber: state.roundNumber,
        fixedTrump: state.fixedTrump!,
      );
    }

    if (state.trump == Trump.sans) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
        decoration: BoxDecoration(
          color: const Color(0xFF4C1D95).withValues(alpha: 0.35),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: const Color(0xFFA78BFA).withValues(alpha: 0.5)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('🚫', style: TextStyle(fontSize: 12)),
            const SizedBox(width: 4),
            Text(
              'سانز',
              style: AppFonts.cooper(
                color: const Color(0xFFDDD6FE),
                fontSize: 11,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
      );
    }

    final suit = state.trumpSuit;
    if (suit == null) return const SizedBox.shrink();

    final isRed = suit.color == SuitColor.red;
    final suitColor = isRed ? AppTheme.suitRed : AppTheme.steelBlue;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: AppTheme.navyDark.withValues(alpha: 0.7),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: suitColor.withValues(alpha: 0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            suit.label,
            style: TextStyle(
              color: suitColor,
              fontSize: 14,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(width: 4),
          Text(
            suit.arabicName,
            style: AppFonts.cooper(
              color: AppTheme.cream,
              fontSize: 11,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

class _BidderBadge extends StatelessWidget {
  final String name;
  const _BidderBadge({required this.name});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
      decoration: BoxDecoration(
        color: AppTheme.gold.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: AppTheme.gold.withValues(alpha: 0.32)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text('👑', style: TextStyle(fontSize: 11)),
          const SizedBox(width: 4),
          Text(
            name,
            style: AppFonts.cooper(
              color: AppTheme.goldLight,
              fontSize: 11,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

class _UnderOverData {
  final String statusText;
  final String? funnyText;
  final Color color;
  final AppIconData icon;

  const _UnderOverData({
    required this.statusText,
    this.funnyText,
    required this.color,
    required this.icon,
  });
}

class _UnderOverBadge extends StatelessWidget {
  final _UnderOverData data;
  const _UnderOverBadge({required this.data});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
          decoration: BoxDecoration(
            color: data.color.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(999),
            border: Border.all(color: data.color.withValues(alpha: 0.35)),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              AppIcon(data.icon, color: data.color, size: 13),
              const SizedBox(width: 4),
              Text(
                data.statusText,
                style: AppFonts.cooper(
                  color: data.color,
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ),
        if (data.funnyText != null) ...[
          const SizedBox(width: 6),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
            decoration: BoxDecoration(
              color: data.color.withValues(alpha: 0.20),
              borderRadius: BorderRadius.circular(999),
              border: Border.all(color: data.color.withValues(alpha: 0.45)),
            ),
            child: Text(
              data.funnyText!,
              style: AppFonts.cooper(
                color: Colors.white,
                fontSize: 11,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ],
    );
  }
}

class _DoubleRoundBadge extends StatefulWidget {
  const _DoubleRoundBadge();

  @override
  State<_DoubleRoundBadge> createState() => _DoubleRoundBadgeState();
}

class _DoubleRoundBadgeState extends State<_DoubleRoundBadge>
    with SingleTickerProviderStateMixin {
  late final AnimationController _pulse;
  late final Animation<double> _glow;

  @override
  void initState() {
    super.initState();
    _pulse = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    )..repeat(reverse: true);
    _glow = Tween<double>(begin: 0.4, end: 1.0).animate(
      CurvedAnimation(parent: _pulse, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _pulse.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _glow,
      builder: (context, _) {
        final glowVal = _glow.value;
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                const Color(0xFFFF9100).withValues(alpha: 0.25 + 0.15 * glowVal),
                const Color(0xFFFFD700).withValues(alpha: 0.20 + 0.10 * glowVal),
              ],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: const Color(0xFFFFD700).withValues(alpha: 0.6 + 0.4 * glowVal),
              width: 1.2,
            ),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFFFF9100).withValues(alpha: 0.3 * glowVal),
                blurRadius: 10 * glowVal,
                spreadRadius: 1 * glowVal,
              ),
            ],
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('⚡', style: TextStyle(fontSize: 10)),
              const SizedBox(width: 3),
              Text(
                '×2 ROUND',
                style: AppFonts.cooper(
                  color: const Color(0xFFFFD54F),
                  fontSize: 10,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 0.5,
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _FixedTrumpBadge extends StatelessWidget {
  final int roundNumber;
  final Trump fixedTrump;

  const _FixedTrumpBadge({required this.roundNumber, required this.fixedTrump});

  String _suitSymbol() {
    switch (fixedTrump) {
      case Trump.sans:
        return '♟';
      case Trump.spade:
        return '♠';
      case Trump.heart:
        return '♥';
      case Trump.diamond:
        return '♦';
      case Trump.club:
        return '♣';
    }
  }

  String _nameEn() {
    switch (fixedTrump) {
      case Trump.sans:
        return 'SANS';
      case Trump.spade:
        return 'SPADE';
      case Trump.heart:
        return 'HEART';
      case Trump.diamond:
        return 'DIAMOND';
      case Trump.club:
        return 'CLUB';
    }
  }

  @override
  Widget build(BuildContext context) {
    final isSans = fixedTrump == Trump.sans;
    final isRed = fixedTrump.color == SuitColor.red;
    final borderColor = isSans
        ? const Color(0xFFA855F7)
        : (isRed ? const Color(0xFFF43F5E) : const Color(0xFF38BDF8));

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
      decoration: BoxDecoration(
        color: borderColor.withValues(alpha: 0.18),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: borderColor.withValues(alpha: 0.65), width: 1.1),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text('🔒', style: TextStyle(fontSize: 10)),
          const SizedBox(width: 3),
          Text(
            '${_suitSymbol()} ${_nameEn()}',
            style: AppFonts.cinzel(
              color: Colors.white,
              fontSize: 10,
              fontWeight: FontWeight.w900,
              letterSpacing: 0.5,
            ),
          ),
        ],
      ),
    );
  }
}
