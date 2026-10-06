import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:saude_konekta/core/api/api_client.dart';
import 'package:saude_konekta/core/api/token_store.dart';
import 'package:saude_konekta/core/l10n/app_strings.dart';
import 'package:saude_konekta/core/sync/app_database.dart';
import 'package:saude_konekta/core/sync/sync_engine.dart';
import 'package:saude_konekta/core/theme/app_theme.dart';
import 'package:saude_konekta/features/auth/auth_repository.dart';
import 'package:saude_konekta/features/auth/user_profile.dart';
import 'package:saude_konekta/features/patients/models/patient.dart';
import 'package:saude_konekta/features/patients/patient_list_screen.dart';
import 'package:saude_konekta/features/patients/patient_repository.dart';
import 'package:saude_konekta/features/shell/app_shell.dart';

import 'support/fake_connectivity.dart';
import 'support/fake_http.dart';

UserProfile _sampleProfile() {
  return const UserProfile(
    id: 1,
    username: 'maria',
    role: 'DOCTOR',
    facility: null,
    firstName: 'Maria',
    lastName: 'Silva',
  );
}

class _FakeAuth implements AuthService {
  int logoutCalls = 0;

  @override
  Future<UserProfile> login(String username, String password) async =>
      _sampleProfile();

  @override
  Future<bool> hasSession() async => true;

  @override
  Future<void> logout() async {
    logoutCalls++;
  }

  @override
  UserProfile? get currentProfile => _sampleProfile();
}

class _FakePatientService implements PatientService {
  final List<String?> queries = <String?>[];

  @override
  Future<PatientPage> search({String? q, int page = 1}) async {
    queries.add(q);
    return const PatientPage(<Patient>[]);
  }

  @override
  Future<PatientDetail> detail(int id) async =>
      throw UnimplementedError('detail');

  @override
  Future<List<MonitoringRecord>> monitoring(int patientId) async =>
      const <MonitoringRecord>[];

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

void main() {
  testWidgets('shows four navigation tabs', (tester) async {
    await tester.pumpWidget(
      _wrap(
        AppShell(
          authService: _FakeAuth(),
          patientService: _FakePatientService(),
          onLoggedOut: () {},
        ),
      ),
    );

    expect(find.text(AppStrings.tabOverview), findsWidgets);
    expect(find.text(AppStrings.tabEmergencies), findsOneWidget);
    expect(find.text(AppStrings.tabReferrals), findsOneWidget);
    expect(find.text(AppStrings.tabPatients), findsOneWidget);
    expect(find.text(AppStrings.placeholderTitle), findsOneWidget);
  });

  testWidgets('switching tabs swaps the placeholder body', (tester) async {
    await tester.pumpWidget(
      _wrap(
        AppShell(
          authService: _FakeAuth(),
          patientService: _FakePatientService(),
          onLoggedOut: () {},
        ),
      ),
    );

    expect(find.text('${AppStrings.roleLabel}: ${AppStrings.roleDoctor}'),
        findsOneWidget);

    await tester.tap(find.text(AppStrings.tabEmergencies));
    await tester.pumpAndSettle();

    expect(find.text(AppStrings.tabEmergencies), findsWidgets);
    expect(find.text(AppStrings.placeholderTitle), findsOneWidget);
  });

  testWidgets('Pazientis tab shows the patient list', (tester) async {
    final patients = _FakePatientService();
    await tester.pumpWidget(
      _wrap(
        AppShell(
          authService: _FakeAuth(),
          patientService: patients,
          onLoggedOut: () {},
        ),
      ),
    );

    await tester.tap(find.text(AppStrings.tabPatients));
    await tester.pumpAndSettle();

    expect(find.byType(PatientListScreen), findsOneWidget);
    expect(find.text(AppStrings.patientsTitle), findsWidgets);
    expect(find.text(AppStrings.searchHint), findsOneWidget);
    expect(patients.queries, <String?>[null]);
    expect(find.text(AppStrings.listEmpty), findsOneWidget);
  });

  testWidgets('logout button signs out and calls onLoggedOut', (tester) async {
    var loggedOut = false;
    final auth = _FakeAuth();
    await tester.pumpWidget(
      _wrap(
        AppShell(
          authService: auth,
          onLoggedOut: () => loggedOut = true,
        ),
      ),
    );

    await tester.tap(find.byTooltip(AppStrings.logout));
    await tester.pumpAndSettle();

    expect(auth.logoutCalls, 1);
    expect(loggedOut, isTrue);
  });

  testWidgets('opens the sync status screen from the app bar', (tester) async {
    final db = AppDatabase.memory();
    addTearDown(db.close);
    final connectivity = FakeConnectivityService();
    addTearDown(connectivity.dispose);
    final engine = SyncEngine(
      store: db,
      client: ApiClient(
        tokenStore: MemoryTokenStore(),
        dio: Dio()..httpClientAdapter = FakeAdapter(
            (options) async => jsonResponse(<String, dynamic>{'id': 1})),
      ),
      connectivity: connectivity,
    );

    await tester.pumpWidget(
      _wrap(
        AppShell(
          authService: _FakeAuth(),
          onLoggedOut: () {},
          syncEngine: engine,
          connectivity: connectivity,
        ),
      ),
    );

    await tester.tap(find.byTooltip(AppStrings.syncTooltip));
    await tester.pumpAndSettle();

    expect(find.text(AppStrings.syncTitle), findsWidgets);
    expect(find.text(AppStrings.syncNow), findsOneWidget);
  });

  testWidgets('syncs automatically when connectivity returns', (tester) async {
    final db = AppDatabase.memory();
    addTearDown(db.close);
    final connectivity = FakeConnectivityService(initialOnline: false);
    addTearDown(connectivity.dispose);
    final engine = SyncEngine(
      store: db,
      client: ApiClient(
        tokenStore: MemoryTokenStore(),
        dio: Dio()..httpClientAdapter = FakeAdapter(
            (options) async => jsonResponse(<String, dynamic>{'id': 1})),
      ),
      connectivity: connectivity,
    );
    await db.enqueue(
      clientUuid: 'queued-1',
      entityType: 'patients',
      method: 'POST',
      path: '/api/patients/',
      payload: <String, dynamic>{},
    );

    await tester.pumpWidget(
      _wrap(
        AppShell(
          authService: _FakeAuth(),
          onLoggedOut: () {},
          syncEngine: engine,
          connectivity: connectivity,
        ),
      ),
    );

    connectivity.emit(true);
    await tester.pumpAndSettle();

    expect(await db.pendingCount(), 0);
  });
}