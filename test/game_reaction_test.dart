// test/game_reaction_test.dart

import 'package:flutter_test/flutter_test.dart';
import 'package:estimation/core/models/game_reaction.dart';

void main() {
  group('GameReaction & Presets Tests', () {
    test('GameReaction serialization and deserialization', () {
      final reaction = GameReaction(
        id: 'r_123',
        playerId: 'p1',
        playerName: 'Mostafa',
        emoji: '👑',
        text: 'أنا الملك',
        timestamp: 1700000000000,
      );

      final json = reaction.toJson();
      expect(json['id'], equals('r_123'));
      expect(json['playerId'], equals('p1'));
      expect(json['playerName'], equals('Mostafa'));
      expect(json['emoji'], equals('👑'));
      expect(json['text'], equals('أنا الملك'));
      expect(json['timestamp'], equals(1700000000000));
      expect(reaction.displayText, equals('أنا الملك 👑'));

      final parsed = GameReaction.fromJson(json);
      expect(parsed.id, equals('r_123'));
      expect(parsed.playerId, equals('p1'));
      expect(parsed.playerName, equals('Mostafa'));
      expect(parsed.emoji, equals('👑'));
      expect(parsed.text, equals('أنا الملك'));
      expect(parsed.timestamp, equals(1700000000000));
    });

    test('GameReaction emoji-only display text', () {
      final reaction = GameReaction(
        id: 'r_456',
        playerId: 'p2',
        emoji: '🔥',
        timestamp: 1700000000000,
      );

      expect(reaction.displayText, equals('🔥'));
    });

    test('Catalog contains required presets and categories', () {
      expect(GameReaction.emojis.isNotEmpty, isTrue);
      expect(GameReaction.tactical.isNotEmpty, isTrue);
      expect(GameReaction.banter.isNotEmpty, isTrue);

      final kingPreset = GameReaction.tactical.firstWhere((p) => p.id == 't_i_am_king');
      expect(kingPreset.text, equals('أنا الملك'));
      expect(kingPreset.emoji, equals('👑'));

      final hurryPreset = GameReaction.banter.firstWhere((p) => p.id == 'b_hurry_up');
      expect(hurryPreset.text, equals('خلص يا غالي'));
      expect(hurryPreset.emoji, equals('⏳'));
    });
  });
}
