import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../../core/icons/app_icons.dart';
import '../../../../core/widgets/app_buttons.dart';
import '../../../../theme/app_theme.dart';

class MatchmakingPlayerSlot extends StatefulWidget {
  final String? playerName;
  final bool isBot;
  final bool isSearching;
  final int seatIndex;
  final bool isYou;

  const MatchmakingPlayerSlot({
    super.key,
    this.playerName,
    this.isBot = false,
    this.isSearching = false,
    this.seatIndex = 0,
    this.isYou = false,
  });

  @override
  State<MatchmakingPlayerSlot> createState() => _MatchmakingPlayerSlotState();
}

class _MatchmakingPlayerSlotState extends State<MatchmakingPlayerSlot>
    with SingleTickerProviderStateMixin {
  static const _seatColors = [
    Color(0xFF11998E),
    Color(0xFFE05A6A),
    Color(0xFF4ADE80),
    Color(0xFFA78BFA),
  ];

  late final AnimationController _ripple;

  @override
  void initState() {
    super.initState();
    _ripple = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1600),
    );
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _syncRipple();
  }

  @override
  void didUpdateWidget(MatchmakingPlayerSlot oldWidget) {
    super.didUpdateWidget(oldWidget);
    _syncRipple();
  }

  void _syncRipple() {
    final reduceMotion =
        MediaQuery.maybeOf(context)?.disableAnimations ?? false;
    if (widget.isSearching && !reduceMotion) {
      if (!_ripple.isAnimating) _ripple.repeat();
    } else {
      _ripple.stop();
      _ripple.value = 0;
    }
  }

  @override
  void dispose() {
    _ripple.dispose();
    super.dispose();
  }

  bool get _occupied => widget.playerName != null || widget.isBot;

  Color get _accent => widget.isBot
      ? AppTheme.gold
      : _seatColors[widget.seatIndex % _seatColors.length];

  String get _label {
    if (widget.isBot) return 'بوت';
    if (widget.playerName != null) return widget.playerName!;
    return 'بحث...';
  }

  String? get _initial {
    final name = widget.playerName?.trim();
    if (name == null || name.isEmpty) return null;
    return name[0].toUpperCase();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        SizedBox(
          width: 72,
          height: 72,
          child: Stack(
            alignment: Alignment.center,
            clipBehavior: Clip.none,
            children: [
              if (widget.isSearching)
                AnimatedBuilder(
                  animation: _ripple,
                  builder: (_, __) {
                    final t = Curves.easeOut.transform(_ripple.value);
                    return Container(
                      width: 56 + (t * 16),
                      height: 56 + (t * 16),
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: AppTheme.steelBlue.withValues(
                            alpha: 0.35 - (t * 0.3),
                          ),
                          width: 1.5,
                        ),
                      ),
                    );
                  },
                ),
              AnimatedContainer(
                duration: const Duration(milliseconds: 280),
                curve: Curves.easeOutCubic,
                width: 56,
                height: 56,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: _occupied
                      ? _accent.withValues(alpha: 0.18)
                      : AppTheme.navyDark.withValues(alpha: 0.7),
                  border: Border.all(
                    color: widget.isYou
                        ? AppTheme.midBlue
                        : _occupied
                            ? _accent.withValues(alpha: 0.75)
                            : AppTheme.steelBlue.withValues(alpha: 0.25),
                    width: widget.isYou ? 2.5 : (_occupied ? 2 : 1.2),
                  ),
                  boxShadow: _occupied
                      ? [
                          BoxShadow(
                            color: _accent.withValues(alpha: 0.3),
                            blurRadius: 12,
                            spreadRadius: 0,
                          ),
                        ]
                      : null,
                ),
                child: Center(
                  child: _occupied
                      ? (widget.isBot
                          ? AppIconWell(
                              icon: AppIcons.smartToy,
                              size: 34,
                              iconSize: 18,
                              color: AppTheme.goldLight,
                              fill: AppTheme.gold.withValues(alpha: 0.15),
                              borderColor:
                                  AppTheme.gold.withValues(alpha: 0.3),
                            )
                          : Text(
                              _initial ?? '…',
                              style: GoogleFonts.cairo(
                                fontSize: 22,
                                fontWeight: FontWeight.w800,
                                color: AppTheme.cream,
                                height: 1,
                              ),
                            ))
                      : AppIcon(
                          AppIcons.hourglassEmpty,
                          size: 20,
                          color: AppTheme.steelBlue.withValues(alpha: 0.5),
                          strokeWidth: AppIconTokens.strokeThin,
                        ),
                ),
              ),
              if (widget.isYou)
                Positioned(
                  top: -2,
                  child: Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                    decoration: BoxDecoration(
                      color: AppTheme.midBlue,
                      borderRadius: BorderRadius.circular(999),
                      border: Border.all(
                        color: AppTheme.deepNavy,
                        width: 1.5,
                      ),
                    ),
                    child: Text(
                      'أنت',
                      style: GoogleFonts.cairo(
                        color: AppTheme.white,
                        fontSize: 9,
                        fontWeight: FontWeight.w800,
                        height: 1,
                      ),
                    ),
                  ),
                ),
              if (_occupied && !widget.isBot)
                Positioned(
                  bottom: 2,
                  right: 2,
                  child: Container(
                    width: 14,
                    height: 14,
                    decoration: BoxDecoration(
                      color: AppTheme.playerGreen,
                      shape: BoxShape.circle,
                      border: Border.all(color: AppTheme.deepNavy, width: 2),
                    ),
                  ),
                ),
            ],
          ),
        ),
        const SizedBox(height: 6),
        Container(
          constraints: const BoxConstraints(maxWidth: 80),
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
          decoration: BoxDecoration(
            color: AppTheme.navyDark.withValues(alpha: 0.72),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: _occupied
                  ? _accent.withValues(alpha: 0.25)
                  : Colors.transparent,
            ),
          ),
          child: Text(
            _label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.center,
            style: GoogleFonts.cairo(
              color: _occupied ? AppTheme.cream : AppTheme.steelBlue,
              fontSize: 11,
              fontWeight: _occupied ? FontWeight.w700 : FontWeight.w500,
              height: 1.1,
            ),
          ),
        ),
      ],
    );
  }
}
