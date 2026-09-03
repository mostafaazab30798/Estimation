// lib/widgets/hud/reaction_bubble_widget.dart
//
// Animated speech/reaction bubble widget anchored to player positions on the game table.

import 'package:flutter/material.dart';
import '../../core/models/game_reaction.dart';
import '../../theme/app_theme.dart';

class ReactionBubbleWidget extends StatefulWidget {
  final GameReaction reaction;
  final Alignment anchorAlignment;

  const ReactionBubbleWidget({
    super.key,
    required this.reaction,
    this.anchorAlignment = Alignment.bottomCenter,
  });

  @override
  State<ReactionBubbleWidget> createState() => _ReactionBubbleWidgetState();
}

class _ReactionBubbleWidgetState extends State<ReactionBubbleWidget>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _scaleAnimation;
  late final Animation<double> _fadeAnimation;
  late final Animation<Offset> _slideAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 3000),
    );

    // Bounce-in scale (0 to 400ms)
    _scaleAnimation = TweenSequence<double>([
      TweenSequenceItem(
        tween: Tween<double>(begin: 0.0, end: 1.12)
            .chain(CurveTween(curve: Curves.easeOutBack)),
        weight: 15,
      ),
      TweenSequenceItem(
        tween: Tween<double>(begin: 1.12, end: 1.0)
            .chain(CurveTween(curve: Curves.easeInOut)),
        weight: 10,
      ),
      TweenSequenceItem(
        tween: ConstantTween<double>(1.0),
        weight: 55,
      ),
      TweenSequenceItem(
        tween: Tween<double>(begin: 1.0, end: 0.8)
            .chain(CurveTween(curve: Curves.easeInCubic)),
        weight: 20,
      ),
    ]).animate(_controller);

    // Fade in quickly, stay, then fade out
    _fadeAnimation = TweenSequence<double>([
      TweenSequenceItem(
        tween: Tween<double>(begin: 0.0, end: 1.0)
            .chain(CurveTween(curve: Curves.easeOut)),
        weight: 12,
      ),
      TweenSequenceItem(
        tween: ConstantTween<double>(1.0),
        weight: 68,
      ),
      TweenSequenceItem(
        tween: Tween<double>(begin: 1.0, end: 0.0)
            .chain(CurveTween(curve: Curves.easeIn)),
        weight: 20,
      ),
    ]).animate(_controller);

    // Gentle upward floating slide
    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, 8),
      end: const Offset(0, -22),
    ).animate(CurvedAnimation(
      parent: _controller,
      curve: Curves.easeOutCubic,
    ));

    _controller.forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final hasText = widget.reaction.text != null && widget.reaction.text!.isNotEmpty;

    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        return Transform.translate(
          offset: _slideAnimation.value,
          child: Opacity(
            opacity: _fadeAnimation.value.clamp(0.0, 1.0),
            child: Transform.scale(
              scale: _scaleAnimation.value.clamp(0.0, 1.5),
              alignment: widget.anchorAlignment,
              child: child,
            ),
          ),
        );
      },
      child: Container(
        padding: EdgeInsets.symmetric(
          horizontal: hasText ? 14 : 10,
          vertical: hasText ? 7 : 6,
        ),
        constraints: const BoxConstraints(maxWidth: 190),
        decoration: BoxDecoration(
          color: AppTheme.navyDark.withValues(alpha: 0.94),
          borderRadius: BorderRadius.circular(hasText ? 18 : 22),
          border: Border.all(
            color: AppTheme.gold.withValues(alpha: 0.65),
            width: 1.5,
          ),
          boxShadow: [
            BoxShadow(
              color: AppTheme.gold.withValues(alpha: 0.35),
              blurRadius: 16,
              spreadRadius: 1,
              offset: const Offset(0, 4),
            ),
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.6),
              blurRadius: 12,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Text(
              widget.reaction.emoji,
              style: TextStyle(
                fontSize: hasText ? 20 : 28,
                height: 1.1,
              ),
            ),
            if (hasText) ...[
              const SizedBox(width: 8),
              Flexible(
                child: Text(
                  widget.reaction.text!,
                  style: AppFonts.cooper(
                    color: AppTheme.white,
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                    height: 1.25,
                    shadows: [
                      Shadow(
                        color: Colors.black.withValues(alpha: 0.8),
                        blurRadius: 4,
                        offset: const Offset(0, 1),
                      ),
                    ],
                  ),
                  textAlign: TextAlign.start,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
