import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:saude_konekta/core/api/api_client.dart';
import 'package:saude_konekta/core/api/token_store.dart';
import 'package:saude_konekta/core/sync/app_database.dart';
import 'package:saude_konekta/core/sync/sync_engine.dart';
import 'package:saude_konekta/features/patients/patient_repository.dart';

import 'support/fake_connectivity.dart';
import 'support/fake_http.dart';

Map<String, dynamic> patientJson(int id, String name) => <String, dynamic>{
      'id': id,
      'client_uuid': 'c$id',
      'patient_id': 'PT-00000$id',
      'first_name': name,
      'last_name': 'Silva',
      'date_of_birth': '1990-05-01',
      'sex': 'F',
      'suco': 4,
      'suco_name': 'Bairo',
      'is_active': true,
      'created_at': '2026-01-01T00:00:00Z',
      'updated_at': '2026-01-01T00:00:00Z',
      'phone': '',
      'address': '',
      'emergency_contact': '',
      'administrative_post': '',
      'municipality': '',
    };

void main() {
  late AppDatabase db;
  late FakeAdapter adapter;
  late FakeConnectivityService connectivity;
  late PatientRepository repository;

  DioException offlineError() => DioException(
        requestOptions: RequestOptions(path: '/api/patients/'),
        type: DioExceptionType.connectionError,
      );

  PatientRepository buildRepository(AdapterHandler handler,
      {bool online = true}) {
    adapter = FakeAdapter(handler);
    connectivity = FakeConnectivityService(initialOnline: online);
    final dio = Dio()..httpClientAdapter = adapter;
    final client = ApiClient(tokenStore: MemoryTokenStore(), dio: dio);
    final engine = SyncEngine(
      store: db,
      client: client,
      connectivity: connectivity,
    );
    return PatientRepository(client, syncEngine: engine);
  }

  setUp(() {
    db = AppDatabase.memory();
  });

  tearDown(() async {
    await connectivity.dispose();
    await db.close();
  });

  test('search falls back to the cache when the network fails', () async {
    await db.cacheUpsert('patients', 1, patientJson(1, 'Ana'));
    repository = buildRepository((options) async => throw offlineError());

    final page = await repository.search();
    expect(page.results, hasLength(1));
    expect(page.results.single.firstName, 'Ana');
    expect(page.count, 1);
  });

  test('search caches successful rows for later offline use', () async {
    repository = buildRepository((options) async {
      return jsonResponse(<String, dynamic>{
        'count': 1,
        'next': null,
        'previous': null,
        'results': <Map<String, dynamic>>[patientJson(8, 'Bea')],
      });
    });
    await repository.search();

    final cached = await db.cachedOne('patients', 8);
    expect(cached!['first_name'], 'Bea');
  });

  test('createPatient queues offline and returns an optimistic record',
      () async {
    repository = buildRepository(
      (options) async => jsonResponse(<String, dynamic>{'id': 99}),
      online: false,
    );
    final patient = await repository.createPatient(<String, dynamic>{
      'first_name': 'Nina',
      'last_name': 'Costa',
      'sex': 'F',
      'suco': 2,
      'client_uuid': 'local-1',
    });

    expect(patient.id, 0);
    expect(patient.firstName, 'Nina');
    expect(await db.pendingCount(), 1);
    expect(adapter.requests, isEmpty);
  });

  test('createPatient caches the server record when online', () async {
    repository = buildRepository((options) async {
      return jsonResponse(patientJson(21, 'Lia'), statusCode: 201);
    });
    final patient = await repository.createPatient(<String, dynamic>{
      'first_name': 'Lia',
      'last_name': 'Silva',
      'sex': 'F',
      'suco': 2,
      'client_uuid': 'local-2',
    });

    expect(patient.id, 21);
    expect(await db.pendingCount(), 0);
    expect(await db.cachedOne('patients', 21), isNotNull);
  });
}