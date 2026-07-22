// lib/main.dart

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:toastification/toastification.dart';

import 'providers/game_provider.dart';
import 'screens/home_screen.dart';
import 'screens/lobby_screen.dart';
import 'screens/game_screen.dart';
import 'screens/profile_screen.dart';
import 'services/audio_service.dart';
import 'services/reconnection_manager.dart';
import 'theme/app_theme.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
    DeviceOrientation.landscapeLeft,
    DeviceOrientation.landscapeRight,
  ]);

  // Pre-initialize audio service for card and collection feedback
  AudioService.instance.initialize();

  // TODO: Replace with your actual Supabase URL and Anon Key
  await Supabase.initialize(
    url: 'https://eqmkbfxerxqihforsgvx.supabase.co',
    anonKey: 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImVxbWtiZnhlcnhxaWhmb3JzZ3Z4Iiwicm9sZSI6ImFub24iLCJpYXQiOjE3ODQwNjQ0NTUsImV4cCI6MjA5OTY0MDQ1NX0.3F_n2TUVGTucW2DUWpv5YxqOtFkBQZaQJZKngL7gOx0',
  );

  // Start app UI immediately without blocking main() thread on network auth
  runApp(const KotshinaApp());

  // Ensure anonymous user exists for RLS asynchronously in background
  final auth = Supabase.instance.client.auth;
  if (auth.currentUser == null) {
    auth.signInAnonymously().catchError((e) {
      debugPrint('[Auth] signInAnonymously failed (offline?): $e');
      return AuthResponse();
    });
  }
}

class KotshinaApp extends StatelessWidget {
  const KotshinaApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        // ── Core state ──────────────────────────────────────────────────────
        ChangeNotifierProvider<GameProvider>(
          create: (_) => GameProvider(),
        ),
        // ── Reconnection manager (depends on GameProvider) ─────────────────
        // ChangeNotifierProxyProvider is used so ReconnectionManager can hold
        // a direct reference to GameProvider. The `update` callback always
        // returns `previous!` to reuse the same instance (never recreate).
        ChangeNotifierProxyProvider<GameProvider, ReconnectionManager>(
          create: (ctx) {
            final rm = ReconnectionManager(ctx.read<GameProvider>());
            rm.start(); // Register WidgetsBindingObserver + start heartbeat
            return rm;
          },
          update: (ctx, gameProvider, previous) => previous!,
        ),
      ],
      child: ToastificationWrapper(
        child: MaterialApp(
          title: 'كوتشينة',
          debugShowCheckedModeBanner: false,
          theme: AppTheme.theme,

          // Force RTL layout for Arabic UI
          builder: (context, child) {
            return Directionality(
              textDirection: TextDirection.rtl,
              child: child!,
            );
          },

          initialRoute: '/',
          routes: {
            '/': (_) => const HomeScreen(),
            '/lobby': (_) => const LobbyScreen(),
            '/game': (_) => const GameScreen(),
            '/profile': (_) => const ProfileScreen(),
          },
        ),
      ),
    );
  }
}

