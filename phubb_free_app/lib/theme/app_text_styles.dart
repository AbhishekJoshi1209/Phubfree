import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// Centralized text styles.
/// Headings and hero numbers use Fraunces (characterful serif).
/// Body / UI text uses Inter (clean sans).
class AppTextStyles {
  AppTextStyles._();

  // ── Serif (hero numbers, headings) ─────────────────────────────
  static TextStyle heroNumber(Color color) => GoogleFonts.fraunces(
        fontSize: 56,
        fontWeight: FontWeight.w600,
        height: 1.1,
        color: color,
      );

  static TextStyle h1(Color color) => GoogleFonts.fraunces(
        fontSize: 28,
        fontWeight: FontWeight.w600,
        height: 1.25,
        color: color,
      );

  static TextStyle h2(Color color) => GoogleFonts.fraunces(
        fontSize: 22,
        fontWeight: FontWeight.w500,
        height: 1.3,
        color: color,
      );

  // ── Sans (body, labels, UI) ────────────────────────────────────
  static TextStyle bodyLarge(Color color) => GoogleFonts.inter(
        fontSize: 16,
        fontWeight: FontWeight.w400,
        height: 1.5,
        color: color,
      );

  static TextStyle body(Color color) => GoogleFonts.inter(
        fontSize: 14,
        fontWeight: FontWeight.w400,
        height: 1.5,
        color: color,
      );

  static TextStyle bodySmall(Color color) => GoogleFonts.inter(
        fontSize: 12,
        fontWeight: FontWeight.w400,
        height: 1.4,
        color: color,
      );

  static TextStyle label(Color color) => GoogleFonts.inter(
        fontSize: 12,
        fontWeight: FontWeight.w500,
        height: 1.3,
        letterSpacing: 0.3,
        color: color,
      );

  static TextStyle labelSmall(Color color) => GoogleFonts.inter(
        fontSize: 11,
        fontWeight: FontWeight.w500,
        height: 1.3,
        letterSpacing: 0.4,
        color: color,
      );

  static TextStyle button(Color color) => GoogleFonts.inter(
        fontSize: 14,
        fontWeight: FontWeight.w600,
        height: 1.4,
        color: color,
      );

  static TextStyle metricValue(Color color) => GoogleFonts.fraunces(
        fontSize: 20,
        fontWeight: FontWeight.w600,
        height: 1.2,
        color: color,
      );

  static TextStyle metricLabel(Color color) => GoogleFonts.inter(
        fontSize: 12,
        fontWeight: FontWeight.w400,
        height: 1.3,
        color: color,
      );
}
