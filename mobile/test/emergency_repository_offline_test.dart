import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:saude_konekta/core/api/api_client.dart';
import 'package:saude_konekta/core/api/token_store.dart';
import 'package:saude_konekta/core/sync/app_database.dart';
import 'package:saude_konekta/core/sync/sync_engine.dart';
import 'package:saude_konekta/features/emergencies/emergency_repository.dart';

import 'support/fake_connectivity.dart';
import 'support/fake_http.dart';

void main() {
  late AppDatabase db;
  late FakeConnectivityService connectivity;
  late EmergencyRepository repository;

  DioException offlineError() => DioException(
        requestOptions: RequestOptions(path: '/api/emergencies/'),
        type: DioExceptionType.connectionError,
      );

  EmergencyRepository buildRepository(AdapterHandler handler,
      {bool online = true}) {
    connectivity = FakeConnectivityService(initialOnline: online);
    final dio = Dio()..httpClientAdapter = FakeAdapter(handler);
    final client = ApiClient(tokenStore: MemoryTokenStore(), dio: dio);
    final engine = SyncEngine(
      store: db,
      client: client,
      connectivity: connectivity,
    );
    return EmergencyRepository(client, syncEngine: engine);
  }

  setUp(() {
    db = AppDatabase.memory();
  });

  tearDown(() async {
    await connectivity.dispose();
    await db.close();
  });

  test('list falls back to the cache when the network fails', () async {
    await db.cacheUpsert('emergencies', 3, <String, dynamic>{
      'id': 3,
      'client_uuid': 'c3',
      'patient': 7,
      'severity': 'HIGH',
      'status': 'OPEN',
      'symptoms': 'fever',
      'description': '',
      'created_at': '2026-01-01T00:00:00Z',
      'updated_at': '2026-01-01T00:00:00Z',
    });
    repository = buildRepository((options) async => throw offlineError());

    final page = await repository.list();
    expect(page.results, hasLength(1));
    expect(page.results.single.severity, 'HIGH');
  });

  test('create queues offline and returns an optimistic case', () async {
    repository = buildRepository(
      (options) async => jsonResponse(<String, dynamic>{'id': 1}),
      online: false,
    );
    final created = await repository.create(<String, dynamic>{
      'patient': 5,
      'severity': 'CRITICAL',
      'symptoms': 'bleeding',
      'client_uuid': 'local-1',
    });

    expect(created.id, 0);
    expect(created.status, 'OPEN');
    expect(await db.pendingCount(), 1);
  });
}