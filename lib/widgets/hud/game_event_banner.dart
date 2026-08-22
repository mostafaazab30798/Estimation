// lib/widgets/hud/game_event_banner.dart
//
// Live micro-animated toast/banner for contextual Estimation game events on table HUD.

import 'dart:async';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../core/events/estimation_event_bus.dart';
import '../../core/events/estimation_game_events.dart';
import '../../theme/app_theme.dart';

class GameEventBanner extends StatefulWidget {
  final Duration displayDuration;

  const GameEventBanner({
    super.key,
    this.displayDuration = const Duration(milliseconds: 2400),
  });

  @override
  State<GameEventBanner> createState() => _GameEventBannerState();
}

class _GameEventBannerState extends State<GameEventBanner>
    with SingleTickerProviderStateMixin {
  late final AnimationController _animController;
  late final Animation<double> _fadeAnimation;
  late final Animation<Offset> _slideAnimation;

  StreamSubscription<EstimationGameEvent>? _eventSub;
  EstimationGameEvent? _currentEvent;
  Timer? _dismissTimer;

  // Set of events worth highlighting prominently in the floating HUD banner
  static final Set<String> _highlightedEvents = {
    'PlayerTakesLead',
    'DashCallMade',
    'RiskDeclaration',
    'ForbiddenDeclarationAttempt',
    'BidderTrickLost',
    'DoubleRoundStarted',
    'FinalRoundStarted',
    'ComebackDetected',
    'AllPlayersPassed',
    'AuctionWon',
  };

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );

    _fadeAnimation = CurvedAnimation(
      parent: _animController,
      curve: Curves.easeOut,
    );

    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, -0.5),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _animController,
      curve: Curves.easeOutBack,
    ));

    _eventSub = EstimationEventBus.instance.events.listen(_onGameEvent);
  }

  void _onGameEvent(EstimationGameEvent event) {
    if (!_highlightedEvents.contains(event.eventName)) return;

    if (!mounted) return;

    _dismissTimer?.cancel();
    setState(() {
      _currentEvent = event;
    });

    _animController.forward(from: 0.0);

    _dismissTimer = Timer(widget.displayDuration, () {
      if (mounted) {
        _animController.reverse().then((_) {
          if (mounted) {
            setState(() {
              _currentEvent = null;
            });
          }
        });
      }
    });
  }

  @override
  void dispose() {
    _dismissTimer?.cancel();
    _eventSub?.cancel();
    _animController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_currentEvent == null) return const SizedBox.shrink();

    final event = _currentEvent!;
    final isDanger = event is ForbiddenDeclarationAttempt ||
        event is BidderTrickLost ||
        event is DashCallFailed;
    final isGold = event is PlayerTakesLead ||
        event is AuctionWon ||
        event is FinalRoundStarted;
    final isElectric = event is DoubleRoundStarted ||
        event is AllPlayersPassed ||
        event is RiskDeclaration ||
        event is ComebackDetected;

    Color borderColor = AppTheme.gold;
    Color glowColor = AppTheme.gold.withValues(alpha: 0.3);
    Color bgGradientStart = AppTheme.navyDark.withValues(alpha: 0.92);
    Color bgGradientEnd = AppTheme.navyMid.withValues(alpha: 0.92);

    if (isDanger) {
      borderColor = AppTheme.errorRed;
      glowColor = AppTheme.errorRed.withValues(alpha: 0.35);
      bgGradientStart = const Color(0xFF2A080C).withValues(alpha: 0.92);
    } else if (isElectric) {
      borderColor = Colors.amberAccent;
      glowColor = Colors.amber.withValues(alpha: 0.35);
      bgGradientStart = const Color(0xFF1E1E38).withValues(alpha: 0.92);
    } else if (isGold) {
      borderColor = AppTheme.gold;
      glowColor = AppTheme.gold.withValues(alpha: 0.4);
    }

    return SlideTransition(
      position: _slideAnimation,
      child: FadeTransition(
        opacity: _fadeAnimation,
        child: Container(
          margin: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [bgGradientStart, bgGradientEnd],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: borderColor, width: 1.5),
            boxShadow: [
              BoxShadow(
                color: glowColor,
                blurRadius: 14,
                spreadRadius: 1,
                offset: const Offset(0, 3),
              ),
            ],
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                event.emoji,
                style: const TextStyle(fontSize: 18),
              ),
              const SizedBox(width: 8),
              Flexible(
                child: Text(
                  event.messageAr,
                  style: GoogleFonts.cairo(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 12.5,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
