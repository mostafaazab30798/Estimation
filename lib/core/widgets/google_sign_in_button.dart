import 'dart:math' as math;
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shimmer/shimmer.dart';

import '../../theme/app_theme.dart';

enum GoogleSignInButtonVariant { login, dark }

/// Slide-to-confirm Google Sign-In with a spinning Google wheel while dragging.
class GoogleSignInButton extends StatefulWidget {
  final Future<bool> Function() onSlide;
  final bool isLoading;
  final String label;
  final GoogleSignInButtonVariant variant;
  final bool compact;

  const GoogleSignInButton({
    super.key,
    required this.onSlide,
    this.isLoading = false,
    this.label = 'اسحب للمتابعة مع Google',
    this.variant = GoogleSignInButtonVariant.dark,
    this.compact = false,
  });

  @override
  State<GoogleSignInButton> createState() => _GoogleSignInButtonState();
}

class _LoginSliderStyle {
  static const deepViolet = Color(0xFF2E2858);
  static const softViolet = Color(0xFF5A528C);
  static const periwinkle = Color(0xFFA8A0D8);
  static const lavender = Color(0xFFD8D2F0);
  static const peach = Color(0xFFF0A898);
}

class _GoogleSignInButtonState extends State<GoogleSignInButton>
    with SingleTickerProviderStateMixin {
  static const _height = 56.0;
  static const _heightCompact = 48.0;
  static const _thumbSize = 48.0;
  static const _thumbSizeCompact = 40.0;
  static const _thumbPadding = 4.0;
  static const _dismissThreshold = 0.72;
  static const _spinTurns = 1.5;

  double get _trackHeight => widget.compact ? _heightCompact : _height;

  double get _thumbDimension => widget.compact ? _thumbSizeCompact : _thumbSize;

  double _trackWidth = 0;
  double _dragX = 0;
  bool _isDragging = false;
  bool _isActing = false;
  bool _completed = false;

  late final AnimationController _resetController;
  late Animation<double> _resetAnimation;

  bool get _isLogin => widget.variant == GoogleSignInButtonVariant.login;

  double get _maxDrag =>
      math.max(0, _trackWidth - _thumbDimension - _thumbPadding * 2);

  double get _progress =>
      _maxDrag <= 0 ? 0 : (_dragX / _maxDrag).clamp(0.0, 1.0);

  double get _rotation => _progress * _spinTurns * math.pi * 2;

  Color get _trackColor => _isLogin
      ? Colors.white.withValues(alpha: widget.isLoading ? 0.45 : 0.62)
      : AppTheme.cream.withValues(alpha: widget.isLoading ? 0.1 : 0.14);

  Color get _trackBorder => _isLogin
      ? _LoginSliderStyle.periwinkle.withValues(alpha: 0.45)
      : AppTheme.cream.withValues(alpha: 0.28);

  Color get _labelColor => _isLogin
      ? _LoginSliderStyle.deepViolet.withValues(alpha: 0.88)
      : AppTheme.cream.withValues(alpha: 0.9);

  Color get _shimmerBase => _isLogin
      ? _LoginSliderStyle.softViolet.withValues(alpha: 0.45)
      : AppTheme.steelBlue.withValues(alpha: 0.55);

  Color get _shimmerHighlight => _isLogin
      ? Colors.white.withValues(alpha: 0.95)
      : AppTheme.cream.withValues(alpha: 0.95);

  Color get _thumbColor =>
      _isLogin ? Colors.white : (widget.isLoading ? Colors.grey.shade400 : AppTheme.cream);

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
    if (_completed) return SizedBox(height: _trackHeight);

    return LayoutBuilder(
      builder: (context, constraints) {
        _trackWidth = constraints.maxWidth.isFinite
            ? constraints.maxWidth
            : MediaQuery.sizeOf(context).width - 48;

        final label = Text(
          widget.isLoading ? 'جاري تسجيل الدخول...' : widget.label,
          style: AppFonts.cooper(
            fontSize: widget.compact ? 12.5 : 14,
            fontWeight: FontWeight.w700,
            color: _labelColor,
          ),
        );

        final trackRadius = _trackHeight / 2;

        return ClipRRect(
          borderRadius: BorderRadius.circular(trackRadius),
          child: BackdropFilter(
            filter: ImageFilter.blur(
              sigmaX: _isLogin ? 10 : 12,
              sigmaY: _isLogin ? 10 : 12,
            ),
            child: Container(
              height: _trackHeight,
              width: _trackWidth,
              decoration: BoxDecoration(
                color: _trackColor,
                borderRadius: BorderRadius.circular(trackRadius),
                border: Border.all(color: _trackBorder, width: 1.2),
                boxShadow: _isLogin
                    ? [
                        BoxShadow(
                          color: _LoginSliderStyle.periwinkle
                              .withValues(alpha: 0.16),
                          blurRadius: 12,
                          offset: const Offset(0, 4),
                        ),
                      ]
                    : null,
              ),
              child: Stack(
                alignment: Alignment.center,
                clipBehavior: Clip.none,
                children: [
                  if (_isLogin)
                    Positioned.fill(
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.centerLeft,
                            end: Alignment.centerRight,
                            colors: [
                              _LoginSliderStyle.lavender.withValues(alpha: 0.15),
                              Colors.transparent,
                              _LoginSliderStyle.peach.withValues(alpha: 0.08),
                            ],
                          ),
                        ),
                      ),
                    ),
                  Center(
                    child: widget.isLoading || !_isInteractive
                        ? label
                        : Shimmer.fromColors(
                            baseColor: _shimmerBase,
                            highlightColor: _shimmerHighlight,
                            child: label,
                          ),
                  ),
                  Positioned(
                    left: _thumbPadding + _dragX,
                    top: (_trackHeight - _thumbDimension) / 2,
                    child: GestureDetector(
                      onHorizontalDragStart: _onDragStart,
                      onHorizontalDragUpdate: _onDragUpdate,
                      onHorizontalDragEnd: _onDragEnd,
                      child: _Thumb(
                        size: _thumbDimension,
                        rotation: _rotation,
                        isDragging: _isDragging,
                        enabled: _isInteractive,
                        color: _thumbColor,
                        isLogin: _isLogin,
                        compact: widget.compact,
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
  final Color color;
  final bool isLogin;
  final bool compact;

  const _Thumb({
    required this.size,
    required this.rotation,
    required this.isDragging,
    required this.enabled,
    required this.color,
    required this.isLogin,
    this.compact = false,
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
          shape: BoxShape.circle,
          color: enabled ? color : Colors.grey.shade400,
          border: isLogin
              ? Border.all(
                  color: _LoginSliderStyle.periwinkle.withValues(alpha: 0.35),
                )
              : null,
          boxShadow: [
            BoxShadow(
              color: (isLogin
                      ? _LoginSliderStyle.periwinkle
                      : Colors.black)
                  .withValues(alpha: isDragging ? 0.28 : 0.18),
              blurRadius: isDragging ? 14 : 10,
              offset: Offset(0, isDragging ? 5 : 3),
            ),
          ],
        ),
        child: Transform.rotate(
          angle: rotation,
          child: Padding(
            padding: EdgeInsets.all(compact ? 9 : 11),
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
