import 'dart:async';

import 'package:flutter/material.dart';

import '../../core/l10n/app_strings.dart';
import '../../core/theme/app_spacing.dart';
import '../geography/geography_repository.dart';
import 'add_patient_screen.dart';
import 'models/patient.dart';
import 'patient_detail_screen.dart';
import 'patient_repository.dart';

class PatientListScreen extends StatefulWidget {
  const PatientListScreen({
    super.key,
    required this.patientService,
    this.geographyService,
  });

  final PatientService patientService;
  final GeographyService? geographyService;

  @override
  State<PatientListScreen> createState() => _PatientListScreenState();
}

class _PatientListScreenState extends State<PatientListScreen> {
  final TextEditingController _queryController = TextEditingController();
  final List<Patient> _patients = <Patient>[];

  Timer? _debounce;
  int _requestId = 0;
  int _page = 1;
  String? _next;
  String? _error;
  String _query = '';
  bool _loading = true;
  bool _loadingMore = false;

  @override
  void initState() {
    super.initState();
    _runSearch();
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _queryController.dispose();
    super.dispose();
  }

  void _onChanged(String value) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 400), _submit);
    setState(() {});
  }

  void _submit() {
    _debounce?.cancel();
    setState(() {
      _loading = true;
      _error = null;
    });
    _runSearch();
  }

  void _retry() {
    setState(() {
      _loading = true;
      _error = null;
    });
    _runSearch();
  }

  Future<void> _runSearch() async {
    final requestId = ++_requestId;
    final term = _queryController.text.trim();
    try {
      final result = await widget.patientService.search(
        q: term.isEmpty ? null : term,
        page: 1,
      );
      if (!mounted || requestId != _requestId) return;
      setState(() {
        _patients
          ..clear()
          ..addAll(result.results);
        _query = term;
        _page = 1;
        _next = result.next;
        _loading = false;
        _error = null;
      });
    } catch (error) {
      if (!mounted || requestId != _requestId) return;
      setState(() {
        _error = patientErrorMessage(error);
        _loading = false;
      });
    }
  }

  Future<void> _loadMore() async {
    if (_loadingMore) return;
    setState(() => _loadingMore = true);
    try {
      final result = await widget.patientService.search(
        q: _query.isEmpty ? null : _query,
        page: _page + 1,
      );
      if (!mounted) return;
      setState(() {
        _patients.addAll(result.results);
        _page += 1;
        _next = result.next;
        _loadingMore = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _loadingMore = false;
        _error = patientErrorMessage(error);
      });
    }
  }

  void _open(Patient patient) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (context) => PatientDetailScreen(
          patientService: widget.patientService,
          patientId: patient.id,
          patient: patient,
        ),
      ),
    );
  }

  Future<void> _addPatient() async {
    final geography = widget.geographyService;
    if (geography == null) {
      return;
    }
    final created = await Navigator.of(context).push<bool>(
      MaterialPageRoute<bool>(
        builder: (context) => AddPatientScreen(
          patientService: widget.patientService,
          geographyService: geography,
          onCreated: () => Navigator.of(context).pop(true),
        ),
      ),
    );
    if (created == true && mounted) {
      _retry();
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.s16,
                AppSpacing.s16,
                AppSpacing.s16,
                AppSpacing.s8,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    AppStrings.patientsTitle,
                    style: theme.textTheme.displaySmall,
                  ),
                  const SizedBox(height: AppSpacing.s12),
                  TextField(
                    controller: _queryController,
                    decoration: InputDecoration(
                      hintText: AppStrings.searchHint,
                      prefixIcon: const Icon(Icons.search_outlined),
                      suffixIcon: _queryController.text.isEmpty
                          ? null
                          : IconButton(
                              onPressed: () {
                                _queryController.clear();
                                _submit();
                              },
                              icon: const Icon(Icons.clear_outlined),
                            ),
                    ),
                    textInputAction: TextInputAction.search,
                    onChanged: _onChanged,
                    onSubmitted: (_) => _submit(),
                  ),
                ],
              ),
            ),
            Expanded(child: _buildBody(theme)),
          ],
        ),
      ),
      floatingActionButton: widget.geographyService == null
          ? null
          : FloatingActionButton.extended(
              onPressed: _addPatient,
              tooltip: AppStrings.addPatient,
              icon: const Icon(Icons.person_add_alt_outlined),
              label: const Text(AppStrings.addPatient),
            ),
    );
  }

  Widget _buildBody(ThemeData theme) {
    if (_error != null) {
      return _errorView(theme);
    }
    if (_loading) {
      if (_patients.isEmpty) {
        return const Center(child: CircularProgressIndicator());
      }
      return _listView(theme, busy: true);
    }
    if (_patients.isEmpty) {
      return _emptyView(theme);
    }
    return _listView(theme, busy: false);
  }

  Widget _errorView(ThemeData theme) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.s24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              _error!,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.error,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: AppSpacing.s16),
            FilledButton(
              onPressed: _retry,
              child: const Text(AppStrings.retry),
            ),
          ],
        ),
      ),
    );
  }

  Widget _emptyView(ThemeData theme) {
    final searching = _query.isNotEmpty;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.s24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              searching ? AppStrings.searchEmpty : AppStrings.listEmpty,
              style: theme.textTheme.headlineSmall,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: AppSpacing.s8),
            Text(
              searching ? AppStrings.searchEmptyHint : AppStrings.listEmptyHint,
              style: theme.textTheme.bodySmall,
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _listView(ThemeData theme, {required bool busy}) {
    final showLoadMore = _next != null;
    return Column(
      children: [
        if (busy) const LinearProgressIndicator(minHeight: 2),
        Expanded(
          child: ListView.builder(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.s16,
              AppSpacing.s8,
              AppSpacing.s16,
              AppSpacing.s16,
            ),
            itemCount: _patients.length + (showLoadMore ? 1 : 0),
            itemBuilder: (context, index) {
              if (index == _patients.length) {
                return _loadMoreButton();
              }
              return _patientTile(context, _patients[index]);
            },
          ),
        ),
      ],
    );
  }

  Widget _loadMoreButton() {
    return Padding(
      padding: const EdgeInsets.only(top: AppSpacing.s8),
      child: OutlinedButton(
        onPressed: _loadingMore ? null : _loadMore,
        child: Text(_loadingMore ? AppStrings.loading : AppStrings.loadMore),
      ),
    );
  }

  Widget _patientTile(BuildContext context, Patient patient) {
    final theme = Theme.of(context);
    return Card(
      margin: const EdgeInsets.only(bottom: AppSpacing.s8),
      child: InkWell(
        borderRadius: BorderRadius.circular(AppSpacing.radiusLg),
        onTap: () => _open(patient),
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.s16),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      patient.patientId,
                      style: theme.textTheme.labelSmall
                          ?.copyWith(fontFamily: 'monospace'),
                    ),
                    const SizedBox(height: AppSpacing.s4),
                    Text(
                      patient.fullName,
                      style: theme.textTheme.titleMedium,
                    ),
                    const SizedBox(height: AppSpacing.s4),
                    Row(
                      children: [
                        Icon(
                          _sexIcon(patient.sex),
                          size: AppSpacing.s16,
                          color: theme.textTheme.bodySmall?.color,
                        ),
                        const SizedBox(width: AppSpacing.s4),
                        Text(
                          '${patient.ageGroup} · ${patient.sexLabel}',
                          style: theme.textTheme.bodySmall,
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              Icon(
                Icons.chevron_right,
                color: theme.textTheme.bodySmall?.color,
              ),
            ],
          ),
        ),
      ),
    );
  }

  IconData _sexIcon(String sex) {
    switch (sex) {
      case 'F':
        return Icons.female_outlined;
      case 'M':
        return Icons.male_outlined;
      default:
        return Icons.person_outline;
    }
  }
}
