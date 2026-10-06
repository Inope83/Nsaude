import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:saude_konekta/core/l10n/app_strings.dart';
import 'package:saude_konekta/core/theme/app_theme.dart';
import 'package:saude_konekta/features/emergencies/emergency_list_screen.dart';
import 'package:saude_konekta/features/auth/auth_repository.dart';
import 'package:saude_konekta/features/emergencies/emergency_repository.dart';
import 'package:saude_konekta/features/emergencies/models/emergency_case.dart';

class _FakeEmergencies implements EmergencyService {
  EmergencyPage Function(String? status, int page)? onList;
  final List<String?> statuses = <String?>[];
  final List<int> pages = <int>[];

  @override
  Future<EmergencyPage> list({String? status, int page = 1}) async {
    statuses.add(status);
    pages.add(page);
    final handler = onList;
    if (handler != null) {
      return handler(status, page);
    }
    return const EmergencyPage(<EmergencyCase>[]);
  }

  @override
  Future<EmergencyCase> create(Map<String, dynamic> payload) async =>
      throw UnimplementedError();
}

EmergencyCase _case({
  int id = 1,
  int patient = 7,
  String severity = 'CRITICAL',
  String status = 'OPEN',
}) =>
    EmergencyCase(
      id: id,
      patient: patient,
      severity: severity,
      status: status,
      symptoms: 'Dolor peitu',
      createdAt: DateTime(2026, 1, 2),
    );

Widget _wrap(EmergencyService service) => MaterialApp(
      theme: AppTheme.light,
      home: EmergencyListScreen(emergencyService: service),
    );

void main() {
  testWidgets('renders a case with severity and status badges',
      (tester) async {
    final service = _FakeEmergencies()
      ..onList = (_, _) => EmergencyPage(<EmergencyCase>[_case()]);
    await tester.pumpWidget(_wrap(service));
    await tester.pumpAndSettle();

    expect(find.text('CRITICAL'), findsOneWidget);
    expect(find.text('OPEN'), findsWidgets);
    expect(find.text('${AppStrings.patientLabel} #7'), findsOneWidget);
    expect(find.text('Dolor peitu'), findsOneWidget);
  });

  testWidgets('shows the empty state', (tester) async {
    final service = _FakeEmergencies();
    await tester.pumpWidget(_wrap(service));
    await tester.pumpAndSettle();

    expect(find.text(AppStrings.emergenciesEmpty), findsOneWidget);
    expect(find.text(AppStrings.emergenciesEmptyHint), findsOneWidget);
  });

  testWidgets('status filter reloads with the status param', (tester) async {
    final service = _FakeEmergencies();
    await tester.pumpWidget(_wrap(service));
    await tester.pumpAndSettle();

    expect(service.statuses, <String?>[null]);

    await tester.tap(find.widgetWithText(ChoiceChip, 'ESCALATED'));
    await tester.pumpAndSettle();

    expect(service.statuses.last, 'ESCALATED');
    expect(service.pages.last, 1);
  });

  testWidgets('shows retry on error and reloads', (tester) async {
    final service = _FakeEmergencies();
    var fail = true;
    service.onList = (status, page) {
      if (fail) {
        throw const NetworkException('offline');
      }
      return EmergencyPage(<EmergencyCase>[_case()]);
    };
    await tester.pumpWidget(_wrap(service));
    await tester.pumpAndSettle();

    expect(find.text(AppStrings.retry), findsOneWidget);

    fail = false;
    await tester.tap(find.text(AppStrings.retry));
    await tester.pumpAndSettle();

    expect(find.text('CRITICAL'), findsOneWidget);
  });
}