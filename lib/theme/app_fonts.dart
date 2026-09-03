// lib/theme/app_fonts.dart

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';

abstract final class AppFonts {
  /// Tajawal font family name for all regular text and subtitles app-wide.
  static const String tajawalFont = 'Tajawal';

  /// Legacy aliases
  static const String cooperFont = tajawalFont;

  /// DG Ghayaty font family name for main titles and display headlines.
  static const String dgGhayatyFont = 'DGGhayaty';

  /// Fallback families for broad platform compatibility
  static const List<String> tajawalFallbacks = [
    'Tajawal',
    'Tajawal-Regular',
    'Cairo',
    'Roboto',
    'sans-serif',
  ];

  static const List<String> cooperFallbacks = tajawalFallbacks;

  static const List<String> dgFallbacks = [
    'DG Ghayaty',
    'DGGhayaty',
    'DGGhayaty-Regular',
  ];

  /// Convenience aliases
  static const String regularFamily = tajawalFont;
  static const String titleFamily = dgGhayatyFont;

  /// Ensures custom fonts are loaded directly into the Flutter engine via FontLoader.
  static Future<void> loadFonts() async {
    try {
      final tajawal = FontLoader(tajawalFont);
      tajawal.addFont(rootBundle.load('assets/fonts/Tajawal-Regular.ttf'));
      await tajawal.load();
    } catch (e) {
      debugPrint('[AppFonts] Tajawal FontLoader error: $e');
    }

    try {
      final dg = FontLoader(dgGhayatyFont);
      dg.addFont(rootBundle.load('assets/fonts/DGGhayaty.ttf'));
      await dg.load();
    } catch (e) {
      debugPrint('[AppFonts] DGGhayaty FontLoader error: $e');
    }

    try {
      final dgSpaced = FontLoader('DG Ghayaty');
      dgSpaced.addFont(rootBundle.load('assets/fonts/DGGhayaty.ttf'));
      await dgSpaced.load();
    } catch (_) {}
  }

  /// Creates a [TextStyle] using the [Tajawal] font family.
  /// Used for regular text, subtitles, buttons, chips, and body text app-wide.
  static TextStyle tajawal({
    TextStyle? textStyle,
    Color? color,
    Color? backgroundColor,
    double? fontSize,
    FontWeight? fontWeight,
    FontStyle? fontStyle,
    double? letterSpacing,
    double? wordSpacing,
    TextBaseline? textBaseline,
    double? height,
    Locale? locale,
    Paint? foreground,
    Paint? background,
    List<Shadow>? shadows,
    List<FontFeature>? fontFeatures,
    TextDecoration? decoration,
    Color? decorationColor,
    TextDecorationStyle? decorationStyle,
    double? decorationThickness,
  }) {
    return TextStyle(
      fontFamily: tajawalFont,
      fontFamilyFallback: tajawalFallbacks,
      inherit: textStyle?.inherit ?? true,
      color: color ?? textStyle?.color,
      backgroundColor: backgroundColor ?? textStyle?.backgroundColor,
      fontSize: fontSize ?? textStyle?.fontSize,
      fontWeight: fontWeight ?? textStyle?.fontWeight,
      fontStyle: fontStyle ?? textStyle?.fontStyle,
      letterSpacing: letterSpacing ?? textStyle?.letterSpacing,
      wordSpacing: wordSpacing ?? textStyle?.wordSpacing,
      textBaseline: textBaseline ?? textStyle?.textBaseline,
      height: height ?? textStyle?.height,
      locale: locale ?? textStyle?.locale,
      foreground: foreground ?? textStyle?.foreground,
      background: background ?? textStyle?.background,
      shadows: shadows ?? textStyle?.shadows,
      fontFeatures: fontFeatures ?? textStyle?.fontFeatures,
      decoration: decoration ?? textStyle?.decoration,
      decorationColor: decorationColor ?? textStyle?.decorationColor,
      decorationStyle: decorationStyle ?? textStyle?.decorationStyle,
      decorationThickness:
          decorationThickness ?? textStyle?.decorationThickness,
    );
  }

  /// Alias for regular text routing to [Tajawal].
  static TextStyle cooper({
    TextStyle? textStyle,
    Color? color,
    Color? backgroundColor,
    double? fontSize,
    FontWeight? fontWeight,
    FontStyle? fontStyle,
    double? letterSpacing,
    double? wordSpacing,
    TextBaseline? textBaseline,
    double? height,
    Locale? locale,
    Paint? foreground,
    Paint? background,
    List<Shadow>? shadows,
    List<FontFeature>? fontFeatures,
    TextDecoration? decoration,
    Color? decorationColor,
    TextDecorationStyle? decorationStyle,
    double? decorationThickness,
  }) =>
      tajawal(
        textStyle: textStyle,
        color: color,
        backgroundColor: backgroundColor,
        fontSize: fontSize,
        fontWeight: fontWeight,
        fontStyle: fontStyle,
        letterSpacing: letterSpacing,
        wordSpacing: wordSpacing,
        textBaseline: textBaseline,
        height: height,
        locale: locale,
        foreground: foreground,
        background: background,
        shadows: shadows,
        fontFeatures: fontFeatures,
        decoration: decoration,
        decorationColor: decorationColor,
        decorationStyle: decorationStyle,
        decorationThickness: decorationThickness,
      );

  /// Creates a [TextStyle] using the [DGGhayaty] font family.
  /// Used for main titles and display headlines.
  static TextStyle dg({
    TextStyle? textStyle,
    Color? color,
    Color? backgroundColor,
    double? fontSize,
    FontWeight? fontWeight,
    FontStyle? fontStyle,
    double? letterSpacing,
    double? wordSpacing,
    TextBaseline? textBaseline,
    double? height,
    Locale? locale,
    Paint? foreground,
    Paint? background,
    List<Shadow>? shadows,
    List<FontFeature>? fontFeatures,
    TextDecoration? decoration,
    Color? decorationColor,
    TextDecorationStyle? decorationStyle,
    double? decorationThickness,
  }) {
    return TextStyle(
      fontFamily: dgGhayatyFont,
      fontFamilyFallback: dgFallbacks,
      inherit: textStyle?.inherit ?? true,
      color: color ?? textStyle?.color,
      backgroundColor: backgroundColor ?? textStyle?.backgroundColor,
      fontSize: fontSize ?? textStyle?.fontSize,
      fontWeight: fontWeight ?? textStyle?.fontWeight,
      fontStyle: fontStyle ?? textStyle?.fontStyle,
      letterSpacing: letterSpacing ?? textStyle?.letterSpacing,
      wordSpacing: wordSpacing ?? textStyle?.wordSpacing,
      textBaseline: textBaseline ?? textStyle?.textBaseline,
      height: height ?? textStyle?.height,
      locale: locale ?? textStyle?.locale,
      foreground: foreground ?? textStyle?.foreground,
      background: background ?? textStyle?.background,
      shadows: shadows ?? textStyle?.shadows,
      fontFeatures: fontFeatures ?? textStyle?.fontFeatures,
      decoration: decoration ?? textStyle?.decoration,
      decorationColor: decorationColor ?? textStyle?.decorationColor,
      decorationStyle: decorationStyle ?? textStyle?.decorationStyle,
      decorationThickness:
          decorationThickness ?? textStyle?.decorationThickness,
    );
  }

  /// Compatibility wrapper for any references previously routed through cairo.
  /// Routes regular text to Tajawal app-wide.
  static TextStyle cairo({
    TextStyle? textStyle,
    Color? color,
    Color? backgroundColor,
    double? fontSize,
    FontWeight? fontWeight,
    FontStyle? fontStyle,
    double? letterSpacing,
    double? wordSpacing,
    TextBaseline? textBaseline,
    double? height,
    Locale? locale,
    Paint? foreground,
    Paint? background,
    List<Shadow>? shadows,
    List<FontFeature>? fontFeatures,
    TextDecoration? decoration,
    Color? decorationColor,
    TextDecorationStyle? decorationStyle,
    double? decorationThickness,
  }) =>
      tajawal(
        textStyle: textStyle,
        color: color,
        backgroundColor: backgroundColor,
        fontSize: fontSize,
        fontWeight: fontWeight,
        fontStyle: fontStyle,
        letterSpacing: letterSpacing,
        wordSpacing: wordSpacing,
        textBaseline: textBaseline,
        height: height,
        locale: locale,
        foreground: foreground,
        background: background,
        shadows: shadows,
        fontFeatures: fontFeatures,
        decoration: decoration,
        decorationColor: decorationColor,
        decorationStyle: decorationStyle,
        decorationThickness: decorationThickness,
      );

  /// Helper for decorative roman/latin numerals
  static TextStyle cinzel({
    TextStyle? textStyle,
    Color? color,
    double? fontSize,
    FontWeight? fontWeight,
    double? letterSpacing,
    double? height,
  }) =>
      GoogleFonts.cinzel(
        textStyle: textStyle,
        color: color,
        fontSize: fontSize,
        fontWeight: fontWeight,
        letterSpacing: letterSpacing,
        height: height,
      );
}
