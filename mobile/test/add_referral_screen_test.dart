import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:saude_konekta/core/l10n/app_strings.dart';
import 'package:saude_konekta/core/theme/app_theme.dart';
import 'package:saude_konekta/features/facilities/facility_repository.dart';
import 'package:saude_konekta/features/patients/models/patient.dart';
import 'package:saude_konekta/features/referrals/add_referral_screen.dart';
import 'package:saude_konekta/features/referrals/models/referral.dart';
import 'package:saude_konekta/features/referrals/referral_repository.dart';

class _FakeReferrals implements ReferralService {
  Map<String, dynamic>? lastPayload;
  int created = 0;
  Object? createError;

  @override
  Future<Referral> create(Map<String, dynamic> payload) async {
    if (createError != null) {
      throw createError!;
    }
    lastPayload = payload;
    created += 1;
    return Referral(
      id: 4,
      patient: payload['patient'] as int,
      urgency: payload['urgency'] as String,
      status: 'PENDING',
    );
  }

  @override
  Future<ReferralPage> list({String? status, int page = 1}) async =>
      const ReferralPage(<Referral>[]);
}

class _FakeFacilities implements FacilityService {
  @override
  Future<List<Facility>> list() async => const <Facility>[
        Facility(id: 1, name: 'CS Comoro'),
        Facility(id: 2, name: 'Hospital Nacional'),
      ];
}

final Patient _patient = Patient(
  id: 8,
  patientId: 'PT-BBBBBB',
  firstName: 'Bruno',
  lastName: 'Ximenes',
  sex: 'M',
  isActive: true,
);

void main() {
  late _FakeReferrals referrals;
  late int created;

  Widget build(WidgetTester tester) {
    tester.view.physicalSize = const Size(1080, 3000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    created = 0;
    return MaterialApp(
      theme: AppTheme.light,
      home: AddReferralScreen(
        referralService: referrals,
        facilityService: _FakeFacilities(),
        patient: _patient,
        onCreated: () => created += 1,
      ),
    );
  }

  setUp(() {
    referrals = _FakeReferrals();
  });

  testWidgets('renders the patient and urgency options', (tester) async {
    await tester.pumpWidget(build(tester));
    await tester.pumpAndSettle();

    expect(find.text('Bruno Ximenes'), findsOneWidget);
    expect(find.text('PT-BBBBBB'), findsOneWidget);
    expect(find.text('ROUTINE'), findsOneWidget);
    expect(find.text('URGENT'), findsOneWidget);
    expect(find.text('EMERGENCY'), findsOneWidget);
  });

  testWidgets('reason and destination are required', (tester) async {
    await tester.pumpWidget(build(tester));
    await tester.pumpAndSettle();

    await tester.tap(find.text(AppStrings.save));
    await tester.pumpAndSettle();

    expect(created, 0);
    expect(referrals.lastPayload, isNull);
    expect(find.text(AppStrings.reasonRequired), findsOneWidget);
    expect(find.text(AppStrings.requiredField), findsOneWidget);
  });

  testWidgets('valid form posts the payload with client_uuid', (tester) async {
    await tester.pumpWidget(build(tester));
    await tester.pumpAndSettle();

    await tester.enterText(
      find.widgetWithText(TextFormField, AppStrings.reason),
      'Needs surgery',
    );
    await tester.tap(find.byType(DropdownButtonFormField<int>));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Hospital Nacional').last);
    await tester.pumpAndSettle();
    await tester.tap(find.text('URGENT'));
    await tester.pumpAndSettle();
    await tester.tap(find.text(AppStrings.save));
    await tester.pumpAndSettle();

    expect(created, 1);
    final payload = referrals.lastPayload!;
    expect(payload['client_uuid'], matches(RegExp(
        r'^[0-9a-f]{8}-[0-9a-f]{4}-4[0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$')));
    expect(payload['patient'], 8);
    expect(payload['destination_facility'], 2);
    expect(payload['urgency'], 'URGENT');
    expect(payload['reason'], 'Needs surgery');
  });
}