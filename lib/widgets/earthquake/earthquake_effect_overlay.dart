// lib/widgets/earthquake/earthquake_effect_overlay.dart
//
// Overlay providing a continuous hand → air → table card flight, then
// violent screen-shake, glowing fissures, and shockwaves on impact.

import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../../core/events/estimation_event_bus.dart';
import '../../core/events/estimation_game_events.dart';
import '../../core/models/card.dart';
import '../../models/earthquake_effect.dart';
import '../../services/audio_service.dart';
import '../../services/settings_service.dart';
import '../playing_card_widget.dart';
import 'earthquake_crack_painter.dart';
import 'earthquake_timing.dart';

class EarthquakeEffectOverlay extends StatefulWidget {
  final Widget child;
  final VoidCallback? onSlamImpact;

  const EarthquakeEffectOverlay({
    super.key,
    required this.child,
    this.onSlamImpact,
  });

  /// Trigger earthquake effect programmatically from any context
  static void trigger(BuildContext context, {Offset? origin}) {
    final state =
        context.findAncestorStateOfType<_EarthquakeEffectOverlayState>();
    state?.triggerEarthquake(origin: origin);
  }

  @override
  State<EarthquakeEffectOverlay> createState() =>
      _EarthquakeEffectOverlayState();
}

class _EarthquakeEffectOverlayState extends State<EarthquakeEffectOverlay>
    with TickerProviderStateMixin {
  late final AnimationController _flightCtrl;
  late final AnimationController _shakeCtrl;
  late final AnimationController _crackCtrl;
  StreamSubscription? _eventSub;

  PlayingCard? _flyingCard;
  Offset _flightStart = Offset.zero;
  Offset _flightTarget = Offset.zero;
  Size _flightCardSize = const Size(60, 87);
  Offset _impactOrigin = Offset.zero;
  bool _impactFired = false;
  bool _showFlight = false;
  EarthquakeEffect _activeEffect = EarthquakeEffect.magma;

  @override
  void initState() {
    super.initState();

    _flightCtrl = AnimationController(
      vsync: this,
      duration: EarthquakeTiming.flightDuration,
    )..addListener(_onFlightTick);

    _shakeCtrl = AnimationController(
      vsync: this,
      duration: EarthquakeTiming.shakeDuration,
    );

    _crackCtrl = AnimationController(
      vsync: this,
      duration: EarthquakeTiming.crackDuration,
    );

    _eventSub =
        EstimationEventBus.instance.on<EarthquakeStrikeUsed>().listen((event) {
      _beginStrikeFlight(event);
    });
  }

  @override
  void dispose() {
    _eventSub?.cancel();
    _flightCtrl.removeListener(_onFlightTick);
    _flightCtrl.dispose();
    _shakeCtrl.dispose();
    _crackCtrl.dispose();
    super.dispose();
  }

  void _onFlightTick() {
    if (!_impactFired &&
        _flightCtrl.value >= EarthquakeTiming.impactFraction) {
      _fireImpact();
    }
    if (_flightCtrl.value >= 1.0 && _showFlight) {
      // Keep one more frame then clear the flying clone
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && _flightCtrl.isCompleted) {
          setState(() {
            _showFlight = false;
            _flyingCard = null;
          });
        }
      });
    }
  }

  void _beginStrikeFlight(EarthquakeStrikeUsed event) {
    if (!mounted) return;

    final media = MediaQuery.sizeOf(context);
    final tableCenter = Offset(
      media.width * 0.5,
      media.height * (media.height > media.width ? 0.38 : 0.40),
    );

    // Bottom seat slot sits slightly below table center
    final target = tableCenter.translate(0, media.height * 0.045);

    Offset start;
    Size cardSize;
    if (event.flightOriginGlobal != null) {
      start = event.flightOriginGlobal!;
      cardSize = event.flightCardSize ?? const Size(60, 87);
    } else {
      // Remote / no measured origin: dive in from above the table
      start = Offset(media.width * 0.5, -media.height * 0.12);
      cardSize = Size(
        media.shortestSide * 0.12,
        media.shortestSide * 0.12 / playingCardAspectRatio,
      );
    }

    setState(() {
      _activeEffect = SettingsService.instance.earthquakeEffect;
      _flyingCard = event.card;
      _flightStart = start;
      _flightTarget = target;
      _flightCardSize = cardSize;
      _impactOrigin = target;
      _impactFired = false;
      _showFlight = true;
    });

    _shakeCtrl.reset();
    _crackCtrl.reset();
    _flightCtrl
      ..reset()
      ..forward();
  }

  /// Direct impact trigger (no flight) — used by static helper / tests.
  void triggerEarthquake({Offset? origin}) {
    if (!mounted) return;
    setState(() {
      _activeEffect = SettingsService.instance.earthquakeEffect;
      _impactOrigin = origin ??
          Offset(
            MediaQuery.sizeOf(context).width / 2,
            MediaQuery.sizeOf(context).height * 0.4,
          );
      _showFlight = false;
      _flyingCard = null;
    });
    _fireImpact();
  }

  void _fireImpact() {
    if (_impactFired) return;
    _impactFired = true;

    AudioService.instance.playEarthquakeSlam();

    _shakeCtrl
      ..reset()
      ..forward();
    _crackCtrl
      ..reset()
      ..forward();
    widget.onSlamImpact?.call();
  }

  /// Bezier-style path: hand → high apex → slam onto table.
  Offset _flightPosition(double t) {
    final start = _flightStart;
    final end = _flightTarget;

    if (_activeEffect == EarthquakeEffect.frost) {
      final eased = t < EarthquakeTiming.impactFraction
          ? Curves.easeInQuart.transform(
              (t / EarthquakeTiming.impactFraction).clamp(0.0, 1.0),
            )
          : 1.0;
      return Offset.lerp(start, end, eased)!;
    }

    if (_activeEffect == EarthquakeEffect.voidRift) {
      final eased = Curves.easeInCubic.transform(
        (t / EarthquakeTiming.impactFraction).clamp(0.0, 1.0),
      );
      final base = Offset.lerp(start, end, eased)!;
      final snap = math.sin(t * math.pi * 10.0).sign;
      final lateral = 42.0 * (1.0 - eased) * snap;
      return base + Offset(lateral, -lateral * 0.28);
    }

    final apex = Offset(
      (start.dx + end.dx) * 0.5 + (end.dx - start.dx) * 0.08,
      math.min(start.dy, end.dy) - 160.0 - (start.dy - end.dy).abs() * 0.15,
    );

    if (t <= 0.42) {
      final u = Curves.easeOutCubic.transform(t / 0.42);
      return _quadBezier(start, apex, end, u * 0.55);
    }

    if (t <= EarthquakeTiming.impactFraction) {
      final localT =
          (t - 0.42) / (EarthquakeTiming.impactFraction - 0.42);
      final u = Curves.easeInCubic.transform(localT.clamp(0.0, 1.0));
      // Continue from mid-arc into the dive
      final mid = _quadBezier(start, apex, end, 0.55);
      return Offset.lerp(mid, end, u)!;
    }

    // Soft settle after impact
    return end;
  }

  Offset _quadBezier(Offset p0, Offset p1, Offset p2, double t) {
    final mt = 1.0 - t;
    return Offset(
      mt * mt * p0.dx + 2 * mt * t * p1.dx + t * t * p2.dx,
      mt * mt * p0.dy + 2 * mt * t * p1.dy + t * t * p2.dy,
    );
  }

  double _flightScale(double t) {
    if (t < 0.42) {
      return 1.0 + Curves.easeOut.transform(t / 0.42) * 0.55;
    }
    if (t < EarthquakeTiming.impactFraction) {
      final local =
          (t - 0.42) / (EarthquakeTiming.impactFraction - 0.42);
      return 1.55 - Curves.easeIn.transform(local) * 0.35;
    }
    // Impact squash then recover
    final settle = ((t - EarthquakeTiming.impactFraction) /
            (1.0 - EarthquakeTiming.impactFraction))
        .clamp(0.0, 1.0);
    final squash = settle < 0.35
        ? 1.0 - (settle / 0.35) * 0.22
        : 0.78 + ((settle - 0.35) / 0.65) * 0.22;
    return squash;
  }

  double _flightRotation(double t) {
    if (_activeEffect == EarthquakeEffect.frost) {
      return math.sin(t * math.pi) * 0.04;
    }
    if (_activeEffect == EarthquakeEffect.voidRift) {
      return math.sin(t * math.pi * 10.0).sign * 0.18;
    }
    if (t < EarthquakeTiming.impactFraction) {
      return math.sin(t * math.pi * 1.6) * 0.35 + t * 0.15;
    }
    final settle = ((t - EarthquakeTiming.impactFraction) /
            (1.0 - EarthquakeTiming.impactFraction))
        .clamp(0.0, 1.0);
    return (1.0 - Curves.easeOutBack.transform(settle)) * 0.28;
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: Listenable.merge([_flightCtrl, _shakeCtrl, _crackCtrl]),
      builder: (context, child) {
        final shakeProgress = _shakeCtrl.value;
        final crackProgress = _crackCtrl.value;
        final flightT = _flightCtrl.value;

        double dx = 0;
        double dy = 0;
        double angle = 0;
        double sceneScale = 1.0;

        if (_shakeCtrl.isAnimating ||
            (_shakeCtrl.value > 0 && _shakeCtrl.value < 1)) {
          final decay = math.pow(1.0 - shakeProgress, 1.65).toDouble();
          final time = shakeProgress * 42.0;

          switch (_activeEffect) {
            case EarthquakeEffect.magma:
              dx = (math.sin(time * 3.4) * 18.0 +
                      math.cos(time * 5.6) * 10.0 +
                      math.sin(time * 7.1) * 4.0) *
                  decay;
              dy = (math.cos(time * 3.0) * 16.0 +
                      math.sin(time * 4.8) * 9.0 +
                      math.cos(time * 6.3) * 3.5) *
                  decay;
              angle = math.sin(time * 2.4) * 0.022 * decay;
              break;
            case EarthquakeEffect.frost:
              dx = (math.sin(time * 7.5) * 10.0 +
                      math.cos(time * 11.0) * 5.0) *
                  decay;
              dy = (math.cos(time * 8.5) * 8.0 +
                      math.sin(time * 13.0) * 4.0) *
                  decay;
              angle = math.sin(time * 6.0) * 0.012 * decay;
              break;
            case EarthquakeEffect.voidRift:
              final split = math.sin(shakeProgress * math.pi * 6.0).sign;
              dx = split * 16.0 * decay;
              dy = math.sin(time * 5.0) * 4.0 * decay;
              angle = split * 0.018 * decay;
              sceneScale = 1.0 + math.sin(shakeProgress * math.pi) * 0.018;
              break;
          }
        }

        final vignetteColors = switch (_activeEffect) {
          EarthquakeEffect.magma => const [
              Color(0xFFFFF59D),
              Color(0xFFFF6F00),
            ],
          EarthquakeEffect.frost => const [
              Color(0xFFE0F2FE),
              Color(0xFF38BDF8),
            ],
          EarthquakeEffect.voidRift => const [
              Color(0xFFF5D0FE),
              Color(0xFF7E22CE),
            ],
        };

        return Stack(
          children: [
            // ── 1. Shaking Screen Layer ─────────────────────────────
            Transform(
              alignment: Alignment.center,
              transform: Matrix4.identity()
                ..translateByDouble(dx, dy, 0.0, 1.0)
                ..rotateZ(angle)
                ..scaleByDouble(sceneScale, sceneScale, 1.0, 1.0),
              child: widget.child,
            ),

            // ── 2. Flying strike card (continuous path) ─────────────
            if (_showFlight && _flyingCard != null)
              Positioned.fill(
                child: IgnorePointer(
                  child: _buildFlyingCard(flightT),
                ),
              ),

            // ── 3. Ground Crack Fissures & Shockwave Overlay ─────────
            if (_crackCtrl.isAnimating ||
                (_crackCtrl.value > 0 && _crackCtrl.value < 1))
              Positioned.fill(
                child: IgnorePointer(
                  child: RepaintBoundary(
                    child: CustomPaint(
                      painter: EarthquakeCrackPainter(
                        progress: crackProgress,
                        origin: _impactOrigin,
                        effect: _activeEffect,
                      ),
                    ),
                  ),
                ),
              ),

            // ── 4. Screen Impact Vignette Flash ──────────────────────
            if (_shakeCtrl.isAnimating ||
                (_shakeCtrl.value > 0 && _shakeCtrl.value < 1))
              Positioned.fill(
                child: IgnorePointer(
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: RadialGradient(
                        center: Alignment(
                          ((_impactOrigin.dx / MediaQuery.sizeOf(context).width) -
                                  0.5) *
                              2,
                          ((_impactOrigin.dy /
                                      MediaQuery.sizeOf(context).height) -
                                  0.5) *
                              2,
                        ),
                        colors: [
                          vignetteColors[0].withValues(
                            alpha: ((1.0 - shakeProgress) * 0.28)
                                .clamp(0.0, 1.0),
                          ),
                          vignetteColors[1].withValues(
                            alpha: ((1.0 - shakeProgress) * 0.16)
                                .clamp(0.0, 1.0),
                          ),
                          Colors.transparent,
                        ],
                        radius: 1.15,
                      ),
                    ),
                  ),
                ),
              ),
          ],
        );
      },
    );
  }

  Widget _buildFlyingCard(double t) {
    final pos = _flightPosition(t);
    final scale = _flightScale(t);
    final rot = _flightRotation(t);
    final w = _flightCardSize.width;
    final h = _flightCardSize.height;

    // Height proxy for shadow (higher early/mid flight)
    final heightFactor = t < 0.42
        ? t / 0.42
        : t < EarthquakeTiming.impactFraction
            ? 1.0 -
                (t - 0.42) /
                    (EarthquakeTiming.impactFraction - 0.42) *
                    0.85
            : 0.05;

    final opacity = t > 0.92 ? (1.0 - (t - 0.92) / 0.08).clamp(0.0, 1.0) : 1.0;

    // Motion trail ghosts
    final trail = <Widget>[];
    if (t > 0.05 && t < EarthquakeTiming.impactFraction) {
      for (int i = 3; i >= 1; i--) {
        final trailT = (t - i * 0.035).clamp(0.0, 1.0);
        final trailPos = _flightPosition(trailT);
        trail.add(Positioned(
          left: trailPos.dx - w / 2,
          top: trailPos.dy - h / 2,
          child: Opacity(
            opacity: 0.18 * (1.0 - i * 0.25) * opacity,
            child: Transform.rotate(
              angle: _flightRotation(trailT),
              child: Transform.scale(
                scale: _flightScale(trailT) * 0.96,
                child: PlayingCardWidget(
                  card: _flyingCard,
                  width: w,
                  playable: false,
                  selected: false,
                ),
              ),
            ),
          ),
        ));
      }
    }

    return Stack(
      children: [
        ...trail,
        // Dynamic ground shadow
        Positioned(
          left: _flightTarget.dx - w * 0.45 * (0.6 + heightFactor * 0.5),
          top: _flightTarget.dy + h * 0.35,
          child: Opacity(
            opacity: (0.15 + heightFactor * 0.35) * opacity,
            child: Container(
              width: w * (0.7 + heightFactor * 0.6),
              height: h * 0.18,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(40),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.45),
                    blurRadius: 18 + heightFactor * 24,
                    spreadRadius: 2 + heightFactor * 6,
                  ),
                ],
              ),
            ),
          ),
        ),
        // Main flying card
        Positioned(
          left: pos.dx - w / 2,
          top: pos.dy - h / 2,
          child: Opacity(
            opacity: opacity,
            child: Transform.rotate(
              angle: rot,
              child: Transform.scale(
                scale: scale,
                child: Stack(
                  alignment: Alignment.center,
                  clipBehavior: Clip.none,
                  children: [
                    // Charge / power aura
                    if (t < EarthquakeTiming.impactFraction)
                      Container(
                        width: w + 28,
                        height: h + 28,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(18),
                          boxShadow: [
                            BoxShadow(
                              color: _activeEffect.primaryColor.withValues(
                                alpha: 0.35 + 0.35 * (1.0 - t),
                              ),
                              blurRadius: 28,
                              spreadRadius: 8,
                            ),
                            BoxShadow(
                              color: _activeEffect.secondaryColor.withValues(
                                alpha: 0.25 + heightFactor * 0.3,
                              ),
                              blurRadius: 16,
                              spreadRadius: 4,
                            ),
                          ],
                        ),
                      ),
                    PlayingCardWidget(
                      card: _flyingCard,
                      width: w,
                      playable: false,
                      selected: false,
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}
