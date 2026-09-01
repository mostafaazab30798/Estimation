// W0.9 / W1.10 — Build-time environment selection (no hardcoded credentials).

import 'package:flutter/foundation.dart';

enum AppEnvironment {
  dev,
  staging,
  production;

  static AppEnvironment parse(String raw) {
    switch (raw.trim().toLowerCase()) {
      case 'dev':
      case 'development':
        return AppEnvironment.dev;
      case 'staging':
      case 'stage':
        return AppEnvironment.staging;
      case 'prod':
      case 'production':
      default:
        return AppEnvironment.production;
    }
  }

  String get label => switch (this) {
        AppEnvironment.dev => 'dev',
        AppEnvironment.staging => 'staging',
        AppEnvironment.production => 'production',
      };
}

class AppConfig {
  AppConfig._();

  static const String _envRaw =
      String.fromEnvironment('APP_ENV', defaultValue: 'production');
  static const String _supabaseUrl =
      String.fromEnvironment('SUPABASE_URL', defaultValue: '');
  static const String _supabaseAnonKey =
      String.fromEnvironment('SUPABASE_ANON_KEY', defaultValue: '');

  /// Production project ref — staging/dev builds must not target this host.
  static const String productionProjectRef = String.fromEnvironment(
    'PROD_PROJECT_REF',
    defaultValue: 'eqmkbfxerxqihforsgvx',
  );

  static final AppEnvironment environment = AppEnvironment.parse(_envRaw);

  static String get supabaseUrl {
    _requireNonEmpty(_supabaseUrl, 'SUPABASE_URL');
    return _supabaseUrl;
  }

  static String get supabaseAnonKey {
    _requireNonEmpty(_supabaseAnonKey, 'SUPABASE_ANON_KEY');
    return _supabaseAnonKey;
  }

  static bool get isProduction => environment == AppEnvironment.production;

  static bool get usesExplicitDartDefines =>
      _supabaseUrl.isNotEmpty && _supabaseAnonKey.isNotEmpty;

  /// Call once at startup before [Supabase.initialize].
  static void validateConfiguration() {
    final url = supabaseUrl;
    final key = supabaseAnonKey;

    if (!url.startsWith('https://') && !url.startsWith('http://127.0.0.1')) {
      throw StateError('SUPABASE_URL must be a valid HTTP(S) URL: $url');
    }
    if (key.length < 20) {
      throw StateError('SUPABASE_ANON_KEY looks invalid (too short).');
    }
    if (environment == AppEnvironment.staging &&
        url.contains(productionProjectRef)) {
      throw StateError(
        'Staging build targets production Supabase ($productionProjectRef). '
        'Use a separate staging project in config/env.staging.json.',
      );
    }
    if (environment == AppEnvironment.dev && url.contains(productionProjectRef)) {
      debugPrint(
        '[AppConfig] Warning: dev build is pointed at production Supabase '
        '($productionProjectRef). Prefer config/env.dev.json with local stack.',
      );
    }
  }

  static void _requireNonEmpty(String value, String name) {
    if (value.isNotEmpty) return;
    throw StateError(
      '$name is required. Run with '
      '--dart-define-from-file=config/env.prod.json (see docs/env-setup.md).',
    );
  }

  /// Extracts the project ref from a Supabase project URL host.
  static String? projectRefFromUrl(String url) {
    final uri = Uri.tryParse(url);
    if (uri == null || uri.host.isEmpty) return null;
    final parts = uri.host.split('.');
    if (parts.length >= 3 && parts[1] == 'supabase') return parts[0];
    return null;
  }
}
