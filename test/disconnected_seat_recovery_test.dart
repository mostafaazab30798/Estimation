import 'package:estimation/networking/game_server.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('disconnected human seats use a 30 second bot takeover delay', () {
    expect(
      GameServer.botTakeoverDelay,
      const Duration(seconds: 30),
    );
    expect(
      GameServer.seatReclaimWindow,
      const Duration(minutes: 5),
    );
  });
}
