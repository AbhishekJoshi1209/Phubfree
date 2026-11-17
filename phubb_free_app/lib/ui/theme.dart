import 'package:flutter/material.dart';

class AppTheme {
  // Deep dark backgrounds for that premium feel
  static const Color background = Color(0xFF0F1016);
  static const Color surface = Color(0xFF1E1F29);
  static const Color surfaceHighlight = Color(0xFF2D2F3F);
  
  // Neon accents
  static const Color accentPurple = Color(0xFFB145E9);
  static const Color accentCyan = Color(0xFF22D2E6);
  
  // Text colors
  static const Color textPrimary = Color(0xFFFFFFFF);
  static const Color textSecondary = Color(0xFFA0A3BD);

  static ThemeData get darkTheme {
    return ThemeData(
      brightness: Brightness.dark,
      scaffoldBackgroundColor: background,
      primaryColor: accentPurple,
      colorScheme: const ColorScheme.dark(
        primary: accentCyan,
        secondary: accentPurple,
        surface: surface,
        background: background,
      ),
      fontFamily: 'Roboto', // Ideally Inter, but Roboto is built-in
      appBarTheme: const AppBarTheme(
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: false,
        titleTextStyle: TextStyle(
          color: textPrimary,
          fontSize: 26,
          fontWeight: FontWeight.w700,
          letterSpacing: -0.5,
        ),
      ),
      cardTheme: CardThemeData(
        color: surface.withOpacity(0.7),
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(24),
          side: const BorderSide(color: surfaceHighlight, width: 1.5),
        ),
      ),
      bottomNavigationBarTheme: const BottomNavigationBarThemeData(
        backgroundColor: background,
        selectedItemColor: accentCyan,
        unselectedItemColor: textSecondary,
        elevation: 0,
      )
    );
  }
}
