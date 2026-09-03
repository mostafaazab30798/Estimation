import 'package:flutter/material.dart';

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
          width: 58,
          height: 58,
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
                      width: 48 + (t * 8),
                      height: 48 + (t * 8),
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: AppTheme.steelBlue.withValues(
                            alpha: 0.2 - (t * 0.16),
                          ),
                          width: 1,
                        ),
                      ),
                    );
                  },
                ),
              AnimatedContainer(
                duration: const Duration(milliseconds: 280),
                curve: Curves.easeOutCubic,
                width: 46,
                height: 46,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: _occupied
                      ? _accent.withValues(alpha: 0.12)
                      : AppTheme.deepNavy,
                  border: Border.all(
                    color: widget.isYou
                        ? AppTheme.midBlue
                            : _occupied
                            ? _accent.withValues(alpha: 0.55)
                            : AppTheme.steelBlue.withValues(alpha: 0.2),
                    width: widget.isYou ? 2 : 1,
                  ),
                ),
                child: Center(
                  child: _occupied
                      ? (widget.isBot
                          ? AppIcon(
                              AppIcons.smartToy,
                              size: 18,
                              color: AppTheme.goldLight,
                              strokeWidth: AppIconTokens.strokeThin,
                            )
                          : Text(
                              _initial ?? '…',
                              style: AppFonts.cooper(
                                fontSize: 18,
                                fontWeight: FontWeight.w700,
                                color: AppTheme.cream,
                                height: 1,
                              ),
                            ))
                      : AppIcon(
                          AppIcons.hourglassEmpty,
                          size: 16,
                          color: AppTheme.steelBlue.withValues(alpha: 0.42),
                          strokeWidth: AppIconTokens.strokeThin,
                        ),
                ),
              ),
              if (widget.isYou)
                Positioned(
                  top: -1,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 5,
                      vertical: 1,
                    ),
                    decoration: BoxDecoration(
                      color: AppTheme.midBlue,
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: Text(
                      'أنت',
                      style: AppFonts.cooper(
                        color: AppTheme.white,
                        fontSize: 8,
                        fontWeight: FontWeight.w700,
                        height: 1,
                      ),
                    ),
                  ),
                ),
              if (_occupied && !widget.isBot)
                Positioned(
                  bottom: 5,
                  right: 5,
                  child: Container(
                    width: 8,
                    height: 8,
                    decoration: BoxDecoration(
                      color: AppTheme.playerGreen,
                      shape: BoxShape.circle,
                      border: Border.all(color: AppTheme.deepNavy, width: 1.5),
                    ),
                  ),
                ),
            ],
          ),
        ),
        const SizedBox(height: 3),
        Text(
          _label,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          textAlign: TextAlign.center,
          style: AppFonts.cooper(
            color: _occupied
                ? AppTheme.cream.withValues(alpha: 0.88)
                : AppTheme.steelBlue.withValues(alpha: 0.65),
            fontSize: 10,
            fontWeight: _occupied ? FontWeight.w600 : FontWeight.w400,
            height: 1.1,
          ),
        ),
      ],
    );
  }
}
