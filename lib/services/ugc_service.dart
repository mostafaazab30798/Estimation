// lib/services/ugc_service.dart

import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Terms version — bump when community guidelines change.
const String kCurrentTermsVersion = '2026-08-31';

const String kTermsOfServiceUrl = 'https://legal.hope-tv.site/terms/';

class UgcService {
  UgcService._();
  static final UgcService instance = UgcService._();

  final SupabaseClient _client = Supabase.instance.client;

  Future<bool> acceptTerms({String version = kCurrentTermsVersion}) async {
    final user = _client.auth.currentUser;
    if (user == null || user.isAnonymous) return false;

    try {
      await _client.from('profiles').update({
        'terms_accepted_at': DateTime.now().toUtc().toIso8601String(),
        'terms_version': version,
        'updated_at': DateTime.now().toUtc().toIso8601String(),
      }).eq('id', user.id);
      return true;
    } catch (e) {
      debugPrint('[UgcService] acceptTerms error: $e');
      return false;
    }
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
    final user = _client.auth.currentUser;
    if (user == null || user.isAnonymous) return {};

    try {
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
}
