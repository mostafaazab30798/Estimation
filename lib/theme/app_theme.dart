// lib/theme/app_theme.dart

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class AppTheme {
  // ── Core Palette (user-specified) ─────────────────────────────
  static const Color deepNavy  = Color(0xFF213448); // darkest – base bg
  static const Color midBlue   = Color(0xFF547792); // surfaces / cards
  static const Color steelBlue = Color(0xFF94B4C1); // accents / borders / secondary text
  static const Color cream     = Color(0xFFEAE0CF); // primary text / highlights

  // ── Extended surface ──────────────────────────────────────────
  static const Color surface2  = Color(0xFF2A4560); // slightly lighter than deepNavy

  // ── Semantic aliases (backward compatibility) ─────────────────
  static const Color navyDeep    = deepNavy;
  static const Color navyMid     = surface2;
  static const Color navyDark    = deepNavy;
  static const Color accentBlue  = midBlue;
  static const Color accentLight = steelBlue;
  static const Color mintSoft    = cream;
  static const Color white       = Color(0xFFFFFFFF);

  static const Color feltGreen      = deepNavy;
  static const Color feltGreenLight = surface2;
  static const Color feltGreenDark  = deepNavy;

  // ── Gold – warm amber, not the old navy blue ──────────────────
  static const Color gold           = Color(0xFFD4A853);
  static const Color goldDark       = Color(0xFFA07830);
  static const Color goldLight      = Color(0xFFE8C470);

  static const Color cardWhite   = cream;
  static const Color cardBack    = deepNavy;
  static const Color suitRed     = Color(0xFFE05C73);
  static const Color suitBlack   = steelBlue;
  static const Color surface     = surface2;
  static const Color surfaceCard = surface2;
  static const Color textPrimary   = cream;
  static const Color textSecondary = steelBlue;
  static const Color errorRed      = Color(0xFFE05C73);

  // ── Player State Colors ───────────────────────────────────────
  static const Color playerBlue   = midBlue;
  static const Color playerGreen  = Color(0xFF3DAA6A);
  static const Color playerOrange = Color(0xFFE8924A);
  static const Color playerRed    = Color(0xFFE05C73);
  static const Color playerGold   = Color(0xFFD4A853);

  // ── Glass / HUD Tokens ────────────────────────────────────────
  static const Color glassBackground = deepNavy;   // used at 80% opacity
  static const Color glassBorder     = steelBlue;  // used at 10–12% opacity
  static const Color cardShadowDeep  = Color(0xFF0D1E2E);

  // ── Glow Tokens ───────────────────────────────────────────────
  static const Color accentGlow  = midBlue;
  static const Color successGlow = Color(0xFF3DAA6A);
  static const Color dangerGlow  = Color(0xFFE05C73);
  static const Color warningGlow = Color(0xFFE8924A);

  // ── Phase Ambient Colors ──────────────────────────────────────
  static const Color phaseReady        = Color(0xFF3DAA6A);
  static const Color phaseAuction      = Color(0xFF7B52C8);
  static const Color phaseDeclarations = midBlue;
  static const Color phasePlay         = Color(0xFFD4A853);
  static const Color phaseScoring      = cream;

  // ── Rank Colors ───────────────────────────────────────────────
  static const Color rankGold   = Color(0xFFD4A853);
  static const Color rankSilver = Color(0xFFABBAC8);
  static const Color rankBronze = Color(0xFFB07B4A);
  static const Color rankLast   = Color(0xFF8B3A4A);

  // ── Gradients ─────────────────────────────────────────────────
  static const LinearGradient bgGradient = LinearGradient(
    colors: [deepNavy, Color(0xFF1A2E40)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const LinearGradient accentGradient = LinearGradient(
    colors: [midBlue, steelBlue],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const LinearGradient goldGradient = LinearGradient(
    colors: [Color(0xFFD4A853), Color(0xFFE8C470)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const LinearGradient glassGradient = LinearGradient(
    colors: [Color(0x28547792), Color(0x14213448)],
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
  );

  static const LinearGradient cardGradient = LinearGradient(
    colors: [Color(0xFF2A4560), Color(0xFF1D3348)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  // ── Shadows & Neumorphic Design Tokens ────────────────────────
  static List<BoxShadow> get glowShadow => [
    BoxShadow(
      color: midBlue.withValues(alpha: 0.4),
      blurRadius: 24,
      spreadRadius: 2,
    ),
  ];

  static List<BoxShadow> get cardShadow => [
    BoxShadow(
      color: const Color(0xFF0D1E2E).withValues(alpha: 0.7),
      blurRadius: 16,
      offset: const Offset(0, 6),
    ),
    BoxShadow(
      color: Colors.black.withValues(alpha: 0.3),
      blurRadius: 8,
      offset: const Offset(0, 3),
    ),
  ];

  /// Dual-shadow Neumorphic Extruded style for 3D tactile elements.
  static List<BoxShadow> get neumorphicExtruded => [
    BoxShadow(
      color: Colors.black.withValues(alpha: 0.5),
      blurRadius: 12,
      offset: const Offset(4, 4),
    ),
    BoxShadow(
      color: steelBlue.withValues(alpha: 0.07),
      blurRadius: 8,
      offset: const Offset(-3, -3),
    ),
  ];

  /// Soft animated glow for active/turn elements.
  static List<BoxShadow> neumorphicTurnGlow(Color mainColor) => [
    BoxShadow(
      color: mainColor.withValues(alpha: 0.45),
      blurRadius: 22,
      spreadRadius: 3,
      offset: const Offset(0, 2),
    ),
    BoxShadow(
      color: mainColor.withValues(alpha: 0.2),
      blurRadius: 40,
      spreadRadius: 6,
    ),
    BoxShadow(
      color: Colors.black.withValues(alpha: 0.35),
      blurRadius: 8,
      offset: const Offset(3, 3),
    ),
  ];

  /// Modern Glassmorphism container decoration helper.
  static BoxDecoration glassDecoration({
    double borderRadius = 24,
    Color? borderColor,
    Color? fillColor,
    Gradient? gradient,
    List<BoxShadow>? shadows,
  }) =>
      BoxDecoration(
        gradient: gradient ?? (fillColor == null ? glassGradient : null),
        color: fillColor,
        borderRadius: BorderRadius.circular(borderRadius),
        border: Border.all(
          color: borderColor ?? steelBlue.withValues(alpha: 0.12),
          width: 1.2,
        ),
        boxShadow: shadows ?? cardShadow,
      );

  // ── Helpers ───────────────────────────────────────────────────

  /// Returns avatar ring / accent color for a player's trick state.
  static Color avatarRingColor({
    required bool isCurrentTurn,
    required int actual,
    required int? declared,
    required int tricksPlayedThisRound,
  }) {
    if (isCurrentTurn) return playerGold;
    if (declared == null) return playerBlue;
    if (actual == declared) return playerGreen;
    if (actual > declared) return playerRed;
    if (tricksPlayedThisRound >= 10 && actual < declared) return playerOrange;
    return playerBlue;
  }

  // ── Theme ─────────────────────────────────────────────────────
  static ThemeData get theme {
    final base = ThemeData.dark();
    return base.copyWith(
      scaffoldBackgroundColor: deepNavy,
      colorScheme: const ColorScheme.dark(
        primary: midBlue,
        secondary: steelBlue,
        surface: surface2,
        error: errorRed,
        onPrimary: white,
        onSecondary: deepNavy,
        onSurface: cream,
      ),
      textTheme: GoogleFonts.cairoTextTheme(base.textTheme).copyWith(
        displayLarge: GoogleFonts.alexandria(
          color: cream,
          fontSize: 36,
          fontWeight: FontWeight.w800,
          letterSpacing: -0.5,
        ),
        displayMedium: GoogleFonts.cairo(
          color: cream,
          fontSize: 26,
          fontWeight: FontWeight.w700,
        ),
        headlineMedium: GoogleFonts.cairo(
          color: cream,
          fontSize: 20,
          fontWeight: FontWeight.w600,
        ),
        bodyLarge: GoogleFonts.cairo(
          color: cream,
          fontSize: 16,
          fontWeight: FontWeight.w500,
        ),
        bodyMedium: GoogleFonts.cairo(
          color: steelBlue,
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
          backgroundColor: midBlue,
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
          foregroundColor: steelBlue,
          side: const BorderSide(color: steelBlue, width: 1.5),
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
          foregroundColor: steelBlue,
          textStyle: GoogleFonts.cairo(
            fontSize: 15,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
      cardTheme: const CardThemeData(
        color: surface2,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.all(Radius.circular(16)),
        ),
      ),
      dialogTheme: const DialogThemeData(
        backgroundColor: surface2,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.all(Radius.circular(24)),
        ),
      ),
      snackBarTheme: const SnackBarThemeData(
        backgroundColor: surface2,
        contentTextStyle: TextStyle(color: cream),
      ),
      dividerColor: Colors.white12,
      iconTheme: const IconThemeData(color: steelBlue),
    );
  }
}
