import 'package:flutter/material.dart';

import '../../core/l10n/app_strings.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/utils/uuid.dart';
import '../../core/widgets/cascading_location_picker.dart';
import '../geography/geography_repository.dart';
import 'field_errors.dart';
import 'patient_repository.dart';

class AddPatientScreen extends StatefulWidget {
  const AddPatientScreen({
    super.key,
    required this.patientService,
    required this.geographyService,
    required this.onCreated,
  });

  final PatientService patientService;
  final GeographyService geographyService;
  final VoidCallback onCreated;

  @override
  State<AddPatientScreen> createState() => _AddPatientScreenState();
}

class _AddPatientScreenState extends State<AddPatientScreen> {
  final _formKey = GlobalKey<FormState>();
  final _firstNameController = TextEditingController();
  final _lastNameController = TextEditingController();
  final _phoneController = TextEditingController();
  final _addressController = TextEditingController();
  final _emergencyContactController = TextEditingController();

  late final String _clientUuid = uuidV4();
  String _sex = 'F';
  DateTime? _dateOfBirth;
  GeoItem? _suco;
  bool _submitting = false;
  String? _submitError;
  String? _sucoLocalError;
  Map<String, List<String>> _serverErrors = const <String, List<String>>{};

  @override
  void dispose() {
    _firstNameController.dispose();
    _lastNameController.dispose();
    _phoneController.dispose();
    _addressController.dispose();
    _emergencyContactController.dispose();
    super.dispose();
  }

  Future<void> _pickDateOfBirth() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _dateOfBirth ?? DateTime(now.year - 10, now.month, now.day),
      firstDate: DateTime(now.year - 120),
      lastDate: now,
    );
    if (picked != null) {
      setState(() => _dateOfBirth = picked);
    }
  }

  String _isoDate(DateTime value) =>
      '${value.year.toString().padLeft(4, '0')}-'
      '${value.month.toString().padLeft(2, '0')}-'
      '${value.day.toString().padLeft(2, '0')}';

  Future<void> _submit() async {
    setState(() => _serverErrors = const <String, List<String>>{});
    final form = _formKey.currentState;
    if (form == null || !form.validate()) {
      return;
    }
    if (_suco == null) {
      setState(() => _sucoLocalError = AppStrings.requiredField);
      return;
    }
    setState(() => _submitting = true);
    final payload = <String, dynamic>{
      'client_uuid': _clientUuid,
      'first_name': _firstNameController.text.trim(),
      'last_name': _lastNameController.text.trim(),
      'sex': _sex,
      'suco': _suco!.id,
    };
    if (_dateOfBirth != null) {
      payload['date_of_birth'] = _isoDate(_dateOfBirth!);
    }
    final phone = _phoneController.text.trim();
    if (phone.isNotEmpty) {
      payload['phone'] = phone;
    }
    final address = _addressController.text.trim();
    if (address.isNotEmpty) {
      payload['address'] = address;
    }
    final emergencyContact = _emergencyContactController.text.trim();
    if (emergencyContact.isNotEmpty) {
      payload['emergency_contact'] = emergencyContact;
    }
    try {
      await widget.patientService.createPatient(payload);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(AppStrings.patientCreated)),
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
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(title: const Text(AppStrings.addPatient)),
      body: SafeArea(
        child: Form(
          key: _formKey,
          child: ListView(
            padding: const EdgeInsets.all(AppSpacing.s16),
            children: [
              TextFormField(
                controller: _firstNameController,
                decoration: InputDecoration(
                  labelText: AppStrings.firstName,
                  errorText:
                      firstFieldError(_serverErrors, 'first_name'),
                ),
                textInputAction: TextInputAction.next,
                validator: (value) =>
                    (value == null || value.trim().isEmpty)
                        ? AppStrings.requiredField
                        : null,
              ),
              const SizedBox(height: AppSpacing.s16),
              TextFormField(
                controller: _lastNameController,
                decoration: InputDecoration(
                  labelText: AppStrings.lastName,
                  errorText: firstFieldError(_serverErrors, 'last_name'),
                ),
                textInputAction: TextInputAction.next,
                validator: (value) =>
                    (value == null || value.trim().isEmpty)
                        ? AppStrings.requiredField
                        : null,
              ),
              const SizedBox(height: AppSpacing.s16),
              _sexSection(theme),
              const SizedBox(height: AppSpacing.s16),
              _dateOfBirthField(theme),
              const SizedBox(height: AppSpacing.s16),
              CascadingLocationPicker(
                geographyService: widget.geographyService,
                onSucoChanged: (value) => setState(() {
                  _suco = value;
                  _sucoLocalError = null;
                }),
                errorText: firstFieldError(_serverErrors, 'suco') ??
                    _sucoLocalError,
              ),
              if (_sucoLocalError != null)
                Padding(
                  padding: const EdgeInsets.only(top: AppSpacing.s4),
                  child: FieldErrorText(_sucoLocalError!),
                ),
              const SizedBox(height: AppSpacing.s16),
              TextFormField(
                controller: _phoneController,
                decoration: InputDecoration(
                  labelText: AppStrings.phone,
                  errorText: firstFieldError(_serverErrors, 'phone'),
                ),
                keyboardType: TextInputType.phone,
                textInputAction: TextInputAction.next,
                validator: (value) {
                  final phone = value?.trim() ?? '';
                  if (phone.isEmpty) {
                    return null;
                  }
                  return RegExp(r'^[\d\s+\-()]*$').hasMatch(phone)
                      ? null
                      : AppStrings.phoneInvalid;
                },
              ),
              const SizedBox(height: AppSpacing.s16),
              TextFormField(
                controller: _addressController,
                decoration: InputDecoration(
                  labelText: AppStrings.address,
                  errorText: firstFieldError(_serverErrors, 'address'),
                ),
                textInputAction: TextInputAction.next,
              ),
              const SizedBox(height: AppSpacing.s16),
              TextFormField(
                controller: _emergencyContactController,
                decoration: InputDecoration(
                  labelText: AppStrings.emergencyContact,
                  errorText:
                      firstFieldError(_serverErrors, 'emergency_contact'),
                ),
                textInputAction: TextInputAction.done,
              ),
              if (_submitError != null) ...[
                const SizedBox(height: AppSpacing.s16),
                FieldErrorText(_submitError!),
              ],
              if (unhandledFieldError(
                    _serverErrors,
                    const {'first_name', 'last_name', 'sex', 'suco',
                      'date_of_birth', 'phone', 'address', 'emergency_contact'},
                  ) !=
                  null) ...[
                const SizedBox(height: AppSpacing.s16),
                FieldErrorText(
                  unhandledFieldError(
                    _serverErrors,
                    const {'first_name', 'last_name', 'sex', 'suco',
                      'date_of_birth', 'phone', 'address', 'emergency_contact'},
                  )!,
                ),
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

  Widget _sexSection(ThemeData theme) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(AppStrings.sex, style: theme.textTheme.labelLarge),
        const SizedBox(height: AppSpacing.s4),
        SegmentedButton<String>(
          segments: const [
            ButtonSegment(value: 'F', label: Text(AppStrings.female)),
            ButtonSegment(value: 'M', label: Text(AppStrings.male)),
            ButtonSegment(value: 'O', label: Text(AppStrings.other)),
          ],
          selected: {_sex},
          onSelectionChanged: (values) => setState(() => _sex = values.first),
          showSelectedIcon: false,
        ),
        if (firstFieldError(_serverErrors, 'sex') != null)
          FieldErrorText(firstFieldError(_serverErrors, 'sex')!),
      ],
    );
  }

  Widget _dateOfBirthField(ThemeData theme) {
    return InkWell(
      onTap: _pickDateOfBirth,
      borderRadius: BorderRadius.circular(AppSpacing.radiusSm),
      child: InputDecorator(
        decoration: InputDecoration(
          labelText: AppStrings.dateOfBirth,
          suffixIcon: const Icon(Icons.calendar_today_outlined),
          errorText: firstFieldError(_serverErrors, 'date_of_birth'),
        ),
        child: Text(_dateOfBirth == null ? '—' : _isoDate(_dateOfBirth!)),
      ),
    );
  }
}
