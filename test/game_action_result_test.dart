import 'package:estimation/services/game_action_service.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('authenticated action response exposes only caller private hand', () {
    final result = GameActionResult.success({
      'seq': 9,
      'publicState': {
        'players': <dynamic>[],
      },
      'privateHand': [
        {'suit': 'heart', 'rank': 'ace'},
        {'suit': 'club', 'rank': 'king'},
      ],
    });

    expect(result.seq, 9);
    expect(result.privateHand, hasLength(2));
    expect(result.privateHand!.first, {
      'suit': 'heart',
      'rank': 'ace',
    });
  });
}
