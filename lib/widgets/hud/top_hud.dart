// lib/widgets/hud/top_hud.dart
//
// Floating glass top HUD bar — replaces the original _buildTopBar.
// Preserves all existing data (round, phase, trump, bidder, under/over).
// Visual layout is completely redesigned into a premium floating glass panel.

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../core/models/game_state.dart';
import '../../core/constants.dart';
import '../../theme/app_theme.dart';
import '../performance_blur.dart';
import '../game_guide_dialog.dart';

class TopHud extends StatelessWidget {
  final GameState state;
  final VoidCallback onExitTap;

  const TopHud({super.key, required this.state, required this.onExitTap});

  // ── Data helpers ─────────────────────────────────────────────────────────

  String _phaseArabic() {
    switch (state.phase) {
      case GamePhase.voidCheck:
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
        icon: Icons.keyboard_double_arrow_down_rounded,
      );
    }
    if (total > 13) {
      return _UnderOverData(
        statusText: 'أوفر ${total - 13}',
        funnyText: 'هتتخانقو ⚔️',
        color: AppTheme.playerRed,
        icon: Icons.keyboard_double_arrow_up_rounded,
      );
    }
    return _UnderOverData(
      statusText: 'مقفولة 🎯',
      funnyText: null,
      color: AppTheme.cream,
      icon: Icons.check_circle_outline_rounded,
    );
  }

  // ── Build ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final isPortrait = MediaQuery.of(context).orientation == Orientation.portrait;
    final phaseColor = _phaseColor();
    final underOver = _underOverData();
    final bidderName = state.bidderPlayerId != null
        ? state.playerById(state.bidderPlayerId!).name
        : null;

    return PerformanceBlur(
      borderRadius: BorderRadius.circular(22),
      sigmaX: 14,
      sigmaY: 14,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 500),
        curve: Curves.easeOut,
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [Color(0xCC2A4560), Color(0xCC1D3348)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(22),
          border: Border.all(
            color: AppTheme.steelBlue.withValues(alpha: 0.15),
            width: 1.0,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.3),
              blurRadius: 20,
              offset: const Offset(0, 8),
            ),
            BoxShadow(
              color: phaseColor.withValues(alpha: 0.06),
              blurRadius: 24,
              spreadRadius: 2,
            ),
          ],
        ),
        child: isPortrait
            ? _buildPortrait(phaseColor, underOver, bidderName, context)
            : _buildLandscape(phaseColor, underOver, bidderName, context),
      ),
    );
  }

  Widget _buildPortrait(
    Color phaseColor,
    _UnderOverData? underOver,
    String? bidderName,
    BuildContext context,
  ) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          children: [
            _ExitButton(onTap: onExitTap),
            const SizedBox(width: 6),
            const _GuideButton(),
            const SizedBox(width: 10),
            Expanded(child: _RoundPhaseCenter(state: state, phaseColor: phaseColor, phaseText: _phaseArabic())),
            const SizedBox(width: 10),
            if (state.trump != null)
              _TrumpBadge(state: state)
            else
              const SizedBox(width: 40),
          ],
        ),
        if (bidderName != null || underOver != null) ...[
          const SizedBox(height: 8),
          Container(height: 1, color: AppTheme.steelBlue.withValues(alpha: 0.12)),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (bidderName != null) _BidderBadge(name: bidderName),
              if (bidderName != null && underOver != null) const SizedBox(width: 14),
              if (underOver != null) _UnderOverBadge(data: underOver),
            ],
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
    return Row(
      children: [
        _ExitButton(onTap: onExitTap),
        const SizedBox(width: 6),
        const _GuideButton(),
        const SizedBox(width: 12),
        _RoundPhaseCenter(state: state, phaseColor: phaseColor, phaseText: _phaseArabic()),
        if (state.trump != null) ...[
          const SizedBox(width: 12),
          _TrumpBadge(state: state),
        ],
        const Spacer(),
        if (bidderName != null) ...[
          _BidderBadge(name: bidderName),
          const SizedBox(width: 10),
        ],
        if (underOver != null) _UnderOverBadge(data: underOver),
      ],
    );
  }
}

// ── Supporting Badges ──────────────────────────────────────────────────────

class _ExitButton extends StatelessWidget {
  final VoidCallback onTap;
  const _ExitButton({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.all(7),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.06),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.white.withValues(alpha: 0.12)),
          ),
          child: const Icon(Icons.arrow_back_rounded, color: AppTheme.cream, size: 18),
        ),
      ),
    );
  }
}

class _GuideButton extends StatelessWidget {
  const _GuideButton();

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () => GameGuideDialog.show(context),
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.all(7),
          decoration: BoxDecoration(
            color: AppTheme.mintSoft.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: AppTheme.mintSoft.withValues(alpha: 0.3)),
          ),
          child: const Icon(Icons.help_outline_rounded, color: AppTheme.mintSoft, size: 18),
        ),
      ),
    );
  }
}

class _RoundPhaseCenter extends StatelessWidget {
  final GameState state;
  final Color phaseColor;
  final String phaseText;

  const _RoundPhaseCenter({
    required this.state,
    required this.phaseColor,
    required this.phaseText,
  });

  @override
  Widget build(BuildContext context) {
    final isFixedRound = state.roundNumber >= 14 && state.roundNumber <= 18;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'الجولة ${state.roundNumber}',
              style: GoogleFonts.cairo(
                color: AppTheme.gold,
                fontSize: 13.5,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(width: 6),
            if (isFixedRound) ...[
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: const Color(0xFFD97706).withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(color: const Color(0xFFF59E0B).withValues(alpha: 0.6)),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text('🔒', style: TextStyle(fontSize: 10)),
                    const SizedBox(width: 3),
                    Text(
                      'ثابت',
                      style: GoogleFonts.cairo(
                        color: const Color(0xFFFDE68A),
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 6),
            ],
            if (state.isDoubleRound) ...[
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: AppTheme.suitRed.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(color: AppTheme.suitRed.withValues(alpha: 0.6)),
                ),
                child: Text(
                  '🔥 x2',
                  style: GoogleFonts.cairo(
                    color: const Color(0xFFFF8A80),
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              const SizedBox(width: 6),
            ],
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(
                color: phaseColor.withValues(alpha: 0.16),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: phaseColor.withValues(alpha: 0.4)),
              ),
              child: Text(
                phaseText,
                style: GoogleFonts.cairo(
                  color: phaseColor,
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _TrumpBadge extends StatelessWidget {
  final GameState state;
  const _TrumpBadge({required this.state});

  @override
  Widget build(BuildContext context) {
    if (state.trump == Trump.sans) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
        decoration: BoxDecoration(
          color: const Color(0xFF4C1D95).withValues(alpha: 0.35),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: const Color(0xFFA78BFA).withValues(alpha: 0.5)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('🚫', style: TextStyle(fontSize: 13)),
            const SizedBox(width: 4),
            Text(
              'سانز',
              style: GoogleFonts.cairo(
                color: const Color(0xFFDDD6FE),
                fontSize: 11.5,
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
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
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
              fontSize: 15,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(width: 4),
          Text(
            suit.arabicName,
            style: GoogleFonts.cairo(
              color: AppTheme.cream,
              fontSize: 11.5,
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
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: AppTheme.gold.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppTheme.gold.withValues(alpha: 0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text('👑', style: TextStyle(fontSize: 11)),
          const SizedBox(width: 4),
          Text(
            name,
            style: GoogleFonts.cairo(
              color: AppTheme.gold,
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
  final IconData icon;

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
        // Primary Under/Over Container
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(
            color: data.color.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: data.color.withValues(alpha: 0.35)),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(data.icon, color: data.color, size: 13),
              const SizedBox(width: 4),
              Text(
                data.statusText,
                style: GoogleFonts.cairo(
                  color: data.color,
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ),
        // Separate Funny Text Container
        if (data.funnyText != null) ...[
          const SizedBox(width: 6),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: data.color.withValues(alpha: 0.22),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: data.color.withValues(alpha: 0.5), width: 1),
            ),
            child: Text(
              data.funnyText!,
              style: GoogleFonts.cairo(
                color: Colors.white,
                fontSize: 11,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ],
    );
  }
}
