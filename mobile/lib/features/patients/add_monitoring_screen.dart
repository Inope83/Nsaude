import 'package:flutter/material.dart';

import '../../core/l10n/app_strings.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/utils/uuid.dart';
import 'field_errors.dart';
import 'patient_repository.dart';

class AddMonitoringScreen extends StatefulWidget {
  const AddMonitoringScreen({
    super.key,
    required this.patientService,
    required this.patientId,
    required this.onCreated,
  });

  final PatientService patientService;
  final int patientId;
  final VoidCallback onCreated;

  @override
  State<AddMonitoringScreen> createState() => _AddMonitoringScreenState();
}

class _VitalSpec {
  const _VitalSpec(this.field, this.label, this.min, this.max,
      {this.decimal = false});

  final String field;
  final String label;
  final double min;
  final double max;
  final bool decimal;
}

const List<_VitalSpec> _vitals = [
  _VitalSpec('temperature', AppStrings.temperature, 20, 50, decimal: true),
  _VitalSpec('heart_rate', AppStrings.heartRate, 0, 250),
  _VitalSpec('respiratory_rate', AppStrings.respiratoryRate, 0, 100),
  _VitalSpec('blood_pressure_systolic', AppStrings.bpSystolic, 0, 300),
  _VitalSpec('blood_pressure_diastolic', AppStrings.bpDiastolic, 0, 200),
  _VitalSpec('oxygen_saturation', AppStrings.spo2, 0, 100),
];

class _AddMonitoringScreenState extends State<AddMonitoringScreen> {
  final _formKey = GlobalKey<FormState>();
  final Map<String, TextEditingController> _controllers = {
    for (final vital in _vitals) vital.field: TextEditingController(),
  };
  final _symptomsController = TextEditingController();
  final _notesController = TextEditingController();

  late final String _clientUuid = uuidV4();
  DateTime _recordedAt = DateTime.now();
  bool _submitting = false;
  String? _submitError;
  Map<String, List<String>> _serverErrors = const <String, List<String>>{};

  @override
  void dispose() {
    for (final controller in _controllers.values) {
      controller.dispose();
    }
    _symptomsController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  String _two(int value) => value.toString().padLeft(2, '0');

  String get _recordedAtLabel {
    final local = _recordedAt.toLocal();
    return '${local.year}-${_two(local.month)}-${_two(local.day)} '
        '${_two(local.hour)}:${_two(local.minute)}';
  }

  String _isoDateTime(DateTime value) {
    final local = value.toLocal();
    final utc = local.toUtc();
    final offset = local.timeZoneOffset;
    final sign = offset.isNegative ? '-' : '+';
    final offsetHours = offset.inHours.abs().toString().padLeft(2, '0');
    final offsetMinutes =
        (offset.inMinutes.abs() % 60).toString().padLeft(2, '0');
    return '${utc.year.toString().padLeft(4, '0')}-'
        '${_two(utc.month)}-${_two(utc.day)} '
        '${_two(utc.hour)}:${_two(utc.minute)}:${_two(utc.second)}'
        '$sign$offsetHours:$offsetMinutes';
  }

  Future<void> _pickRecordedAt() async {
    final date = await showDatePicker(
      context: context,
      initialDate: _recordedAt,
      firstDate: DateTime(2000),
      lastDate: DateTime.now(),
    );
    if (date == null || !mounted) return;
    final time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(_recordedAt),
    );
    if (time == null || !mounted) return;
    setState(() {
      _recordedAt = DateTime(
        date.year,
        date.month,
        date.day,
        time.hour,
        time.minute,
      );
    });
  }

  String? _validateVital(_VitalSpec spec) {
    final raw = _controllers[spec.field]!.text.trim();
    if (raw.isEmpty) {
      return null;
    }
    final value = double.tryParse(raw.replaceAll(',', '.'));
    if (value == null || value < spec.min || value > spec.max) {
      return AppStrings.vitalOutOfRange;
    }
    return null;
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
      'recorded_at': _isoDateTime(_recordedAt),
    };
    for (final spec in _vitals) {
      final raw = _controllers[spec.field]!.text.trim();
      if (raw.isEmpty) continue;
      final value = double.parse(raw.replaceAll(',', '.'));
      payload[spec.field] =
          spec.decimal ? value : value.toInt();
    }
    final symptoms = _symptomsController.text.trim();
    if (symptoms.isNotEmpty) {
      payload['symptoms'] = symptoms;
    }
    final notes = _notesController.text.trim();
    if (notes.isNotEmpty) {
      payload['notes'] = notes;
    }
    try {
      await widget.patientService.createMonitoring(widget.patientId, payload);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(AppStrings.monitoringCreated)),
      );
      widget.onCreated();
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _submitting = false;
        _serverErrors = fieldErrorsFrom(error);
        _submitError = _serverErrors.isEmpty ? patientErrorMessage(error) : null;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text(AppStrings.addMonitoring)),
      body: SafeArea(
        child: Form(
          key: _formKey,
          child: ListView(
            padding: const EdgeInsets.all(AppSpacing.s16),
            children: [
              InkWell(
                onTap: _pickRecordedAt,
                borderRadius: BorderRadius.circular(AppSpacing.radiusSm),
                child: InputDecorator(
                  decoration: InputDecoration(
                    labelText: AppStrings.observedAt,
                    suffixIcon: const Icon(Icons.schedule_outlined),
                    errorText: firstFieldError(_serverErrors, 'recorded_at'),
                  ),
                  child: Text(_recordedAtLabel),
                ),
              ),
              const SizedBox(height: AppSpacing.s16),
              for (final spec in _vitals) ...[
                TextFormField(
                  controller: _controllers[spec.field],
                  decoration: InputDecoration(
                    labelText: spec.label,
                    errorText: firstFieldError(_serverErrors, spec.field),
                  ),
                  validator: (_) => _validateVital(spec),
                  keyboardType:
                      const TextInputType.numberWithOptions(decimal: true),
                  textInputAction: TextInputAction.next,
                ),
                const SizedBox(height: AppSpacing.s16),
              ],
              TextFormField(
                controller: _symptomsController,
                decoration: InputDecoration(
                  labelText: AppStrings.symptoms,
                  errorText: firstFieldError(_serverErrors, 'symptoms'),
                ),
                maxLines: 2,
                textInputAction: TextInputAction.next,
              ),
              const SizedBox(height: AppSpacing.s16),
              TextFormField(
                controller: _notesController,
                decoration: InputDecoration(
                  labelText: AppStrings.notes,
                  errorText: firstFieldError(_serverErrors, 'notes'),
                ),
                maxLines: 3,
                textInputAction: TextInputAction.done,
              ),
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
