import 'package:flutter_test/flutter_test.dart';
import 'package:estimation/core/config/app_config.dart';

void main() {
  group('AppConfig', () {
    test('parses environment label', () {
      expect(AppEnvironment.parse('production').label, 'production');
      expect(AppEnvironment.parse('staging').label, 'staging');
      expect(AppEnvironment.parse('dev').label, 'dev');
    });

    test('projectRefFromUrl extracts Supabase project ref', () {
      expect(
        AppConfig.projectRefFromUrl('https://abcxyz.supabase.co'),
        'abcxyz',
      );
      expect(
        AppConfig.projectRefFromUrl('http://127.0.0.1:54321'),
        isNull,
      );
    });

    test('validateConfiguration requires dart-defines', () {
      expect(
        () => AppConfig.validateConfiguration(),
        throwsA(isA<StateError>()),
      );
    });
  });
}
