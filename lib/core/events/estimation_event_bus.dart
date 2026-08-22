// lib/core/events/estimation_event_bus.dart
//
// Reusable, reactive Event Bus specifically for Estimation game events.

import 'dart:async';
import 'package:flutter/foundation.dart';
import 'estimation_game_events.dart';

/// Central reactive event bus for Egyptian Estimation.
class EstimationEventBus {
  static final EstimationEventBus _instance = EstimationEventBus._internal();
  static EstimationEventBus get instance => _instance;

  EstimationEventBus._internal();

  factory EstimationEventBus() => _instance;

  final StreamController<EstimationGameEvent> _controller =
      StreamController<EstimationGameEvent>.broadcast();

  final List<EstimationGameEvent> _history = [];
  int _maxHistoryLength = 100;

  /// Stream of all Estimation game events
  Stream<EstimationGameEvent> get events => _controller.stream;

  /// Returns unmodifiable recent event history
  List<EstimationGameEvent> get history => List.unmodifiable(_history);

  /// Maximum number of recent events stored in the in-memory history buffer
  int get maxHistoryLength => _maxHistoryLength;
  set maxHistoryLength(int val) {
    _maxHistoryLength = val.clamp(1, 1000);
    while (_history.length > _maxHistoryLength) {
      _history.removeAt(0);
    }
  }

  /// Fire a game event to all active subscribers.
  void fire(EstimationGameEvent event) {
    if (kDebugMode) {
      debugPrint('[EstimationEventBus] 📢 ${event.emoji} ${event.eventName}: ${event.messageEn}');
    }

    _history.add(event);
    if (_history.length > _maxHistoryLength) {
      _history.removeAt(0);
    }

    if (!_controller.isClosed) {
      _controller.add(event);
    }
  }

  /// Filter stream by a specific event type.
  /// Example: `EstimationEventBus.instance.on<PerfectEstimate>().listen((e) => ...)`
  Stream<T> on<T extends EstimationGameEvent>() {
    return _controller.stream.where((event) => event is T).cast<T>();
  }

  /// Clear in-memory history buffer (useful between matches or in test suites)
  void clearHistory() {
    _history.clear();
  }

  /// Closes the stream controller (typically only in tests or app shutdown)
  @visibleForTesting
  void reset() {
    clearHistory();
  }
}
