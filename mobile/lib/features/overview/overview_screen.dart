import 'package:flutter/material.dart';

import '../../core/l10n/app_strings.dart';
import '../../core/theme/app_spacing.dart';
import '../emergencies/emergency_repository.dart';
import '../patients/patient_repository.dart';
import '../referrals/referral_repository.dart';

class OverviewScreen extends StatefulWidget {
  const OverviewScreen({
    super.key,
    required this.patientService,
    required this.emergencyService,
    required this.referralService,
    this.roleLabel,
  });

  final PatientService patientService;
  final EmergencyService emergencyService;
  final ReferralService referralService;
  final String? roleLabel;

  @override
  State<OverviewScreen> createState() => _OverviewScreenState();
}

class _OverviewScreenState extends State<OverviewScreen> {
  int? _patients;
  int? _openEmergencies;
  int? _pendingReferrals;
  bool _loading = true;
  bool _error = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = false;
    });
    try {
      final results = await Future.wait<int>(<Future<int>>[
        widget.patientService
            .search(page: 1)
            .then((page) => page.count),
        widget.emergencyService
            .list(status: 'OPEN', page: 1)
            .then((page) => page.count),
        widget.referralService
            .list(status: 'PENDING', page: 1)
            .then((page) => page.count),
      ]);
      if (!mounted) return;
      setState(() {
        _patients = results[0];
        _openEmergencies = results[1];
        _pendingReferrals = results[2];
        _loading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _error = true;
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: _load,
          child: ListView(
            padding: const EdgeInsets.all(AppSpacing.s16),
            children: [
              Text(
                AppStrings.overviewTitle,
                style: theme.textTheme.displaySmall,
              ),
              const SizedBox(height: AppSpacing.s4),
              Text(
                AppStrings.overviewSubtitle,
                style: theme.textTheme.bodySmall,
              ),
              if (widget.roleLabel != null) ...[
                const SizedBox(height: AppSpacing.s4),
                Text(
                  '${AppStrings.roleLabel}: ${widget.roleLabel}',
                  style: theme.textTheme.bodySmall,
                ),
              ],
              const SizedBox(height: AppSpacing.s16),
              if (_loading)
                const Padding(
                  padding: EdgeInsets.only(top: AppSpacing.s32),
                  child: Center(child: CircularProgressIndicator()),
                )
              else if (_error)
                _errorView(theme)
              else
                _stats(theme),
            ],
          ),
        ),
      ),
    );
  }

  Widget _errorView(ThemeData theme) {
    return Column(
      children: [
        const SizedBox(height: AppSpacing.s24),
        Text(
          AppStrings.overviewError,
          style: theme.textTheme.bodyMedium
              ?.copyWith(color: theme.colorScheme.error),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: AppSpacing.s16),
        FilledButton(
          onPressed: _load,
          child: const Text(AppStrings.retry),
        ),
      ],
    );
  }

  Widget _stats(ThemeData theme) {
    return Column(
      children: [
        _statCard(
          theme,
          icon: Icons.groups_outlined,
          label: AppStrings.statPatients,
          value: _patients ?? 0,
        ),
        const SizedBox(height: AppSpacing.s12),
        _statCard(
          theme,
          icon: Icons.emergency_outlined,
          label: AppStrings.statOpenEmergencies,
          value: _openEmergencies ?? 0,
        ),
        const SizedBox(height: AppSpacing.s12),
        _statCard(
          theme,
          icon: Icons.swap_horiz_outlined,
          label: AppStrings.statPendingReferrals,
          value: _pendingReferrals ?? 0,
        ),
      ],
    );
  }

  Widget _statCard(
    ThemeData theme, {
    required IconData icon,
    required String label,
    required int value,
  }) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.s16),
        child: Row(
          children: [
            Icon(icon, size: AppSpacing.s32, color: theme.colorScheme.primary),
            const SizedBox(width: AppSpacing.s16),
            Expanded(
              child: Text(label, style: theme.textTheme.titleMedium),
            ),
            Text(
              '$value',
              style: theme.textTheme.displaySmall,
            ),
          ],
        ),
      ),
    );
  }
}