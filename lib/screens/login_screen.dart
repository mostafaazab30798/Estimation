// lib/screens/login_screen.dart

import 'dart:async';
import 'dart:math' as math;
import 'dart:ui';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../core/icons/app_icons.dart';
import '../core/utils/snackbar_helper.dart';
import '../core/widgets/google_sign_in_button.dart';
import '../core/widgets/mode_home_shell.dart';
import '../services/audio_service.dart';
import '../services/auth_service.dart';
import '../services/profile_service.dart';
import '../services/settings_service.dart';
import '../theme/app_theme.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _floatController;
  StreamSubscription<AuthState>? _authSubscription;
  bool _isGuestLoading = false;

  @override
  void initState() {
    super.initState();
    _floatController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 4200),
    )..repeat();

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
    _floatController.dispose();
    _authSubscription?.cancel();
    super.dispose();
  }

  Future<void> _completeAndNavigate() async {
    await SettingsService.instance.markLoginGateCompleted();
  }

  Future<bool> _handleGoogleSignIn() async {
    HapticFeedback.mediumImpact();
    AudioService.instance.playCard();
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
    AudioService.instance.playCard();
    setState(() => _isGuestLoading = true);

    try {
      final auth = Supabase.instance.client.auth;
      if (auth.currentUser == null) {
        await auth.signInAnonymously();
      }
      await ProfileService.ensureGuestAvatar();
      await _completeAndNavigate();
    } catch (e) {
      if (!mounted) return;
      setState(() => _isGuestLoading = false);
      SnackbarHelper.showError(
        context,
        'تعذر المتابعة. تحقق من الاتصال بالإنترنت.',
        title: 'خطأ',
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final isCompact = size.height < 700;

    return Scaffold(
      backgroundColor: AppTheme.deepNavy,
      body: Stack(
        fit: StackFit.expand,
        children: [
          const ModeHomeBackground(
            wallpaperAsset: 'assets/wallpapers/w2.jpg',
            primaryGlow: AppTheme.gold,
            secondaryGlow: AppTheme.phaseAuction,
          ),
          SafeArea(
            child: Column(
              children: [
                Expanded(
                  child: SingleChildScrollView(
                    physics: const BouncingScrollPhysics(),
                    padding: EdgeInsets.symmetric(
                      horizontal: 24,
                      vertical: isCompact ? 12 : 20,
                    ),
                    child: Column(
                      children: [
                        SizedBox(height: isCompact ? 8 : 24),
                        _LoginHero(
                          floatAnimation: _floatController,
                          compact: isCompact,
                        ),
                        SizedBox(height: isCompact ? 20 : 32),
                        _LoginAuthPanel(
                          onGoogleSignIn: _handleGoogleSignIn,
                          onGuestContinue: _handleGuestContinue,
                          isGuestLoading: _isGuestLoading,
                        ),
                        SizedBox(height: isCompact ? 16 : 24),
                      ],
                    ),
                  ),
                ),
                const ModeHomeSuitFooter(),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ── Hero ─────────────────────────────────────────────────────────────────────

class _LoginHero extends StatelessWidget {
  final Animation<double> floatAnimation;
  final bool compact;

  const _LoginHero({
    required this.floatAnimation,
    this.compact = false,
  });

  @override
  Widget build(BuildContext context) {
    final imageWidth = compact ? 240.0 : 280.0;

    return Column(
      children: [
        AnimatedBuilder(
          animation: floatAnimation,
          builder: (context, child) {
            final t = floatAnimation.value * math.pi * 2;
            final bob = math.sin(t) * 5;
            return Transform.translate(
              offset: Offset(0, bob),
              child: child,
            );
          },
          child: Image.asset(
            'assets/p1.png',
            width: imageWidth,
            fit: BoxFit.contain,
            filterQuality: FilterQuality.high,
          ),
        )
            .animate()
            .fadeIn(duration: 600.ms, curve: Curves.easeOut)
            .scale(
              begin: const Offset(0.92, 0.92),
              end: const Offset(1, 1),
              duration: 700.ms,
              curve: Curves.easeOutBack,
            ),
        SizedBox(height: compact ? 14 : 20),
        Text(
          'كوتشينة',
          style: GoogleFonts.cairo(
            fontSize: compact ? 30 : 38,
            fontWeight: FontWeight.w900,
            color: AppTheme.white,
            letterSpacing: 0.5,
            height: 1.05,
            shadows: [
              Shadow(
                color: Colors.black.withValues(alpha: 0.45),
                blurRadius: 12,
                offset: const Offset(0, 3),
              ),
            ],
          ),
        )
            .animate(delay: 120.ms)
            .fadeIn(duration: 500.ms)
            .slideY(begin: 0.15, end: 0, curve: Curves.easeOutCubic),
      ],
    );
  }
}

// ── Auth Panel ───────────────────────────────────────────────────────────────

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
        filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
        child: Container(
          width: double.infinity,
          constraints: const BoxConstraints(maxWidth: 420),
          padding: const EdgeInsets.fromLTRB(22, 26, 22, 22),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                AppTheme.surface2.withValues(alpha: 0.82),
                AppTheme.deepNavy.withValues(alpha: 0.88),
              ],
            ),
            borderRadius: BorderRadius.circular(28),
            border: Border.all(
              color: AppTheme.steelBlue.withValues(alpha: 0.22),
              width: 1.2,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.35),
                blurRadius: 24,
                offset: const Offset(0, 10),
              ),
              BoxShadow(
                color: AppTheme.gold.withValues(alpha: 0.06),
                blurRadius: 40,
                spreadRadius: 2,
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'مرحباً بك',
                textAlign: TextAlign.center,
                style: GoogleFonts.cairo(
                  fontSize: 20,
                  fontWeight: FontWeight.w800,
                  color: AppTheme.cream,
                ),
              ),
              const SizedBox(height: 22),
              Consumer<AuthService>(
                builder: (context, auth, _) => GoogleSignInButton(
                  onSlide: onGoogleSignIn,
                  isLoading: auth.isLoading,
                ),
              ),
              const SizedBox(height: 16),
              _OrDivider(),
              const SizedBox(height: 16),
              _GuestButton(
                onPressed: onGuestContinue,
                isLoading: isGuestLoading,
              ),
            ],
          ),
        ),
      ),
    )
        .animate(delay: 280.ms)
        .fadeIn(duration: 550.ms, curve: Curves.easeOut)
        .slideY(begin: 0.08, end: 0, curve: Curves.easeOutCubic);
  }
}

class _OrDivider extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Container(
            height: 1,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  Colors.transparent,
                  AppTheme.steelBlue.withValues(alpha: 0.35),
                ],
              ),
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14),
          child: Text(
            'أو',
            style: GoogleFonts.cairo(
              fontSize: 12,
              color: AppTheme.steelBlue.withValues(alpha: 0.8),
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
        Expanded(
          child: Container(
            height: 1,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  AppTheme.steelBlue.withValues(alpha: 0.35),
                  Colors.transparent,
                ],
              ),
            ),
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
        scale: _pressed ? 0.97 : 1.0,
        duration: const Duration(milliseconds: 100),
        child: Container(
          width: double.infinity,
          height: 54,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: AppTheme.steelBlue.withValues(alpha: 0.45),
              width: 1.4,
            ),
            color: Colors.white.withValues(alpha: 0.05),
          ),
          child: widget.isLoading
              ? const Center(
                  child: SizedBox(
                    width: 22,
                    height: 22,
                    child: CircularProgressIndicator(
                      color: AppTheme.steelBlue,
                      strokeWidth: 2.5,
                    ),
                  ),
                )
              : Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const AppIcon(
                      AppIcons.person,
                      color: AppTheme.steelBlue,
                      size: 20,
                    ),
                    const SizedBox(width: 10),
                    Text(
                      'متابعة كضيف',
                      style: GoogleFonts.cairo(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        color: AppTheme.cream,
                      ),
                    ),
                  ],
                ),
        ),
      ),
    );
  }
}
