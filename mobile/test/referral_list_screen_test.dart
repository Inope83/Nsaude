import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:saude_konekta/core/l10n/app_strings.dart';
import 'package:saude_konekta/core/theme/app_theme.dart';
import 'package:saude_konekta/features/auth/auth_repository.dart';
import 'package:saude_konekta/features/referrals/models/referral.dart';
import 'package:saude_konekta/features/referrals/referral_list_screen.dart';
import 'package:saude_konekta/features/referrals/referral_repository.dart';

class _FakeReferrals implements ReferralService {
  ReferralPage Function(String? status, int page)? onList;
  final List<String?> statuses = <String?>[];

  @override
  Future<ReferralPage> list({String? status, int page = 1}) async {
    statuses.add(status);
    final handler = onList;
    if (handler != null) {
      return handler(status, page);
    }
    return const ReferralPage(<Referral>[]);
  }

  @override
  Future<Referral> create(Map<String, dynamic> payload) async =>
      throw UnimplementedError();
}

Referral _referral({
  int id = 1,
  int patient = 8,
  String urgency = 'URGENT',
  String status = 'PENDING',
}) =>
    Referral(
      id: id,
      patient: patient,
      urgency: urgency,
      status: status,
      reason: 'Needs surgery',
      createdAt: DateTime(2026, 1, 3),
    );

Widget _wrap(ReferralService service) => MaterialApp(
      theme: AppTheme.light,
      home: ReferralListScreen(referralService: service),
    );

void main() {
  testWidgets('renders a referral with urgency and status badges',
      (tester) async {
    final service = _FakeReferrals()
      ..onList = (_, _) => ReferralPage(<Referral>[_referral()]);
    await tester.pumpWidget(_wrap(service));
    await tester.pumpAndSettle();

    expect(find.text('URGENT'), findsOneWidget);
    expect(find.text('PENDING'), findsWidgets);
    expect(find.text('${AppStrings.patientLabel} #8'), findsOneWidget);
    expect(find.text('Needs surgery'), findsOneWidget);
  });

  testWidgets('shows the empty state', (tester) async {
    await tester.pumpWidget(_wrap(_FakeReferrals()));
    await tester.pumpAndSettle();

    expect(find.text(AppStrings.referralsEmpty), findsOneWidget);
  });

  testWidgets('status filter reloads with the status param', (tester) async {
    final service = _FakeReferrals();
    await tester.pumpWidget(_wrap(service));
    await tester.pumpAndSettle();

    await tester.tap(find.widgetWithText(ChoiceChip, 'ACCEPTED'));
    await tester.pumpAndSettle();

    expect(service.statuses.last, 'ACCEPTED');
  });

  testWidgets('shows retry on error', (tester) async {
    final service = _FakeReferrals();
    var fail = true;
    service.onList = (status, page) {
      if (fail) {
        throw const NetworkException('offline');
      }
      return ReferralPage(<Referral>[_referral()]);
    };
    await tester.pumpWidget(_wrap(service));
    await tester.pumpAndSettle();

    expect(find.text(AppStrings.retry), findsOneWidget);

    fail = false;
    await tester.tap(find.text(AppStrings.retry));
    await tester.pumpAndSettle();

    expect(find.text('URGENT'), findsOneWidget);
  });
}