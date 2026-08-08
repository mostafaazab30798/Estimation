// lib/screens/mode_selection_screen.dart

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../theme/app_theme.dart';
import '../widgets/performance_blur.dart';

// ── Data model ──────────────────────────────────────────────────────────────

class _ModeData {
  final String title;
  final String subtitle;
  final String badgeText;
  final Color accentColor;
  final Color secondaryAccent;
  final String symbol;
  final String route;

  const _ModeData({
    required this.title,
    required this.subtitle,
    required this.badgeText,
    required this.accentColor,
    required this.secondaryAccent,
    required this.symbol,
    required this.route,
  });
}

// ── Screen ───────────────────────────────────────────────────────────────────

class ModeSelectionScreen extends StatefulWidget {
  const ModeSelectionScreen({super.key});

  @override
  State<ModeSelectionScreen> createState() => _ModeSelectionScreenState();
}

class _ModeSelectionScreenState extends State<ModeSelectionScreen>
    with TickerProviderStateMixin {
  // Entry animation
  late final AnimationController _entryCtrl;
  late final Animation<double> _fadeIn;
  late final Animation<Offset> _slideIn;

  // Ambient pulse
  late final AnimationController _pulseCtrl;
  late final Animation<double> _pulseAnim;

  // Staggered card animations
  late final List<AnimationController> _cardCtrls;
  late final List<Animation<double>> _cardFades;
  late final List<Animation<Offset>> _cardSlides;

  static const List<_ModeData> _modes = [
    _ModeData(
      title: 'إستميشن',
      subtitle: 'اللعبة الكلاسيكية بالمزايدات والتخمين',
      badgeText: 'كلاسيك',
      accentColor: AppTheme.gold,
      secondaryAccent: AppTheme.goldLight,
      symbol: '♠',
      route: '/kotchina/home',
    ),
    _ModeData(
      title: 'مود الـ 99',
      subtitle: 'وصّل الأرض لـ99 وإياك تكون الأخير',
      badgeText: 'جديد 🔥',
      accentColor: Color(0xFFEF4444),
      secondaryAccent: Color(0xFFFC8181),
      symbol: '99',
      route: '/ninety_nine/home',
    ),
  ];

  @override
  void initState() {
    super.initState();

    _entryCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 700),
    );
    _fadeIn = CurvedAnimation(parent: _entryCtrl, curve: Curves.easeOutCubic);
    _slideIn = Tween<Offset>(begin: const Offset(0, 0.05), end: Offset.zero)
        .animate(CurvedAnimation(parent: _entryCtrl, curve: Curves.easeOutCubic));

    _pulseCtrl = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 5),
    )..repeat(reverse: true);
    _pulseAnim = Tween<double>(begin: 0.0, end: 1.0)
        .animate(CurvedAnimation(parent: _pulseCtrl, curve: Curves.easeInOut));

    // Per-card staggered controllers
    _cardCtrls = List.generate(
      _modes.length,
      (i) => AnimationController(
        vsync: this,
        duration: const Duration(milliseconds: 600),
      ),
    );
    _cardFades = _cardCtrls.map((c) {
      return CurvedAnimation(parent: c, curve: Curves.easeOutCubic)
          as Animation<double>;
    }).toList();
    _cardSlides = _cardCtrls.map((c) {
      return Tween<Offset>(begin: const Offset(0, 0.12), end: Offset.zero)
          .animate(CurvedAnimation(parent: c, curve: Curves.easeOutCubic));
    }).toList();

    _entryCtrl.forward();
    _startCardStagger();
  }

  Future<void> _startCardStagger() async {
    for (int i = 0; i < _cardCtrls.length; i++) {
      await Future.delayed(Duration(milliseconds: 180 + i * 140));
      if (mounted) _cardCtrls[i].forward();
    }
  }

  @override
  void dispose() {
    _entryCtrl.dispose();
    _pulseCtrl.dispose();
    for (final c in _cardCtrls) {
      c.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final isLandscape = size.width > size.height;

    return Scaffold(
      backgroundColor: AppTheme.deepNavy,
      body: Stack(
        fit: StackFit.expand,
        children: [
          // ── Background ──────────────────────────────────────────
          Positioned.fill(
            child: Image.asset(
              'assets/wallpapers/w1.jpg',
              fit: BoxFit.cover,
              alignment: Alignment.center,
              gaplessPlayback: true,
              errorBuilder: (_, __, ___) => Container(
                decoration: const BoxDecoration(gradient: AppTheme.bgGradient),
              ),
            ),
          ),

          // ── Dark overlay ────────────────────────────────────────
          Positioned.fill(
            child: Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Colors.black.withValues(alpha: 0.62),
                    AppTheme.deepNavy.withValues(alpha: 0.90),
                    AppTheme.deepNavy,
                  ],
                  stops: const [0.0, 0.55, 1.0],
                ),
              ),
            ),
          ),

          // ── Ambient orbs ────────────────────────────────────────
          AnimatedBuilder(
            animation: _pulseAnim,
            builder: (_, __) {
              final t = _pulseAnim.value;
              return Stack(
                children: [
                  // Gold orb — top right
                  Positioned(
                    top: -80 + t * 20,
                    right: -80 + t * 10,
                    child: _Orb(
                      size: 320,
                      color: AppTheme.gold.withValues(alpha: 0.12 + t * 0.06),
                    ),
                  ),
                  // Red orb — bottom left
                  Positioned(
                    bottom: -80 + (1 - t) * 20,
                    left: -80 + (1 - t) * 10,
                    child: _Orb(
                      size: 280,
                      color: const Color(0xFFEF4444)
                          .withValues(alpha: 0.10 + (1 - t) * 0.05),
                    ),
                  ),
                ],
              );
            },
          ),

          // ── Main content ────────────────────────────────────────
          SafeArea(
            child: FadeTransition(
              opacity: _fadeIn,
              child: SlideTransition(
                position: _slideIn,
                child: isLandscape
                    ? _buildLandscapeLayout(context)
                    : _buildPortraitLayout(context),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ── Portrait ─────────────────────────────────────────────────────────────

  Widget _buildPortraitLayout(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SizedBox(height: 16),
        _buildHeader(),
        const SizedBox(height: 28),
        Expanded(
          child: SingleChildScrollView(
            physics: const BouncingScrollPhysics(),
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Column(
              children: [
                for (int i = 0; i < _modes.length; i++) ...[
                  if (i > 0) const SizedBox(height: 16),
                  _buildModeCard(i, context),
                ],
                const SizedBox(height: 24),
              ],
            ),
          ),
        ),
      ],
    );
  }

  // ── Landscape ────────────────────────────────────────────────────────────

  Widget _buildLandscapeLayout(BuildContext context) {
    return Column(
      children: [
        const SizedBox(height: 16),
        Expanded(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              // Left — header
              Expanded(
                flex: 3,
                child: Padding(
                  padding: const EdgeInsets.only(left: 24, right: 8),
                  child: _buildHeader(),
                ),
              ),
              // Right — cards
              Expanded(
                flex: 5,
                child: SingleChildScrollView(
                  physics: const BouncingScrollPhysics(),
                  padding: const EdgeInsets.fromLTRB(8, 0, 20, 16),
                  child: Column(
                    children: [
                      for (int i = 0; i < _modes.length; i++) ...[
                        if (i > 0) const SizedBox(height: 14),
                        _buildModeCard(i, context),
                      ],
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  // ── Header ───────────────────────────────────────────────────────────────

  Widget _buildHeader() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          // Eyebrow label
          Row(
            children: [
              Container(
                width: 3,
                height: 14,
                decoration: BoxDecoration(
                  color: AppTheme.gold,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(width: 8),
              Text(
                'استميشن مالتيبلاير',
                style: GoogleFonts.cairo(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: AppTheme.gold,
                  letterSpacing: 0.5,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            'اختر\nمود اللعب',
            style: GoogleFonts.cairo(
              fontSize: 34,
              fontWeight: FontWeight.w900,
              height: 1.1,
              color: AppTheme.cream,
            ),
          ),
          const SizedBox(height: 10),
          Text(
            'اختر المود المفضل واستمتع بالتحدي',
            style: GoogleFonts.cairo(
              fontSize: 13,
              color: AppTheme.steelBlue,
              height: 1.5,
            ),
          ),
        ],
      ),
    );
  }

  // ── Mode card ────────────────────────────────────────────────────────────

  Widget _buildModeCard(int index, BuildContext context) {
    return FadeTransition(
      opacity: _cardFades[index],
      child: SlideTransition(
        position: _cardSlides[index],
        child: _ModeCard(
          mode: _modes[index],
          onTap: () => Navigator.pushNamed(context, _modes[index].route),
        ),
      ),
    );
  }
}

// ── Orb helper ───────────────────────────────────────────────────────────────

class _Orb extends StatelessWidget {
  final double size;
  final Color color;
  const _Orb({required this.size, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: RadialGradient(
          colors: [color, Colors.transparent],
          stops: const [0.0, 1.0],
        ),
      ),
    );
  }
}

// ── Mode Card ────────────────────────────────────────────────────────────────

class _ModeCard extends StatefulWidget {
  final _ModeData mode;
  final VoidCallback onTap;

  const _ModeCard({required this.mode, required this.onTap});

  @override
  State<_ModeCard> createState() => _ModeCardState();
}

class _ModeCardState extends State<_ModeCard>
    with SingleTickerProviderStateMixin {
  bool _isPressed = false;
  late final AnimationController _shimmerCtrl;
  late final Animation<double> _shimmerAnim;

  @override
  void initState() {
    super.initState();
    _shimmerCtrl = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 3),
    )..repeat();
    _shimmerAnim = CurvedAnimation(parent: _shimmerCtrl, curve: Curves.linear);
  }

  @override
  void dispose() {
    _shimmerCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final mode = widget.mode;

    return GestureDetector(
      onTapDown: (_) => setState(() => _isPressed = true),
      onTapUp: (_) {
        setState(() => _isPressed = false);
        widget.onTap();
      },
      onTapCancel: () => setState(() => _isPressed = false),
      child: AnimatedScale(
        scale: _isPressed ? 0.975 : 1.0,
        duration: const Duration(milliseconds: 130),
        curve: Curves.easeOutCubic,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            boxShadow: [
              BoxShadow(
                color: mode.accentColor
                    .withValues(alpha: _isPressed ? 0.28 : 0.12),
                blurRadius: _isPressed ? 30 : 16,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(20),
            child: PerformanceBlur(
              borderRadius: BorderRadius.circular(20),
              sigmaX: 14,
              sigmaY: 14,
              child: Container(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(20),
                  color: AppTheme.deepNavy.withValues(alpha: 0.55),
                  border: Border.all(
                    color: _isPressed
                        ? mode.accentColor.withValues(alpha: 0.55)
                        : mode.accentColor.withValues(alpha: 0.22),
                    width: _isPressed ? 1.5 : 1.0,
                  ),
                ),
                child: Stack(
                  children: [
                    // Subtle shimmer sweep
                    Positioned.fill(
                      child: AnimatedBuilder(
                        animation: _shimmerAnim,
                        builder: (_, __) {
                          final dx = _shimmerAnim.value * 2 - 0.5;
                          return ShaderMask(
                            shaderCallback: (bounds) {
                              return LinearGradient(
                                begin: Alignment(dx - 0.6, -1),
                                end: Alignment(dx + 0.6, 1),
                                colors: [
                                  Colors.transparent,
                                  mode.accentColor.withValues(alpha: 0.04),
                                  Colors.transparent,
                                ],
                              ).createShader(bounds);
                            },
                            child: Container(
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(20),
                              ),
                            ),
                          );
                        },
                      ),
                    ),

                    // Content
                    Padding(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 20, vertical: 20),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Symbol icon
                          _SymbolBadge(
                            symbol: mode.symbol,
                            accentColor: mode.accentColor,
                            isPressed: _isPressed,
                          ),
                          const SizedBox(width: 18),

                          // Text content
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                // Badge + Title row
                                Row(
                                  crossAxisAlignment: CrossAxisAlignment.center,
                                  children: [
                                    Expanded(
                                      child: Text(
                                        mode.title,
                                        style: GoogleFonts.cairo(
                                          fontSize: 18,
                                          fontWeight: FontWeight.w800,
                                          color: AppTheme.cream,
                                          height: 1.2,
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    _BadgePill(
                                      text: mode.badgeText,
                                      color: mode.accentColor,
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 5),

                                // Subtitle
                                Text(
                                  mode.subtitle,
                                  style: GoogleFonts.cairo(
                                    fontSize: 12.5,
                                    color: AppTheme.steelBlue,
                                    height: 1.4,
                                  ),
                                ),
                              ],
                            ),
                          ),

                          // Arrow
                          const SizedBox(width: 12),
                          Align(
                            alignment: Alignment.center,
                            child: AnimatedContainer(
                              duration: const Duration(milliseconds: 200),
                              transform: Matrix4.translationValues(
                                  _isPressed ? -3 : 0, 0, 0),
                              child: Icon(
                                Icons.arrow_forward_ios_rounded,
                                color:
                                    mode.accentColor.withValues(alpha: 0.85),
                                size: 16,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),

                    // Bottom accent line
                    Positioned(
                      bottom: 0,
                      left: 0,
                      right: 0,
                      child: Container(
                        height: 2.5,
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [
                              Colors.transparent,
                              mode.accentColor.withValues(alpha: 0.6),
                              mode.secondaryAccent.withValues(alpha: 0.4),
                              Colors.transparent,
                            ],
                          ),
                          borderRadius: const BorderRadius.only(
                            bottomLeft: Radius.circular(20),
                            bottomRight: Radius.circular(20),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// ── Symbol badge ─────────────────────────────────────────────────────────────

class _SymbolBadge extends StatelessWidget {
  final String symbol;
  final Color accentColor;
  final bool isPressed;

  const _SymbolBadge({
    required this.symbol,
    required this.accentColor,
    required this.isPressed,
  });

  @override
  Widget build(BuildContext context) {
    final isNumber = symbol == '99';

    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      width: 60,
      height: 60,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        color: accentColor.withValues(alpha: isPressed ? 0.20 : 0.12),
        border: Border.all(
          color: accentColor.withValues(alpha: isPressed ? 0.60 : 0.35),
          width: 1.2,
        ),
        boxShadow: isPressed
            ? [
                BoxShadow(
                  color: accentColor.withValues(alpha: 0.25),
                  blurRadius: 16,
                  spreadRadius: 1,
                ),
              ]
            : null,
      ),
      alignment: Alignment.center,
      child: Text(
        symbol,
        style: GoogleFonts.cairo(
          fontSize: isNumber ? 22 : 30,
          fontWeight: FontWeight.w900,
          color: accentColor,
          height: 1,
        ),
      ),
    );
  }
}

// ── Badge pill ───────────────────────────────────────────────────────────────

class _BadgePill extends StatelessWidget {
  final String text;
  final Color color;
  const _BadgePill({required this.text, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(30),
        border: Border.all(color: color.withValues(alpha: 0.40), width: 0.8),
      ),
      child: Text(
        text,
        style: GoogleFonts.cairo(
          fontSize: 10.5,
          fontWeight: FontWeight.w700,
          color: color,
        ),
      ),
    );
  }
}

