import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../core/models/card.dart';
import '../theme/app_theme.dart';
import 'playing_card_widget.dart';

// Helper widget to display 4 cards of a trick
class TrickDisplay extends StatelessWidget {
  final List<TrickCard> trick;
  final double cardWidth;

  const TrickDisplay({super.key, required this.trick, this.cardWidth = 60});

  @override
  Widget build(BuildContext context) {
    if (trick.isEmpty) return const SizedBox();

    return Wrap(
      spacing: 8,
      runSpacing: 8,
      alignment: WrapAlignment.center,
      children: trick.map((tc) {
        return PlayingCardWidget(
          card: tc.card,
          width: cardWidth,
          playable: false,
        );
      }).toList(),
    );
  }
}

class TakenTricksDialog extends StatelessWidget {
  final List<List<TrickCard>> takenTricks;

  const TakenTricksDialog({super.key, required this.takenTricks});

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: AppTheme.navyDark,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: BorderSide(color: AppTheme.gold.withValues(alpha: 0.5), width: 1.5),
      ),
      child: Container(
        width: 400,
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'اللمّات التي أخذتها',
              style: GoogleFonts.cairo(
                fontSize: 22,
                fontWeight: FontWeight.bold,
                color: AppTheme.gold,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            if (takenTricks.isEmpty)
              Padding(
                padding: const EdgeInsets.all(32.0),
                child: Text(
                  'لم تأخذ أي لمّات حتى الآن',
                  style: GoogleFonts.cairo(
                    fontSize: 16,
                    color: AppTheme.textSecondary,
                  ),
                ),
              )
            else
              ConstrainedBox(
                constraints: BoxConstraints(
                  maxHeight: MediaQuery.of(context).size.height * 0.6,
                ),
                child: ListView.separated(
                  shrinkWrap: true,
                  physics: const BouncingScrollPhysics(),
                  itemCount: takenTricks.length,
                  separatorBuilder: (context, index) => const Divider(color: Colors.white24, height: 24),
                  itemBuilder: (context, index) {
                    final trick = takenTricks[index];
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'لمّة ${index + 1}',
                          style: GoogleFonts.cairo(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                            color: Colors.white,
                          ),
                        ),
                        const SizedBox(height: 8),
                        TrickDisplay(trick: trick),
                      ],
                    );
                  },
                ),
              ),
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: () => Navigator.of(context).pop(),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.white10,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 12),
              ),
              child: Text('إغلاق', style: GoogleFonts.cairo(fontWeight: FontWeight.bold)),
            ),
          ],
        ),
      ),
    );
  }
}

class LatestTrickDialog extends StatelessWidget {
  final List<TrickCard>? trick;
  final String playerName;

  const LatestTrickDialog({super.key, required this.trick, required this.playerName});

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: AppTheme.navyDark,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: BorderSide(color: Colors.white.withValues(alpha: 0.2), width: 1.5),
      ),
      child: Container(
        width: 350,
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'آخر لمّة ($playerName)',
              style: GoogleFonts.cairo(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 20),
            if (trick == null || trick!.isEmpty)
              Padding(
                padding: const EdgeInsets.all(24.0),
                child: Text(
                  'لم يأخذ أي لمّات حتى الآن',
                  style: GoogleFonts.cairo(
                    fontSize: 16,
                    color: AppTheme.textSecondary,
                  ),
                ),
              )
            else
              TrickDisplay(trick: trick!, cardWidth: 65),
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: () => Navigator.of(context).pop(),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.white10,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 12),
              ),
              child: Text('إغلاق', style: GoogleFonts.cairo(fontWeight: FontWeight.bold)),
            ),
          ],
        ),
      ),
    );
  }
}
