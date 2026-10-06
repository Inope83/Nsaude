import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:saude_konekta/core/l10n/app_strings.dart';
import 'package:saude_konekta/core/theme/app_theme.dart';
import 'package:saude_konekta/features/patients/models/patient.dart';
import 'package:saude_konekta/features/patients/patient_detail_screen.dart';
import 'package:saude_konekta/features/patients/patient_repository.dart';

PatientDetail _detail({bool isActive = true}) {
  return PatientDetail(
    id: 11,
    patientId: 'PT-AAAAAA',
    firstName: 'Ana',
    lastName: 'Costa',
    sex: 'F',
    isActive: isActive,
    dateOfBirth: DateTime(1990, 5, 4),
    suco: 3,
    sucoName: 'Comoro',
    createdAt: DateTime(2025, 3, 1),
    updatedAt: DateTime(2025, 4, 1),
    phone: '772111111',
    address: 'Rua X',
    emergencyContact: 'Fulano 772333444',
  );
}

MonitoringRecord _record() {
  return const MonitoringRecord(
    id: 5,
    patient: 11,
    recordedBy: 'hw',
    temperature: 36.6,
    heartRate: 72,
    respiratoryRate: 16,
    bloodPressureSystolic: 120,
    bloodPressureDiastolic: 80,
    oxygenSaturation: 98,
    symptoms: 'Tuse',
    notes: 'Leve liu',
  );
}

class _FakePatientService implements PatientService {
  _FakePatientService({required this.detailResult, required this.records});

  PatientDetail detailResult;
  List<MonitoringRecord> records;
  Object? detailError;
  Object? monitoringError;
  final List<int> detailIds = <int>[];

  @override
  Future<PatientDetail> detail(int id) async {
    detailIds.add(id);
    final error = detailError;
    if (error != null) {
      throw error;
    }
    return detailResult;
  }

  @override
  Future<List<MonitoringRecord>> monitoring(int patientId) async {
    final error = monitoringError;
    if (error != null) {
      throw error;
    }
    return records;
  }

  @override
  Future<PatientPage> search({String? q, int page = 1}) async =>
      const PatientPage(<Patient>[]);

  @override
  Future<PatientDetail> createPatient(Map<String, dynamic> payload) async =>
      throw UnimplementedError('createPatient');

  @override
  Future<MonitoringRecord> createMonitoring(
    int patientId,
    Map<String, dynamic> payload,
  ) async =>
      throw UnimplementedError('createMonitoring');
}

Widget _wrap(Widget child) {
  return MaterialApp(theme: AppTheme.light, home: child);
}

Future<void> _tallSurface(WidgetTester tester) async {
  tester.view.physicalSize = const Size(2400, 3600);
  addTearDown(tester.view.reset);
}

void main() {
  testWidgets('renders identity, contact and location sections',
      (tester) async {
    await _tallSurface(tester);
    final service = _FakePatientService(
      detailResult: _detail(),
      records: [_record()],
    );
    await tester.pumpWidget(
      _wrap(PatientDetailScreen(patientService: service, patientId: 11)),
    );
    await tester.pumpAndSettle();

    expect(find.text(AppStrings.patientRecord), findsOneWidget);
    expect(service.detailIds, <int>[11]);

    expect(find.text(AppStrings.identity), findsOneWidget);
    expect(find.text('PT-AAAAAA'), findsOneWidget);
    expect(find.text('Ana'), findsOneWidget);
    expect(find.text('Costa'), findsOneWidget);
    expect(find.text('1990-05-04'), findsOneWidget);
    expect(find.text(PatientLabels.age18To64), findsOneWidget);
    expect(find.text(AppStrings.female), findsOneWidget);

    expect(find.text(AppStrings.contact), findsOneWidget);
    expect(find.text('772111111'), findsOneWidget);
    expect(find.text('Rua X'), findsOneWidget);
    expect(find.text('Fulano 772333444'), findsOneWidget);

    expect(find.text(AppStrings.location), findsOneWidget);
    expect(find.text('Comoro'), findsOneWidget);
    expect(find.text('2025-03-01'), findsOneWidget);

    expect(find.text(AppStrings.monitoringRecords), findsOneWidget);
  });

  testWidgets('renders monitoring records with vitals and author',
      (tester) async {
    await _tallSurface(tester);
    final service = _FakePatientService(
      detailResult: _detail(),
      records: [_record()],
    );
    await tester.pumpWidget(
      _wrap(PatientDetailScreen(patientService: service, patientId: 11)),
    );
    await tester.pumpAndSettle();

    expect(find.textContaining(AppStrings.observedAt), findsOneWidget);
    expect(
      find.text('${AppStrings.temperature}: 36.6'),
      findsOneWidget,
    );
    expect(
      find.text('${AppStrings.heartRate}: 72'),
      findsOneWidget,
    );
    expect(
      find.text('${AppStrings.bpSystolic}: 120'),
      findsOneWidget,
    );
    expect(
      find.text('${AppStrings.spo2}: 98'),
      findsOneWidget,
    );
    expect(find.text('${AppStrings.symptoms}: Tuse'), findsOneWidget);
    expect(find.text('${AppStrings.notes}: Leve liu'), findsOneWidget);
    expect(find.text('${AppStrings.recordedBy}: hw'), findsOneWidget);
    expect(find.text(AppStrings.monitoringEmpty), findsNothing);
  });

  testWidgets('shows the Tetum monitoring empty state', (tester) async {
    await _tallSurface(tester);
    final service = _FakePatientService(
      detailResult: _detail(),
      records: const <MonitoringRecord>[],
    );
    await tester.pumpWidget(
      _wrap(PatientDetailScreen(patientService: service, patientId: 11)),
    );
    await tester.pumpAndSettle();

    expect(find.text(AppStrings.monitoringEmpty), findsOneWidget);
    expect(find.text(AppStrings.monitoringEmptyHint), findsOneWidget);
  });

  testWidgets('inactive records show the inactive banner', (tester) async {
    await _tallSurface(tester);
    final service = _FakePatientService(
      detailResult: _detail(isActive: false),
      records: const <MonitoringRecord>[],
    );
    await tester.pumpWidget(
      _wrap(PatientDetailScreen(patientService: service, patientId: 11)),
    );
    await tester.pumpAndSettle();

    expect(find.text(AppStrings.inactiveRecord), findsOneWidget);
  });

  testWidgets('uses the list row as header until the detail loads',
      (tester) async {
    await _tallSurface(tester);
    final service = _FakePatientService(
      detailResult: _detail(),
      records: const <MonitoringRecord>[],
    );
    final patient = Patient(
      id: 11,
      patientId: 'PT-AAAAAA',
      firstName: 'Ana',
      lastName: 'Costa',
      sex: 'F',
      isActive: true,
      dateOfBirth: DateTime(1990, 5, 4),
      sucoName: 'Comoro',
    );
    await tester.pumpWidget(
      _wrap(
        PatientDetailScreen(
          patientService: service,
          patientId: 11,
          patient: patient,
        ),
      ),
    );

    expect(find.text('PT-AAAAAA'), findsOneWidget);
    expect(find.text('772111111'), findsNothing);

    await tester.pumpAndSettle();

    expect(find.text('772111111'), findsOneWidget);
  });

  testWidgets('detail failure without a header shows retry',
      (tester) async {
    await _tallSurface(tester);
    final service = _FakePatientService(
      detailResult: _detail(),
      records: const <MonitoringRecord>[],
    );
    service.detailError = StateError('boom');
    await tester.pumpWidget(
      _wrap(PatientDetailScreen(patientService: service, patientId: 11)),
    );
    await tester.pumpAndSettle();

    expect(find.text(AppStrings.connectionError), findsOneWidget);
    expect(find.text(AppStrings.retry), findsOneWidget);

    service.detailError = null;
    await tester.tap(find.widgetWithText(FilledButton, AppStrings.retry));
    await tester.pumpAndSettle();

    expect(find.text('PT-AAAAAA'), findsOneWidget);
    expect(find.text(AppStrings.retry), findsNothing);
  });
}
