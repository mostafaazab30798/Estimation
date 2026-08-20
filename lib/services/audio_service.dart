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
  AudioPlayer? _winPlayer;
  AudioPlayer? _defeatPlayer;
  AudioPlayer? _riskPlayer;
  bool _initialized = false;

  /// Initializes audio players and pre-loads sound assets for low latency playback.
  Future<void> initialize() async {
    if (_initialized) return;
    try {
      _cardPlayer = AudioPlayer();
      _collectPlayer = AudioPlayer();
      _winPlayer = AudioPlayer();
      _defeatPlayer = AudioPlayer();
      _riskPlayer = AudioPlayer();

      // Configure player modes for low latency sound effects if available
      await _cardPlayer?.setPlayerMode(PlayerMode.lowLatency);
      await _collectPlayer?.setPlayerMode(PlayerMode.lowLatency);
      await _winPlayer?.setPlayerMode(PlayerMode.lowLatency);
      await _defeatPlayer?.setPlayerMode(PlayerMode.lowLatency);
      await _riskPlayer?.setPlayerMode(PlayerMode.lowLatency);

      await _cardPlayer?.setVolume(0.6);
      await _collectPlayer?.setVolume(0.8);
      await _winPlayer?.setVolume(0.9);
      await _defeatPlayer?.setVolume(0.8);
      await _riskPlayer?.setVolume(0.9);

      // Pre-set audio sources for pre-caching
      await _cardPlayer?.setSource(AssetSource('audio/card_play.mp3'));
      await _collectPlayer?.setSource(AssetSource('audio/collect_cards.mp3'));
      await _winPlayer?.setSource(AssetSource('audio/win.mp3'));
      await _defeatPlayer?.setSource(AssetSource('audio/defeat.mp3'));
      await _riskPlayer?.setSource(AssetSource('audio/risk-win.mp3'));

      _initialized = true;
    } catch (e) {
      debugPrint('AudioService initialization error: $e');
    }
  }

  /// Triggers subtle selection haptic and card play sound at ~60% volume.
  Future<void> playCard() async {
    try {
      HapticFeedback.selectionClick();
    } catch (_) {}

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
    try {
      HapticFeedback.lightImpact();
    } catch (_) {}

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

  /// Triggers celebratory haptic and victory fanfare.
  Future<void> playWin() async {
    try {
      HapticFeedback.heavyImpact();
    } catch (_) {}

    try {
      if (_winPlayer != null) {
        await _winPlayer!.stop();
        await _winPlayer!.play(
          AssetSource('audio/win.mp3'),
          volume: 0.9,
        );
      }
    } catch (e) {
      debugPrint('AudioService playWin error: $e');
    }
  }

  /// Triggers defeat audio cue.
  Future<void> playDefeat() async {
    try {
      HapticFeedback.vibrate();
    } catch (_) {}

    try {
      if (_defeatPlayer != null) {
        await _defeatPlayer!.stop();
        await _defeatPlayer!.play(
          AssetSource('audio/defeat.mp3'),
          volume: 0.8,
        );
      }
    } catch (e) {
      debugPrint('AudioService playDefeat error: $e');
    }
  }

  /// Triggers high-stake Risk/Dash success fanfare.
  Future<void> playRiskWin() async {
    try {
      HapticFeedback.heavyImpact();
    } catch (_) {}

    try {
      if (_riskPlayer != null) {
        await _riskPlayer!.stop();
        await _riskPlayer!.play(
          AssetSource('audio/risk-win.mp3'),
          volume: 0.9,
        );
      }
    } catch (e) {
      debugPrint('AudioService playRiskWin error: $e');
    }
  }

  /// Cleanly disposes audio players.
  void dispose() {
    _cardPlayer?.dispose();
    _collectPlayer?.dispose();
    _winPlayer?.dispose();
    _defeatPlayer?.dispose();
    _riskPlayer?.dispose();
    _cardPlayer = null;
    _collectPlayer = null;
    _winPlayer = null;
    _defeatPlayer = null;
    _riskPlayer = null;
    _initialized = false;
  }
}
