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
import 'screens/history_screen.dart';
import 'theme/app_theme.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
    DeviceOrientation.landscapeLeft,
    DeviceOrientation.landscapeRight,
  ]);

  // TODO: Replace with your actual Supabase URL and Anon Key
  await Supabase.initialize(
    url: 'https://eqmkbfxerxqihforsgvx.supabase.co',
    anonKey: 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImVxbWtiZnhlcnhxaWhmb3JzZ3Z4Iiwicm9sZSI6ImFub24iLCJpYXQiOjE3ODQwNjQ0NTUsImV4cCI6MjA5OTY0MDQ1NX0.3F_n2TUVGTucW2DUWpv5YxqOtFkBQZaQJZKngL7gOx0',
  );

  // Ensure anonymous user exists for RLS
  // Wrapped in try-catch: if device is offline the app still opens,
  // and Supabase will retry on the next network request.
  final auth = Supabase.instance.client.auth;
  if (auth.currentUser == null) {
    try {
      await auth.signInAnonymously();
    } catch (e) {
      debugPrint('[Auth] signInAnonymously failed (offline?): $e');
      // App continues — multiplayer features will fail gracefully later.
    }
  }

  runApp(const KotshinaApp());
}

class KotshinaApp extends StatelessWidget {
  const KotshinaApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (_) => GameProvider(),
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
          '/history': (_) => const HistoryScreen(),
        },
      ),
      ),
    );
  }
}

