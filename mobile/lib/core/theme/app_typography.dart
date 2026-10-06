import 'package:flutter/material.dart';

/// Design tokens — typography.
/// Source: genesis-DESIGN.md type scale, adapted to mobile (Step 2 C1/C2/C3).
/// Fonts: system default (no remote fonts). Headings bold, body regular/medium;
/// never more than two weights on one screen.
abstract final class AppTypography {
  static const String? fontFamily = null; // platform default (Roboto on Android)

  // Mobile scale (genesis web values: display 72 / headline 60 → not used)
  static const double sectionHeading = 24;
  static const double subhead = 20;
  static const double body = 16;
  static const double small = 14;
  static const double caption = 12;
  static const double overline = 11;

  static const double weightRegular = 400;
  static const double weightMedium = 500;
  static const double weightBold = 700;

  static const double lineHeightTight = 1.2; // headings
  static const double lineHeightBody = 1.5; // body

  static const double letterSpacingHeading = -0.03;
  static const double letterSpacingOverline = 0.06;

  static TextTheme textTheme = const TextTheme(
    // Headings — bold, tight tracking
    displaySmall: TextStyle(
      fontFamily: fontFamily,
      fontSize: sectionHeading,
      fontWeight: FontWeight.w700,
      letterSpacing: letterSpacingHeading,
      height: lineHeightTight,
      color: Color(0xFF0A0A0A),
    ),
    headlineSmall: TextStyle(
      fontFamily: fontFamily,
      fontSize: subhead,
      fontWeight: FontWeight.w700,
      letterSpacing: letterSpacingHeading,
      height: lineHeightTight,
      color: Color(0xFF0A0A0A),
    ),
    titleMedium: TextStyle(
      fontFamily: fontFamily,
      fontSize: subhead,
      fontWeight: FontWeight.w500,
      height: lineHeightTight,
      color: Color(0xFF0A0A0A),
    ),
    // Body — regular / medium
    bodyLarge: TextStyle(
      fontFamily: fontFamily,
      fontSize: body,
      fontWeight: FontWeight.w400,
      height: lineHeightBody,
      color: Color(0xFF0A0A0A),
    ),
    bodyMedium: TextStyle(
      fontFamily: fontFamily,
      fontSize: body,
      fontWeight: FontWeight.w400,
      height: lineHeightBody,
      color: Color(0xFF0A0A0A),
    ),
    bodySmall: TextStyle(
      fontFamily: fontFamily,
      fontSize: small,
      fontWeight: FontWeight.w400,
      height: lineHeightBody,
      color: Color(0xFF6B6B6B),
    ),
    labelLarge: TextStyle(
      fontFamily: fontFamily,
      fontSize: body,
      fontWeight: FontWeight.w500,
      height: lineHeightBody,
      color: Color(0xFF0A0A0A),
    ),
    labelMedium: TextStyle(
      fontFamily: fontFamily,
      fontSize: small,
      fontWeight: FontWeight.w500,
      height: lineHeightBody,
      color: Color(0xFF0A0A0A),
    ),
    // Metadata
    labelSmall: TextStyle(
      fontFamily: fontFamily,
      fontSize: caption,
      fontWeight: FontWeight.w400,
      height: lineHeightBody,
      color: Color(0xFF6B6B6B),
    ),
  );

  /// Overline — uppercase section labels (11px, +0.06em).
  static const TextStyle overlineStyle = TextStyle(
    fontFamily: fontFamily,
    fontSize: overline,
    fontWeight: FontWeight.w500,
    height: 1.4,
    letterSpacing: letterSpacingOverline,
    color: Color(0xFF6B6B6B),
  );
}
