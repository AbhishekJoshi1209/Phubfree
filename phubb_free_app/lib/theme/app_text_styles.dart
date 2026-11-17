import 'package:flutter/material.dart';

/// Centralized text styles.
/// Headings and hero numbers use Fraunces (characterful serif).
/// Body / UI text uses Inter (clean sans).
class AppTextStyles {
  AppTextStyles._();

  // ── Serif (hero numbers, headings) ─────────────────────────────
  static TextStyle heroNumber(Color color) => TextStyle(
    fontFamily: 'Fraunces',
    fontSize: 56,
    fontWeight: FontWeight.w600,
    height: 1.1,
    color: color,
  );

  static TextStyle h1(Color color) => TextStyle(
    fontFamily: 'Fraunces',
    fontSize: 28,
    fontWeight: FontWeight.w600,
    height: 1.25,
    color: color,
  );

  static TextStyle h2(Color color) => TextStyle(
    fontFamily: 'Fraunces',
    fontSize: 22,
    fontWeight: FontWeight.w500,
    height: 1.3,
    color: color,
  );

  // ── Sans (body, labels, UI) ────────────────────────────────────
  static TextStyle bodyLarge(Color color) => TextStyle(
    fontFamily: 'Inter',
    fontSize: 16,
    fontWeight: FontWeight.w400,
    height: 1.5,
    color: color,
  );

  static TextStyle body(Color color) => TextStyle(
    fontFamily: 'Inter',
    fontSize: 14,
    fontWeight: FontWeight.w400,
    height: 1.5,
    color: color,
  );

  static TextStyle bodySmall(Color color) => TextStyle(
    fontFamily: 'Inter',
    fontSize: 12,
    fontWeight: FontWeight.w400,
    height: 1.4,
    color: color,
  );

  static TextStyle label(Color color) => TextStyle(
    fontFamily: 'Inter',
    fontSize: 12,
    fontWeight: FontWeight.w500,
    height: 1.3,
    letterSpacing: 0.3,
    color: color,
  );

  static TextStyle labelSmall(Color color) => TextStyle(
    fontFamily: 'Inter',
    fontSize: 11,
    fontWeight: FontWeight.w500,
    height: 1.3,
    letterSpacing: 0.4,
    color: color,
  );

  static TextStyle button(Color color) => TextStyle(
    fontFamily: 'Inter',
    fontSize: 14,
    fontWeight: FontWeight.w600,
    height: 1.4,
    color: color,
  );

  static TextStyle metricValue(Color color) => TextStyle(
    fontFamily: 'Fraunces',
    fontSize: 20,
    fontWeight: FontWeight.w600,
    height: 1.2,
    color: color,
  );

  static TextStyle metricLabel(Color color) => TextStyle(
    fontFamily: 'Inter',
    fontSize: 12,
    fontWeight: FontWeight.w400,
    height: 1.3,
    color: color,
  );
}
