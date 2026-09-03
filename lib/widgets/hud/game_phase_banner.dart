// lib/widgets/hud/game_phase_banner.dart
//
// Cinematic phase notification overlay — slides in, holds, then fades away.
// Used for round-start announcements and major phase transitions.

import 'package:flutter/material.dart';
import '../../theme/app_theme.dart';

/// Shows a full-width cinematic banner that slides in from the top,
/// holds for [holdDuration], then fades away automatically.
///
/// Usage:
///   key.currentState?.show('بداية الجولة 3');
class GamePhaseBanner extends StatefulWidget {
  const GamePhaseBanner({super.key});

  @override
  State<GamePhaseBanner> createState() => GamePhaseBannerState();
}

class _BannerData {
  final String message;
  final Color color;
  const _BannerData(this.message, this.color);
}

class GamePhaseBannerState extends State<GamePhaseBanner>
    with TickerProviderStateMixin {
  late final AnimationController _ctrl;
  late final Animation<Offset> _slide;
  late final Animation<double> _fade;

  final _bannerData = ValueNotifier<_BannerData>(const _BannerData('', AppTheme.gold));

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );

    _slide = Tween<Offset>(begin: const Offset(0, -1.5), end: Offset.zero)
        .animate(CurvedAnimation(parent: _ctrl, curve: Curves.easeOutBack));

    _fade = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(
        parent: _ctrl,
        curve: const Interval(0.0, 0.3, curve: Curves.easeIn),
      ),
    );
  }

  @override
  void dispose() {
    _ctrl.dispose();
    _bannerData.dispose();
    super.dispose();
  }

  Future<void> show(String message, {Color? color}) async {
    if (!mounted) return;
    _bannerData.value = _BannerData(message, color ?? AppTheme.gold);
    await _ctrl.forward(from: 0.0);
    await Future.delayed(const Duration(milliseconds: 1400));
    if (mounted) await _ctrl.reverse();
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<_BannerData>(
      valueListenable: _bannerData,
      builder: (context, data, _) {
        return AnimatedBuilder(
          animation: _ctrl,
          builder: (_, __) {
            if (_ctrl.value == 0) return const SizedBox.shrink();

            return SlideTransition(
              position: _slide,
              child: FadeTransition(
                opacity: _fade,
                child: Center(
                  child: Container(
                    margin: const EdgeInsets.symmetric(horizontal: 24),
                    padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 14),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          data.color.withValues(alpha: 0.20),
                          AppTheme.deepNavy.withValues(alpha: 0.92),
                          data.color.withValues(alpha: 0.20),
                        ],
                        begin: Alignment.centerLeft,
                        end: Alignment.centerRight,
                      ),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: data.color.withValues(alpha: 0.45), width: 1.2),
                      boxShadow: [
                        BoxShadow(
                          color: data.color.withValues(alpha: 0.25),
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
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        // Left decorator
                        SizedBox(
                          width: 40,
                          child: Divider(color: data.color.withValues(alpha: 0.5), thickness: 1),
                        ),
                        const SizedBox(width: 12),
                        Text(
                          data.message,
                          style: AppFonts.cooper(
                            color: data.color,
                            fontSize: 15,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 0.5,
                          ),
                        ),
                        const SizedBox(width: 12),
                        // Right decorator
                        SizedBox(
                          width: 40,
                          child: Divider(color: data.color.withValues(alpha: 0.5), thickness: 1),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }
}
