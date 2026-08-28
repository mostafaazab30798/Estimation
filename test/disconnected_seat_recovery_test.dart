import 'package:estimation/networking/game_server.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('disconnected human seats have an exact 60 second grace period', () {
    expect(
      GameServer.disconnectedPlayerGracePeriod,
      const Duration(seconds: 60),
    );
  });
}
