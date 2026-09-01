// lib/main.dart

import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import 'package:supabase_flutter/supabase_flutter.dart';

import 'providers/game_provider.dart';
import 'modes/ninety_nine/presentation/providers/ninety_nine_game_provider.dart';
import 'modes/basra/presentation/providers/basra_game_provider.dart';
import 'screens/app_entry_screen.dart';
import 'screens/mode_selection_screen.dart';
import 'screens/home_screen.dart';
import 'screens/lobby_screen.dart';
import 'screens/game_screen.dart';
import 'screens/profile_screen.dart';
import 'screens/local_discovery_screen.dart';
import 'screens/academy/academy_home_screen.dart';
import 'screens/puzzles/puzzles_home_screen.dart';
import 'modes/ninety_nine/presentation/screens/ninety_nine_home_screen.dart';
import 'modes/ninety_nine/presentation/screens/ninety_nine_game_screen.dart';
import 'modes/basra/presentation/screens/basra_home_screen.dart';
import 'modes/basra/presentation/screens/basra_game_screen.dart';
import 'features/matchmaking/presentation/screens/matchmaking_screen.dart';

import 'services/audio_service.dart';
import 'services/reconnection_manager.dart';
import 'services/online_play_gate.dart';
import 'services/device_performance_service.dart';
import 'services/auth_service.dart';
import 'services/settings_service.dart';
import 'services/game_action_service.dart';
import 'theme/app_theme.dart';
import 'core/constants.dart';
import 'core/utils/wallpaper_precache.dart';
import 'core/config/app_config.dart';
import 'core/widgets/app_logo.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

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

  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
    DeviceOrientation.landscapeLeft,
    DeviceOrientation.landscapeRight,
  ]);

  const serverAuthority =
      bool.fromEnvironment('SERVER_AUTHORITY', defaultValue: false);
  GameActionService.useServerAuthority = serverAuthority;

  runApp(const AppBootstrap());
}

class AppBootstrap extends StatefulWidget {
  const AppBootstrap({super.key});

  @override
  State<AppBootstrap> createState() => _AppBootstrapState();
}

class _AppBootstrapState extends State<AppBootstrap> {
  bool _isReady = false;
  bool _isLoading = true;
  Object? _error;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _initialize());
  }

  Future<void> _initialize() async {
    if (_isLoading && _error != null) return;
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      AppConfig.validateConfiguration();
      await Supabase.initialize(
        url: AppConfig.supabaseUrl,
        publishableKey: AppConfig.supabaseAnonKey,
      );

      await Future.wait([
        DevicePerformanceService.instance.initialize(),
        SettingsService.instance.initialize(),
        AuthService.instance.initialize(),
      ]);

      if (!mounted) return;
      setState(() {
        _isReady = true;
        _isLoading = false;
      });

      unawaited(AudioService.instance.initialize());
      // Best-effort byte warm-up before any route context exists. Full decode
      // happens via [WallpaperPrecache] on the mode selection / home screens.
      unawaited(Future.wait([
        _preloadAssetBytes(WallpaperPrecache.modeSelection),
        _preloadAssetBytes(WallpaperPrecache.modeHome),
      ]));

      final auth = Supabase.instance.client.auth;
      if (auth.currentUser == null) {
        unawaited(
          auth.signInAnonymously().catchError((Object error) {
            debugPrint(
              '[Auth] signInAnonymously skipped (disabled or offline): $error',
            );
            return AuthResponse();
          }),
        );
      }
    } catch (error, stackTrace) {
      debugPrint('[Bootstrap] initialization failed: $error\n$stackTrace');
      if (!mounted) return;
      setState(() {
        _error = error;
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isReady) return const KotshinaApp();

    return MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: AppTheme.theme,
      home: Scaffold(
        body: Center(
          child: _error == null
              ? const Center(child: AppLogo(pulsing: true))
              : Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(
                      Icons.cloud_off_rounded,
                      color: AppTheme.errorRed,
                      size: 40,
                    ),
                    const SizedBox(height: 16),
                    const Text('تعذر تشغيل التطبيق'),
                    const SizedBox(height: 12),
                    FilledButton.icon(
                      onPressed: _isLoading ? null : _initialize,
                      icon: const Icon(Icons.refresh_rounded),
                      label: const Text('إعادة المحاولة'),
                    ),
                  ],
                ),
        ),
      ),
    );
  }
}

/// Loads asset bytes into the asset bundle cache (no [ImageCache] decode yet).
Future<void> _preloadAssetBytes(String assetPath) async {
  try {
    await rootBundle.load(assetPath);
  } catch (error) {
    debugPrint('[Preload] $assetPath bytes failed: $error');
  }
}

class KotshinaApp extends StatelessWidget {
  const KotshinaApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        // ── Core state ──────────────────────────────────────────────────────
        ChangeNotifierProvider<AuthService>.value(
          value: AuthService.instance,
        ),
        ChangeNotifierProvider<DevicePerformanceService>.value(
          value: DevicePerformanceService.instance,
        ),
        ChangeNotifierProvider<NinetyNineGameProvider>(
          create: (_) => NinetyNineGameProvider(),
        ),
        ChangeNotifierProvider<BasraGameProvider>(
          create: (_) => BasraGameProvider(),
        ),
        ChangeNotifierProxyProvider2<NinetyNineGameProvider, BasraGameProvider,
            GameProvider>(
          create: (ctx) => GameProvider()
            ..nnProvider = ctx.read<NinetyNineGameProvider>()
            ..basraProvider = ctx.read<BasraGameProvider>(),
          update: (ctx, nnProvider, basraProvider, previous) => previous!
            ..nnProvider = nnProvider
            ..basraProvider = basraProvider,
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
        ChangeNotifierProvider<OnlinePlayGate>(
          create: (_) => OnlinePlayGate(),
        ),
      ],
      child: MaterialApp(
        title: kAppName,
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
          '/': (_) => const AppEntryLoader(),
          '/home': (_) => const ModeSelectionScreen(),
          '/kotchina/home': (_) => const HomeScreen(),
          '/lobby': (_) => const LobbyScreen(),
          '/game': (_) => const GameScreen(),
          '/matchmaking': (_) => const MatchmakingScreen(),
          '/profile': (_) => const ProfileScreen(),
          '/local_discovery': (_) => const LocalDiscoveryScreen(),
          '/academy': (_) => const AcademyHomeScreen(),
          '/puzzles': (_) => const PuzzlesHomeScreen(),
          '/ninety_nine/home': (_) => const NinetyNineHomeScreen(),
          '/ninety_nine/game': (_) => const NinetyNineGameScreen(),
          '/basra/home': (_) => const BasraHomeScreen(),
          '/basra/game': (_) => const BasraGameScreen(),
        },
      ),
    );
  }
}
