// lib/services/settings_service.dart

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Manages sound effects, haptic feedback, and audio volume settings across the app.
class SettingsService extends ChangeNotifier {
  SettingsService._();
  static final SettingsService instance = SettingsService._();

  static const String _kKeySfxEnabled = 'settings_sfx_enabled';
  static const String _kKeyHapticsEnabled = 'settings_haptics_enabled';
  static const String _kKeySfxVolume = 'settings_sfx_volume';

  bool _sfxEnabled = true;
  bool _hapticsEnabled = true;
  double _sfxVolume = 0.8;
  bool _initialized = false;

  bool get sfxEnabled => _sfxEnabled;
  bool get hapticsEnabled => _hapticsEnabled;
  double get sfxVolume => _sfxVolume;
  bool get isInitialized => _initialized;

  /// Loads saved preferences from SharedPreferences.
  Future<void> initialize() async {
    if (_initialized) return;
    try {
      final prefs = await SharedPreferences.getInstance();
      _sfxEnabled = prefs.getBool(_kKeySfxEnabled) ?? true;
      _hapticsEnabled = prefs.getBool(_kKeyHapticsEnabled) ?? true;
      _sfxVolume = prefs.getDouble(_kKeySfxVolume) ?? 0.8;
      _initialized = true;
      notifyListeners();
    } catch (e) {
      debugPrint('[SettingsService] Failed to load settings: $e');
    }
  }

  /// Sets SFX enabled/disabled state and persists to storage.
  Future<void> setSfxEnabled(bool enabled) async {
    if (_sfxEnabled == enabled) return;
    _sfxEnabled = enabled;
    notifyListeners();
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_kKeySfxEnabled, enabled);
    } catch (e) {
      debugPrint('[SettingsService] Failed to save sfxEnabled: $e');
    }
  }

  /// Sets haptics enabled/disabled state and persists to storage.
  Future<void> setHapticsEnabled(bool enabled) async {
    if (_hapticsEnabled == enabled) return;
    _hapticsEnabled = enabled;
    notifyListeners();
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_kKeyHapticsEnabled, enabled);
    } catch (e) {
      debugPrint('[SettingsService] Failed to save hapticsEnabled: $e');
    }
  }

  /// Sets SFX playback volume (0.0 to 1.0) and persists to storage.
  Future<void> setSfxVolume(double volume) async {
    final clamped = volume.clamp(0.0, 1.0);
    if ((_sfxVolume - clamped).abs() < 0.01) return;
    _sfxVolume = clamped;
    notifyListeners();
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setDouble(_kKeySfxVolume, clamped);
    } catch (e) {
      debugPrint('[SettingsService] Failed to save sfxVolume: $e');
    }
  }
}
