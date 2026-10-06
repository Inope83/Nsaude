import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:saude_konekta/core/l10n/app_strings.dart';
import 'package:saude_konekta/core/theme/app_theme.dart';
import 'package:saude_konekta/features/auth/auth_repository.dart';
import 'package:saude_konekta/features/emergencies/emergency_repository.dart';
import 'package:saude_konekta/features/emergencies/models/emergency_case.dart';
import 'package:saude_konekta/features/overview/overview_screen.dart';
import 'package:saude_konekta/features/patients/models/patient.dart';
import 'package:saude_konekta/features/patients/patient_repository.dart';
import 'package:saude_konekta/features/referrals/models/referral.dart';
import 'package:saude_konekta/features/referrals/referral_repository.dart';

class _FakePatients implements PatientService {
  _FakePatients(this.count);
  final int count;

  @override
  Future<PatientPage> search({String? q, int page = 1}) async =>
      PatientPage(const <Patient>[], null, count);

  @override
  Future<PatientDetail> createPatient(Map<String, dynamic> payload) async =>
      throw UnimplementedError();
  @override
  Future<PatientDetail> detail(int id) async => throw UnimplementedError();
  @override
  Future<List<MonitoringRecord>> monitoring(int patientId) async =>
      const <MonitoringRecord>[];
  @override
  Future<MonitoringRecord> createMonitoring(int patientId, payload) async =>
      throw UnimplementedError();
}

class _FakeEmergencies implements EmergencyService {
  _FakeEmergencies(this.count, {this.fail = false});
  final int count;
  final bool fail;

  @override
  Future<EmergencyPage> list({String? status, int page = 1}) async {
    if (fail) {
      throw const NetworkException('offline');
    }
    return EmergencyPage(const <EmergencyCase>[], null, count);
  }

  @override
  Future<EmergencyCase> create(Map<String, dynamic> payload) async =>
      throw UnimplementedError();
}

class _FakeReferrals implements ReferralService {
  _FakeReferrals(this.count);
  final int count;

  @override
  Future<ReferralPage> list({String? status, int page = 1}) async =>
      ReferralPage(const <Referral>[], null, count);

  @override
  Future<Referral> create(Map<String, dynamic> payload) async =>
      throw UnimplementedError();
}

Widget _wrap({
  int patients = 12,
  int emergencies = 3,
  int referrals = 5,
  bool fail = false,
}) =>
    MaterialApp(
      theme: AppTheme.light,
      home: OverviewScreen(
        patientService: _FakePatients(patients),
        emergencyService: _FakeEmergencies(emergencies, fail: fail),
        referralService: _FakeReferrals(referrals),
        roleLabel: 'Trabaladór saúde',
      ),
    );

void main() {
  testWidgets('renders the counts from each service', (tester) async {
    await tester.pumpWidget(_wrap());
    await tester.pumpAndSettle();

    expect(find.text(AppStrings.statPatients), findsOneWidget);
    expect(find.text('12'), findsOneWidget);
    expect(find.text(AppStrings.statOpenEmergencies), findsOneWidget);
    expect(find.text('3'), findsOneWidget);
    expect(find.text(AppStrings.statPendingReferrals), findsOneWidget);
    expect(find.text('5'), findsOneWidget);
    expect(find.text('${AppStrings.roleLabel}: Trabaladór saúde'), findsOneWidget);
  });

  testWidgets('shows an error with retry on failure', (tester) async {
    await tester.pumpWidget(_wrap(fail: true));
    await tester.pumpAndSettle();

    expect(find.text(AppStrings.overviewError), findsOneWidget);
    expect(find.text(AppStrings.retry), findsOneWidget);
  });
}