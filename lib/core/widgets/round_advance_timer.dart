import 'dart:async';

import 'package:flutter/foundation.dart';

/// Counts down and fires [onComplete] once unless cancelled or paused.
class RoundAdvanceTimer {
  RoundAdvanceTimer({
    this.duration = const Duration(seconds: 5),
    required this.onTick,
    required this.onComplete,
  });

  final Duration duration;
  final ValueChanged<int> onTick;
  final VoidCallback onComplete;

  Timer? _timer;
  bool _paused = false;
  bool _completed = false;
  int _remainingMs = 0;

  int get secondsRemaining =>
      _remainingMs <= 0 ? 0 : (_remainingMs / 1000).ceil().clamp(1, 999);

  double get progress {
    if (duration.inMilliseconds <= 0) return 1;
    return 1 - (_remainingMs / duration.inMilliseconds).clamp(0.0, 1.0);
  }

  bool get isPaused => _paused;

  void start() {
    cancel();
    _completed = false;
    _paused = false;
    _remainingMs = duration.inMilliseconds;
    onTick(secondsRemaining);
    _timer = Timer.periodic(const Duration(milliseconds: 50), _handleTick);
  }

  void setPaused(bool paused) {
    if (_completed || _paused == paused) return;
    _paused = paused;
    if (!paused) {
      onTick(secondsRemaining);
    }
  }

  void completeNow() {
    if (_completed) return;
    _completed = true;
    _timer?.cancel();
    _timer = null;
    onComplete();
  }

  void cancel() {
    _timer?.cancel();
    _timer = null;
    _completed = false;
    _paused = false;
    _remainingMs = 0;
  }

  void _handleTick(Timer timer) {
    if (_paused || _completed) return;

    _remainingMs -= 50;
    if (_remainingMs <= 0) {
      _completed = true;
      timer.cancel();
      _timer = null;
      onComplete();
      return;
    }

    final nextSeconds = secondsRemaining;
    onTick(nextSeconds);
  }
}
