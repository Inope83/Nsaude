import 'package:flutter/material.dart';

import 'app_colors.dart';

/// Shared status vocabulary — identical naming and color mapping on
/// Flutter (mobile) and Django (tokens.css). Source: Step 2 approved table.
///
/// Badge rule: always tint background + accessible text + icon.
/// Never communicate status by color alone.
enum Severity { low, medium, high, critical }

enum EmergencyStatus { open, inReview, escalated, resolved }

enum ReferralUrgency { routine, urgent, emergency }

enum ReferralStatus { pending, accepted, inTransit, completed, cancelled }

enum SyncStatus { pending, syncing, synced, failed }

enum ConnectivityStatus { online, offline }

/// Soft background tints (genesis has no tint tokens — Step 2 proposal).
abstract final class AppTints {
  static const Color success = Color(0xFFECFDF5);
  static const Color warning = Color(0xFFFFFBEB);
  static const Color error = Color(0xFFFEF2F2);
  static const Color emergency = Color(0xFFFEF2F2);
  static const Color info = Color(0xFFEEF2FF);
  static const Color neutral = Color(0xFFF4F4F5);
}

class StatusVisual {
  const StatusVisual({
    required this.label,
    required this.background,
    required this.foreground,
    required this.icon,
  });

  final String label; // English fallback label; Tetum comes from l10n (step 3+)
  final Color background;
  final Color foreground;
  final IconData icon;
}

abstract final class StatusVocabulary {
  static StatusVisual of(dynamic status) {
    if (status is Severity) {
      switch (status) {
        case Severity.low:
          return const StatusVisual(
            label: 'LOW',
            background: AppTints.success,
            foreground: Color(0xFF047857),
            icon: Icons.arrow_downward,
          );
        case Severity.medium:
          return const StatusVisual(
            label: 'MEDIUM',
            background: AppTints.warning,
            foreground: Color(0xFFB45309),
            icon: Icons.remove,
          );
        case Severity.high:
          return const StatusVisual(
            label: 'HIGH',
            background: AppTints.error,
            foreground: Color(0xFFB91C1C),
            icon: Icons.warning_amber,
          );
        case Severity.critical:
          return const StatusVisual(
            label: 'CRITICAL',
            background: AppColors.emergency,
            foreground: AppColors.textOnPrimary,
            icon: Icons.emergency,
          );
      }
    }
    if (status is EmergencyStatus) {
      switch (status) {
        case EmergencyStatus.open:
          return const StatusVisual(
            label: 'OPEN',
            background: AppTints.warning,
            foreground: Color(0xFFB45309),
            icon: Icons.fiber_new,
          );
        case EmergencyStatus.inReview:
          return const StatusVisual(
            label: 'IN REVIEW',
            background: AppTints.info,
            foreground: Color(0xFF4338CA),
            icon: Icons.search,
          );
        case EmergencyStatus.escalated:
          return const StatusVisual(
            label: 'ESCALATED',
            background: AppTints.error,
            foreground: Color(0xFFB91C1C),
            icon: Icons.arrow_upward,
          );
        case EmergencyStatus.resolved:
          return const StatusVisual(
            label: 'RESOLVED',
            background: AppTints.success,
            foreground: Color(0xFF047857),
            icon: Icons.check_circle,
          );
      }
    }
    if (status is ReferralUrgency) {
      switch (status) {
        case ReferralUrgency.routine:
          return const StatusVisual(
            label: 'ROUTINE',
            background: AppTints.success,
            foreground: Color(0xFF047857),
            icon: Icons.schedule,
          );
        case ReferralUrgency.urgent:
          return const StatusVisual(
            label: 'URGENT',
            background: AppTints.warning,
            foreground: Color(0xFFB45309),
            icon: Icons.fast_forward,
          );
        case ReferralUrgency.emergency:
          return const StatusVisual(
            label: 'EMERGENCY',
            background: AppColors.emergency,
            foreground: AppColors.textOnPrimary,
            icon: Icons.emergency,
          );
      }
    }
    if (status is ReferralStatus) {
      switch (status) {
        case ReferralStatus.pending:
          return const StatusVisual(
            label: 'PENDING',
            background: AppTints.warning,
            foreground: Color(0xFFB45309),
            icon: Icons.hourglass_top,
          );
        case ReferralStatus.accepted:
          return const StatusVisual(
            label: 'ACCEPTED',
            background: AppTints.info,
            foreground: Color(0xFF4338CA),
            icon: Icons.how_to_reg,
          );
        case ReferralStatus.inTransit:
          return const StatusVisual(
            label: 'IN TRANSIT',
            background: AppTints.neutral,
            foreground: AppColors.textSecondary,
            icon: Icons.directions,
          );
        case ReferralStatus.completed:
          return const StatusVisual(
            label: 'COMPLETED',
            background: AppTints.success,
            foreground: Color(0xFF047857),
            icon: Icons.check_circle,
          );
        case ReferralStatus.cancelled:
          return const StatusVisual(
            label: 'CANCELLED',
            background: AppTints.neutral,
            foreground: AppColors.textSecondary,
            icon: Icons.cancel,
          );
      }
    }
    if (status is SyncStatus) {
      switch (status) {
        case SyncStatus.pending:
          return const StatusVisual(
            label: 'PENDING SYNC',
            background: AppTints.warning,
            foreground: Color(0xFFB45309),
            icon: Icons.cloud_off,
          );
        case SyncStatus.syncing:
          return const StatusVisual(
            label: 'SYNCING',
            background: AppTints.info,
            foreground: Color(0xFF4338CA),
            icon: Icons.sync,
          );
        case SyncStatus.synced:
          return const StatusVisual(
            label: 'SYNCED',
            background: AppTints.success,
            foreground: Color(0xFF047857),
            icon: Icons.cloud_done,
          );
        case SyncStatus.failed:
          return const StatusVisual(
            label: 'SYNC FAILED',
            background: AppTints.error,
            foreground: Color(0xFFB91C1C),
            icon: Icons.cloud_off,
          );
      }
    }
    if (status is ConnectivityStatus) {
      switch (status) {
        case ConnectivityStatus.online:
          return const StatusVisual(
            label: 'ONLINE',
            background: AppTints.success,
            foreground: Color(0xFF047857),
            icon: Icons.wifi,
          );
        case ConnectivityStatus.offline:
          return const StatusVisual(
            label: 'OFFLINE',
            background: AppTints.warning,
            foreground: Color(0xFFB45309),
            icon: Icons.wifi_off,
          );
      }
    }
    throw ArgumentError('Unknown status: $status');
  }
}

/// Resolves a raw API status/severity/urgency code to its shared visual.
/// Codes stay untranslated across platforms (status vocabulary parity).
StatusVisual? statusVisualFromCode(String code) {
  switch (code) {
    case 'LOW':
      return StatusVocabulary.of(Severity.low);
    case 'MEDIUM':
      return StatusVocabulary.of(Severity.medium);
    case 'HIGH':
      return StatusVocabulary.of(Severity.high);
    case 'CRITICAL':
      return StatusVocabulary.of(Severity.critical);
    case 'OPEN':
      return StatusVocabulary.of(EmergencyStatus.open);
    case 'IN_REVIEW':
      return StatusVocabulary.of(EmergencyStatus.inReview);
    case 'ESCALATED':
      return StatusVocabulary.of(EmergencyStatus.escalated);
    case 'RESOLVED':
      return StatusVocabulary.of(EmergencyStatus.resolved);
    case 'ROUTINE':
      return StatusVocabulary.of(ReferralUrgency.routine);
    case 'URGENT':
      return StatusVocabulary.of(ReferralUrgency.urgent);
    case 'EMERGENCY':
      return StatusVocabulary.of(ReferralUrgency.emergency);
    case 'PENDING':
      return StatusVocabulary.of(ReferralStatus.pending);
    case 'ACCEPTED':
      return StatusVocabulary.of(ReferralStatus.accepted);
    case 'IN_TRANSIT':
      return StatusVocabulary.of(ReferralStatus.inTransit);
    case 'COMPLETED':
      return StatusVocabulary.of(ReferralStatus.completed);
    case 'CANCELLED':
      return StatusVocabulary.of(ReferralStatus.cancelled);
    default:
      return null;
  }
}
