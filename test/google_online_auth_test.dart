import 'package:flutter_test/flutter_test.dart';
import 'package:estimation/core/utils/google_online_auth.dart';

void main() {
  test('missing users cannot play online', () {
    expect(isGoogleAuthenticated(null), isFalse);
  });

  test('maps auth failures to the Google login message', () {
    expect(
      isGoogleOnlineAuthError(Exception(kGoogleOnlineRequiredCode)),
      isTrue,
    );
    expect(
      isGoogleOnlineAuthError(Exception('MATCHMAKING_NOT_AUTHENTICATED')),
      isTrue,
    );
    expect(
      isGoogleOnlineAuthError(Exception('ROOM_FULL')),
      isFalse,
    );
  });
}
