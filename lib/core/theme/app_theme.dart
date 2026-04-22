import 'package:flutter/material.dart';

class AppTheme {
  // CLAUDE.md canonical palette
  static const Color background    = Color(0xFF0D0D0D);
  static const Color surface       = Color(0xFF1A1A1A);
  static const Color surfaceHigh   = Color(0xFF222222);
  static const Color accent        = Color(0xFF00D4A0);
  static const Color silver        = Color(0xFFC0C0C0);
  static const Color textPrimary   = Color(0xFFFFFFFF);
  static const Color textSecondary = Color(0xFF8A8A8A);
  static const Color speedGreen    = Color(0xFF06D6A0);
  static const Color speedYellow   = Color(0xFFFFD23F);
  static const Color speedRed      = Color(0xFFE63946);
  static const Color routeLine     = Color(0xFF00D4A0);

  // Legacy aliases kept for existing prototype code
  static const Color primaryRed    = speedRed;
  static const Color accentOrange  = Color(0xFFFF6B35);
  static const Color darkBackground = background;
  static const Color surfaceGrey   = surface;
  static const Color cardGrey      = Color(0xFF252525);
  static const Color successGreen  = speedGreen;
  static const Color warningYellow = speedYellow;

  static ThemeData get darkTheme {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      scaffoldBackgroundColor: background,
      primaryColor: accent,
      colorScheme: const ColorScheme.dark(
        primary: accent,
        secondary: silver,
        surface: surface,
      ),
      cardTheme: CardThemeData(
        color: cardGrey,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(
            color: surfaceGrey.withValues(alpha: 0.3),
            width: 1,
          ),
        ),
      ),
      textTheme: const TextTheme(
        displayLarge: TextStyle(
          fontSize: 72,
          fontWeight: FontWeight.w700,
          color: textPrimary,
          letterSpacing: -2,
        ),
        displayMedium: TextStyle(
          fontSize: 48,
          fontWeight: FontWeight.w600,
          color: textPrimary,
        ),
        headlineMedium: TextStyle(
          fontSize: 24,
          fontWeight: FontWeight.w600,
          color: textPrimary,
        ),
        bodyLarge: TextStyle(
          fontSize: 16,
          color: textPrimary,
        ),
        bodyMedium: TextStyle(
          fontSize: 14,
          color: textSecondary,
        ),
        labelLarge: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w600,
          color: textSecondary,
          letterSpacing: 1.2,
        ),
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: darkBackground,
        elevation: 0,
        centerTitle: true,
      ),
      snackBarTheme: SnackBarThemeData(
        backgroundColor: surfaceHigh,
        contentTextStyle: const TextStyle(color: textPrimary),
        actionTextColor: accent,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      ),
    );
  }
}
