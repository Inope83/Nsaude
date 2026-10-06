import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:saude_konekta/core/api/api_client.dart';
import 'package:saude_konekta/core/api/token_store.dart';
import 'package:saude_konekta/features/auth/auth_repository.dart';
import 'package:saude_konekta/features/emergencies/emergency_repository.dart';
import 'package:saude_konekta/features/patients/patient_repository.dart';

import 'support/fake_http.dart';

void main() {
  late MemoryTokenStore tokenStore;
  late FakeAdapter adapter;

  EmergencyRepository buildRepository(AdapterHandler handler) {
    adapter = FakeAdapter(handler);
    final dio = Dio()..httpClientAdapter = adapter;
    final client = ApiClient(tokenStore: tokenStore, dio: dio);
    return EmergencyRepository(client);
  }

  setUp(() {
    tokenStore = MemoryTokenStore();
  });

  const envelope = <String, dynamic>{
    'count': 1,
    'next': null,
    'previous': null,
    'results': <Map<String, dynamic>>[
      <String, dynamic>{
        'id': 5,
        'client_uuid': null,
        'patient': 7,
        'created_by': 'hw',
        'facility': 2,
        'severity': 'CRITICAL',
        'symptoms': 'Chest pain',
        'description': 'Sudden onset',
        'status': 'OPEN',
        'created_at': '2026-01-01T10:00:00Z',
        'updated_at': '2026-01-01T10:05:00Z',
      },
    ],
  };

  test('list parses the DRF envelope', () async {
    final repository = buildRepository((options) async {
      expect(options.path, '/api/emergencies/');
      expect(options.queryParameters['page'], 1);
      expect(options.queryParameters.containsKey('status'), isFalse);
      return jsonResponse(envelope);
    });

    final page = await repository.list();

    expect(page.results, hasLength(1));
    final emergency = page.results.single;
    expect(emergency.id, 5);
    expect(emergency.patient, 7);
    expect(emergency.severity, 'CRITICAL');
    expect(emergency.status, 'OPEN');
    expect(emergency.symptoms, 'Chest pain');
    expect(emergency.createdBy, 'hw');
    expect(emergency.createdAt, isNotNull);
  });

  test('list sends the status filter', () async {
    final repository = buildRepository((options) async {
      expect(options.queryParameters['status'], 'ESCALATED');
      return jsonResponse(const <String, dynamic>{
        'count': 0,
        'next': null,
        'previous': null,
        'results': <Map<String, dynamic>>[],
      });
    });

    final page = await repository.list(status: 'ESCALATED');

    expect(page.results, isEmpty);
  });

  test('create posts the payload and parses the case', () async {
    final repository = buildRepository((options) async {
      expect(options.path, '/api/emergencies/');
      expect(options.method, 'POST');
      expect(
        options.data,
        <String, dynamic>{
          'client_uuid': 'uuid-1',
          'patient': 5,
          'severity': 'HIGH',
          'symptoms': 'Fever',
        },
      );
      return jsonResponse(
        <String, dynamic>{
          'id': 9,
          'client_uuid': 'uuid-1',
          'patient': 5,
          'created_by': 'hw',
          'facility': 1,
          'severity': 'HIGH',
          'symptoms': 'Fever',
          'description': '',
          'status': 'OPEN',
          'created_at': '2026-01-01T00:00:00Z',
          'updated_at': '2026-01-01T00:00:00Z',
        },
        statusCode: 201,
      );
    });

    final created = await repository.create(<String, dynamic>{
      'client_uuid': 'uuid-1',
      'patient': 5,
      'severity': 'HIGH',
      'symptoms': 'Fever',
    });

    expect(created.id, 9);
    expect(created.severity, 'HIGH');
    expect(created.status, 'OPEN');
  });

  test('4xx throws ApiException', () async {
    final repository = buildRepository(
      (options) async => jsonResponse(
        <String, dynamic>{
          'symptoms': <String>['This field is required.'],
        },
        statusCode: 400,
      ),
    );

    await expectLater(
      repository.create(<String, dynamic>{}),
      throwsA(
        isA<ApiException>().having((e) => e.status, 'status', 400),
      ),
    );
  });

  test('transport failure throws NetworkException', () async {
    final repository = buildRepository((options) async {
      throw Exception('offline');
    });

    await expectLater(
      repository.list(),
      throwsA(isA<NetworkException>()),
    );
  });
}