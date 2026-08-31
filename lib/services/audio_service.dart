import 'dart:async';
import 'dart:io' show Platform;
import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'settings_service.dart';

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
      if (!kIsWeb && Platform.environment.containsKey('FLUTTER_TEST')) {
        return;
      }
      await SettingsService.instance.initialize();

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

      final vol = SettingsService.instance.sfxVolume;
      await _cardPlayer?.setVolume(0.6 * vol);
      await _collectPlayer?.setVolume(0.8 * vol);
      await _winPlayer?.setVolume(0.9 * vol);
      await _defeatPlayer?.setVolume(0.8 * vol);
      await _riskPlayer?.setVolume(0.9 * vol);

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

  void _triggerHaptic(VoidCallback hapticAction) {
    if (!SettingsService.instance.hapticsEnabled) return;
    try {
      if (!kIsWeb && Platform.environment.containsKey('FLUTTER_TEST')) {
        return;
      }
    } catch (_) {}
    try {
      hapticAction();
    } catch (_) {}
  }

  Future<void> _safePlay(AudioPlayer? player, Source source, double volume, {PlayerMode mode = PlayerMode.mediaPlayer}) async {
    if (player == null) return;
    try {
      if (!kIsWeb && Platform.environment.containsKey('FLUTTER_TEST')) {
        return;
      }
    } catch (_) {}
    try {
      await player.stop().timeout(const Duration(milliseconds: 80), onTimeout: () {});
      await player.play(source, volume: volume, mode: mode).timeout(const Duration(milliseconds: 80), onTimeout: () {});
    } catch (e) {
      debugPrint('AudioService safePlay error: $e');
    }
  }

  /// Plays card swipe sound effect with low latency.
  Future<void> playCard() async {
    _triggerHaptic(HapticFeedback.selectionClick);

    if (!SettingsService.instance.sfxEnabled) return;
    await _safePlay(
      _cardPlayer,
      AssetSource('audio/card_play.mp3'),
      0.7 * SettingsService.instance.sfxVolume,
      mode: PlayerMode.lowLatency,
    );
  }

  /// Plays trick collection sound.
  Future<void> playCollection() async {
    _triggerHaptic(HapticFeedback.lightImpact);

    if (!SettingsService.instance.sfxEnabled) return;
    await _safePlay(
      _collectPlayer,
      AssetSource('audio/collect_cards.mp3'),
      0.8 * SettingsService.instance.sfxVolume,
      mode: PlayerMode.lowLatency,
    );
  }

  /// Triggers celebratory haptic and victory fanfare.
  Future<void> playWin() async {
    _triggerHaptic(HapticFeedback.heavyImpact);

    if (!SettingsService.instance.sfxEnabled) return;
    await _safePlay(
      _winPlayer,
      AssetSource('audio/win.mp3'),
      0.9 * SettingsService.instance.sfxVolume,
    );
  }

  /// Triggers defeat audio cue.
  Future<void> playDefeat() async {
    _triggerHaptic(HapticFeedback.vibrate);

    if (!SettingsService.instance.sfxEnabled) return;
    await _safePlay(
      _defeatPlayer,
      AssetSource('audio/defeat.mp3'),
      0.8 * SettingsService.instance.sfxVolume,
    );
  }

  /// Triggers high-stake Risk/Dash success fanfare.
  Future<void> playRiskWin() async {
    _triggerHaptic(HapticFeedback.heavyImpact);

    if (!SettingsService.instance.sfxEnabled) return;
    await _safePlay(
      _riskPlayer,
      AssetSource('audio/risk-win.mp3'),
      0.9 * SettingsService.instance.sfxVolume,
    );
  }

  /// Triggers earthquake rumble haptics and card slide audio.
  Future<void> playEarthquakeSlam() async {
    try {
      if (!kIsWeb && Platform.environment.containsKey('FLUTTER_TEST')) {
        return;
      }
    } catch (_) {}

    _triggerHaptic(HapticFeedback.heavyImpact);
    _triggerHaptic(HapticFeedback.vibrate);

    // Secondary rumble pulses for real shockwave feel
    Future.delayed(const Duration(milliseconds: 140), () {
      _triggerHaptic(HapticFeedback.heavyImpact);
    });
    Future.delayed(const Duration(milliseconds: 320), () {
      _triggerHaptic(HapticFeedback.vibrate);
    });

    if (!SettingsService.instance.sfxEnabled) return;
    await _safePlay(
      _cardPlayer,
      AssetSource('audio/card_play.mp3'),
      0.8 * SettingsService.instance.sfxVolume,
      mode: PlayerMode.lowLatency,
    );
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
