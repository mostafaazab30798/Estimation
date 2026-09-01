import 'package:flutter/material.dart';

import '../../providers/game_provider.dart';

/// Detects game/lobby routes that outlived a [GameProvider.reset] (e.g. bot
/// mode cleared on background) and sends the player home instead of spinning.
class StaleGameRoute {
  StaleGameRoute._();

  static bool isStaleKotchinaGame(GameProvider provider) {
    if (provider.status == ConnectionStatus.connecting) return false;
    if (provider.isTemporarilyAway) return false;
    if (provider.currentRoom != null) return false;
    if (provider.isTestMode && provider.state != null) return false;
    return provider.state == null;
  }

  static bool isStaleLobby(
    GameProvider provider, {
    required bool isAlternateMode,
  }) {
    if (provider.status == ConnectionStatus.connecting) return false;
    if (provider.isTemporarilyAway) return false;
    if (provider.currentRoom != null) return false;
    if (provider.isTestMode) return false;
    if (isAlternateMode) return false;
    return provider.state == null;
  }

  static void redirectToModeHome(BuildContext context) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!context.mounted) return;
      Navigator.of(context, rootNavigator: true).pushNamedAndRemoveUntil(
        '/',
        (route) => false,
      );
    });
  }
}
