import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:saude_konekta/core/l10n/app_strings.dart';
import 'package:saude_konekta/core/theme/app_theme.dart';
import 'package:saude_konekta/features/auth/auth_repository.dart';
import 'package:saude_konekta/features/patients/models/patient.dart';
import 'package:saude_konekta/features/patients/patient_detail_screen.dart';
import 'package:saude_konekta/features/patients/patient_list_screen.dart';
import 'package:saude_konekta/features/patients/patient_repository.dart';

Patient _patient({
  int id = 11,
  String patientId = 'PT-AAAAAA',
  String firstName = 'Ana',
  String lastName = 'Costa',
}) {
  return Patient(
    id: id,
    patientId: patientId,
    firstName: firstName,
    lastName: lastName,
    sex: 'F',
    isActive: true,
    dateOfBirth: DateTime(1990, 5, 4),
    suco: 3,
    sucoName: 'Comoro',
    createdAt: DateTime(2025, 3, 1),
    updatedAt: DateTime(2025, 4, 1),
  );
}

PatientDetail _detail() {
  return PatientDetail(
    id: 11,
    patientId: 'PT-AAAAAA',
    firstName: 'Ana',
    lastName: 'Costa',
    sex: 'F',
    isActive: true,
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

class _FakePatientService implements PatientService {
  PatientPage page = const PatientPage(<Patient>[]);
  PatientPage Function(String? q, int page)? onSearch;
  PatientDetail? detailResult;
  List<MonitoringRecord> records = const <MonitoringRecord>[];
  Object? searchError;
  final List<String?> queries = <String?>[];
  final List<int> pages = <int>[];

  @override
  Future<PatientPage> search({String? q, int page = 1}) async {
    queries.add(q);
    pages.add(page);
    final error = searchError;
    if (error != null) {
      throw error;
    }
    final responder = onSearch;
    if (responder != null) {
      return responder(q, page);
    }
    return this.page;
  }

  @override
  Future<PatientDetail> detail(int id) async {
    final result = detailResult;
    if (result == null) {
      throw StateError('missing detail fixture');
    }
    return result;
  }

  @override
  Future<List<MonitoringRecord>> monitoring(int patientId) async => records;

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
  testWidgets('renders the Tetum title and search hint', (tester) async {
    final service = _FakePatientService()..page = PatientPage([_patient()]);
    await tester.pumpWidget(_wrap(PatientListScreen(patientService: service)));
    await tester.pumpAndSettle();

    expect(find.text(AppStrings.patientsTitle), findsOneWidget);
    expect(find.text(AppStrings.searchHint), findsOneWidget);
    expect(find.byType(TextField), findsOneWidget);
  });

  testWidgets('renders patient rows returned by the service', (tester) async {
    final service = _FakePatientService()..page = PatientPage([_patient()]);
    await tester.pumpWidget(_wrap(PatientListScreen(patientService: service)));
    await tester.pumpAndSettle();

    expect(find.text('PT-AAAAAA'), findsOneWidget);
    expect(find.text('Ana Costa'), findsOneWidget);
    expect(
      find.text('${PatientLabels.age18To64} · ${AppStrings.female}'),
      findsOneWidget,
    );
    expect(service.queries, <String?>[null]);
  });

  testWidgets('debounced typing searches with q and shows the empty state',
      (tester) async {
    final service = _FakePatientService();
    await tester.pumpWidget(_wrap(PatientListScreen(patientService: service)));
    await tester.pumpAndSettle();

    expect(find.text(AppStrings.listEmpty), findsOneWidget);
    expect(find.text(AppStrings.listEmptyHint), findsOneWidget);

    await tester.enterText(find.byType(TextField), 'zzz');
    await tester.pump(const Duration(milliseconds: 450));
    await tester.pumpAndSettle();

    expect(service.queries, contains('zzz'));
    expect(find.text(AppStrings.searchEmpty), findsOneWidget);
    expect(find.text(AppStrings.searchEmptyHint), findsOneWidget);
    expect(find.text(AppStrings.listEmpty), findsNothing);
  });

  testWidgets('submitting the search field searches immediately',
      (tester) async {
    final service = _FakePatientService();
    await tester.pumpWidget(_wrap(PatientListScreen(patientService: service)));
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextField), 'Ana');
    await tester.testTextInput.receiveAction(TextInputAction.search);
    await tester.pumpAndSettle();

    expect(service.queries, contains('Ana'));
    expect(find.text(AppStrings.searchEmpty), findsOneWidget);
  });

  testWidgets('tapping a row opens the patient detail screen',
      (tester) async {
    final service = _FakePatientService()
      ..page = PatientPage([_patient()])
      ..detailResult = _detail();
    await tester.pumpWidget(_wrap(PatientListScreen(patientService: service)));
    await tester.pumpAndSettle();

    await tester.tap(find.text('PT-AAAAAA'));
    await tester.pumpAndSettle();

    expect(find.byType(PatientDetailScreen), findsOneWidget);
    expect(find.text(AppStrings.patientRecord), findsOneWidget);
    expect(find.text('772111111'), findsOneWidget);
  });

  testWidgets('load more appends the next page', (tester) async {
    final service = _FakePatientService();
    service.onSearch = (q, page) {
      if (page == 1) {
        return PatientPage([_patient()], 'http://testserver/?page=2');
      }
      return PatientPage([
        _patient(
          id: 12,
          patientId: 'PT-BBBBBB',
          firstName: 'Bruno',
          lastName: 'Ximenes',
        )
      ]);
    };
    await tester.pumpWidget(_wrap(PatientListScreen(patientService: service)));
    await tester.pumpAndSettle();

    expect(find.text('PT-AAAAAA'), findsOneWidget);
    expect(find.text(AppStrings.loadMore), findsOneWidget);

    await tester.tap(find.widgetWithText(OutlinedButton, AppStrings.loadMore));
    await tester.pumpAndSettle();

    expect(service.pages, <int>[1, 2]);
    expect(find.text('PT-AAAAAA'), findsOneWidget);
    expect(find.text('PT-BBBBBB'), findsOneWidget);
    expect(find.text(AppStrings.loadMore), findsNothing);
  });

  testWidgets('errors show the retry action and reload the list',
      (tester) async {
    final service = _FakePatientService()
      ..searchError = const NetworkException(AppStrings.connectionError);
    await tester.pumpWidget(_wrap(PatientListScreen(patientService: service)));
    await tester.pumpAndSettle();

    expect(find.text(AppStrings.connectionError), findsOneWidget);
    expect(find.text(AppStrings.retry), findsOneWidget);

    service.searchError = null;
    service.page = PatientPage([_patient()]);
    await tester.tap(find.widgetWithText(FilledButton, AppStrings.retry));
    await tester.pumpAndSettle();

    expect(find.text('PT-AAAAAA'), findsOneWidget);
    expect(find.text(AppStrings.retry), findsNothing);
  });
}
