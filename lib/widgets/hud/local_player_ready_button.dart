// lib/widgets/hud/local_player_ready_button.dart
//
// Premium animated ready button for the local player during voidCheck phase.

import 'package:flutter/material.dart';
import '../../theme/app_theme.dart';
import '../../core/widgets/app_buttons.dart';
import 'package:estimation/core/icons/app_icons.dart';

/// Toggle-ready button for the local player.
/// Modern, clean, sleek design with touch feedback and glowing animations.
class LocalPlayerReadyButton extends StatefulWidget {
  final bool isReady;
  final VoidCallback onTap;

  const LocalPlayerReadyButton({
    super.key,
    required this.isReady,
    required this.onTap,
  });

  @override
  State<LocalPlayerReadyButton> createState() => _LocalPlayerReadyButtonState();
}

class _LocalPlayerReadyButtonState extends State<LocalPlayerReadyButton>
    with TickerProviderStateMixin {
  static const _readyColor = Color(0xFF00E5A0);

  // Idle "invite to tap" breathing, only active while not ready.
  late final AnimationController _breatheController;
  late final Animation<double> _breatheAnim;

  // Diagonal shimmer sweep across the CTA surface — the button's one
  // deliberate flourish, silenced the moment the player is ready.
  late final AnimationController _shimmerController;

  // One-shot confirm burst: a soft ring that expands and fades the instant
  // the player taps in, giving the state change a felt moment instead of
  // just swapping colors.
  late final AnimationController _confirmController;
  late final Animation<double> _confirmRing;
  late final Animation<double> _confirmFade;

  bool _isPressed = false;

  @override
  void initState() {
    super.initState();

    _breatheController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..repeat(reverse: true);
    _breatheAnim = Tween<double>(begin: 0.97, end: 1.03).animate(
      CurvedAnimation(parent: _breatheController, curve: Curves.easeInOut),
    );

    _shimmerController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2200),
    )..repeat();

    _confirmController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 520),
    );
    _confirmRing = Tween<double>(begin: 0.6, end: 1.9).animate(
      CurvedAnimation(parent: _confirmController, curve: Curves.easeOut),
    );
    _confirmFade = Tween<double>(begin: 0.55, end: 0.0).animate(
      CurvedAnimation(parent: _confirmController, curve: Curves.easeOut),
    );
  }

  @override
  void didUpdateWidget(covariant LocalPlayerReadyButton oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!oldWidget.isReady && widget.isReady) {
      _confirmController.forward(from: 0);
    } else if (oldWidget.isReady && !widget.isReady) {
      _confirmController.reset();
    }
  }

  @override
  void dispose() {
    _breatheController.dispose();
    _shimmerController.dispose();
    _confirmController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isReady = widget.isReady;
    final accent = isReady ? _readyColor : AppTheme.gold;

    return GestureDetector(
      onTapDown: (_) => setState(() => _isPressed = true),
      onTapUp: (_) {
        setState(() => _isPressed = false);
        widget.onTap();
      },
      onTapCancel: () => setState(() => _isPressed = false),
      child: AnimatedScale(
        scale: _isPressed ? 0.93 : 1.0,
        duration: const Duration(milliseconds: 120),
        curve: Curves.easeOutCubic,
        child: AnimatedBuilder(
          animation: Listenable.merge([_breatheAnim, _confirmController]),
          builder: (context, child) {
            final pulse = isReady ? 1.0 : _breatheAnim.value;

            return SizedBox(
              width: 168,
              height: 52,
              child: Stack(
                alignment: Alignment.center,
                clipBehavior: Clip.none,
                children: [
                  // Confirm burst ring, only drawn while animating.
                  if (_confirmController.value > 0)
                    Transform.scale(
                      scale: _confirmRing.value,
                      child: Container(
                        width: 168,
                        height: 52,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(30),
                          border: Border.all(
                            color: _readyColor.withValues(alpha: _confirmFade.value),
                            width: 2,
                          ),
                        ),
                      ),
                    ),
                  Transform.scale(
                    scale: pulse,
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 320),
                      curve: Curves.easeInOut,
                      width: 168,
                      height: 52,
                      padding: const EdgeInsets.symmetric(horizontal: 18),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(30),
                        color: isReady
                            ? AppTheme.deepNavy.withValues(alpha: 0.55)
                            : AppTheme.gold,
                        border: Border.all(
                          color: isReady
                              ? _readyColor.withValues(alpha: 0.75)
                              : Colors.white.withValues(alpha: 0.65),
                          width: 1.6,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: accent.withValues(alpha: isReady ? 0.22 : 0.45 * pulse),
                            blurRadius: isReady ? 12 : 20 * pulse,
                            spreadRadius: isReady ? 0.5 : 1.5 * pulse,
                            offset: const Offset(0, 4),
                          ),
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.4),
                            blurRadius: 12,
                            offset: const Offset(0, 5),
                          ),
                        ],
                      ),
                      clipBehavior: Clip.antiAlias,
                      child: Stack(
                        alignment: Alignment.center,
                        children: [
                          // Shimmer sweep — silent once the player is ready.
                          if (!isReady)
                            AnimatedBuilder(
                              animation: _shimmerController,
                              builder: (context, _) {
                                final t = _shimmerController.value;
                                return Positioned.fill(
                                  child: FractionalTranslation(
                                    translation: Offset(1.6 - t * 3.2, 0),
                                    child: Transform.rotate(
                                      angle: -0.5,
                                      child: Container(
                                        width: 26,
                                        color: Colors.white.withValues(alpha: 0.28),
                                      ),
                                    ),
                                  ),
                                );
                              },
                            ),
                          Row(
                            mainAxisSize: MainAxisSize.min,
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Container(
                                width: 8,
                                height: 8,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: isReady ? _readyColor : AppTheme.deepNavy,
                                  boxShadow: [
                                    BoxShadow(
                                      color: (isReady ? _readyColor : Colors.white)
                                          .withValues(alpha: 0.8),
                                      blurRadius: 6,
                                      spreadRadius: 1,
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(width: 10),
                              AnimatedSwitcher(
                                duration: const Duration(milliseconds: 250),
                                transitionBuilder: (child, anim) =>
                                    ScaleTransition(scale: anim, child: child),
                                child: AppIcon(
                                  isReady ? AppIcons.taskAlt : AppIcons.bolt,
                                  key: ValueKey(isReady),
                                  size: AppIconTokens.sizeLg,
                                  color: isReady ? _readyColor : AppTheme.deepNavy,
                                  strokeWidth: AppIconTokens.strokeBold,
                                ),
                              ),
                              const SizedBox(width: 8),
                              AnimatedSwitcher(
                                duration: const Duration(milliseconds: 250),
                                transitionBuilder: (child, anim) =>
                                    FadeTransition(opacity: anim, child: child),
                                child: Text(
                                  isReady ? 'أنا جاهز' : 'جاهز للعب',
                                  key: ValueKey(isReady),
                                  style: AppFonts.cooper(
                                    color: isReady ? _readyColor : AppTheme.deepNavy,
                                    fontSize: 14,
                                    fontWeight: FontWeight.w900,
                                    letterSpacing: 0.3,
                                    height: 1.1,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }
}