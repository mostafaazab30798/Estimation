// lib/widgets/bid_dialog.dart
//
// Arabic bidding dialog shown during the auction phase.

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../core/constants.dart';
import '../core/models/bid.dart';
import '../theme/app_theme.dart';
import 'hud/gameplay_dialog_shell.dart';
import 'hud/turn_timer_badge.dart';

class BidDialog extends StatefulWidget {
  final Bid? currentHighBid;
  final String? bidderName;
  final Trump? fixedTrump;
  final int roundNumber;
  final bool isDoubleRound;
  final int? deadlineEpochMs;
  final int? durationSeconds;
  final void Function(Bid bid) onBid;
  final VoidCallback onPass;

  const BidDialog({
    super.key,
    this.currentHighBid,
    this.bidderName,
    this.fixedTrump,
    this.roundNumber = 1,
    this.isDoubleRound = false,
    this.deadlineEpochMs,
    this.durationSeconds,
    required this.onBid,
    required this.onPass,
  });

  @override
  State<BidDialog> createState() => _BidDialogState();
}

class _BidDialogState extends State<BidDialog> {
  late final _trickCount = ValueNotifier<int>(4);
  late final _trump = ValueNotifier<Trump>(Trump.spade);

  bool _isValidFor(int count, Trump trump) {
    final bid = Bid(trickCount: count, trump: trump);
    if (widget.fixedTrump != null) {
      if (trump != widget.fixedTrump && count < kOverrideFixedTrumpTricks) {
        return false;
      }
    }
    if (widget.currentHighBid == null) return count >= kMinBidTricks;
    return bid.beats(widget.currentHighBid!);
  }

  String _fixedTrumpTitle(Trump trump) {
    switch (trump) {
      case Trump.sans:
        return 'SANS ROUND';
      case Trump.spade:
        return 'SPADE ROUND';
      case Trump.heart:
        return 'HEART ROUND';
      case Trump.diamond:
        return 'DIAMOND ROUND';
      case Trump.club:
        return 'CLUB ROUND';
    }
  }

  @override
  void initState() {
    super.initState();
    if (widget.fixedTrump != null) {
      _trump.value = widget.fixedTrump!;
      _trickCount.value = (widget.currentHighBid != null)
          ? (widget.currentHighBid!.trickCount + 1).clamp(4, 13)
          : 4;
    } else if (widget.currentHighBid != null) {
      int tc = widget.currentHighBid!.trickCount;
      Trump t = Trump.values[
          (widget.currentHighBid!.trump.priority + 1) % Trump.values.length];
      if (t.priority <= widget.currentHighBid!.trump.priority) {
        tc++;
      }
      _trickCount.value = tc.clamp(4, 13);
      _trump.value = t;
    } else {
      _trickCount.value = 4;
      _trump.value = Trump.spade;
    }
  }

  @override
  void dispose() {
    _trickCount.dispose();
    _trump.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isPortrait = MediaQuery.of(context).orientation == Orientation.portrait;

    return ValueListenableBuilder<int>(
      valueListenable: _trickCount,
      builder: (context, count, _) {
        return ValueListenableBuilder<Trump>(
          valueListenable: _trump,
          builder: (context, trump, _) {
            final isValid = _isValidFor(count, trump);

            return GameplayDialogShell(
              maxWidth: GameplayDialogShell.widthFor(context),
              scrollable: true,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            'المزاد',
                            style: GoogleFonts.cairo(
                              color: AppTheme.cream,
                              fontSize: 20,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                          const SizedBox(width: 10),
                          TurnTimerBadge(
                            customPhaseLabel: 'AUCTION',
                            explicitDurationSeconds: widget.durationSeconds ?? 15,
                            explicitDeadlineEpochMs: widget.deadlineEpochMs,
                            isMyTurn: true,
                            compact: true,
                          ),
                        ],
                      ),
                      if (widget.currentHighBid != null)
                        Flexible(
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                            decoration: BoxDecoration(
                              color: AppTheme.gold.withValues(alpha: 0.12),
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(color: AppTheme.gold.withValues(alpha: 0.38)),
                            ),
                            child: Text(
                              'أعلى: ${widget.currentHighBid!.arabicLabel}${widget.bidderName != null ? ' (${widget.bidderName})' : ''}',
                              style: GoogleFonts.cairo(
                                color: AppTheme.gold,
                                fontWeight: FontWeight.w800,
                                fontSize: 12,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ),
                    ],
                  ),
                      if (widget.isDoubleRound) ...[
                        const SizedBox(height: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              colors: [
                                const Color(0xFFFF9100).withValues(alpha: 0.25),
                                const Color(0xFFFFD700).withValues(alpha: 0.15),
                              ],
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                            ),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: const Color(0xFFFFD700).withValues(alpha: 0.6),
                              width: 1.2,
                            ),
                          ),
                          child: const Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Text('⚡', style: TextStyle(fontSize: 13)),
                              SizedBox(width: 6),
                              Flexible(
                                child: Text(
                                  'جولة مضاعفة (⚡ ×2 ROUND) — النقاط مضاعفة',
                                  style: TextStyle(
                                    color: Color(0xFFFFD54F),
                                    fontWeight: FontWeight.bold,
                                    fontSize: 12,
                                  ),
                                  textAlign: TextAlign.center,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                      if (widget.fixedTrump != null) ...[
                        const SizedBox(height: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              colors: [
                                const Color(0xFF1E293B).withValues(alpha: 0.8),
                                const Color(0xFF0F172A).withValues(alpha: 0.9),
                              ],
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                            ),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: const Color(0xFFF59E0B).withValues(alpha: 0.6),
                              width: 1.2,
                            ),
                          ),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  const Text('👑', style: TextStyle(fontSize: 12)),
                                  const SizedBox(width: 5),
                                  Text(
                                    'ROUND ${widget.roundNumber} • ${_fixedTrumpTitle(widget.fixedTrump!)}',
                                    style: const TextStyle(
                                      color: Color(0xFFFFD700),
                                      fontWeight: FontWeight.w900,
                                      fontSize: 11.5,
                                      letterSpacing: 0.8,
                                    ),
                                  ),
                                  const SizedBox(width: 5),
                                  const Text('🔒', style: TextStyle(fontSize: 11)),
                                ],
                              ),
                              const SizedBox(height: 2),
                              Text(
                                'Trump is fixed to ${widget.fixedTrump!.name.toUpperCase()}. Bid 8+ to override.',
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.w700,
                                  fontSize: 11,
                                ),
                                textAlign: TextAlign.center,
                              ),
                              Text(
                                'الحكم إجباري: ${widget.fixedTrump!.arabicName} (اطلب ٨ لمات أو أكثر لتغيير الحكم)',
                                style: const TextStyle(
                                  color: Color(0xFFFDE68A),
                                  fontWeight: FontWeight.w600,
                                  fontSize: 10.5,
                                ),
                                textAlign: TextAlign.center,
                              ),
                            ],
                          ),
                        ),
                      ],
                      const SizedBox(height: 14),

                      // Content Layout
                      if (isPortrait) ...[
                        Text(
                          'عدد اللمات',
                          style: GoogleFonts.cairo(
                            color: AppTheme.steelBlue,
                            fontWeight: FontWeight.w600,
                            fontSize: 13,
                          ),
                        ),
                        const SizedBox(height: 8),
                        _TrickCountSelector(
                          value: count,
                          onChanged: (v) => _trickCount.value = v,
                        ),
                        const SizedBox(height: 14),
                        Text(
                          'نوع الحكم / القطوع',
                          style: GoogleFonts.cairo(
                            color: AppTheme.steelBlue,
                            fontWeight: FontWeight.w600,
                            fontSize: 13,
                          ),
                        ),
                        const SizedBox(height: 8),
                        _TrumpSelector(
                          selected: trump,
                          fixedTrump: widget.fixedTrump,
                          currentTrickCount: count,
                          onChanged: (t) => _trump.value = t,
                        ),
                      ] else
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(
                              flex: 6,
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'عدد اللمات',
                                    style: GoogleFonts.cairo(
                                      color: AppTheme.steelBlue,
                                      fontWeight: FontWeight.w600,
                                      fontSize: 13,
                                    ),
                                  ),
                                  const SizedBox(height: 8),
                                  _TrickCountSelector(
                                    value: count,
                                    onChanged: (v) => _trickCount.value = v,
                                  ),
                                ],
                              ),
                            ),
                            Container(
                              width: 1,
                              height: 90,
                              margin: const EdgeInsets.symmetric(horizontal: 12),
                              color: Colors.white12,
                            ),
                            Expanded(
                              flex: 5,
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'نوع الحكم / القطوع',
                                    style: GoogleFonts.cairo(
                                      color: AppTheme.steelBlue,
                                      fontWeight: FontWeight.w600,
                                      fontSize: 13,
                                    ),
                                  ),
                                  const SizedBox(height: 8),
                                  _TrumpSelector(
                                    selected: trump,
                                    fixedTrump: widget.fixedTrump,
                                    currentTrickCount: count,
                                    onChanged: (t) => _trump.value = t,
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),

                      const SizedBox(height: 18),

                      // Actions
                      Row(
                        children: [
                          Expanded(
                            child: OutlinedButton(
                              style: OutlinedButton.styleFrom(
                                padding: const EdgeInsets.symmetric(vertical: 13),
                                side: BorderSide(color: AppTheme.errorRed.withValues(alpha: 0.45), width: 1.5),
                                foregroundColor: AppTheme.errorRed,
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                              ),
                              onPressed: () {
                                Navigator.of(context).pop();
                                widget.onPass();
                              },
                              child: const Text('باس (Pass)', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: FilledButton(
                              style: FilledButton.styleFrom(
                                padding: const EdgeInsets.symmetric(vertical: 13),
                                backgroundColor: AppTheme.gold,
                                foregroundColor: AppTheme.navyDark,
                                disabledBackgroundColor: AppTheme.gold.withValues(alpha: 0.35),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                                elevation: 0,
                              ),
                              onPressed: isValid
                                  ? () {
                                      Navigator.of(context).pop();
                                      widget.onBid(Bid(trickCount: count, trump: trump));
                                    }
                                  : null,
                              child: const Text('مزايدة (Bid)', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
            );
          },
        );
      },
    );
  }
}

class _TrickCountSelector extends StatelessWidget {
  final int value;
  final void Function(int) onChanged;

  const _TrickCountSelector({required this.value, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 6,
      runSpacing: 6,
      alignment: WrapAlignment.start,
      children: [
        for (int i = 4; i <= 13; i++)
          GestureDetector(
            onTap: () => onChanged(i),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 120),
              width: 38,
              height: 38,
              decoration: BoxDecoration(
                color: value == i ? AppTheme.gold : AppTheme.surfaceCard,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                  color: value == i ? AppTheme.gold : Colors.white12,
                  width: value == i ? 2 : 1,
                ),
                boxShadow: value == i ? [
                  BoxShadow(color: AppTheme.gold.withValues(alpha: 0.3), blurRadius: 4, spreadRadius: 1)
                ] : [],
              ),
              alignment: Alignment.center,
              child: Text(
                '$i',
                style: TextStyle(
                  color: value == i ? AppTheme.navyDark : AppTheme.textPrimary,
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                ),
              ),
            ),
          ),
      ],
    );
  }
}

class _TrumpSelector extends StatelessWidget {
  final Trump selected;
  final Trump? fixedTrump;
  final int currentTrickCount;
  final void Function(Trump) onChanged;

  const _TrumpSelector({
    required this.selected,
    this.fixedTrump,
    required this.currentTrickCount,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final trumps = Trump.values.toList()
      ..sort((a, b) => b.priority.compareTo(a.priority));

    return Wrap(
      spacing: 6,
      runSpacing: 6,
      alignment: WrapAlignment.start,
      children: trumps.map((trump) {
        final isSelected = trump == selected;
        final isFixedLocked = fixedTrump != null &&
            trump != fixedTrump &&
            currentTrickCount < kOverrideFixedTrumpTricks;

        Color textColor;
        if (trump.color == SuitColor.red) {
          textColor = AppTheme.suitRed;
        } else if (trump.color == SuitColor.gold) {
          textColor = AppTheme.gold;
        } else {
          textColor = AppTheme.suitBlack;
        }

        return GestureDetector(
          onTap: isFixedLocked ? null : () => onChanged(trump),
          child: Opacity(
            opacity: isFixedLocked ? 0.35 : 1.0,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 120),
              padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 6),
              decoration: BoxDecoration(
                color: isSelected ? AppTheme.cardWhite : AppTheme.surfaceCard,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                  color: isSelected ? AppTheme.gold : Colors.white12,
                  width: isSelected ? 2 : 1,
                ),
                boxShadow: isSelected
                    ? [
                        BoxShadow(
                          color: AppTheme.gold.withValues(alpha: 0.4),
                          blurRadius: 4,
                        )
                      ]
                    : [],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    trump.isSans ? '👑' : trump.label,
                    style: TextStyle(
                      fontSize: 18,
                      color: isSelected && trump.isSans ? AppTheme.navyDark : textColor,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    trump.arabicName,
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                      color: isSelected
                          ? AppTheme.navyDark
                          : AppTheme.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      }).toList(),
    );
  }
}
