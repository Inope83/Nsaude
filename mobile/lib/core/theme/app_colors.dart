import 'package:flutter/material.dart';

/// Design tokens — colors.
/// Source: genesis-DESIGN.md Step 2 approved token table.
/// Do not use raw hex anywhere else in the app.
abstract final class AppColors {
  // Core palette
  static const Color primary = Color(0xFF6366F1); // interactive accents, links, focus
  static const Color primaryPressed = Color(0xFF4F46E5); // filled button bg (C4)
  static const Color background = Color(0xFFFAFAFA);
  static const Color surface = Color(0xFFFFFFFF);
  static const Color surfaceSunken = Color(0xFFF4F4F5);
  static const Color textPrimary = Color(0xFF0A0A0A);
  static const Color textSecondary = Color(0xFF6B6B6B);
  static const Color textMuted = Color(0xFF9C9C9C); // disabled/decorative only
  static const Color textOnPrimary = Color(0xFFFFFFFF);
  static const Color border = Color(0xFFE8E8EC);
  static const Color borderStrong = Color(0xFFD0D0D8);

  // Semantic fills
  static const Color success = Color(0xFF10B981);
  static const Color warning = Color(0xFFF59E0B);
  static const Color error = Color(0xFFEF4444);
  static const Color emergency = Color(0xFFDC2626); // AA-safe with white text

  // Focus / overlay
  static const Color focusRing = Color(0x1F6366F1); // rgba(99,102,241,0.12)
  static const Color scrim = Color(0x730A0A0A); // rgba(10,10,10,0.45)
}
