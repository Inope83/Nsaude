import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:saude_konekta/core/l10n/app_strings.dart';
import 'package:saude_konekta/core/theme/app_theme.dart';
import 'package:saude_konekta/features/patients/add_monitoring_screen.dart';
import 'package:saude_konekta/features/patients/models/patient.dart';
import 'package:saude_konekta/features/patients/patient_repository.dart';

class _FakePatients implements PatientService {
  Map<String, dynamic>? lastPayload;
  int? lastPatientId;
  int created = 0;
  Object? createError;

  @override
  Future<MonitoringRecord> createMonitoring(
    int patientId,
    Map<String, dynamic> payload,
  ) async {
    if (createError != null) {
      throw createError!;
    }
    lastPatientId = patientId;
    lastPayload = payload;
    created += 1;
    return MonitoringRecord.fromJson(<String, dynamic>{
      'id': 9,
      'client_uuid': payload['client_uuid'],
      'patient': patientId,
      'recorded_by': 'hw',
      'recorded_at': payload['recorded_at'],
      'temperature': payload['temperature'],
      'heart_rate': payload['heart_rate'],
      'respiratory_rate': null,
      'blood_pressure_systolic': null,
      'blood_pressure_diastolic': null,
      'oxygen_saturation': null,
      'symptoms': payload['symptoms'],
      'notes': payload['notes'],
      'created_at': '2026-01-01T00:00:00Z',
    });
  }

  @override
  Future<PatientDetail> createPatient(Map<String, dynamic> payload) async =>
      throw UnimplementedError();

  @override
  Future<PatientDetail> detail(int id) async => throw UnimplementedError();

  @override
  Future<List<MonitoringRecord>> monitoring(int patientId) async =>
      const <MonitoringRecord>[];

  @override
  Future<PatientPage> search({String? q, int page = 1}) async =>
      const PatientPage(<Patient>[]);
}

void main() {
  late _FakePatients patients;
  late int created;

  Widget build(WidgetTester tester) {
    tester.view.physicalSize = const Size(1080, 3000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    created = 0;
    return MaterialApp(
      theme: AppTheme.light,
      home: AddMonitoringScreen(
        patientService: patients,
        patientId: 11,
        onCreated: () => created += 1,
      ),
    );
  }

  setUp(() {
    patients = _FakePatients();
  });

  testWidgets('renders Tetum labels', (tester) async {
    await tester.pumpWidget(build(tester));
    await tester.pumpAndSettle();

    expect(find.text(AppStrings.addMonitoring), findsOneWidget);
    expect(find.text(AppStrings.observedAt), findsOneWidget);
    expect(find.text(AppStrings.temperature), findsOneWidget);
    expect(find.text(AppStrings.heartRate), findsOneWidget);
    expect(find.text(AppStrings.symptoms), findsOneWidget);
    expect(find.text(AppStrings.save), findsOneWidget);
  });

  testWidgets('posts vitals with client_uuid and omits empty fields',
      (tester) async {
    await tester.pumpWidget(build(tester));
    await tester.pumpAndSettle();

    await tester.enterText(
      find.widgetWithText(TextFormField, AppStrings.temperature),
      '36.6',
    );
    await tester.enterText(
      find.widgetWithText(TextFormField, AppStrings.heartRate),
      '80',
    );
    await tester.tap(find.text(AppStrings.save));
    await tester.pumpAndSettle();

    expect(created, 1);
    expect(patients.lastPatientId, 11);
    final payload = patients.lastPayload!;
    expect(payload['client_uuid'], matches(RegExp(
        r'^[0-9a-f]{8}-[0-9a-f]{4}-4[0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$')));
    expect(payload['recorded_at'], isA<String>());
    expect(payload['temperature'], 36.6);
    expect(payload['heart_rate'], 80);
    expect(payload.containsKey('respiratory_rate'), isFalse);
    expect(payload.containsKey('blood_pressure_systolic'), isFalse);
    expect(payload.containsKey('symptoms'), isFalse);
    expect(find.text(AppStrings.monitoringCreated), findsOneWidget);
  });

  testWidgets('empty optional vitals still submit', (tester) async {
    await tester.pumpWidget(build(tester));
    await tester.pumpAndSettle();

    await tester.tap(find.text(AppStrings.save));
    await tester.pumpAndSettle();

    expect(created, 1);
    final payload = patients.lastPayload!;
    expect(payload.containsKey('client_uuid'), isTrue);
    expect(payload.containsKey('recorded_at'), isTrue);
    expect(payload.length, 2);
  });

  testWidgets('out of range vitals block submit locally', (tester) async {
    await tester.pumpWidget(build(tester));
    await tester.pumpAndSettle();

    await tester.enterText(
      find.widgetWithText(TextFormField, AppStrings.temperature),
      '99',
    );
    await tester.tap(find.text(AppStrings.save));
    await tester.pumpAndSettle();

    expect(created, 0);
    expect(patients.lastPayload, isNull);
    expect(find.text(AppStrings.vitalOutOfRange), findsOneWidget);
  });

  testWidgets('server field error displays under the field', (tester) async {
    patients.createError = const ApiException(
      400,
      <String, dynamic>{
        'temperature': <String>['Ensure this value is less than or equal to 50.'],
      },
    );
    await tester.pumpWidget(build(tester));
    await tester.pumpAndSettle();

    await tester.enterText(
      find.widgetWithText(TextFormField, AppStrings.temperature),
      '40',
    );
    await tester.tap(find.text(AppStrings.save));
    await tester.pumpAndSettle();

    expect(created, 0);
    expect(
      find.text('Ensure this value is less than or equal to 50.'),
      findsOneWidget,
    );
  });
}
