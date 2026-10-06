/// Design tokens — spacing, radius, sizing.
/// Source: genesis-DESIGN.md (4px base grid) + 48dp touch-target constraint.
library;

import 'package:flutter/material.dart';

abstract final class AppSpacing {
  // Base scale (multiples of 4)
  static const double s4 = 4;
  static const double s8 = 8;
  static const double s12 = 12;
  static const double s16 = 16;
  static const double s20 = 20;
  static const double s24 = 24;
  static const double s32 = 32;
  static const double s40 = 40;
  static const double s48 = 48;
  static const double s64 = 64;
  static const double s80 = 80;
  static const double s96 = 96;

  // Component padding
  static const EdgeInsets paddingSmall = EdgeInsets.symmetric(vertical: 8, horizontal: 12);
  static const EdgeInsets paddingMedium = EdgeInsets.symmetric(vertical: 10, horizontal: 16);
  static const EdgeInsets paddingLarge = EdgeInsets.symmetric(vertical: 12, horizontal: 24);

  // Layout
  static const double screenHorizontal = 16;
  static const double sectionSpacing = 32; // mobile
  static const double cardGridGap = 20;

  // Corner radius
  static const double radiusXs = 4; // tags, chips, badges
  static const double radiusSm = 6; // buttons, inputs
  static const double radiusMd = 8; // panels, dropdowns
  static const double radiusLg = 12; // cards, dialogs
  static const double radiusFull = 9999; // avatars, pills

  // Sizing
  static const double touchTargetMin = 48; // hard constraint
  static const double buttonSmall = 40;
  static const double buttonMedium = 48;
  static const double buttonLarge = 56;
  static const double listRowMinHeight = 56;
}
