import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:slider_button/slider_button.dart';

import '../../theme/app_theme.dart';

/// Slide-to-confirm Google Sign-In — Google icon acts as the draggable wheel.
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

class _GoogleSignInButtonState extends State<GoogleSignInButton> {
  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final trackWidth = constraints.maxWidth.isFinite
            ? constraints.maxWidth
            : MediaQuery.sizeOf(context).width - 48;

        return SliderButton(
          buttonKey: ValueKey('google_slider_${widget.isLoading}'),
          action: widget.onSlide,
          disable: widget.isLoading,
          rightToLeftLocale: true,
          vibrationFlag: true,
          width: trackWidth,
          height: 56,
          buttonSize: 48,
          radius: 16,
          dismissThresholds: 0.72,
          backgroundColor: AppTheme.cream.withValues(alpha: 0.14),
          useGlassEffect: true,
          glassBlurSigma: 12,
          glassBorderColor: AppTheme.cream.withValues(alpha: 0.28),
          glassBorderWidth: 1.2,
          buttonColor: AppTheme.cream,
          baseColor: AppTheme.steelBlue.withValues(alpha: 0.55),
          highlightedColor: AppTheme.cream.withValues(alpha: 0.95),
          alignLabel: Alignment.center,
          boxShadow: BoxShadow(
            color: Colors.black.withValues(alpha: 0.18),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
          label: widget.isLoading
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
                ),
          icon: Padding(
            padding: const EdgeInsets.all(11),
            child: Image.asset(
              'assets/google.png',
              fit: BoxFit.contain,
              filterQuality: FilterQuality.high,
            ),
          ),
        );
      },
    );
  }
}
