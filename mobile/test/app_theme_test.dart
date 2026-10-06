import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:saude_konekta/core/theme/app_colors.dart';
import 'package:saude_konekta/core/theme/app_spacing.dart';
import 'package:saude_konekta/core/theme/app_status.dart';
import 'package:saude_konekta/core/theme/app_theme.dart';
import 'package:saude_konekta/core/theme/app_typography.dart';

void main() {
  group('AppTheme.light', () {
    final theme = AppTheme.light;

    test('uses approved color tokens', () {
      expect(theme.scaffoldBackgroundColor, AppColors.background);
      expect(theme.colorScheme.surface, AppColors.surface);
      // C4: filled primary background must be the AA-safe darker indigo
      expect(theme.colorScheme.primary, AppColors.primaryPressed);
      expect(theme.colorScheme.primary, const Color(0xFF4F46E5));
      expect(theme.colorScheme.outline, AppColors.border);
    });

    test('uses approved typography tokens', () {
      expect(theme.textTheme.bodyMedium?.fontSize, AppTypography.body);
      expect(theme.textTheme.bodyMedium?.fontWeight, FontWeight.w400);
      expect(theme.textTheme.displaySmall?.fontSize, AppTypography.sectionHeading);
      expect(theme.textTheme.displaySmall?.fontWeight, FontWeight.w700);
      expect(AppTypography.fontFamily, isNull, reason: 'system font only (C1)');
    });

    test('buttons meet 48dp minimum touch target', () {
      final minSize = theme.filledButtonTheme.style?.minimumSize;
      expect(minSize?.resolve({}),
          const Size(0, AppSpacing.touchTargetMin));
      expect(theme.outlinedButtonTheme.style?.minimumSize?.resolve({}),
          const Size(0, AppSpacing.touchTargetMin));
      expect(theme.filledButtonTheme.style?.tapTargetSize,
          MaterialTapTargetSize.padded);
    });

    test('inputs use token radius and borders', () {
      final border =
          theme.inputDecorationTheme.enabledBorder as OutlineInputBorder?;
      expect(border?.borderRadius, BorderRadius.circular(AppSpacing.radiusSm));
      expect(border?.borderSide.color, AppColors.border);
    });

    test('cards use 12px radius and 1px token border', () {
      final shape = theme.cardTheme.shape as RoundedRectangleBorder?;
      expect(shape?.borderRadius, BorderRadius.circular(AppSpacing.radiusLg));
      expect(shape?.side.color, AppColors.border);
    });
  });

  group('StatusVocabulary', () {
    test('every enum value resolves to a visual', () {
      for (final s in Severity.values) {
        expect(StatusVocabulary.of(s).label, isNotEmpty);
      }
      for (final s in EmergencyStatus.values) {
        expect(StatusVocabulary.of(s).label, isNotEmpty);
      }
      for (final s in ReferralUrgency.values) {
        expect(StatusVocabulary.of(s).label, isNotEmpty);
      }
      for (final s in ReferralStatus.values) {
        expect(StatusVocabulary.of(s).label, isNotEmpty);
      }
      for (final s in SyncStatus.values) {
        expect(StatusVocabulary.of(s).label, isNotEmpty);
      }
      for (final s in ConnectivityStatus.values) {
        expect(StatusVocabulary.of(s).label, isNotEmpty);
      }
    });

    test('critical and emergency badges use emergency fill with white text', () {
      final critical = StatusVocabulary.of(Severity.critical);
      expect(critical.background, AppColors.emergency);
      expect(critical.foreground, AppColors.textOnPrimary);

      final urgency = StatusVocabulary.of(ReferralUrgency.emergency);
      expect(urgency.background, AppColors.emergency);
      expect(urgency.foreground, AppColors.textOnPrimary);
    });

    test('non-solid badges pair tint background with dark accessible text', () {
      final pending = StatusVocabulary.of(SyncStatus.pending);
      expect(pending.background, const Color(0xFFFFFBEB));
      expect(pending.foreground, const Color(0xFFB45309));
      expect(pending.icon, isNotNull);
    });

    test('unknown status throws', () {
      expect(() => StatusVocabulary.of('nope'), throwsArgumentError);
    });
  });
}
