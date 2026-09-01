import 'package:supabase_flutter/supabase_flutter.dart';

/// Dummy Supabase endpoint for widget/unit tests (no network).
const kTestSupabaseUrl = 'https://test-project.supabase.co';
const kTestSupabaseAnonKey =
    'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.test-anon-key-not-real';

Future<void> initTestSupabase() async {
  try {
    await Supabase.initialize(
      url: kTestSupabaseUrl,
      publishableKey: kTestSupabaseAnonKey,
      authOptions: const FlutterAuthClientOptions(autoRefreshToken: false),
    );
  } catch (_) {}
}
