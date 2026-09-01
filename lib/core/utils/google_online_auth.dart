// lib/core/utils/google_online_auth.dart

import 'package:supabase_flutter/supabase_flutter.dart';

const kGoogleOnlineRequiredCode = 'GOOGLE_LOGIN_REQUIRED';

const kGoogleOnlineRequiredMessage =
    'يجب تسجيل الدخول بحساب Google للعب أونلاين أو إنشاء غرفة أو الانضمام.';

bool isGoogleAuthenticated(User? user) =>
    user != null && user.isAnonymous == false;

void requireGoogleSession(SupabaseClient client) {
  if (!isGoogleAuthenticated(client.auth.currentUser)) {
    throw Exception(kGoogleOnlineRequiredCode);
  }
}

bool isGoogleOnlineAuthError(Object error) {
  final raw = error.toString();
  return raw.contains(kGoogleOnlineRequiredCode) ||
      raw.contains('MATCHMAKING_NOT_AUTHENTICATED') ||
      raw.contains('NOT_AUTHENTICATED');
}
