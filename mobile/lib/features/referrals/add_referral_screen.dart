import 'package:flutter/material.dart';

import '../../core/l10n/app_strings.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/utils/uuid.dart';
import '../facilities/facility_repository.dart';
import '../patients/field_errors.dart';
import '../patients/models/patient.dart';
import 'models/referral.dart';
import 'referral_repository.dart';

class AddReferralScreen extends StatefulWidget {
  const AddReferralScreen({
    super.key,
    required this.referralService,
    required this.facilityService,
    required this.patient,
    required this.onCreated,
  });

  final ReferralService referralService;
  final FacilityService facilityService;
  final Patient patient;
  final VoidCallback onCreated;

  @override
  State<AddReferralScreen> createState() => _AddReferralScreenState();
}

class _AddReferralScreenState extends State<AddReferralScreen> {
  final _formKey = GlobalKey<FormState>();
  final _reasonController = TextEditingController();
  final _notesController = TextEditingController();

  late final String _clientUuid = uuidV4();
  String _urgency = ReferralLabels.urgencies.first;
  int? _destinationFacility;

  bool _loadingFacilities = true;
  String? _facilitiesError;
  List<Facility> _facilities = const <Facility>[];

  bool _submitting = false;
  String? _submitError;
  Map<String, List<String>> _serverErrors = const <String, List<String>>{};

  @override
  void initState() {
    super.initState();
    _loadFacilities();
  }

  @override
  void dispose() {
    _reasonController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  Future<void> _loadFacilities() async {
    setState(() {
      _loadingFacilities = true;
      _facilitiesError = null;
    });
    try {
      final facilities = await widget.facilityService.list();
      if (!mounted) return;
      setState(() {
        _facilities = facilities;
        _loadingFacilities = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _facilitiesError = AppStrings.genericError;
        _loadingFacilities = false;
      });
    }
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
      'destination_facility': _destinationFacility,
      'urgency': _urgency,
      'reason': _reasonController.text.trim(),
    };
    final notes = _notesController.text.trim();
    if (notes.isNotEmpty) {
      payload['notes'] = notes;
    }
    try {
      await widget.referralService.create(payload);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(AppStrings.referralCreated)),
      );
      widget.onCreated();
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _submitting = false;
        _serverErrors = fieldErrorsFrom(error);
        _submitError =
            _serverErrors.isEmpty ? referralErrorMessage(error) : null;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(title: const Text(AppStrings.newReferral)),
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
              Text(AppStrings.urgency, style: theme.textTheme.titleSmall),
              const SizedBox(height: AppSpacing.s8),
              SegmentedButton<String>(
                segments: [
                  for (final urgency in ReferralLabels.urgencies)
                    ButtonSegment<String>(
                      value: urgency,
                      label: Text(urgency),
                    ),
                ],
                selected: <String>{_urgency},
                onSelectionChanged: (selection) =>
                    setState(() => _urgency = selection.first),
              ),
              const SizedBox(height: AppSpacing.s16),
              _destinationField(),
              const SizedBox(height: AppSpacing.s16),
              TextFormField(
                controller: _reasonController,
                decoration: InputDecoration(
                  labelText: AppStrings.reason,
                  errorText: firstFieldError(_serverErrors, 'reason'),
                ),
                maxLines: 3,
                validator: (value) => (value == null || value.trim().isEmpty)
                    ? AppStrings.reasonRequired
                    : null,
              ),
              const SizedBox(height: AppSpacing.s16),
              TextFormField(
                controller: _notesController,
                decoration: InputDecoration(
                  labelText: AppStrings.notes,
                  errorText: firstFieldError(_serverErrors, 'notes'),
                ),
                maxLines: 3,
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

  Widget _destinationField() {
    if (_loadingFacilities) {
      return const Padding(
        padding: EdgeInsets.all(AppSpacing.s8),
        child: LinearProgressIndicator(minHeight: 2),
      );
    }
    if (_facilitiesError != null) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          FieldErrorText(_facilitiesError!),
          const SizedBox(height: AppSpacing.s8),
          OutlinedButton(
            onPressed: _loadFacilities,
            child: const Text(AppStrings.retry),
          ),
        ],
      );
    }
    return DropdownButtonFormField<int>(
      initialValue: _destinationFacility,
      isExpanded: true,
      decoration: InputDecoration(
        labelText: AppStrings.destinationFacility,
        errorText: firstFieldError(_serverErrors, 'destination_facility'),
      ),
      items: [
        for (final facility in _facilities)
          DropdownMenuItem<int>(
            value: facility.id,
            child: Text(
              facility.name,
              overflow: TextOverflow.ellipsis,
            ),
          ),
      ],
      onChanged: (value) => setState(() => _destinationFacility = value),
      validator: (value) =>
          value == null ? AppStrings.requiredField : null,
    );
  }
}