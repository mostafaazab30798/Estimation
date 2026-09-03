import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';

/// Stable identifier for this app installation.
///
/// Authentication identifies the person; this identifier lets the server
/// distinguish two phones signed in with the same Google account.
class DeviceIdentityService {
  static const _storageKey = 'installation_device_id';
  static String? _cachedId;

  static Future<String> getId() async {
    if (_cachedId case final id?) return id;
    final preferences = await SharedPreferences.getInstance();
    final stored = preferences.getString(_storageKey);
    if (stored != null && stored.isNotEmpty) {
      _cachedId = stored;
      return stored;
    }

    final created = const Uuid().v4();
    await preferences.setString(_storageKey, created);
    _cachedId = created;
    return created;
  }
}
