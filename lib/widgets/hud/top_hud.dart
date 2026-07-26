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

class TopHud extends StatelessWidget {
  final GameState state;
  final VoidCallback onExitTap;

  const TopHud({super.key, required this.state, required this.onExitTap});

  // ── Data helpers ─────────────────────────────────────────────────────────

  String _phaseArabic() {
    switch (state.phase) {
      case GamePhase.voidCheck:
        return 'جاهزون ${state.voidCheckPassed.length}/4';
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
    if (total < 13) return _UnderOverData('أندر ${13 - total}', Colors.lightBlueAccent, Icons.keyboard_double_arrow_down_rounded);
    if (total > 13) return _UnderOverData('أوفر ${total - 13}', AppTheme.playerRed, Icons.keyboard_double_arrow_up_rounded);
    return _UnderOverData('مقفولة', AppTheme.cream, Icons.check_circle_outline_rounded);
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
            const SizedBox(width: 10),
            Expanded(child: _RoundPhaseCenter(state: state, phaseColor: phaseColor, phaseText: _phaseArabic())),
            const SizedBox(width: 10),
            if (state.trumpSuit != null)
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
        const SizedBox(width: 12),
        _RoundPhaseCenter(state: state, phaseColor: phaseColor, phaseText: _phaseArabic()),
        const Spacer(),
        if (bidderName != null) _BidderBadge(name: bidderName),
        if (bidderName != null && underOver != null) const SizedBox(width: 12),
        if (underOver != null) _UnderOverBadge(data: underOver),
        if (state.trumpSuit != null) ...[
          const SizedBox(width: 12),
          _TrumpBadge(state: state),
        ],
      ],
    );
  }
}

// ── Sub-components ────────────────────────────────────────────────────────

class _ExitButton extends StatelessWidget {
  final VoidCallback onTap;
  const _ExitButton({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: AppTheme.playerRed.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppTheme.playerRed.withValues(alpha: 0.3)),
        ),
        child: const Icon(Icons.exit_to_app_rounded,
            color: AppTheme.playerRed, size: 18),
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
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        // Round number
        AnimatedSwitcher(
          duration: const Duration(milliseconds: 400),
          child: RichText(
            key: ValueKey(state.roundNumber),
            textAlign: TextAlign.center,
            text: TextSpan(
              children: [
                TextSpan(
                  text: 'جولة ',
                  style: GoogleFonts.cairo(
                    color: AppTheme.steelBlue,
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                TextSpan(
                  text: '${state.roundNumber}',
                  style: GoogleFonts.cairo(
                    color: AppTheme.gold,
                    fontSize: 15,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 2),
        // Phase badge
        AnimatedSwitcher(
          duration: const Duration(milliseconds: 350),
          transitionBuilder: (child, anim) => FadeTransition(opacity: anim, child: child),
          child: Container(
            key: ValueKey(state.phase),
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
            decoration: BoxDecoration(
              color: phaseColor.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(6),
              border: Border.all(color: phaseColor.withValues(alpha: 0.35), width: 0.8),
            ),
            child: Text(
              phaseText,
              style: GoogleFonts.cairo(
                color: phaseColor,
                fontSize: 10,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
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
    final suit = state.trumpSuit!;
    final isRed = suit.color == SuitColor.red;
    final suitColor = isRed ? AppTheme.suitRed : AppTheme.steelBlue;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            suitColor.withValues(alpha: 0.18),
            suitColor.withValues(alpha: 0.08),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: suitColor.withValues(alpha: 0.4), width: 1.0),
        boxShadow: [
          BoxShadow(
            color: suitColor.withValues(alpha: 0.15),
            blurRadius: 8,
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            suit.label,
            style: TextStyle(
              fontSize: 16,
              color: suitColor,
              height: 1.0,
            ),
          ),
          Text(
            suit.arabicName,
            style: GoogleFonts.cairo(
              color: suitColor,
              fontSize: 8,
              fontWeight: FontWeight.w700,
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
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        const Icon(Icons.emoji_events_rounded, color: AppTheme.gold, size: 14),
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
    );
  }
}

class _UnderOverData {
  final String text;
  final Color color;
  final IconData icon;
  const _UnderOverData(this.text, this.color, this.icon);
}

class _UnderOverBadge extends StatelessWidget {
  final _UnderOverData data;
  const _UnderOverBadge({required this.data});

  @override
  Widget build(BuildContext context) {
    return Container(
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
            data.text,
            style: GoogleFonts.cairo(
              color: data.color,
              fontSize: 11,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}
