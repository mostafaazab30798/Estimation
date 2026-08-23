// lib/services/update_checker_service.dart

import 'package:supabase_flutter/supabase_flutter.dart';

/// Keep this in sync with the `version` field in pubspec.yaml (the part before `+`).
/// Example: if pubspec has `version: 0.1.2+5`, set this to '0.1.2'.
const String kAppVersion = '1.7.0';

class UpdateInfo {
  final bool updateAvailable;
  final String currentVersion;
  final String latestVersion;
  final String releaseNotes;
  /// Direct download URL for the APK. Empty string means no direct install available.
  final String downloadUrl;

  const UpdateInfo({
    required this.updateAvailable,
    required this.currentVersion,
    required this.latestVersion,
    required this.releaseNotes,
    required this.downloadUrl,
  });
}

class UpdateCheckerService {
  final _client = Supabase.instance.client;

  Future<UpdateInfo> checkForUpdate() async {
    const currentVersion = kAppVersion;

    final response = await _client
        .from('app_version')
        .select('latest_version, release_notes, download_url')
        .eq('id', 1)
        .single();

    final latestVersion = response['latest_version'] as String;
    final releaseNotes = response['release_notes'] as String? ?? '';
    final downloadUrl = response['download_url'] as String? ?? '';

    return UpdateInfo(
      updateAvailable: _isNewer(latestVersion, currentVersion),
      currentVersion: currentVersion,
      latestVersion: latestVersion,
      releaseNotes: releaseNotes,
      downloadUrl: downloadUrl,
    );
  }

  /// Simple semantic version comparison (major.minor.patch)
  bool _isNewer(String latest, String current) {
    final l = latest.split('.').map(int.parse).toList();
    final c = current.split('.').map(int.parse).toList();

    for (var i = 0; i < 3; i++) {
      final lv = i < l.length ? l[i] : 0;
      final cv = i < c.length ? c[i] : 0;
      if (lv > cv) return true;
      if (lv < cv) return false;
    }
    return false;
  }
}
