// lib/services/ugc_service.dart

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Terms version — bump when community guidelines change.
const String kCurrentTermsVersion = '2026-08-31';

const String kTermsOfServiceUrl = 'https://legal.hope-tv.site/terms/';

class UgcService {
  UgcService._();
  static final UgcService instance = UgcService._();

  static const _kTermsVersionKey = 'ugc_terms_version';
  static const _kTermsAcceptedAtKey = 'ugc_terms_accepted_at';

  String? _acceptedVersion;
  bool _loaded = false;

  SupabaseClient get _client => Supabase.instance.client;

  Future<void> _ensureLoaded() async {
    if (_loaded) return;
    try {
      final prefs = await SharedPreferences.getInstance();
      _acceptedVersion = prefs.getString(_kTermsVersionKey);
    } catch (e) {
      debugPrint('[UgcService] load terms error: $e');
    }
    _loaded = true;
  }

  Future<bool> hasAcceptedCurrentTerms() async {
    await _ensureLoaded();
    return _acceptedVersion == kCurrentTermsVersion;
  }

  Future<void> rememberAcceptedTerms({
    String version = kCurrentTermsVersion,
  }) async {
    _acceptedVersion = version;
    _loaded = true;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_kTermsVersionKey, version);
      await prefs.setString(
        _kTermsAcceptedAtKey,
        DateTime.now().toUtc().toIso8601String(),
      );
    } catch (e) {
      debugPrint('[UgcService] persist terms error: $e');
    }
  }

  Future<bool> acceptTerms({String version = kCurrentTermsVersion}) async {
    await rememberAcceptedTerms(version: version);

    try {
      final user = _client.auth.currentUser;
      if (user == null || user.isAnonymous) return true;

      await _client.from('profiles').update({
        'terms_accepted_at': DateTime.now().toUtc().toIso8601String(),
        'terms_version': version,
        'updated_at': DateTime.now().toUtc().toIso8601String(),
      }).eq('id', user.id);
    } catch (e) {
      debugPrint('[UgcService] acceptTerms server sync skipped: $e');
    }
    return true;
  }

  Future<bool> submitReport({
    required String reportedUserId,
    required String reason,
    String? details,
    String? contextType,
    String? contextId,
  }) async {
    try {
      await _client.rpc('submit_user_report', params: {
        'p_reported_id': reportedUserId,
        'p_reason': reason,
        'p_details': details,
        'p_context_type': contextType,
        'p_context_id': contextId,
      });
      return true;
    } catch (e) {
      debugPrint('[UgcService] submitReport error: $e');
      return false;
    }
  }

  Future<bool> blockUser(String blockedUserId) async {
    try {
      await _client.rpc('block_user', params: {'p_blocked_id': blockedUserId});
      return true;
    } catch (e) {
      debugPrint('[UgcService] blockUser error: $e');
      return false;
    }
  }

  Future<bool> unblockUser(String blockedUserId) async {
    try {
      await _client.rpc('unblock_user', params: {'p_blocked_id': blockedUserId});
      return true;
    } catch (e) {
      debugPrint('[UgcService] unblockUser error: $e');
      return false;
    }
  }

  Future<Set<String>> fetchBlockedUserIds() async {
    try {
      final user = _client.auth.currentUser;
      if (user == null || user.isAnonymous) return {};

      final rows = await _client
          .from('user_blocks')
          .select('blocked_id')
          .eq('blocker_id', user.id);
      return (rows as List<dynamic>)
          .map((row) => row['blocked_id'] as String)
          .toSet();
    } catch (e) {
      debugPrint('[UgcService] fetchBlockedUserIds error: $e');
      return {};
    }
  }

  @visibleForTesting
  void resetForTest() {
    _acceptedVersion = null;
    _loaded = false;
  }
}
