import 'package:flutter/material.dart';

import '../../core/l10n/app_strings.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/theme/app_status.dart';
import 'add_monitoring_screen.dart';
import 'models/patient.dart';
import 'patient_repository.dart';

String _two(int value) => value.toString().padLeft(2, '0');

String _formatDate(DateTime? value) {
  if (value == null) {
    return '—';
  }
  final date = value.toLocal();
  return '${date.year}-${_two(date.month)}-${_two(date.day)}';
}

String _formatDateTime(DateTime? value) {
  if (value == null) {
    return '—';
  }
  final date = value.toLocal();
  return '${_formatDate(date)} ${_two(date.hour)}:${_two(date.minute)}';
}

String _value(String? value) => value == null || value.isEmpty ? '—' : value;

class PatientDetailScreen extends StatefulWidget {
  const PatientDetailScreen({
    super.key,
    required this.patientService,
    required this.patientId,
    this.patient,
  });

  final PatientService patientService;
  final int patientId;
  final Patient? patient;

  @override
  State<PatientDetailScreen> createState() => _PatientDetailScreenState();
}

class _PatientDetailScreenState extends State<PatientDetailScreen> {
  PatientDetail? _detail;
  List<MonitoringRecord>? _records;
  String? _detailError;
  String? _monitoringError;
  bool _loadingDetail = true;
  bool _loadingMonitoring = true;

  @override
  void initState() {
    super.initState();
    _loadDetail();
    _loadMonitoring();
  }

  Future<void> _loadDetail() async {
    try {
      final detail = await widget.patientService.detail(widget.patientId);
      if (!mounted) return;
      setState(() {
        _detail = detail;
        _detailError = null;
        _loadingDetail = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _detailError = patientErrorMessage(error);
        _loadingDetail = false;
      });
    }
  }

  Future<void> _loadMonitoring() async {
    try {
      final records = await widget.patientService.monitoring(widget.patientId);
      if (!mounted) return;
      setState(() {
        _records = records;
        _monitoringError = null;
        _loadingMonitoring = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _monitoringError = patientErrorMessage(error);
        _loadingMonitoring = false;
      });
    }
  }

  void _retryDetail() {
    setState(() {
      _detailError = null;
      _loadingDetail = true;
    });
    _loadDetail();
  }

  void _retryMonitoring() {
    setState(() {
      _monitoringError = null;
      _records = null;
      _loadingMonitoring = true;
    });
    _loadMonitoring();
  }

  void _retryAll() {
    setState(() {
      _detailError = null;
      _monitoringError = null;
      _records = null;
      _loadingDetail = true;
      _loadingMonitoring = true;
    });
    _loadDetail();
    _loadMonitoring();
  }

  Future<void> _addMonitoring() async {
    final created = await Navigator.of(context).push<bool>(
      MaterialPageRoute<bool>(
        builder: (context) => AddMonitoringScreen(
          patientService: widget.patientService,
          patientId: widget.patientId,
          onCreated: () => Navigator.of(context).pop(true),
        ),
      ),
    );
    if (created == true && mounted) {
      _retryMonitoring();
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final patient = _detail ?? widget.patient;
    if (patient == null) {
      return Scaffold(
        appBar: _appBar(),
        body: Center(
          child: _detailError != null && !_loadingDetail
              ? _fullError(theme)
              : const CircularProgressIndicator(),
        ),
      );
    }
    return Scaffold(
      appBar: _appBar(),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(AppSpacing.s16),
          children: [
            if (!patient.isActive) _inactiveBanner(theme),
            if (_detailError != null) _detailErrorBanner(theme),
            _section(
              theme,
              AppStrings.identity,
              [
                _row(theme, AppStrings.patientId, patient.patientId),
                _row(theme, AppStrings.firstName, patient.firstName),
                _row(theme, AppStrings.lastName, patient.lastName),
                _row(theme, AppStrings.dateOfBirth, _formatDate(patient.dateOfBirth)),
                _row(theme, AppStrings.ageGroup, patient.ageGroup),
                _row(theme, AppStrings.sex, patient.sexLabel),
              ],
            ),
            const SizedBox(height: AppSpacing.s16),
            _section(
              theme,
              AppStrings.contact,
              [
                _row(theme, AppStrings.phone, _value(_detail?.phone)),
                _row(theme, AppStrings.address, _value(_detail?.address)),
                _row(
                  theme,
                  AppStrings.emergencyContact,
                  _value(_detail?.emergencyContact),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.s16),
            _section(
              theme,
              AppStrings.location,
              [
                _row(theme, AppStrings.suco, _value(patient.sucoName)),
                _row(
                  theme,
                  AppStrings.adminPost,
                  _value(_detail?.administrativePost),
                ),
                _row(
                  theme,
                  AppStrings.municipality,
                  _value(_detail?.municipality),
                ),
                _row(theme, AppStrings.registered, _formatDate(patient.createdAt)),
              ],
            ),
            const SizedBox(height: AppSpacing.s16),
            Align(
              alignment: Alignment.centerLeft,
              child: FilledButton.tonalIcon(
                onPressed: _addMonitoring,
                icon: const Icon(Icons.note_add_outlined),
                label: const Text(AppStrings.addMonitoring),
              ),
            ),
            const SizedBox(height: AppSpacing.s12),
            _section(theme, AppStrings.monitoringRecords, _monitoring(theme)),
          ],
        ),
      ),
    );
  }

  PreferredSizeWidget _appBar() {
    return AppBar(
      title: const Text(AppStrings.patientRecord),
      leading: IconButton(
        onPressed: () => Navigator.of(context).maybePop(),
        tooltip: AppStrings.backToPatients,
        icon: const Icon(Icons.arrow_back),
      ),
    );
  }

  Widget _fullError(ThemeData theme) {
    return Padding(
      padding: const EdgeInsets.all(AppSpacing.s24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            _detailError!,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.error,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: AppSpacing.s16),
          FilledButton(
            onPressed: _retryAll,
            child: const Text(AppStrings.retry),
          ),
        ],
      ),
    );
  }

  Widget _detailErrorBanner(ThemeData theme) {
    return Container(
      margin: const EdgeInsets.only(bottom: AppSpacing.s16),
      padding: AppSpacing.paddingSmall,
      decoration: BoxDecoration(
        color: AppTints.error,
        borderRadius: BorderRadius.circular(AppSpacing.radiusSm),
        border: Border.all(color: AppColors.error),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(_detailError!, style: theme.textTheme.bodyMedium),
          const SizedBox(height: AppSpacing.s8),
          FilledButton(
            onPressed: _retryDetail,
            child: const Text(AppStrings.retry),
          ),
        ],
      ),
    );
  }

  Widget _inactiveBanner(ThemeData theme) {
    return Container(
      margin: const EdgeInsets.only(bottom: AppSpacing.s16),
      padding: AppSpacing.paddingSmall,
      decoration: BoxDecoration(
        color: AppTints.warning,
        borderRadius: BorderRadius.circular(AppSpacing.radiusSm),
        border: Border.all(color: AppColors.warning),
      ),
      child: Row(
        children: [
          const Icon(
            Icons.warning_amber_outlined,
            size: AppSpacing.s20,
            color: AppColors.textPrimary,
          ),
          const SizedBox(width: AppSpacing.s8),
          Expanded(
            child: Text(
              AppStrings.inactiveRecord,
              style: theme.textTheme.bodyMedium,
            ),
          ),
        ],
      ),
    );
  }

  Widget _section(ThemeData theme, String title, List<Widget> children) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.s16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: theme.textTheme.headlineSmall),
            const SizedBox(height: AppSpacing.s4),
            ...children,
          ],
        ),
      ),
    );
  }

  Widget _row(ThemeData theme, String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.s4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            flex: 4,
            child: Text(label, style: theme.textTheme.bodySmall),
          ),
          const SizedBox(width: AppSpacing.s8),
          Expanded(
            flex: 5,
            child: Text(value, style: theme.textTheme.bodyMedium),
          ),
        ],
      ),
    );
  }

  List<Widget> _monitoring(ThemeData theme) {
    if (_loadingMonitoring) {
      return const [
        Padding(
          padding: EdgeInsets.symmetric(vertical: AppSpacing.s16),
          child: Center(child: CircularProgressIndicator()),
        ),
      ];
    }
    final error = _monitoringError;
    if (error != null) {
      return [
        Text(
          error,
          style:
              theme.textTheme.bodyMedium?.copyWith(color: theme.colorScheme.error),
        ),
        const SizedBox(height: AppSpacing.s12),
        FilledButton(
          onPressed: _retryMonitoring,
          child: const Text(AppStrings.retry),
        ),
      ];
    }
    final records = _records ?? const <MonitoringRecord>[];
    if (records.isEmpty) {
      return [
        Text(AppStrings.monitoringEmpty, style: theme.textTheme.titleMedium),
        const SizedBox(height: AppSpacing.s4),
        Text(AppStrings.monitoringEmptyHint, style: theme.textTheme.bodySmall),
      ];
    }
    return [
      for (final record in records) _recordCard(theme, record),
    ];
  }

  Widget _recordCard(ThemeData theme, MonitoringRecord record) {
    final vitals = _vitals(record);
    return Padding(
      padding: const EdgeInsets.only(top: AppSpacing.s8),
      child: Container(
        width: double.infinity,
        padding: AppSpacing.paddingSmall,
        decoration: BoxDecoration(
          color: AppColors.surfaceSunken,
          borderRadius: BorderRadius.circular(AppSpacing.radiusSm),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '${AppStrings.observedAt}: ${_formatDateTime(record.recordedAt)}',
              style: theme.textTheme.labelMedium,
            ),
            if (vitals.isNotEmpty) ...[
              const SizedBox(height: AppSpacing.s4),
              Wrap(
                spacing: AppSpacing.s12,
                runSpacing: AppSpacing.s4,
                children: [
                  for (final vital in vitals)
                    Text(vital, style: theme.textTheme.bodySmall),
                ],
              ),
            ],
            if (record.symptoms != null) ...[
              const SizedBox(height: AppSpacing.s4),
              Text(
                '${AppStrings.symptoms}: ${record.symptoms}',
                style: theme.textTheme.bodySmall,
              ),
            ],
            if (record.notes != null) ...[
              const SizedBox(height: AppSpacing.s4),
              Text(
                '${AppStrings.notes}: ${record.notes}',
                style: theme.textTheme.bodySmall,
              ),
            ],
            const SizedBox(height: AppSpacing.s4),
            Text(
              '${AppStrings.recordedBy}: ${_value(record.recordedBy)}',
              style: theme.textTheme.labelSmall,
            ),
          ],
        ),
      ),
    );
  }

  List<String> _vitals(MonitoringRecord record) {
    final values = <String>[];
    final temperature = record.temperature;
    if (temperature != null) {
      values.add('${AppStrings.temperature}: ${temperature.toStringAsFixed(1)}');
    }
    final heartRate = record.heartRate;
    if (heartRate != null) {
      values.add('${AppStrings.heartRate}: $heartRate');
    }
    final respiratoryRate = record.respiratoryRate;
    if (respiratoryRate != null) {
      values.add('${AppStrings.respiratoryRate}: $respiratoryRate');
    }
    final systolic = record.bloodPressureSystolic;
    if (systolic != null) {
      values.add('${AppStrings.bpSystolic}: $systolic');
    }
    final diastolic = record.bloodPressureDiastolic;
    if (diastolic != null) {
      values.add('${AppStrings.bpDiastolic}: $diastolic');
    }
    final oxygenSaturation = record.oxygenSaturation;
    if (oxygenSaturation != null) {
      values.add('${AppStrings.spo2}: $oxygenSaturation');
    }
    return values;
  }
}
