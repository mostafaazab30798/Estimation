// lib/services/audio_service.dart

import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

/// Dedicated service managing audio playback and haptic feedback for game events.
class AudioService {
  AudioService._();
  static final AudioService instance = AudioService._();

  AudioPlayer? _cardPlayer;
  AudioPlayer? _collectPlayer;
  bool _initialized = false;

  /// Initializes audio players and pre-loads sound assets for low latency playback.
  Future<void> initialize() async {
    if (_initialized) return;
    try {
      _cardPlayer = AudioPlayer();
      _collectPlayer = AudioPlayer();

      // Configure player modes for low latency sound effects if available
      await _cardPlayer?.setPlayerMode(PlayerMode.lowLatency);
      await _collectPlayer?.setPlayerMode(PlayerMode.lowLatency);

      await _cardPlayer?.setVolume(0.6);
      await _collectPlayer?.setVolume(0.8);

      // Pre-set audio sources for pre-caching
      await _cardPlayer?.setSource(AssetSource('audio/card_play.mp3'));
      await _collectPlayer?.setSource(AssetSource('audio/collect_cards.mp3'));

      _initialized = true;
    } catch (e) {
      debugPrint('AudioService initialization error: $e');
    }
  }

  /// Triggers subtle selection haptic and card play sound at ~60% volume.
  Future<void> playCard() async {
    // 1. Trigger selection click haptic feedback
    try {
      HapticFeedback.selectionClick();
    } catch (_) {}

    // 2. Play card play audio effect
    try {
      if (_cardPlayer != null) {
        await _cardPlayer!.stop();
        await _cardPlayer!.play(
          AssetSource('audio/card_play.mp3'),
          volume: 0.6,
          mode: PlayerMode.lowLatency,
        );
      }
    } catch (e) {
      debugPrint('AudioService playCard error: $e');
    }
  }

  /// Triggers light impact haptic and trick collection sound at ~80% volume.
  Future<void> playCollection() async {
    // 1. Trigger light impact haptic feedback
    try {
      HapticFeedback.lightImpact();
    } catch (_) {}

    // 2. Play collection audio effect
    try {
      if (_collectPlayer != null) {
        await _collectPlayer!.stop();
        await _collectPlayer!.play(
          AssetSource('audio/collect_cards.mp3'),
          volume: 0.8,
          mode: PlayerMode.lowLatency,
        );
      }
    } catch (e) {
      debugPrint('AudioService playCollection error: $e');
    }
  }

  /// Cleanly disposes audio players.
  void dispose() {
    _cardPlayer?.dispose();
    _collectPlayer?.dispose();
    _cardPlayer = null;
    _collectPlayer = null;
    _initialized = false;
  }
}
