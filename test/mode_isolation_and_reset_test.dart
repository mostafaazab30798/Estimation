import 'package:flutter_test/flutter_test.dart';
import 'package:estimation/providers/game_provider.dart';
import 'package:estimation/modes/ninety_nine/presentation/providers/ninety_nine_game_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    SharedPreferences.setMockInitialValues({});
    try {
      await Supabase.initialize(
        url: 'https://eqmkbfxerxqihforsgvx.supabase.co',
        anonKey: 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImVxbWtiZnhlcnhxaWhmb3JzZ3Z4Iiwicm9sZSI6ImFub24iLCJpYXQiOjE3ODQwNjQ0NTUsImV4cCI6MjA5OTY0MDQ1NX0.3F_n2TUVGTucW2DUWpv5YxqOtFkBQZaQJZKngL7gOx0',
      );
    } catch (_) {}
  });

  group('Mode Isolation & State Reset Tests', () {
    test('Playing 99 mode with 5 players then resetting restores expectedPlayers to 4', () async {
      final gameProvider = GameProvider();
      final nnProvider = NinetyNineGameProvider();
      gameProvider.nnProvider = nnProvider;

      // Start 99 test game with 5 players
      await gameProvider.startNinetyNineTestGame('Player 1', totalPlayers: 5);

      expect(gameProvider.expectedPlayers, equals(5));
      expect(gameProvider.isNinetyNine, isTrue);
      expect(gameProvider.isTestMode, isTrue);

      // User quits 99 mode
      await gameProvider.reset();
      nnProvider.reset();

      expect(gameProvider.expectedPlayers, equals(4));
      expect(gameProvider.isNinetyNine, isFalse);
      expect(gameProvider.isTestMode, isFalse);
      expect(gameProvider.state, isNull);
    });

    test('Starting Estimation bot game after 99 mode has exactly 4 players and 4 expectedPlayers', () async {
      final gameProvider = GameProvider();
      final nnProvider = NinetyNineGameProvider();
      gameProvider.nnProvider = nnProvider;

      // Simulate playing 99 mode with 5 players
      await gameProvider.startNinetyNineTestGame('Player 1', totalPlayers: 5);
      expect(gameProvider.expectedPlayers, equals(5));

      // Quit and enter Estimation test game
      await gameProvider.startTestGame('Player 1');

      expect(gameProvider.expectedPlayers, equals(4));
      expect(gameProvider.isNinetyNine, isFalse);
      expect(gameProvider.isTestMode, isTrue);
      expect(gameProvider.state?.players.length, equals(4));

      final bots = gameProvider.state?.players.where((p) => p.id.startsWith('bot_')).toList() ?? [];
      expect(bots.length, equals(3)); // 1 human + 3 bots = 4 total

      await gameProvider.reset();
      expect(gameProvider.expectedPlayers, equals(4));
    });
  });
}
