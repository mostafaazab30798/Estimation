// lib/services/device_performance_service.dart

import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:device_info_plus/device_info_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';

enum PerformanceMode {
  auto,
  lowSpec,
  highSpec,
}

class DevicePerformanceService extends ChangeNotifier {
  static final DevicePerformanceService instance = DevicePerformanceService._();

  DevicePerformanceService._();

  static const String _kPrefKey = 'user_performance_mode';

  PerformanceMode _mode = PerformanceMode.auto;
  bool _isAutoDetectedLowSpec = false;
  bool _isInitialized = false;

  PerformanceMode get mode => _mode;
  bool get isInitialized => _isInitialized;

  /// Returns true if heavy GPU blurs (BackdropFilter) should be disabled
  /// and lightweight graphics rendering should be used.
  bool get isLowSpecDevice {
    switch (_mode) {
      case PerformanceMode.lowSpec:
        return true;
      case PerformanceMode.highSpec:
        return false;
      case PerformanceMode.auto:
        return _isAutoDetectedLowSpec;
    }
  }

  /// Initializes hardware inspection and loads user performance preference.
  Future<void> initialize() async {
    if (_isInitialized) return;

    try {
      final prefs = await SharedPreferences.getInstance();
      final savedMode = prefs.getString(_kPrefKey);
      if (savedMode != null) {
        _mode = PerformanceMode.values.firstWhere(
          (e) => e.name == savedMode,
          orElse: () => PerformanceMode.auto,
        );
      }

      _isAutoDetectedLowSpec = await _detectLowSpecHardware();
    } catch (e) {
      debugPrint('[DevicePerformanceService] Detection error: $e');
      _isAutoDetectedLowSpec = false;
    } finally {
      _isInitialized = true;
      notifyListeners();
    }
  }

  /// Auto-detects legacy or low-spec mobile hardware (e.g., Galaxy Note 9, older Androids, low-RAM).
  Future<bool> _detectLowSpecHardware() async {
    if (kIsWeb) return false;

    if (Platform.isAndroid) {
      final deviceInfo = DeviceInfoPlugin();
      final androidInfo = await deviceInfo.androidInfo;

      // 1. Android Low RAM flag reported by OS
      if (androidInfo.isLowRamDevice) {
        return true;
      }

      // 2. Older Android SDK version (Android 10 / SDK 29 or older)
      if (androidInfo.version.sdkInt <= 29) {
        return true;
      }

      // 3. Known legacy flagship/budget model identifiers (e.g. Galaxy Note 9, Galaxy S9, S8)
      final model = androidInfo.model.toUpperCase();
      final hardware = androidInfo.hardware.toUpperCase();
      final board = androidInfo.board.toUpperCase();

      const legacyIdentifiers = [
        'SM-N960', // Galaxy Note 9
        'SM-G960', // Galaxy S9
        'SM-G965', // Galaxy S9+
        'SM-N950', // Galaxy Note 8
        'SM-G950', // Galaxy S8
        'NOTE 9',
        'NOTE9',
        'EXYNOS 9810',
        'EXYNOS 8895',
      ];

      for (final id in legacyIdentifiers) {
        if (model.contains(id) || hardware.contains(id) || board.contains(id)) {
          return true;
        }
      }

      // 4. Limited CPU cores
      if (Platform.numberOfProcessors <= 4) {
        return true;
      }
    }

    return false;
  }

  /// Change performance mode preference manually.
  Future<void> setPerformanceMode(PerformanceMode mode) async {
    _mode = mode;
    notifyListeners();
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_kPrefKey, mode.name);
    } catch (e) {
      debugPrint('[DevicePerformanceService] Save preference error: $e');
    }
  }
}
