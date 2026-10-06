import 'package:flutter/material.dart';

import '../../core/l10n/app_strings.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/widgets/status_badge.dart';
import '../facilities/facility_repository.dart';
import '../patients/models/patient.dart';
import '../patients/patient_repository.dart';
import '../emergencies/patient_picker_screen.dart';
import 'add_referral_screen.dart';
import 'models/referral.dart';
import 'referral_repository.dart';

class ReferralListScreen extends StatefulWidget {
  const ReferralListScreen({
    super.key,
    required this.referralService,
    this.patientService,
    this.facilityService,
  });

  final ReferralService referralService;
  final PatientService? patientService;
  final FacilityService? facilityService;

  @override
  State<ReferralListScreen> createState() => _ReferralListScreenState();
}

class _ReferralListScreenState extends State<ReferralListScreen> {
  final List<Referral> _referrals = <Referral>[];

  String? _statusFilter;
  int _page = 1;
  String? _next;
  String? _error;
  bool _loading = true;
  bool _loadingMore = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final result = await widget.referralService.list(
        status: _statusFilter,
        page: 1,
      );
      if (!mounted) return;
      setState(() {
        _referrals
          ..clear()
          ..addAll(result.results);
        _page = 1;
        _next = result.next;
        _loading = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _error = referralErrorMessage(error);
        _loading = false;
      });
    }
  }

  Future<void> _loadMore() async {
    if (_loadingMore) return;
    setState(() => _loadingMore = true);
    try {
      final result = await widget.referralService.list(
        status: _statusFilter,
        page: _page + 1,
      );
      if (!mounted) return;
      setState(() {
        _referrals.addAll(result.results);
        _page += 1;
        _next = result.next;
        _loadingMore = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _error = referralErrorMessage(error);
        _loadingMore = false;
      });
    }
  }

  void _selectFilter(String? status) {
    if (_statusFilter == status) return;
    setState(() => _statusFilter = status);
    _load();
  }

  Future<void> _addReferral() async {
    final patientService = widget.patientService;
    final facilityService = widget.facilityService;
    if (patientService == null || facilityService == null) return;
    final patient = await Navigator.of(context).push<Patient>(
      MaterialPageRoute<Patient>(
        builder: (_) => PatientPickerScreen(patientService: patientService),
      ),
    );
    if (patient == null || !mounted) return;
    await Navigator.of(context).push<void>(
      MaterialPageRoute<void>(
        builder: (_) => AddReferralScreen(
          referralService: widget.referralService,
          facilityService: facilityService,
          patient: patient,
          onCreated: () => Navigator.of(context).pop(),
        ),
      ),
    );
    if (mounted) _load();
  }

  bool get _canCreate =>
      widget.patientService != null && widget.facilityService != null;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      floatingActionButton: _canCreate
          ? FloatingActionButton.extended(
              onPressed: _addReferral,
              icon: const Icon(Icons.swap_horiz_outlined),
              label: const Text(AppStrings.newReferral),
            )
          : null,
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.s16,
                AppSpacing.s16,
                AppSpacing.s16,
                0,
              ),
              child: Text(
                AppStrings.referralsTitle,
                style: Theme.of(context).textTheme.displaySmall,
              ),
            ),
            _filterBar(),
            Expanded(child: _buildBody()),
          ],
        ),
      ),
    );
  }

  Widget _filterBar() {
    final filters = <MapEntry<String?, String>>[
      MapEntry<String?, String>(null, AppStrings.statusAll),
      for (final status in ReferralLabels.statuses)
        MapEntry<String?, String>(status, status),
    ];
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.s16,
        AppSpacing.s8,
        AppSpacing.s16,
        AppSpacing.s8,
      ),
      child: Row(
        children: [
          for (final filter in filters)
            Padding(
              padding: const EdgeInsets.only(right: AppSpacing.s8),
              child: ChoiceChip(
                label: Text(filter.value),
                selected: _statusFilter == filter.key,
                onSelected: (_) => _selectFilter(filter.key),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildBody() {
    final theme = Theme.of(context);
    if (_error != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.s24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                _error!,
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
          ),
        ),
      );
    }
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_referrals.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.s24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                AppStrings.referralsEmpty,
                style: theme.textTheme.headlineSmall,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: AppSpacing.s8),
              Text(
                AppStrings.referralsEmptyHint,
                style: theme.textTheme.bodySmall,
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      );
    }
    final showLoadMore = _next != null;
    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.s16,
        0,
        AppSpacing.s16,
        AppSpacing.s16,
      ),
      itemCount: _referrals.length + (showLoadMore ? 1 : 0),
      itemBuilder: (context, index) {
        if (index == _referrals.length) {
          return Padding(
            padding: const EdgeInsets.only(top: AppSpacing.s8),
            child: OutlinedButton(
              onPressed: _loadingMore ? null : _loadMore,
              child: Text(
                _loadingMore ? AppStrings.loading : AppStrings.loadMore,
              ),
            ),
          );
        }
        return _referralTile(theme, _referrals[index]);
      },
    );
  }

  Widget _referralTile(ThemeData theme, Referral referral) {
    final hasReason = referral.reason != null && referral.reason!.isNotEmpty;
    return Card(
      margin: const EdgeInsets.only(bottom: AppSpacing.s8),
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.s16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                StatusBadge(referral.urgency),
                const SizedBox(width: AppSpacing.s8),
                StatusBadge(referral.status),
                const Spacer(),
                if (referral.createdAt != null)
                  Text(
                    _dateLabel(referral.createdAt!),
                    style: theme.textTheme.bodySmall,
                  ),
              ],
            ),
            const SizedBox(height: AppSpacing.s8),
            Text(
              '${AppStrings.patientLabel} #${referral.patient}',
              style: theme.textTheme.titleMedium,
            ),
            if (hasReason) ...[
              const SizedBox(height: AppSpacing.s4),
              Text(
                referral.reason!,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.bodySmall,
              ),
            ],
          ],
        ),
      ),
    );
  }

  String _dateLabel(DateTime value) {
    final local = value.toLocal();
    final month = local.month.toString().padLeft(2, '0');
    final day = local.day.toString().padLeft(2, '0');
    return '${local.year}-$month-$day';
  }
}