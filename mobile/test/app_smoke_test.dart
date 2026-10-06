import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:saude_konekta/app.dart';
import 'package:saude_konekta/core/api/token_store.dart';
import 'package:saude_konekta/core/l10n/app_strings.dart';
import 'package:saude_konekta/core/sync/app_database.dart';
import 'package:saude_konekta/core/sync/connectivity_service.dart';

void main() {
  testWidgets('app gates to login screen without a session',
      (tester) async {
    await tester.pumpWidget(SaudeKonektaApp(
      tokenStore: MemoryTokenStore(),
      database: AppDatabase.memory(),
      connectivityService: const AlwaysOnlineConnectivity(),
    ));
    await tester.pumpAndSettle();

    expect(find.text(AppStrings.appName), findsWidgets);
    expect(find.byType(FilledButton), findsOneWidget);
    expect(find.widgetWithText(FilledButton, AppStrings.login), findsOneWidget);
    expect(find.text(AppStrings.username), findsOneWidget);
  });

  testWidgets('app opens the shell when a session exists', (tester) async {
    final store = MemoryTokenStore();
    await store.saveTokens(access: 'a', refresh: 'r');
    await tester.pumpWidget(SaudeKonektaApp(
      tokenStore: store,
      database: AppDatabase.memory(),
      connectivityService: const AlwaysOnlineConnectivity(),
    ));
    await tester.pumpAndSettle();

    expect(find.byType(NavigationBar), findsOneWidget);
    expect(find.text(AppStrings.tabOverview), findsWidgets);
    expect(find.widgetWithText(FilledButton, AppStrings.login), findsNothing);
  });
}