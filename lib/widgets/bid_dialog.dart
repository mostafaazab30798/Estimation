// lib/widgets/bid_dialog.dart
//
// Arabic bidding dialog shown during the auction phase.

import 'package:flutter/material.dart';
import '../core/constants.dart';
import '../core/models/bid.dart';
import '../theme/app_theme.dart';

class BidDialog extends StatefulWidget {
  final Bid? currentHighBid;
  final String? bidderName;
  final void Function(Bid bid) onBid;
  final VoidCallback onPass;

  const BidDialog({
    super.key,
    this.currentHighBid,
    this.bidderName,
    required this.onBid,
    required this.onPass,
  });

  @override
  State<BidDialog> createState() => _BidDialogState();
}

class _BidDialogState extends State<BidDialog> {
  int _trickCount = 4;
  Suit _suit = Suit.spade;

  bool get _isValid {
    final bid = Bid(trickCount: _trickCount, trumpSuit: _suit);
    return bid.beats(widget.currentHighBid ??
        const Bid(trickCount: 0, trumpSuit: Suit.club));
  }

  @override
  void initState() {
    super.initState();
    // Pre-select a value higher than current high bid
    if (widget.currentHighBid != null) {
      _trickCount = widget.currentHighBid!.trickCount;
      _suit = Suit.values[
          (widget.currentHighBid!.trumpSuit.priority + 1) %
              Suit.values.length];
      if (_suit.priority <= widget.currentHighBid!.trumpSuit.priority) {
        _trickCount++;
      }
      _trickCount = _trickCount.clamp(4, 13);
    } else {
      _trickCount = 4;
    }
  }

  @override
  Widget build(BuildContext context) {
    final isPortrait = MediaQuery.of(context).orientation == Orientation.portrait;
    final dialogWidth = MediaQuery.of(context).size.width * (isPortrait ? 0.92 : 0.65);

    return Dialog(
      alignment: Alignment.center,
      insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      backgroundColor: Colors.transparent,
      elevation: 0,
      child: Container(
        width: dialogWidth,
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: AppTheme.navyDark,
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: AppTheme.gold.withValues(alpha: 0.4), width: 1.5),
          boxShadow: AppTheme.neumorphicTurnGlow(AppTheme.navyDeep),
        ),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Header Row
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'المزاد',
                    style: Theme.of(context).textTheme.headlineMedium,
                  ),
                  if (widget.currentHighBid != null)
                    Flexible(
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: AppTheme.gold.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(color: AppTheme.gold.withValues(alpha: 0.5)),
                        ),
                        child: Text(
                          'أعلى: ${widget.currentHighBid!.arabicLabel}${widget.bidderName != null ? ' (${widget.bidderName})' : ''}',
                          style: Theme.of(context)
                              .textTheme.bodyMedium
                              ?.copyWith(color: AppTheme.gold, fontWeight: FontWeight.bold, fontSize: 12),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 14),

              // Content Layout (Vertical for Portrait, Horizontal for Landscape)
              if (isPortrait) ...[
                Text('عدد اللمات',
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: AppTheme.textSecondary)),
                const SizedBox(height: 8),
                _TrickCountSelector(
                  value: _trickCount,
                  onChanged: (v) => setState(() => _trickCount = v),
                ),
                const SizedBox(height: 14),
                Text('القطوع (الكار الكبير)',
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: AppTheme.textSecondary)),
                const SizedBox(height: 8),
                _SuitSelector(
                  selected: _suit,
                  onChanged: (s) => setState(() => _suit = s),
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
                          Text('عدد اللمات',
                              style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: AppTheme.textSecondary)),
                          const SizedBox(height: 8),
                          _TrickCountSelector(
                            value: _trickCount,
                            onChanged: (v) => setState(() => _trickCount = v),
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
                          Text('القطوع (الكار الكبير)',
                              style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: AppTheme.textSecondary)),
                          const SizedBox(height: 8),
                          _SuitSelector(
                            selected: _suit,
                            onChanged: (s) => setState(() => _suit = s),
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
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        side: BorderSide(color: AppTheme.errorRed.withValues(alpha: 0.5), width: 2),
                        foregroundColor: AppTheme.errorRed,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
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
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        backgroundColor: AppTheme.gold,
                        foregroundColor: AppTheme.navyDark,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        elevation: _isValid ? 4 : 0,
                      ),
                      onPressed: _isValid
                          ? () {
                              Navigator.of(context).pop();
                              widget.onBid(
                                  Bid(trickCount: _trickCount, trumpSuit: _suit));
                            }
                          : null,
                      child: const Text('مزايدة (Bid)', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
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

class _SuitSelector extends StatelessWidget {
  final Suit selected;
  final void Function(Suit) onChanged;

  const _SuitSelector({required this.selected, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    // Show suits in priority order (highest first for easy selection)
    final suits = Suit.values.toList()
      ..sort((a, b) => b.priority.compareTo(a.priority));

    return Wrap(
      spacing: 6,
      runSpacing: 6,
      alignment: WrapAlignment.start,
      children: suits.map((suit) {
        final isSelected = suit == selected;
        final color = suit.color == SuitColor.red
            ? AppTheme.suitRed
            : AppTheme.suitBlack;
        return GestureDetector(
          onTap: () => onChanged(suit),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 120),
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
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
                Text(suit.label,
                    style: TextStyle(fontSize: 20, color: color)),
                const SizedBox(height: 2),
                Text(suit.arabicName,
                    style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                        color: isSelected
                            ? AppTheme.navyDark
                            : AppTheme.textSecondary)),
              ],
            ),
          ),
        );
      }).toList(),
    );
  }
}
