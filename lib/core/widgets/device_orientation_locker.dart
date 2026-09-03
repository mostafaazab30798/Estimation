import 'dart:async';
import 'dart:math' as math;
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// Matches [GameLayoutMetrics.isTablet] / [HomeLayoutMetrics.isTablet].
const double kTabletShortestSideBreakpoint = 600;

/// Locks portrait on phones; tablets keep all orientations.
class DeviceOrientationLocker extends StatefulWidget {
  const DeviceOrientationLocker({super.key, required this.child});

  final Widget child;

  @override
  State<DeviceOrientationLocker> createState() => _DeviceOrientationLockerState();
}

class _DeviceOrientationLockerState extends State<DeviceOrientationLocker>
    with WidgetsBindingObserver {
  bool? _portraitLocked;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _syncOrientation(_shortestSideFromPlatform());
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _syncOrientation(MediaQuery.sizeOf(context).shortestSide);
  }

  @override
  void didChangeMetrics() {
    _syncOrientation(_shortestSideFromPlatform());
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    unawaited(SystemChrome.setPreferredOrientations(DeviceOrientation.values));
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => widget.child;

  double _shortestSideFromPlatform() {
    final view = WidgetsBinding.instance.platformDispatcher.views.first;
    return _logicalShortestSide(view);
  }

  void _syncOrientation(double shortestSide) {
    final lockPortrait = shortestSide < kTabletShortestSideBreakpoint;
    if (_portraitLocked == lockPortrait) return;
    _portraitLocked = lockPortrait;
    unawaited(_applyOrientationPolicy(lockPortrait: lockPortrait));
  }
}

double logicalShortestSide(FlutterView view) {
  final size = view.physicalSize;
  final dpr = view.devicePixelRatio;
  return math.min(size.width, size.height) / dpr;
}

double _logicalShortestSide(FlutterView view) => logicalShortestSide(view);

Future<void> applyDeviceOrientationPolicy({required double shortestSide}) {
  return _applyOrientationPolicy(
    lockPortrait: shortestSide < kTabletShortestSideBreakpoint,
  );
}

Future<void> applyDeviceOrientationPolicyFromPlatform() {
  final view = WidgetsBinding.instance.platformDispatcher.views.first;
  return applyDeviceOrientationPolicy(
    shortestSide: logicalShortestSide(view),
  );
}

Future<void> _applyOrientationPolicy({required bool lockPortrait}) {
  if (lockPortrait) {
    return SystemChrome.setPreferredOrientations(const [
      DeviceOrientation.portraitUp,
      DeviceOrientation.portraitDown,
    ]);
  }
  return SystemChrome.setPreferredOrientations(const [
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
    DeviceOrientation.landscapeLeft,
    DeviceOrientation.landscapeRight,
  ]);
}
