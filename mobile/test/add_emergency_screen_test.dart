import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:saude_konekta/core/l10n/app_strings.dart';
import 'package:saude_konekta/core/theme/app_theme.dart';
import 'package:saude_konekta/features/emergencies/add_emergency_screen.dart';
import 'package:saude_konekta/features/emergencies/emergency_repository.dart';
import 'package:saude_konekta/features/emergencies/models/emergency_case.dart';
import 'package:saude_konekta/features/patients/models/patient.dart';
import 'package:saude_konekta/features/patients/patient_repository.dart';

class _FakeEmergencies implements EmergencyService {
  Map<String, dynamic>? lastPayload;
  int created = 0;
  Object? createError;

  @override
  Future<EmergencyCase> create(Map<String, dynamic> payload) async {
    if (createError != null) {
      throw createError!;
    }
    lastPayload = payload;
    created += 1;
    return EmergencyCase(
      id: 9,
      patient: payload['patient'] as int,
      severity: payload['severity'] as String,
      status: 'OPEN',
    );
  }

  @override
  Future<EmergencyPage> list({String? status, int page = 1}) async =>
      const EmergencyPage(<EmergencyCase>[]);
}

final Patient _patient = Patient(
  id: 5,
  patientId: 'PT-AAAAAA',
  firstName: 'Ana',
  lastName: 'Costa',
  sex: 'F',
  isActive: true,
);

void main() {
  late _FakeEmergencies emergencies;
  late int created;

  Widget build(WidgetTester tester) {
    tester.view.physicalSize = const Size(1080, 3000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    created = 0;
    return MaterialApp(
      theme: AppTheme.light,
      home: AddEmergencyScreen(
        emergencyService: emergencies,
        patient: _patient,
        onCreated: () => created += 1,
      ),
    );
  }

  setUp(() {
    emergencies = _FakeEmergencies();
  });

  testWidgets('renders the patient and severity options', (tester) async {
    await tester.pumpWidget(build(tester));
    await tester.pumpAndSettle();

    expect(find.text('Ana Costa'), findsOneWidget);
    expect(find.text('PT-AAAAAA'), findsOneWidget);
    expect(find.text(AppStrings.severity), findsOneWidget);
    expect(find.text('LOW'), findsOneWidget);
    expect(find.text('MEDIUM'), findsOneWidget);
    expect(find.text('HIGH'), findsOneWidget);
    expect(find.text('CRITICAL'), findsOneWidget);
    expect(find.text(AppStrings.symptoms), findsOneWidget);
    expect(find.text(AppStrings.save), findsOneWidget);
  });

  testWidgets('symptoms are required', (tester) async {
    await tester.pumpWidget(build(tester));
    await tester.pumpAndSettle();

    await tester.tap(find.text(AppStrings.save));
    await tester.pumpAndSettle();

    expect(created, 0);
    expect(emergencies.lastPayload, isNull);
    expect(find.text(AppStrings.emergencySymptomsRequired), findsOneWidget);
  });

  testWidgets('valid form posts the payload with client_uuid', (tester) async {
    await tester.pumpWidget(build(tester));
    await tester.pumpAndSettle();

    await tester.enterText(
      find.widgetWithText(TextFormField, AppStrings.symptoms),
      'Dolor peitu',
    );
    await tester.tap(find.text('MEDIUM'));
    await tester.pumpAndSettle();
    await tester.tap(find.text(AppStrings.save));
    await tester.pumpAndSettle();

    expect(created, 1);
    final payload = emergencies.lastPayload!;
    expect(payload['client_uuid'], matches(RegExp(
        r'^[0-9a-f]{8}-[0-9a-f]{4}-4[0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$')));
    expect(payload['patient'], 5);
    expect(payload['severity'], 'MEDIUM');
    expect(payload['symptoms'], 'Dolor peitu');
    expect(payload.containsKey('description'), isFalse);
    expect(find.text(AppStrings.emergencyCreated), findsOneWidget);
  });

  testWidgets('server field error displays under the field', (tester) async {
    emergencies.createError = const ApiException(
      400,
      <String, dynamic>{
        'symptoms': <String>['This field is required.'],
      },
    );
    await tester.pumpWidget(build(tester));
    await tester.pumpAndSettle();

    await tester.enterText(
      find.widgetWithText(TextFormField, AppStrings.symptoms),
      'Febre',
    );
    await tester.tap(find.text(AppStrings.save));
    await tester.pumpAndSettle();

    expect(created, 0);
    expect(find.text('This field is required.'), findsOneWidget);
  });
}