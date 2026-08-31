import 'dart:math' as math;
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shimmer/shimmer.dart';

import '../../theme/app_theme.dart';

/// Slide-to-confirm Google Sign-In with a spinning Google wheel while dragging.
class GoogleSignInButton extends StatefulWidget {
  final Future<bool> Function() onSlide;
  final bool isLoading;
  final String label;

  const GoogleSignInButton({
    super.key,
    required this.onSlide,
    this.isLoading = false,
    this.label = 'اسحب للمتابعة مع Google',
  });

  @override
  State<GoogleSignInButton> createState() => _GoogleSignInButtonState();
}

class _GoogleSignInButtonState extends State<GoogleSignInButton>
    with SingleTickerProviderStateMixin {
  static const _height = 56.0;
  static const _thumbSize = 48.0;
  static const _thumbPadding = 4.0;
  static const _dismissThreshold = 0.72;
  static const _spinTurns = 1.5;

  double _trackWidth = 0;
  double _dragX = 0;
  bool _isDragging = false;
  bool _isActing = false;
  bool _completed = false;

  late final AnimationController _resetController;
  late Animation<double> _resetAnimation;

  double get _maxDrag =>
      math.max(0, _trackWidth - _thumbSize - _thumbPadding * 2);

  double get _progress =>
      _maxDrag <= 0 ? 0 : (_dragX / _maxDrag).clamp(0.0, 1.0);

  double get _rotation => _progress * _spinTurns * math.pi * 2;

  @override
  void initState() {
    super.initState();
    _resetController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 320),
    );
    _resetAnimation = CurvedAnimation(
      parent: _resetController,
      curve: Curves.easeOutCubic,
    )..addListener(() {
        setState(() {
          _dragX = _resetFrom * (1 - _resetAnimation.value);
        });
      });
  }

  double _resetFrom = 0;

  @override
  void dispose() {
    _resetController.dispose();
    super.dispose();
  }

  bool get _isInteractive =>
      !widget.isLoading && !_isActing && !_completed && _maxDrag > 0;

  void _onDragStart(DragStartDetails _) {
    if (!_isInteractive) return;
    _resetController.stop();
    setState(() => _isDragging = true);
  }

  void _onDragUpdate(DragUpdateDetails details) {
    if (!_isInteractive || !_isDragging) return;
    setState(() {
      // Thumb starts on the left; drag right to advance.
      _dragX = (_dragX + details.delta.dx).clamp(0, _maxDrag);
    });
  }

  Future<void> _onDragEnd(DragEndDetails _) async {
    if (!_isInteractive || !_isDragging) return;
    setState(() => _isDragging = false);

    if (_progress >= _dismissThreshold) {
      await _completeSlide();
    } else {
      _springBack();
    }
  }

  void _springBack() {
    _resetFrom = _dragX;
    _resetController
      ..reset()
      ..forward();
  }

  Future<void> _completeSlide() async {
    setState(() {
      _isActing = true;
      _dragX = _maxDrag;
    });
    HapticFeedback.mediumImpact();

    bool success = false;
    try {
      success = await widget.onSlide();
    } catch (_) {
      success = false;
    }

    if (!mounted) return;

    if (success) {
      setState(() => _completed = true);
    } else {
      setState(() {
        _isActing = false;
        _dragX = _maxDrag;
      });
      _springBack();
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_completed) return const SizedBox(height: _height);

    return LayoutBuilder(
      builder: (context, constraints) {
        _trackWidth = constraints.maxWidth.isFinite
            ? constraints.maxWidth
            : MediaQuery.sizeOf(context).width - 48;

        final label = widget.isLoading
            ? Text(
                'جاري تسجيل الدخول...',
                style: GoogleFonts.cairo(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: AppTheme.cream.withValues(alpha: 0.85),
                ),
              )
            : Text(
                widget.label,
                style: GoogleFonts.cairo(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: AppTheme.cream.withValues(alpha: 0.9),
                ),
              );

        return ClipRRect(
          borderRadius: BorderRadius.circular(16),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
            child: Container(
              height: _height,
              width: _trackWidth,
              decoration: BoxDecoration(
                color: widget.isLoading
                    ? AppTheme.surface2.withValues(alpha: 0.55)
                    : AppTheme.cream.withValues(alpha: 0.14),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: AppTheme.cream.withValues(alpha: 0.28),
                  width: 1.2,
                ),
              ),
              child: Stack(
                alignment: Alignment.center,
                clipBehavior: Clip.none,
                children: [
                  Center(
                    child: widget.isLoading || !_isInteractive
                        ? label
                        : Shimmer.fromColors(
                            baseColor:
                                AppTheme.steelBlue.withValues(alpha: 0.55),
                            highlightColor:
                                AppTheme.cream.withValues(alpha: 0.95),
                            child: label,
                          ),
                  ),
                  Positioned(
                    left: _thumbPadding + _dragX,
                    top: (_height - _thumbSize) / 2,
                    child: GestureDetector(
                      onHorizontalDragStart: _onDragStart,
                      onHorizontalDragUpdate: _onDragUpdate,
                      onHorizontalDragEnd: _onDragEnd,
                      child: _Thumb(
                        size: _thumbSize,
                        rotation: _rotation,
                        isDragging: _isDragging,
                        enabled: _isInteractive,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

class _Thumb extends StatelessWidget {
  final double size;
  final double rotation;
  final bool isDragging;
  final bool enabled;

  const _Thumb({
    required this.size,
    required this.rotation,
    required this.isDragging,
    required this.enabled,
  });

  @override
  Widget build(BuildContext context) {
    return AnimatedScale(
      scale: isDragging ? 1.06 : 1.0,
      duration: const Duration(milliseconds: 120),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 120),
        height: size,
        width: size,
        decoration: BoxDecoration(
          color: enabled ? AppTheme.cream : Colors.grey.shade400,
          borderRadius: BorderRadius.circular(14),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: isDragging ? 0.28 : 0.18),
              blurRadius: isDragging ? 14 : 10,
              offset: Offset(0, isDragging ? 5 : 3),
            ),
          ],
        ),
        child: Transform.rotate(
          angle: rotation,
          child: Padding(
            padding: const EdgeInsets.all(11),
            child: Image.asset(
              'assets/google.png',
              fit: BoxFit.contain,
              filterQuality: FilterQuality.high,
            ),
          ),
        ),
      ),
    );
  }
}
