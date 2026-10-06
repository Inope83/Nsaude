import 'package:flutter/material.dart';

import '../../core/l10n/app_strings.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/utils/uuid.dart';
import '../patients/field_errors.dart';
import '../patients/models/patient.dart';
import 'emergency_repository.dart';
import 'models/emergency_case.dart';

class AddEmergencyScreen extends StatefulWidget {
  const AddEmergencyScreen({
    super.key,
    required this.emergencyService,
    required this.patient,
    required this.onCreated,
  });

  final EmergencyService emergencyService;
  final Patient patient;
  final VoidCallback onCreated;

  @override
  State<AddEmergencyScreen> createState() => _AddEmergencyScreenState();
}

class _AddEmergencyScreenState extends State<AddEmergencyScreen> {
  final _formKey = GlobalKey<FormState>();
  final _symptomsController = TextEditingController();
  final _descriptionController = TextEditingController();

  late final String _clientUuid = uuidV4();
  String _severity = EmergencyLabels.severities.first;
  bool _submitting = false;
  String? _submitError;
  Map<String, List<String>> _serverErrors = const <String, List<String>>{};

  @override
  void dispose() {
    _symptomsController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    setState(() => _serverErrors = const <String, List<String>>{});
    final form = _formKey.currentState;
    if (form == null || !form.validate()) {
      return;
    }
    setState(() => _submitting = true);
    final payload = <String, dynamic>{
      'client_uuid': _clientUuid,
      'patient': widget.patient.id,
      'severity': _severity,
      'symptoms': _symptomsController.text.trim(),
    };
    final description = _descriptionController.text.trim();
    if (description.isNotEmpty) {
      payload['description'] = description;
    }
    try {
      await widget.emergencyService.create(payload);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(AppStrings.emergencyCreated)),
      );
      widget.onCreated();
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _submitting = false;
        _serverErrors = fieldErrorsFrom(error);
        _submitError =
            _serverErrors.isEmpty ? emergencyErrorMessage(error) : null;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(title: const Text(AppStrings.newEmergency)),
      body: SafeArea(
        child: Form(
          key: _formKey,
          child: ListView(
            padding: const EdgeInsets.all(AppSpacing.s16),
            children: [
              Card(
                child: ListTile(
                  leading: const Icon(Icons.person_outline),
                  title: Text(widget.patient.fullName),
                  subtitle: Text(widget.patient.patientId),
                ),
              ),
              const SizedBox(height: AppSpacing.s16),
              Text(AppStrings.severity, style: theme.textTheme.titleSmall),
              const SizedBox(height: AppSpacing.s8),
              SegmentedButton<String>(
                segments: [
                  for (final severity in EmergencyLabels.severities)
                    ButtonSegment<String>(
                      value: severity,
                      label: Text(severity),
                    ),
                ],
                selected: <String>{_severity},
                onSelectionChanged: (selection) =>
                    setState(() => _severity = selection.first),
              ),
              if (firstFieldError(_serverErrors, 'severity') != null) ...[
                const SizedBox(height: AppSpacing.s4),
                FieldErrorText(
                  firstFieldError(_serverErrors, 'severity')!,
                ),
              ],
              const SizedBox(height: AppSpacing.s16),
              TextFormField(
                controller: _symptomsController,
                decoration: InputDecoration(
                  labelText: AppStrings.symptoms,
                  errorText: firstFieldError(_serverErrors, 'symptoms'),
                ),
                maxLines: 3,
                validator: (value) => (value == null || value.trim().isEmpty)
                    ? AppStrings.emergencySymptomsRequired
                    : null,
              ),
              const SizedBox(height: AppSpacing.s16),
              TextFormField(
                controller: _descriptionController,
                decoration: InputDecoration(
                  labelText: AppStrings.description,
                  errorText: firstFieldError(_serverErrors, 'description'),
                ),
                maxLines: 4,
              ),
              if (unhandledFieldError(_serverErrors,
                      const <String>{'severity', 'symptoms', 'description'}) !=
                  null) ...[
                const SizedBox(height: AppSpacing.s16),
                FieldErrorText(unhandledFieldError(_serverErrors,
                    const <String>{'severity', 'symptoms', 'description'})!),
              ],
              if (_submitError != null) ...[
                const SizedBox(height: AppSpacing.s16),
                FieldErrorText(_submitError!),
              ],
              const SizedBox(height: AppSpacing.s24),
              FilledButton(
                onPressed: _submitting ? null : _submit,
                child:
                    Text(_submitting ? AppStrings.loading : AppStrings.save),
              ),
            ],
          ),
        ),
      ),
    );
  }
}