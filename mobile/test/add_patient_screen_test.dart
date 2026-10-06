import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:saude_konekta/core/l10n/app_strings.dart';
import 'package:saude_konekta/core/theme/app_theme.dart';
import 'package:saude_konekta/features/geography/geography_repository.dart';
import 'package:saude_konekta/features/patients/add_patient_screen.dart';
import 'package:saude_konekta/features/patients/models/patient.dart';
import 'package:saude_konekta/features/patients/patient_repository.dart';

class _FakeGeography implements GeographyService {
  @override
  Future<List<GeoItem>> municipalities() async => const <GeoItem>[
        GeoItem(id: 1, name: 'Dili', code: 'dili'),
      ];

  @override
  Future<List<GeoItem>> postsFor(String municipalityCode) async =>
      <GeoItem>[GeoItem(id: 10, name: 'Posto A', code: 'pa')];

  @override
  Future<List<GeoItem>> sucosFor(String administrativePostCode) async =>
      <GeoItem>[GeoItem(id: 100, name: 'Suco A', code: 'sa')];
}

class _FakePatients implements PatientService {
  Map<String, dynamic>? lastPayload;
  Object? createError;
  int created = 0;

  @override
  Future<PatientDetail> createPatient(Map<String, dynamic> payload) async {
    if (createError != null) {
      throw createError!;
    }
    lastPayload = payload;
    return PatientDetail.fromJson(<String, dynamic>{
      'id': 42,
      'client_uuid': payload['client_uuid'],
      'patient_id': 'PT-NEW001',
      'first_name': payload['first_name'],
      'last_name': payload['last_name'],
      'date_of_birth': null,
      'sex': payload['sex'],
      'suco': payload['suco'],
      'suco_name': 'Suco A',
      'is_active': true,
      'created_at': '2026-01-01T00:00:00Z',
      'updated_at': '2026-01-01T00:00:00Z',
      'phone': null,
      'address': null,
      'emergency_contact': null,
    });
  }

  @override
  Future<MonitoringRecord> createMonitoring(
    int patientId,
    Map<String, dynamic> payload,
  ) async =>
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

Future<void> _selectDropdown(WidgetTester tester, int index, String label) async {
  final dropdown = find.byType(DropdownButtonFormField<GeoItem>).at(index);
  await tester.ensureVisible(dropdown);
  await tester.pumpAndSettle();
  await tester.tap(dropdown);
  await tester.pumpAndSettle();
  await tester.tap(find.text(label).last);
  await tester.pumpAndSettle();
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
      home: AddPatientScreen(
        patientService: patients,
        geographyService: _FakeGeography(),
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

    expect(find.text(AppStrings.addPatient), findsOneWidget);
    expect(find.text(AppStrings.firstName), findsOneWidget);
    expect(find.text(AppStrings.lastName), findsOneWidget);
    expect(find.text(AppStrings.sex), findsOneWidget);
    expect(find.text(AppStrings.female), findsOneWidget);
    expect(find.text(AppStrings.male), findsOneWidget);
    expect(find.text(AppStrings.save), findsOneWidget);
  });

  testWidgets('required validation blocks submit', (tester) async {
    await tester.pumpWidget(build(tester));
    await tester.pumpAndSettle();

    await tester.tap(find.text(AppStrings.save));
    await tester.pumpAndSettle();

    expect(created, 0);
    expect(patients.lastPayload, isNull);
    expect(find.text(AppStrings.requiredField), findsWidgets);
  });

  testWidgets('suco is required', (tester) async {
    await tester.pumpWidget(build(tester));
    await tester.pumpAndSettle();

    await tester.enterText(
      find.widgetWithText(TextFormField, AppStrings.firstName),
      'Ana',
    );
    await tester.enterText(
      find.widgetWithText(TextFormField, AppStrings.lastName),
      'Costa',
    );
    await tester.tap(find.text(AppStrings.save));
    await tester.pumpAndSettle();

    expect(created, 0);
    expect(find.text(AppStrings.requiredField), findsWidgets);
  });

  testWidgets('invalid phone is rejected locally', (tester) async {
    await tester.pumpWidget(build(tester));
    await tester.pumpAndSettle();

    await tester.enterText(
      find.widgetWithText(TextFormField, AppStrings.firstName),
      'Ana',
    );
    await tester.enterText(
      find.widgetWithText(TextFormField, AppStrings.lastName),
      'Costa',
    );
    final phone = find.widgetWithText(TextFormField, AppStrings.phone);
    await tester.ensureVisible(phone);
    await tester.enterText(phone, 'call-me');
    await tester.tap(find.text(AppStrings.save));
    await tester.pumpAndSettle();

    expect(created, 0);
    expect(find.text(AppStrings.phoneInvalid), findsOneWidget);
  });

  testWidgets('valid form posts the payload with client_uuid', (tester) async {
    await tester.pumpWidget(build(tester));
    await tester.pumpAndSettle();

    await tester.enterText(
      find.widgetWithText(TextFormField, AppStrings.firstName),
      'Ana',
    );
    await tester.enterText(
      find.widgetWithText(TextFormField, AppStrings.lastName),
      'Costa',
    );
    await _selectDropdown(tester, 0, 'Dili');
    await _selectDropdown(tester, 1, 'Posto A');
    await _selectDropdown(tester, 2, 'Suco A');

    await tester.tap(find.text(AppStrings.save));
    await tester.pumpAndSettle();

    expect(created, 1);
    final payload = patients.lastPayload!;
    expect(payload['client_uuid'], matches(RegExp(
        r'^[0-9a-f]{8}-[0-9a-f]{4}-4[0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$')));
    expect(payload['first_name'], 'Ana');
    expect(payload['last_name'], 'Costa');
    expect(payload['sex'], 'F');
    expect(payload['suco'], 100);
    expect(payload.containsKey('phone'), isFalse);
    expect(find.text(AppStrings.patientCreated), findsOneWidget);
  });

  testWidgets('server field error displays under the field', (tester) async {
    patients.createError = const ApiException(
      400,
      <String, dynamic>{'first_name': <String>['Esse campo é obrigatório.']},
    );
    await tester.pumpWidget(build(tester));
    await tester.pumpAndSettle();

    await tester.enterText(
      find.widgetWithText(TextFormField, AppStrings.firstName),
      'Ana',
    );
    await tester.enterText(
      find.widgetWithText(TextFormField, AppStrings.lastName),
      'Costa',
    );
    await _selectDropdown(tester, 0, 'Dili');
    await _selectDropdown(tester, 1, 'Posto A');
    await _selectDropdown(tester, 2, 'Suco A');

    await tester.tap(find.text(AppStrings.save));
    await tester.pumpAndSettle();

    expect(created, 0);
    expect(find.text('Esse campo é obrigatório.'), findsOneWidget);
  });
}
