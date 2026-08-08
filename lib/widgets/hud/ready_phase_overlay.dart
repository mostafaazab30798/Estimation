// lib/widgets/hud/ready_phase_overlay.dart
//
// Premium void-check / ready-phase overlay — replaces the plain text
// info chip with a visual progress display and glass-styled prompt.

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../core/models/game_state.dart';
import '../../theme/app_theme.dart';

/// Overlay shown during [GamePhase.voidCheck].
/// Displays per-player ready dots and, when a void suit is declared,
/// shows the redeal prompt with premium glass buttons.
class ReadyPhaseOverlay extends StatelessWidget {
  final GameState state;
  final String? myPlayerId;
  final VoidCallback onApproveRedeal;
  final VoidCallback onRejectRedeal;

  const ReadyPhaseOverlay({
    super.key,
    required this.state,
    this.myPlayerId,
    required this.onApproveRedeal,
    required this.onRejectRedeal,
  });

  @override
  Widget build(BuildContext context) {
    if (state.voidDeclaringPlayerId != null) {
      return _buildVoidPrompt(context);
    }
    return _buildReadyPrompt(context);
  }

  // ── Ready waiting prompt ──────────────────────────────────────────────────

  Widget _buildReadyPrompt(BuildContext context) {
    final readyCount = state.voidCheckPassed.length;
    final totalCount = state.players.length;

    return Center(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
        decoration: AppTheme.glassDecoration(
          borderRadius: 24,
          borderColor: AppTheme.accentBlue.withValues(alpha: 0.35),
          fillColor: AppTheme.navyDark.withValues(alpha: 0.8),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 8,
                  height: 8,
                  decoration: const BoxDecoration(
                    color: Color(0xFF00E676),
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: Color(0xFF00E676),
                        blurRadius: 6,
                        spreadRadius: 1,
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  "انتظار اللاعبين ($readyCount/$totalCount)",
                  style: GoogleFonts.cairo(
                    color: AppTheme.cream,
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            // Ready progress pills
            Row(
              mainAxisSize: MainAxisSize.min,
              children: state.players.map((p) {
                final isReady = state.voidCheckPassed.contains(p.id);
                return Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 350),
                    curve: Curves.easeOutCubic,
                    width: isReady ? 14 : 9,
                    height: 9,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(5),
                      color: isReady
                          ? const Color(0xFF00E676)
                          : AppTheme.steelBlue.withValues(alpha: 0.3),
                      boxShadow: isReady
                          ? [
                              BoxShadow(
                                color: const Color(0xFF00E676)
                                    .withValues(alpha: 0.65),
                                blurRadius: 8,
                                spreadRadius: 1,
                              ),
                            ]
                          : null,
                    ),
                  ),
                );
              }).toList(),
            ),
            const SizedBox(height: 8),
            Text(
              "اضغط 'جاهز للعب' للبدء",
              style: GoogleFonts.cairo(
                color: AppTheme.steelBlue.withValues(alpha: 0.85),
                fontSize: 11,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── Void-suit redeal prompt ───────────────────────────────────────────────

  Widget _buildVoidPrompt(BuildContext context) {
    final declarer = state.playerById(state.voidDeclaringPlayerId!);
    final hasRejected = myPlayerId != null &&
        state.voidRedealRejections.contains(myPlayerId);

    return Center(
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 20),
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [Color(0xE62A4560), Color(0xE61D3348)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: AppTheme.warningGlow.withValues(alpha: 0.35),
            width: 1.2,
          ),
          boxShadow: [
            BoxShadow(
              color: AppTheme.warningGlow.withValues(alpha: 0.12),
              blurRadius: 24,
              spreadRadius: 2,
            ),
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.4),
              blurRadius: 16,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.warning_amber_rounded,
                color: AppTheme.warningGlow, size: 28),
            const SizedBox(height: 8),
            Text(
              '${declarer.name} لديه سويتة فاضية!',
              style: GoogleFonts.cairo(
                color: AppTheme.cream,
                fontSize: 13,
                fontWeight: FontWeight.w700,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 14),
            if (hasRejected)
              Text(
                'في انتظار باقي اللاعبين...',
                style: GoogleFonts.cairo(
                  color: AppTheme.steelBlue,
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                ),
              )
            else
              Wrap(
                alignment: WrapAlignment.center,
                spacing: 12,
                runSpacing: 8,
                children: [
                  _glassBtn(
                    label: 'إكمال اللعب',
                    color: AppTheme.steelBlue,
                    onTap: onRejectRedeal,
                  ),
                  _glassBtn(
                    label: 'إعادة التوزيع',
                    color: AppTheme.playerRed,
                    onTap: onApproveRedeal,
                  ),
                ],
              ),
          ],
        ),
      ),
    );
  }

  Widget _glassBtn({
    required String label,
    required Color color,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.15),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: color.withValues(alpha: 0.45), width: 1.0),
          boxShadow: [
            BoxShadow(color: color.withValues(alpha: 0.15), blurRadius: 8),
          ],
        ),
        child: Text(
          label,
          style: GoogleFonts.cairo(
            color: color,
            fontSize: 12,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
    );
  }
}
