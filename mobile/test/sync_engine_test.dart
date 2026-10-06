import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:saude_konekta/core/api/api_client.dart';
import 'package:saude_konekta/core/api/token_store.dart';
import 'package:saude_konekta/core/sync/app_database.dart';
import 'package:saude_konekta/core/sync/sync_engine.dart';

import 'support/fake_connectivity.dart';
import 'support/fake_http.dart';

void main() {
  late AppDatabase db;
  late FakeAdapter adapter;
  late FakeConnectivityService connectivity;
  late SyncEngine engine;

  SyncEngine buildEngine(AdapterHandler handler, {bool online = true}) {
    adapter = FakeAdapter(handler);
    connectivity = FakeConnectivityService(initialOnline: online);
    final dio = Dio()..httpClientAdapter = adapter;
    final client = ApiClient(tokenStore: MemoryTokenStore(), dio: dio);
    return SyncEngine(
      store: db,
      client: client,
      connectivity: connectivity,
      baseBackoff: const Duration(seconds: 5),
    );
  }

  setUp(() {
    db = AppDatabase.memory();
  });

  tearDown(() async {
    await connectivity.dispose();
    await db.close();
  });

  test('submit pushes an online operation and caches the server id', () async {
    engine = buildEngine((options) async {
      return jsonResponse(<String, dynamic>{'id': 42}, statusCode: 201);
    });
    final outcome = await engine.submit(
      entityType: 'patients',
      path: '/api/patients/',
      payload: <String, dynamic>{'client_uuid': 'c1', 'first_name': 'Ana'},
    );
    expect(outcome.serverData?['id'], 42);
    expect(await db.pendingCount(), 0);
    expect(await db.pending(), isEmpty);
    expect(adapter.requests.single.path, '/api/patients/');
  });

  test('submit surfaces a 4xx rejection and drops the operation', () async {
    engine = buildEngine((options) async {
      return jsonResponse(
        <String, dynamic>{
          'first_name': <String>['This field is required.'],
        },
        statusCode: 400,
      );
    });
    final outcome = await engine.submit(
      entityType: 'patients',
      path: '/api/patients/',
      payload: <String, dynamic>{'client_uuid': 'c1'},
    );
    expect(outcome.rejection, isNotNull);
    expect(outcome.serverData, isNull);
    expect(await db.pendingCount(), 0);
    expect(await db.pending(), isEmpty);
  });

  test('submit queues while offline without touching the network', () async {
    engine = buildEngine(
      (options) async => jsonResponse(<String, dynamic>{'id': 1}),
      online: false,
    );
    final outcome = await engine.submit(
      entityType: 'patients',
      path: '/api/patients/',
      payload: <String, dynamic>{'client_uuid': 'c1'},
    );
    expect(outcome.queued, isTrue);
    expect(await db.pendingCount(), 1);
    expect(adapter.requests, isEmpty);
  });

  test('sync drains the queue and pings the heartbeat', () async {
    engine = buildEngine((options) async {
      if (options.path.endsWith('/heartbeat/')) {
        return jsonResponse(<String, dynamic>{'id': 1});
      }
      return jsonResponse(<String, dynamic>{'id': 9});
    });
    await db.enqueue(
      clientUuid: 'a',
      entityType: 'patients',
      method: 'POST',
      path: '/api/patients/',
      payload: <String, dynamic>{},
    );
    await db.enqueue(
      clientUuid: 'b',
      entityType: 'emergencies',
      method: 'POST',
      path: '/api/emergencies/',
      payload: <String, dynamic>{},
    );
    final result = await engine.sync();
    expect(result.synced, 2);
    expect(result.remaining, 0);
    expect(
      adapter.requests.any((r) => r.path.endsWith('/heartbeat/')),
      isTrue,
    );
  });

  int patientPosts() =>
      adapter.requests.where((r) => r.path == '/api/patients/').length;

  test('backoff defers a failed operation until retryFailed', () async {
    engine = buildEngine((options) async {
      if (options.path.endsWith('/heartbeat/')) {
        return jsonResponse(<String, dynamic>{'id': 1});
      }
      return jsonResponse(<String, dynamic>{'error': 'boom'}, statusCode: 500);
    });
    await db.enqueue(
      clientUuid: 'a',
      entityType: 'patients',
      method: 'POST',
      path: '/api/patients/',
      payload: <String, dynamic>{},
    );
    final first = await engine.sync();
    expect(first.failed, 1);
    expect(await db.failedCount(), 1);
    expect(patientPosts(), 1);

    final second = await engine.sync();
    expect(second.failed, 0);
    expect(patientPosts(), 1);

    await db.retryFailed();
    final third = await engine.sync();
    expect(third.failed, 1);
    expect(patientPosts(), 2);
  });
}