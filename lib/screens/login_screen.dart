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
import '../services/settings_service.dart';
import '../theme/app_theme.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen>
    with TickerProviderStateMixin {
  late final AnimationController _floatController;
  late final AnimationController _glowController;
  StreamSubscription<AuthState>? _authSubscription;
  bool _isGuestLoading = false;

  static final _featureItems = [
    _LoginFeature(
      icon: AppIcons.cloudSync,
      label: 'مزامنة XP والتقدم',
      color: AppTheme.gold,
    ),
    _LoginFeature(
      icon: AppIcons.leaderboard,
      label: 'لوحة المتصدرين',
      color: AppTheme.rankGold,
    ),
    _LoginFeature(
      icon: AppIcons.history,
      label: 'سجل المباريات السحابي',
      color: AppTheme.midBlue,
    ),
  ];

  @override
  void initState() {
    super.initState();
    _floatController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 4200),
    )..repeat();
    _glowController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2800),
    )..repeat(reverse: true);

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
    _glowController.dispose();
    _authSubscription?.cancel();
    super.dispose();
  }

  Future<void> _completeAndNavigate() async {
    await SettingsService.instance.markLoginGateCompleted();
  }

  Future<void> _handleGoogleSignIn() async {
    HapticFeedback.mediumImpact();
    AudioService.instance.playCard();
    try {
      final profile = await AuthService.instance.signInWithGoogle();
      if (!mounted) return;
      if (profile != null) {
        SnackbarHelper.showSuccess(
          context,
          'مرحباً ${profile.username}!',
          title: 'تم تسجيل الدخول',
        );
        await _completeAndNavigate();
      }
    } catch (e) {
      if (!mounted) return;
      SnackbarHelper.showError(
        context,
        'تعذر تسجيل الدخول. حاول مرة أخرى.',
        title: 'خطأ',
      );
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
                          glowAnimation: _glowController,
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
  final Animation<double> glowAnimation;
  final bool compact;

  const _LoginHero({
    required this.floatAnimation,
    required this.glowAnimation,
    this.compact = false,
  });

  @override
  Widget build(BuildContext context) {
    final emblemSize = compact ? 96.0 : 112.0;

    return Column(
      children: [
        SizedBox(
          height: compact ? 130 : 160,
          child: Stack(
            alignment: Alignment.center,
            clipBehavior: Clip.none,
            children: [
              _FloatingCard(
                animation: floatAnimation,
                phase: 0,
                offset: const Offset(-52, -18),
                rotation: -0.22,
                asset: 'assets/estimation.png',
                width: compact ? 52 : 60,
              ),
              _FloatingCard(
                animation: floatAnimation,
                phase: 0.33,
                offset: const Offset(58, -8),
                rotation: 0.18,
                asset: 'assets/basra.png',
                width: compact ? 48 : 56,
              ),
              _FloatingCard(
                animation: floatAnimation,
                phase: 0.66,
                offset: const Offset(0, 42),
                rotation: 0.06,
                asset: 'assets/99.png',
                width: compact ? 44 : 52,
              ),
              AnimatedBuilder(
                animation: glowAnimation,
                builder: (context, child) {
                  final glow = 0.55 + (glowAnimation.value * 0.45);
                  return Container(
                    width: emblemSize + 28,
                    height: emblemSize + 28,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: AppTheme.gold.withValues(alpha: 0.22 * glow),
                          blurRadius: 36 * glow,
                          spreadRadius: 4 * glow,
                        ),
                      ],
                    ),
                    child: child,
                  );
                },
                child: _BrandEmblem(size: emblemSize),
              ),
            ],
          ),
        )
            .animate()
            .fadeIn(duration: 600.ms, curve: Curves.easeOut)
            .scale(
              begin: const Offset(0.88, 0.88),
              end: const Offset(1, 1),
              duration: 700.ms,
              curve: Curves.easeOutBack,
            ),
        SizedBox(height: compact ? 12 : 18),
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
        const SizedBox(height: 6),
        Text(
          'العب. تنافس. تقدّم.',
          style: GoogleFonts.cairo(
            fontSize: compact ? 13 : 14.5,
            color: AppTheme.steelBlue,
            fontWeight: FontWeight.w600,
            letterSpacing: 0.3,
          ),
        )
            .animate(delay: 200.ms)
            .fadeIn(duration: 500.ms)
            .slideY(begin: 0.12, end: 0, curve: Curves.easeOutCubic),
      ],
    );
  }
}

class _BrandEmblem extends StatelessWidget {
  final double size;

  const _BrandEmblem({required this.size});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF1A2E40), Color(0xFF0D1E2E)],
        ),
        border: Border.all(
          color: AppTheme.gold.withValues(alpha: 0.55),
          width: 2,
        ),
        boxShadow: AppTheme.neumorphicExtruded,
      ),
      child: ClipOval(
        child: Padding(
          padding: EdgeInsets.all(size * 0.06),
          child: Image.asset(
            'assets/cards.png',
            fit: BoxFit.contain,
            filterQuality: FilterQuality.high,
            errorBuilder: (_, __, ___) => const Center(
              child: AppIcon(
                AppIcons.style,
                color: AppTheme.gold,
                size: 40,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _FloatingCard extends StatelessWidget {
  final Animation<double> animation;
  final double phase;
  final Offset offset;
  final double rotation;
  final String asset;
  final double width;

  const _FloatingCard({
    required this.animation,
    required this.phase,
    required this.offset,
    required this.rotation,
    required this.asset,
    required this.width,
  });

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: animation,
      builder: (context, child) {
        final t = (animation.value + phase) % 1.0;
        final bob = math.sin(t * math.pi * 2) * 6;
        final drift = math.cos(t * math.pi * 2) * 3;
        return Transform.translate(
          offset: Offset(offset.dx + drift, offset.dy + bob),
          child: Transform.rotate(
            angle: rotation + math.sin(t * math.pi * 2) * 0.04,
            child: child,
          ),
        );
      },
      child: Container(
        width: width,
        height: width * 1.35,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(8),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.45),
              blurRadius: 14,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: Image.asset(
            asset,
            fit: BoxFit.cover,
            filterQuality: FilterQuality.high,
          ),
        ),
      ),
    );
  }
}

// ── Auth Panel ───────────────────────────────────────────────────────────────

class _LoginAuthPanel extends StatelessWidget {
  final VoidCallback onGoogleSignIn;
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
              const SizedBox(height: 4),
              Text(
                'سجّل دخولك لمزامنة تقدمك أو تابع كضيف',
                textAlign: TextAlign.center,
                style: GoogleFonts.cairo(
                  fontSize: 12.5,
                  color: AppTheme.steelBlue,
                  fontWeight: FontWeight.w500,
                  height: 1.4,
                ),
              ),
              const SizedBox(height: 22),
              Consumer<AuthService>(
                builder: (context, auth, _) => GoogleSignInButton(
                  onPressed: onGoogleSignIn,
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
              const SizedBox(height: 22),
              _FeatureRow(items: _LoginScreenState._featureItems),
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

class _FeatureRow extends StatelessWidget {
  final List<_LoginFeature> items;

  const _FeatureRow({required this.items});

  @override
  Widget build(BuildContext context) {
    return Wrap(
      alignment: WrapAlignment.center,
      spacing: 8,
      runSpacing: 8,
      children: [
        for (int i = 0; i < items.length; i++)
          _FeatureChip(feature: items[i])
              .animate(delay: (420 + i * 80).ms)
              .fadeIn(duration: 400.ms)
              .slideY(begin: 0.1, end: 0),
      ],
    );
  }
}

class _FeatureChip extends StatelessWidget {
  final _LoginFeature feature;

  const _FeatureChip({required this.feature});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        color: feature.color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: feature.color.withValues(alpha: 0.28)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          AppIcon(feature.icon, color: feature.color, size: 14),
          const SizedBox(width: 6),
          Text(
            feature.label,
            style: GoogleFonts.cairo(
              fontSize: 10.5,
              fontWeight: FontWeight.w600,
              color: AppTheme.cream.withValues(alpha: 0.9),
            ),
          ),
        ],
      ),
    );
  }
}

class _LoginFeature {
  final AppIconData icon;
  final String label;
  final Color color;

  const _LoginFeature({
    required this.icon,
    required this.label,
    required this.color,
  });
}
