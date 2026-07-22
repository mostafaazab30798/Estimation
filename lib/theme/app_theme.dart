// lib/theme/app_theme.dart

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class AppTheme {
  // ── Palette ──────────────────────────────────────────────────
  static const Color navyDeep    = Color(0xFF293681);
  static const Color navyMid     = Color(0xFF1E2A6B);
  static const Color navyDark    = Color(0xFF161D4A);
  static const Color accentBlue  = Color(0xFF4274D9);
  static const Color accentLight = Color(0xFF95CCDD);
  static const Color mintSoft    = Color(0xFFD0E7E6);
  static const Color white       = Color(0xFFFFFFFF);

  // ── Semantic aliases (backward compatibility) ─────────────────
  static const Color feltGreen      = navyDeep;
  static const Color feltGreenLight = navyMid;
  static const Color feltGreenDark  = navyDark;
  static const Color gold           = accentBlue;
  static const Color goldDark       = Color(0xFF2F5BB0);
  static const Color cardWhite      = mintSoft;
  static const Color cardBack       = navyDeep;
  static const Color suitRed        = Color(0xFFE05C73);
  static const Color suitBlack      = mintSoft;
  static const Color surface        = navyMid;
  static const Color surfaceCard    = Color(0xFF253070);
  static const Color textPrimary    = mintSoft;
  static const Color textSecondary  = accentLight;
  static const Color errorRed       = Color(0xFFE05C73);

  // ── Gradients ─────────────────────────────────────────────────
  static const LinearGradient bgGradient = LinearGradient(
    colors: [navyDark, navyDeep],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const LinearGradient accentGradient = LinearGradient(
    colors: [accentBlue, Color(0xFF5B8FE8)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  // ── Shadows & Neumorphic Design Tokens ───────────────────────
  static List<BoxShadow> get glowShadow => [
    BoxShadow(
      color: accentBlue.withValues(alpha: 0.4),
      blurRadius: 24,
      spreadRadius: 2,
    ),
  ];

  static List<BoxShadow> get cardShadow => [
    BoxShadow(
      color: navyDark.withValues(alpha: 0.6),
      blurRadius: 16,
      offset: const Offset(0, 6),
    ),
  ];

  /// Dual-shadow Neumorphic Extruded style for 3D tactile buttons & cards.
  static List<BoxShadow> get neumorphicExtruded => [
    BoxShadow(
      color: Colors.black.withValues(alpha: 0.45),
      blurRadius: 10,
      offset: const Offset(4, 4),
    ),
    BoxShadow(
      color: Colors.white.withValues(alpha: 0.08),
      blurRadius: 8,
      offset: const Offset(-3, -3),
    ),
  ];

  /// Soft Neumorphic active glow for turn cards / active elements.
  static List<BoxShadow> neumorphicTurnGlow(Color mainColor) => [
    BoxShadow(
      color: mainColor.withValues(alpha: 0.4),
      blurRadius: 18,
      spreadRadius: 2,
      offset: const Offset(0, 2),
    ),
    BoxShadow(
      color: Colors.black.withValues(alpha: 0.35),
      blurRadius: 8,
      offset: const Offset(3, 3),
    ),
  ];

  static ThemeData get theme {
    final base = ThemeData.dark();
    return base.copyWith(
      scaffoldBackgroundColor: navyDark,
      colorScheme: const ColorScheme.dark(
        primary: accentBlue,
        secondary: accentLight,
        surface: navyMid,
        error: errorRed,
        onPrimary: white,
        onSecondary: navyDark,
        onSurface: mintSoft,
      ),
      textTheme: GoogleFonts.cairoTextTheme(base.textTheme).copyWith(
        displayLarge: GoogleFonts.alexandria(
          color: mintSoft,
          fontSize: 36,
          fontWeight: FontWeight.w800,
          letterSpacing: -0.5,
        ),
        displayMedium: GoogleFonts.cairo(
          color: mintSoft,
          fontSize: 26,
          fontWeight: FontWeight.w700,
        ),
        headlineMedium: GoogleFonts.cairo(
          color: mintSoft,
          fontSize: 20,
          fontWeight: FontWeight.w600,
        ),
        bodyLarge: GoogleFonts.cairo(
          color: mintSoft,
          fontSize: 16,
          fontWeight: FontWeight.w500,
        ),
        bodyMedium: GoogleFonts.cairo(
          color: accentLight,
          fontSize: 14,
          fontWeight: FontWeight.w400,
        ),
        labelLarge: GoogleFonts.cairo(
          color: white,
          fontSize: 16,
          fontWeight: FontWeight.w700,
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: accentBlue,
          foregroundColor: white,
          padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          elevation: 0,
          shadowColor: Colors.transparent,
          textStyle: GoogleFonts.cairo(
            fontSize: 17,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: accentLight,
          side: const BorderSide(color: accentLight, width: 1.5),
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          textStyle: GoogleFonts.cairo(
            fontSize: 16,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: accentLight,
          textStyle: GoogleFonts.cairo(
            fontSize: 15,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
      cardTheme: CardThemeData(
        color: navyMid,
        elevation: 0,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: navyMid,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      ),
      snackBarTheme: const SnackBarThemeData(
        backgroundColor: surfaceCard,
        contentTextStyle: TextStyle(color: mintSoft),
      ),
      dividerColor: Colors.white12,
      iconTheme: const IconThemeData(color: accentLight),
    );
  }
}
