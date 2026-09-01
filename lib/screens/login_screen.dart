// lib/screens/login_screen.dart

import 'dart:async';
import 'dart:ui';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../core/icons/app_icons.dart';
import '../core/utils/snackbar_helper.dart';
import '../core/widgets/google_sign_in_button.dart';
import '../core/widgets/mode_home_shell.dart';
import '../services/auth_service.dart';
import '../services/profile_service.dart';
import '../services/settings_service.dart';
import '../theme/app_theme.dart';
import '../core/constants.dart';

abstract final class _LoginPalette {
  static const deepViolet = Color(0xFF2E2858);
  static const softViolet = Color(0xFF5A528C);
  static const periwinkle = Color(0xFFA8A0D8);
  static const coral = Color(0xFFE07A6A);
  static const cardTop = Color(0xE8FFFFFF);
  static const cardBottom = Color(0xD0EEE8FA);
}

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  StreamSubscription<AuthState>? _authSubscription;
  bool _isGuestLoading = false;

  @override
  void initState() {
    super.initState();
    if (kIsWeb) {
      _authSubscription =
          Supabase.instance.client.auth.onAuthStateChange.listen((data) {
        final user = data.session?.user;
        if (user != null && !user.isAnonymous && mounted) {
          unawaited(_completeAndNavigate());
        }
      });
    }
  }

  @override
  void dispose() {
    _authSubscription?.cancel();
    super.dispose();
  }

  Future<void> _completeAndNavigate() async {
    await SettingsService.instance.markLoginGateCompleted();
  }

  Future<bool> _handleGoogleSignIn() async {
    HapticFeedback.mediumImpact();
    try {
      final profile = await AuthService.instance.signInWithGoogle();
      if (!mounted) return false;
      if (profile != null) {
        SnackbarHelper.showSuccess(
          context,
          'مرحباً ${profile.username}!',
          title: 'تم تسجيل الدخول',
        );
        await _completeAndNavigate();
        return true;
      }
      return false;
    } catch (e) {
      if (!mounted) return false;
      SnackbarHelper.showError(
        context,
        'تعذر تسجيل الدخول. حاول مرة أخرى.',
        title: 'خطأ',
      );
      return false;
    }
  }

  Future<void> _handleGuestContinue() async {
    HapticFeedback.lightImpact();
    setState(() => _isGuestLoading = true);

    try {
      // Local-only — anonymous Supabase auth is optional and may be disabled.
      await ProfileService.ensureGuestAvatar();
      await _completeAndNavigate();
    } catch (e, stack) {
      debugPrint('[Login] guest continue failed: $e\n$stack');
      if (!mounted) return;
      setState(() => _isGuestLoading = false);
      SnackbarHelper.showError(
        context,
        'تعذر المتابعة. حاول مرة أخرى.',
        title: 'خطأ',
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        fit: StackFit.expand,
        children: [
          const ModeHomeBackground(
            wallpaperAsset: 'assets/wallpapers/login-wall.png',
            primaryGlow: AppTheme.phaseAuction,
            secondaryGlow: AppTheme.midBlue,
            subtleOverlay: true,
          ),
          SafeArea(
            child: LayoutBuilder(
              builder: (context, constraints) {
                final heroWidth =
                    (constraints.maxWidth * 0.72).clamp(220.0, 280.0);

                return Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  child: Column(
                    children: [
                      Spacer(flex: constraints.maxHeight < 700 ? 1 : 2),
                      Flexible(
                        flex: 4,
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Flexible(
                              child: Image.asset(
                                kAppLoginArtAsset,
                                width: heroWidth,
                                fit: BoxFit.contain,
                                filterQuality: FilterQuality.high,
                              ),
                            ),
                            const SizedBox(height: 16),
                            Text(
                              kAppName,
                              style: GoogleFonts.cairo(
                                fontSize: 34,
                                fontWeight: FontWeight.w900,
                                color: _LoginPalette.deepViolet,
                                height: 1.05,
                                shadows: [
                                  Shadow(
                                    color: Colors.white.withValues(alpha: 0.5),
                                    blurRadius: 8,
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 20),
                      _LoginAuthPanel(
                        onGoogleSignIn: _handleGoogleSignIn,
                        onGuestContinue: _handleGuestContinue,
                        isGuestLoading: _isGuestLoading,
                      ),
                      Spacer(flex: constraints.maxHeight < 700 ? 2 : 3),
                    ],
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _LoginAuthPanel extends StatelessWidget {
  final Future<bool> Function() onGoogleSignIn;
  final VoidCallback onGuestContinue;
  final bool isGuestLoading;

  const _LoginAuthPanel({
    required this.onGoogleSignIn,
    required this.onGuestContinue,
    required this.isGuestLoading,
  });

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(28),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 22, sigmaY: 22),
        child: Container(
          width: double.infinity,
          constraints: const BoxConstraints(maxWidth: 400),
          padding: const EdgeInsets.fromLTRB(20, 22, 20, 18),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(28),
            gradient: const LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [_LoginPalette.cardTop, _LoginPalette.cardBottom],
            ),
            border: Border.all(
              color: Colors.white.withValues(alpha: 0.7),
              width: 1.2,
            ),
            boxShadow: [
              BoxShadow(
                color: _LoginPalette.periwinkle.withValues(alpha: 0.28),
                blurRadius: 24,
                offset: const Offset(0, 10),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'مرحباً بك',
                textAlign: TextAlign.center,
                style: GoogleFonts.cairo(
                  fontSize: 22,
                  fontWeight: FontWeight.w800,
                  color: _LoginPalette.deepViolet,
                  height: 1.2,
                ),
              ),
              const SizedBox(height: 18),
              Consumer<AuthService>(
                builder: (context, auth, _) => GoogleSignInButton(
                  onSlide: onGoogleSignIn,
                  isLoading: auth.isLoading,
                  variant: GoogleSignInButtonVariant.login,
                ),
              ),
              const SizedBox(height: 14),
              const _OrDivider(),
              const SizedBox(height: 14),
              _GuestButton(
                onPressed: onGuestContinue,
                isLoading: isGuestLoading,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _OrDivider extends StatelessWidget {
  const _OrDivider();

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Divider(
            color: _LoginPalette.periwinkle.withValues(alpha: 0.4),
            height: 1,
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          child: Text(
            'أو',
            style: GoogleFonts.cairo(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: _LoginPalette.softViolet,
            ),
          ),
        ),
        Expanded(
          child: Divider(
            color: _LoginPalette.periwinkle.withValues(alpha: 0.4),
            height: 1,
          ),
        ),
      ],
    );
  }
}

class _GuestButton extends StatefulWidget {
  final VoidCallback onPressed;
  final bool isLoading;

  const _GuestButton({
    required this.onPressed,
    required this.isLoading,
  });

  @override
  State<_GuestButton> createState() => _GuestButtonState();
}

class _GuestButtonState extends State<_GuestButton> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (_) => setState(() => _pressed = true),
      onTapUp: (_) {
        setState(() => _pressed = false);
        if (!widget.isLoading) widget.onPressed();
      },
      onTapCancel: () => setState(() => _pressed = false),
      child: AnimatedScale(
        scale: _pressed ? 0.98 : 1,
        duration: const Duration(milliseconds: 100),
        child: Container(
          height: 50,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(25),
            color: Colors.white.withValues(alpha: _pressed ? 0.5 : 0.62),
            border: Border.all(
              color: _LoginPalette.coral.withValues(alpha: 0.32),
            ),
          ),
          child: widget.isLoading
              ? SizedBox(
                  width: 22,
                  height: 22,
                  child: CircularProgressIndicator(
                    color: _LoginPalette.softViolet,
                    strokeWidth: 2.5,
                  ),
                )
              : Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    AppIcon(
                      AppIcons.person,
                      color: _LoginPalette.coral,
                      size: 18,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      'متابعة كضيف',
                      style: GoogleFonts.cairo(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        color: _LoginPalette.deepViolet,
                      ),
                    ),
                  ],
                ),
        ),
      ),
    );
  }
}
