// lib/screens/app_entry_screen.dart

import 'package:flutter/material.dart';

import '../services/auth_service.dart';
import '../services/settings_service.dart';
import '../theme/app_theme.dart';
import '../core/widgets/app_logo.dart';
import 'login_screen.dart';
import 'mode_selection_screen.dart';

/// Routes first-time users to [LoginScreen]; returning users go straight home.
class AppEntryScreen extends StatefulWidget {
  const AppEntryScreen({super.key});

  @override
  State<AppEntryScreen> createState() => _AppEntryScreenState();
}

class _AppEntryScreenState extends State<AppEntryScreen> {
  @override
  void initState() {
    super.initState();
    SettingsService.instance.addListener(_rebuild);
    AuthService.instance.addListener(_rebuild);
  }

  @override
  void dispose() {
    SettingsService.instance.removeListener(_rebuild);
    AuthService.instance.removeListener(_rebuild);
    super.dispose();
  }

  void _rebuild() {
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final settings = SettingsService.instance;
    final auth = AuthService.instance;

    final showLogin = !settings.loginGateCompleted && !auth.isAuthenticated;

    if (showLogin) {
      return const LoginScreen();
    }
    return const ModeSelectionScreen();
  }
}

/// Lightweight splash while settings hydrate before routing.
class AppEntryLoader extends StatefulWidget {
  const AppEntryLoader({super.key});

  @override
  State<AppEntryLoader> createState() => _AppEntryLoaderState();
}

class _AppEntryLoaderState extends State<AppEntryLoader> {
  bool _ready = false;

  @override
  void initState() {
    super.initState();
    _waitForSettings();
  }

  Future<void> _waitForSettings() async {
    if (!SettingsService.instance.isInitialized) {
      await SettingsService.instance.initialize();
    }
    if (mounted) setState(() => _ready = true);
  }

  @override
  Widget build(BuildContext context) {
    if (!_ready) {
      return const Scaffold(
        backgroundColor: AppTheme.deepNavy,
        body: Center(
          child: AppLogo(pulsing: true),
        ),
      );
    }
    return const AppEntryScreen();
  }
}
