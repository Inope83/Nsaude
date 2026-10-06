import 'dart:async';

import 'package:flutter/material.dart';

import '../../core/l10n/app_strings.dart';
import '../../core/theme/app_spacing.dart';
import '../patients/models/patient.dart';
import '../patients/patient_repository.dart';

class PatientPickerScreen extends StatefulWidget {
  const PatientPickerScreen({super.key, required this.patientService});

  final PatientService patientService;

  @override
  State<PatientPickerScreen> createState() => _PatientPickerScreenState();
}

class _PatientPickerScreenState extends State<PatientPickerScreen> {
  final TextEditingController _queryController = TextEditingController();
  final List<Patient> _patients = <Patient>[];

  Timer? _debounce;
  int _requestId = 0;
  bool _loading = true;
  String? _error;

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
    _debounce = Timer(const Duration(milliseconds: 400), _runSearch);
  }

  Future<void> _runSearch() async {
    final requestId = ++_requestId;
    setState(() {
      _loading = true;
      _error = null;
    });
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
        _loading = false;
      });
    } catch (error) {
      if (!mounted || requestId != _requestId) return;
      setState(() {
        _error = patientErrorMessage(error);
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(title: const Text(AppStrings.pickPatient)),
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(AppSpacing.s16),
              child: TextField(
                controller: _queryController,
                decoration: const InputDecoration(
                  hintText: AppStrings.patientPickerHint,
                  prefixIcon: Icon(Icons.search_outlined),
                ),
                autofocus: true,
                textInputAction: TextInputAction.search,
                onChanged: _onChanged,
                onSubmitted: (_) => _runSearch(),
              ),
            ),
            Expanded(child: _buildBody(theme)),
          ],
        ),
      ),
    );
  }

  Widget _buildBody(ThemeData theme) {
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
                onPressed: _runSearch,
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
    if (_patients.isEmpty) {
      return Center(
        child: Text(
          AppStrings.searchEmpty,
          style: theme.textTheme.bodyMedium,
          textAlign: TextAlign.center,
        ),
      );
    }
    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.s16,
        0,
        AppSpacing.s16,
        AppSpacing.s16,
      ),
      itemCount: _patients.length,
      itemBuilder: (context, index) {
        final patient = _patients[index];
        return Card(
          margin: const EdgeInsets.only(bottom: AppSpacing.s8),
          child: ListTile(
            title: Text(patient.fullName),
            subtitle: Text(patient.patientId),
            onTap: () => Navigator.of(context).pop(patient),
          ),
        );
      },
    );
  }
}