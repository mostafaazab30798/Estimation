// lib/widgets/reconnection_banner.dart
//
// Overlay widget shown on GameScreen when the ReconnectionManager reports
// a live reconnection attempt or a terminal failure.
//
//  • reconnecting → slim top banner with spinner (non-blocking)
//  • failed       → full-screen modal with retry / go-home buttons

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../services/reconnection_manager.dart';
import '../theme/app_theme.dart';
import 'performance_blur.dart';
import 'package:estimation/core/icons/app_icons.dart';

class ReconnectionBanner extends StatelessWidget {
  const ReconnectionBanner({
    super.key,
    required this.reconnectionState,
    required this.onRetry,
    required this.onGoHome,
  });

  final ReconnectionState reconnectionState;
  final VoidCallback onRetry;
  final VoidCallback onGoHome;

  @override
  Widget build(BuildContext context) {
    return switch (reconnectionState) {
      ReconnectionState.reconnecting => _buildTopBanner(context),
      ReconnectionState.failed       => _buildFailedModal(context),
      _                              => const SizedBox.shrink(),
    };
  }

  // ── Slim top banner (non-blocking) ────────────────────────────────────────

  Widget _buildTopBanner(BuildContext context) {
    return Positioned(
      top: 0, left: 0, right: 0,
      child: SafeArea(
        bottom: false,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          child: PerformanceBlur(
            borderRadius: BorderRadius.circular(14),
            sigmaX: 14,
            sigmaY: 14,
            child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16, vertical: 10,
                ),
                decoration: BoxDecoration(
                  color: AppTheme.navyDark.withValues(alpha: 0.88),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                    color: AppTheme.accentBlue.withValues(alpha: 0.45),
                    width: 1.2,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: AppTheme.accentBlue.withValues(alpha: 0.18),
                      blurRadius: 18,
                      spreadRadius: 1,
                    ),
                  ],
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const SizedBox(
                      width: 16, height: 16,
                      child: CircularProgressIndicator(
                        color: AppTheme.accentBlue,
                        strokeWidth: 2,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Flexible(
                      child: Text(
                        'جاري إعادة الاتصال…',
                        style: GoogleFonts.cairo(
                          color: AppTheme.accentLight,
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      );
    }

  // ── Full-screen failure modal ─────────────────────────────────────────────

  Widget _buildFailedModal(BuildContext context) {
    return Positioned.fill(
      child: ColoredBox(
        color: Colors.black.withValues(alpha: 0.72),
        child: Center(
          child: Container(
            margin: const EdgeInsets.symmetric(horizontal: 28),
            padding: const EdgeInsets.all(28),
            constraints: const BoxConstraints(maxWidth: 400),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFF1A235A), AppTheme.navyDark],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(24),
              border: Border.all(
                color: AppTheme.errorRed.withValues(alpha: 0.45),
                width: 1.5,
              ),
              boxShadow: [
                BoxShadow(
                  color: AppTheme.errorRed.withValues(alpha: 0.12),
                  blurRadius: 40,
                  spreadRadius: 4,
                ),
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.4),
                  blurRadius: 20,
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Icon
                Container(
                  width: 72, height: 72,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: AppTheme.errorRed.withValues(alpha: 0.12),
                    border: Border.all(
                      color: AppTheme.errorRed.withValues(alpha: 0.3),
                    ),
                  ),
                  child: const AppIcon(
                    AppIcons.wifiOff,
                    color: AppTheme.errorRed,
                    size: 36,
                  ),
                ),
                const SizedBox(height: 16),

                // Title
                Text(
                  'انقطع الاتصال',
                  style: GoogleFonts.cairo(
                    color: AppTheme.textPrimary,
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 8),

                // Subtitle
                Text(
                  'تعذّر الاتصال بغرفة اللعب.\nتحقق من اتصالك بالإنترنت وحاول مجدداً.',
                  style: GoogleFonts.cairo(
                    color: AppTheme.textSecondary,
                    fontSize: 13,
                    height: 1.6,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 24),

                // Action buttons
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: onGoHome,
                        icon: const AppIcon(
                          AppIcons.home,
                          size: 18,
                          color: AppTheme.textSecondary,
                        ),
                        label: Text(
                          'الرئيسية',
                          style: GoogleFonts.cairo(
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: AppTheme.textSecondary,
                          side: const BorderSide(color: Colors.white24, width: 1.5),
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: onRetry,
                        icon: const AppIcon(AppIcons.refresh, size: 18),
                        label: Text(
                          'إعادة المحاولة',
                          style: GoogleFonts.cairo(
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppTheme.accentBlue,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
