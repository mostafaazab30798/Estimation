import 'dart:async';
import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'settings_service.dart';
import '../core/events/estimation_event_bus.dart';
import '../core/events/estimation_game_events.dart';

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
      hapticAction();
    } catch (_) {}
  }

  /// Triggers subtle selection haptic and card play sound at ~60% volume.
  Future<void> playCard() async {
    _triggerHaptic(HapticFeedback.selectionClick);

    if (!SettingsService.instance.sfxEnabled) return;
    try {
      if (_cardPlayer != null) {
        await _cardPlayer!.stop();
        await _cardPlayer!.play(
          AssetSource('audio/card_play.mp3'),
          volume: 0.6 * SettingsService.instance.sfxVolume,
          mode: PlayerMode.lowLatency,
        );
      }
    } catch (e) {
      debugPrint('AudioService playCard error: $e');
    }
  }

  /// Triggers light impact haptic and trick collection sound at ~80% volume.
  Future<void> playCollection() async {
    _triggerHaptic(HapticFeedback.lightImpact);

    if (!SettingsService.instance.sfxEnabled) return;
    try {
      if (_collectPlayer != null) {
        await _collectPlayer!.stop();
        await _collectPlayer!.play(
          AssetSource('audio/collect_cards.mp3'),
          volume: 0.8 * SettingsService.instance.sfxVolume,
          mode: PlayerMode.lowLatency,
        );
      }
    } catch (e) {
      debugPrint('AudioService playCollection error: $e');
    }
  }

  /// Triggers celebratory haptic and victory fanfare.
  Future<void> playWin() async {
    _triggerHaptic(HapticFeedback.heavyImpact);

    if (!SettingsService.instance.sfxEnabled) return;
    try {
      if (_winPlayer != null) {
        await _winPlayer!.stop();
        await _winPlayer!.play(
          AssetSource('audio/win.mp3'),
          volume: 0.9 * SettingsService.instance.sfxVolume,
        );
      }
    } catch (e) {
      debugPrint('AudioService playWin error: $e');
    }
  }

  /// Triggers defeat audio cue.
  Future<void> playDefeat() async {
    _triggerHaptic(HapticFeedback.vibrate);

    if (!SettingsService.instance.sfxEnabled) return;
    try {
      if (_defeatPlayer != null) {
        await _defeatPlayer!.stop();
        await _defeatPlayer!.play(
          AssetSource('audio/defeat.mp3'),
          volume: 0.8 * SettingsService.instance.sfxVolume,
        );
      }
    } catch (e) {
      debugPrint('AudioService playDefeat error: $e');
    }
  }

  /// Triggers high-stake Risk/Dash success fanfare.
  Future<void> playRiskWin() async {
    _triggerHaptic(HapticFeedback.heavyImpact);

    if (!SettingsService.instance.sfxEnabled) return;
    try {
      if (_riskPlayer != null) {
        await _riskPlayer!.stop();
        await _riskPlayer!.play(
          AssetSource('audio/risk-win.mp3'),
          volume: 0.9 * SettingsService.instance.sfxVolume,
        );
      }
    } catch (e) {
      debugPrint('AudioService playRiskWin error: $e');
    }
  }

  StreamSubscription? _eventSub;

  /// Binds AudioService to the EstimationEventBus to automatically trigger sound cues on game events.
  void bindToEventBus({String? currentUserId}) {
    _eventSub?.cancel();
    _eventSub = EstimationEventBus.instance.events.listen((event) {
      playEventAudio(event, currentUserId: currentUserId);
    });
  }

  /// Triggers sound effects and haptics mapped to an EstimationGameEvent.
  void playEventAudio(EstimationGameEvent event, {String? currentUserId}) {
    if (event is TrickWon) {
      playCollection();
    } else if (event is RiskDeclaration || event is DashCallSucceeded) {
      playRiskWin();
    } else if (event is PerfectEstimate) {
      if (currentUserId == null || event.playerId == currentUserId) {
        playWin();
      }
    } else if (event is DeclarationMissed) {
      if (currentUserId == null || event.playerId == currentUserId) {
        playDefeat();
      }
    } else if (event is DashCallFailed) {
      if (currentUserId == null || event.playerId == currentUserId) {
        playDefeat();
      }
    } else if (event is ForbiddenDeclarationAttempt) {
      _triggerHaptic(HapticFeedback.vibrate);
    } else if (event is DoubleRoundStarted || event is FinalRoundStarted) {
      playRiskWin();
    } else if (event is MatchCompleted) {
      if (currentUserId == null || event.winner.id == currentUserId) {
        playWin();
      }
    }
  }

  /// Cleanly disposes audio players.
  void dispose() {
    _eventSub?.cancel();
    _eventSub = null;
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
