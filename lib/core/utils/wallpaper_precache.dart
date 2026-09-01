import 'dart:async';

import 'package:flutter/material.dart';

/// Keeps mode-picker and mode-home wallpapers decoded in [ImageCache].
class WallpaperPrecache {
  WallpaperPrecache._();

  static const modeSelection = 'assets/wallpapers/w1.jpg';
  static const modeHome = 'assets/wallpapers/w2.jpg';
  static const login = 'assets/wallpapers/login-wall.png';

  /// Wallpapers used across mode selection + Estimation / Basra / 99 homes.
  static const List<String> modeFlowWallpapers = [
    modeSelection,
    modeHome,
  ];

  static final Set<String> _warming = {};

  /// Target decode width — matches [wallpaperProvider] so cache keys align.
  static int wallpaperCacheWidth(BuildContext context) {
    final width =
        MediaQuery.sizeOf(context).width * MediaQuery.devicePixelRatioOf(context);
    return width.round().clamp(360, 4096);
  }

  static ImageProvider wallpaperProvider(String assetPath, BuildContext context) {
    return ResizeImage(
      AssetImage(assetPath),
      width: wallpaperCacheWidth(context),
    );
  }

  /// Fire-and-forget warm-up safe to call from [State.didChangeDependencies].
  static void warmModeFlow(BuildContext context) {
    unawaited(precacheModeFlow(context));
  }

  static Future<void> precacheModeFlow(BuildContext context) {
    return Future.wait(
      modeFlowWallpapers.map((path) => precache(context, path)),
    );
  }

  static Future<void> precache(BuildContext context, String assetPath) async {
    if (_warming.contains(assetPath)) return;
    _warming.add(assetPath);
    try {
      await precacheImage(wallpaperProvider(assetPath, context), context);
    } catch (error) {
      debugPrint('[WallpaperPrecache] Failed for $assetPath: $error');
    } finally {
      _warming.remove(assetPath);
    }
  }
}

/// Call once per screen visit from [didChangeDependencies].
mixin ModeWallpaperPrecacheMixin<T extends StatefulWidget> on State<T> {
  bool _modeWallpapersScheduled = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_modeWallpapersScheduled) return;
    _modeWallpapersScheduled = true;
    WallpaperPrecache.warmModeFlow(context);
  }
}
