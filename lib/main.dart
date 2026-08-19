// lib/main.dart

import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import 'package:supabase_flutter/supabase_flutter.dart';

import 'providers/game_provider.dart';
import 'modes/ninety_nine/presentation/providers/ninety_nine_game_provider.dart';
import 'screens/mode_selection_screen.dart';
import 'screens/home_screen.dart';
import 'screens/lobby_screen.dart';
import 'screens/game_screen.dart';
import 'screens/profile_screen.dart';
import 'screens/local_discovery_screen.dart';
import 'modes/ninety_nine/presentation/screens/ninety_nine_home_screen.dart';
import 'modes/ninety_nine/presentation/screens/ninety_nine_game_screen.dart';

import 'services/audio_service.dart';
import 'services/reconnection_manager.dart';
import 'services/device_performance_service.dart';
import 'theme/app_theme.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // Initialize device performance hardware detection (e.g. Note 9 / low-spec auto-detection)
  await DevicePerformanceService.instance.initialize();
  
  // Enable full-screen edge-to-edge mode for status & navigation bars
  await SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.light,
      statusBarBrightness: Brightness.dark,
      systemNavigationBarColor: Colors.transparent,
      systemNavigationBarIconBrightness: Brightness.light,
      systemNavigationBarDividerColor: Colors.transparent,
    ),
  );

  SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
    DeviceOrientation.landscapeLeft,
    DeviceOrientation.landscapeRight,
  ]);

  // Pre-initialize audio service for card and collection feedback
  AudioService.instance.initialize();

  // Pre-load wallpaper images into Flutter's image codec cache BEFORE runApp
  // so they are instantly available when the first frame renders
  await Future.wait([
    _preloadAsset('assets/wallpapers/w1.jpg'),
    _preloadAsset('assets/wallpapers/w2.jpg'),
  ]);

  // Supabase initialization
  await Supabase.initialize(
    url: 'https://eqmkbfxerxqihforsgvx.supabase.co',
    anonKey: 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImVxbWtiZnhlcnhxaWhmb3JzZ3Z4Iiwicm9sZSI6ImFub24iLCJpYXQiOjE3ODQwNjQ0NTUsImV4cCI6MjA5OTY0MDQ1NX0.3F_n2TUVGTucW2DUWpv5YxqOtFkBQZaQJZKngL7gOx0',
  );

  // Start app UI immediately
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

/// Preloads an asset image into Flutter's [PaintingBinding.imageCache].
Future<void> _preloadAsset(String assetPath) async {
  final provider = AssetImage(assetPath);
  final stream = provider.resolve(ImageConfiguration.empty);

  final completer = Completer<void>();
  late ImageStreamListener listener;
  listener = ImageStreamListener(
    (ImageInfo info, bool sync) {
      info.dispose();
      if (!completer.isCompleted) completer.complete();
    },
    onError: (Object error, StackTrace? stack) {
      debugPrint('[Preload] $assetPath failed: $error');
      if (!completer.isCompleted) completer.complete();
    },
  );

  stream.addListener(listener);
  await completer.future;
  stream.removeListener(listener);
}

class KotshinaApp extends StatelessWidget {
  const KotshinaApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        // ── Core state ──────────────────────────────────────────────────────
        ChangeNotifierProvider<DevicePerformanceService>.value(
          value: DevicePerformanceService.instance,
        ),
        ChangeNotifierProvider<NinetyNineGameProvider>(
          create: (_) => NinetyNineGameProvider(),
        ),
        ChangeNotifierProxyProvider<NinetyNineGameProvider, GameProvider>(
          create: (ctx) => GameProvider()..nnProvider = ctx.read<NinetyNineGameProvider>(),
          update: (ctx, nnProvider, previous) => previous!..nnProvider = nnProvider,
        ),
        // ── Reconnection manager (depends on GameProvider) ─────────────────
        ChangeNotifierProxyProvider<GameProvider, ReconnectionManager>(
          create: (ctx) {
            final rm = ReconnectionManager(ctx.read<GameProvider>());
            rm.start(); // Register WidgetsBindingObserver + start heartbeat
            return rm;
          },
          update: (ctx, gameProvider, previous) => previous!,
        ),
      ],
      child: MaterialApp(
        title: 'كوتشينة مالتيبلاير',
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
          '/': (_) => const ModeSelectionScreen(),
          '/kotchina/home': (_) => const HomeScreen(),
          '/lobby': (_) => const LobbyScreen(),
          '/game': (_) => const GameScreen(),
          '/profile': (_) => const ProfileScreen(),
          '/local_discovery': (_) => const LocalDiscoveryScreen(),
          '/ninety_nine/home': (_) => const NinetyNineHomeScreen(),
          '/ninety_nine/game': (_) => const NinetyNineGameScreen(),
        },
      ),
    );
  }
}
