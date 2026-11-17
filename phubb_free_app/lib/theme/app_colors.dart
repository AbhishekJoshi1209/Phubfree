import 'package:flutter/material.dart';

/// Phubb-Free "Moss & Stone" color palette.
/// Every widget pulls colors from these tokens via Theme — no hardcoded values.
class AppColors {
  AppColors._();

  // ── Light palette ──────────────────────────────────────────────
  static const Color lightBackground     = Color(0xFFF5F4EE);
  static const Color lightSurface        = Color(0xFFFFFFFF);
  static const Color lightBorder         = Color(0xFFDFDFD4);
  static const Color lightTextPrimary    = Color(0xFF1B1E1A);
  static const Color lightTextSecondary  = Color(0xFF646A60);
  static const Color lightAccent         = Color(0xFF2F6B4F);
  static const Color lightAccentSoft     = Color(0xFFDCE9E0);
  static const Color lightOnAccent       = Color(0xFFFFFFFF);
  static const Color lightPositive       = Color(0xFF3D7A4F);
  static const Color lightWarning        = Color(0xFFB7791F);
  static const Color lightError          = Color(0xFFB3392F);

  // ── Dark palette ───────────────────────────────────────────────
  static const Color darkBackground      = Color(0xFF1A1C1A);
  static const Color darkSurface         = Color(0xFF232622);
  static const Color darkBorder          = Color(0xFF363A35);
  static const Color darkTextPrimary     = Color(0xFFEFF1EA);
  static const Color darkTextSecondary   = Color(0xFFA3A99E);
  static const Color darkAccent          = Color(0xFF7FC4A0);
  static const Color darkAccentSoft      = Color(0xFF27382F);
  static const Color darkOnAccent        = Color(0xFF1A1C1A);
  static const Color darkPositive        = Color(0xFF8CC79D);
  static const Color darkWarning         = Color(0xFFE0B45C);
  static const Color darkError           = Color(0xFFE57A70);

  // ── Convenience: get palette by brightness ─────────────────────
  static Color background(Brightness b)    => b == Brightness.light ? lightBackground    : darkBackground;
  static Color surface(Brightness b)       => b == Brightness.light ? lightSurface       : darkSurface;
  static Color border(Brightness b)        => b == Brightness.light ? lightBorder        : darkBorder;
  static Color textPrimary(Brightness b)   => b == Brightness.light ? lightTextPrimary   : darkTextPrimary;
  static Color textSecondary(Brightness b) => b == Brightness.light ? lightTextSecondary : darkTextSecondary;
  static Color accent(Brightness b)        => b == Brightness.light ? lightAccent        : darkAccent;
  static Color accentSoft(Brightness b)    => b == Brightness.light ? lightAccentSoft    : darkAccentSoft;
  static Color onAccent(Brightness b)      => b == Brightness.light ? lightOnAccent      : darkOnAccent;
  static Color positive(Brightness b)      => b == Brightness.light ? lightPositive      : darkPositive;
  static Color warning(Brightness b)       => b == Brightness.light ? lightWarning       : darkWarning;
  static Color error(Brightness b)         => b == Brightness.light ? lightError         : darkError;

  /// Build a full [ColorScheme] for [MaterialApp].
  static ColorScheme colorScheme(Brightness brightness) {
    final b = brightness;
    return ColorScheme(
      brightness: brightness,
      primary: accent(b),
      onPrimary: onAccent(b),
      primaryContainer: accentSoft(b),
      onPrimaryContainer: accent(b),
      secondary: accent(b),
      onSecondary: onAccent(b),
      secondaryContainer: accentSoft(b),
      onSecondaryContainer: accent(b),
      surface: surface(b),
      onSurface: textPrimary(b),
      onSurfaceVariant: textSecondary(b),
      error: error(b),
      onError: Colors.white,
      outline: border(b),
      outlineVariant: border(b),
      shadow: Colors.transparent,
    );
  }
}
