import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:saude_konekta/core/api/api_client.dart';
import 'package:saude_konekta/core/api/token_store.dart';
import 'package:saude_konekta/core/l10n/app_strings.dart';
import 'package:saude_konekta/core/sync/app_database.dart';
import 'package:saude_konekta/core/sync/sync_engine.dart';
import 'package:saude_konekta/features/sync/sync_status_screen.dart';

import 'support/fake_connectivity.dart';
import 'support/fake_http.dart';

void main() {
  late AppDatabase db;
  late FakeConnectivityService connectivity;
  late FakeAdapter adapter;
  late SyncEngine engine;

  setUp(() {
    db = AppDatabase.memory();
    connectivity = FakeConnectivityService();
    adapter = FakeAdapter((options) async {
      if (options.path.endsWith('/heartbeat/')) {
        return jsonResponse(<String, dynamic>{'id': 1});
      }
      return jsonResponse(<String, dynamic>{'id': 1}, statusCode: 201);
    });
    final dio = Dio()..httpClientAdapter = adapter;
    final client = ApiClient(tokenStore: MemoryTokenStore(), dio: dio);
    engine = SyncEngine(
      store: db,
      client: client,
      connectivity: connectivity,
    );
  });

  tearDown(() async {
    await connectivity.dispose();
    await db.close();
  });

  Future<void> pump(WidgetTester tester) async {
    await tester.pumpWidget(MaterialApp(
      home: SyncStatusScreen(syncEngine: engine, connectivity: connectivity),
    ));
    await tester.pumpAndSettle();
  }

  testWidgets('shows connectivity, counts and last synced', (tester) async {
    await db.enqueue(
      clientUuid: 'c1',
      entityType: 'patients',
      method: 'POST',
      path: '/api/patients/',
      payload: <String, dynamic>{},
    );
    final failed = await db.enqueue(
      clientUuid: 'c2',
      entityType: 'patients',
      method: 'POST',
      path: '/api/patients/',
      payload: <String, dynamic>{},
    );
    await db.markFailed(failed.id, 'boom');

    await pump(tester);

    expect(find.text('ONLINE'), findsOneWidget);
    expect(find.text('PENDING SYNC'), findsOneWidget);
    expect(find.text('SYNC FAILED'), findsOneWidget);
    expect(find.textContaining(AppStrings.syncNeverLabel), findsOneWidget);
    expect(find.text(AppStrings.syncNow), findsOneWidget);
    expect(find.text(AppStrings.syncRetryFailed), findsOneWidget);
  });

  testWidgets('manual sync drains the queue and reports completion',
      (tester) async {
    await db.enqueue(
      clientUuid: 'c1',
      entityType: 'patients',
      method: 'POST',
      path: '/api/patients/',
      payload: <String, dynamic>{},
    );
    await pump(tester);

    await tester.tap(find.text(AppStrings.syncNow));
    await tester.pumpAndSettle();

    expect(find.text(AppStrings.syncComplete), findsOneWidget);
    expect(await db.pendingCount(), 0);
  });

  testWidgets('offline notice when there is no connection', (tester) async {
    connectivity.emit(false);
    await pump(tester);

    expect(find.text('OFFLINE'), findsOneWidget);
    await tester.tap(find.text(AppStrings.syncNow));
    await tester.pumpAndSettle();
    expect(find.text(AppStrings.syncOfflineNotice), findsOneWidget);
  });
}