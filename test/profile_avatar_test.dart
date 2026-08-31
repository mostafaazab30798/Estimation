import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:estimation/services/profile_service.dart';

void main() {
  group('Preset animal avatars', () {
    test('exposes eight asset-backed presets', () {
      expect(ProfileService.presetAvatars, hasLength(8));
      for (final avatar in ProfileService.presetAvatars) {
        expect(avatar.id, startsWith('preset:'));
        expect(avatar.assetPath, startsWith('assets/avatars/'));
        expect(avatar.assetPath, endsWith('.png'));
        expect(ProfileService.isKnownPreset(avatar.id), isTrue);
      }
    });

    test('randomPresetId stays within the catalog', () {
      final rng = Random(42);
      final ids = {
        for (var i = 0; i < 40; i++) ProfileService.randomPresetId(rng),
      };
      expect(ids, isNotEmpty);
      expect(
        ids.every(ProfileService.isKnownPreset),
        isTrue,
      );
    });

    test('guests keep animal presets but not Google photos', () {
      expect(
        ProfileService.isGuestAssignableAvatar('preset:panda'),
        isTrue,
      );
      expect(
        ProfileService.isGuestAssignableAvatar('https://lh3.googleusercontent.com/a/photo'),
        isFalse,
      );
      expect(
        ProfileService.isAssignableAvatar('https://lh3.googleusercontent.com/a/photo'),
        isTrue,
      );
      expect(ProfileService.isGuestAssignableAvatar('preset:king'), isFalse);
    });

    test('publicAvatarRef maps retired presets to a known animal', () {
      expect(
        ProfileService.publicAvatarRef('preset:king'),
        equals(ProfileService.presetAvatars.first.id),
      );
      expect(
        ProfileService.publicAvatarRef('preset:rabbit'),
        equals('preset:rabbit'),
      );
    });
  });
}
