import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:saude_konekta/core/api/api_client.dart';
import 'package:saude_konekta/core/api/token_store.dart';
import 'package:saude_konekta/core/l10n/app_strings.dart';
import 'package:saude_konekta/features/auth/auth_repository.dart';
import 'package:saude_konekta/features/patients/models/patient.dart';
import 'package:saude_konekta/features/patients/patient_repository.dart';

typedef _AdapterHandler = Future<ResponseBody> Function(RequestOptions options);

class _RecordedRequest {
  _RecordedRequest(RequestOptions options)
      : path = options.path,
        queryParameters = Map<String, dynamic>.of(options.queryParameters),
        headers = Map<String, dynamic>.of(options.headers),
        data = options.data;

  final String path;
  final Map<String, dynamic> queryParameters;
  final Map<String, dynamic> headers;
  final dynamic data;
}

class _FakeAdapter implements HttpClientAdapter {
  _FakeAdapter(this.handler);

  final _AdapterHandler handler;
  final List<_RecordedRequest> requests = <_RecordedRequest>[];

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) {
    requests.add(_RecordedRequest(options));
    return handler(options);
  }

  @override
  void close({bool force = false}) {}
}

ResponseBody jsonResponse(Object? body, {int statusCode = 200}) {
  return ResponseBody.fromString(
    jsonEncode(body),
    statusCode,
    headers: <String, List<String>>{
      Headers.contentTypeHeader: <String>[Headers.jsonContentType],
    },
  );
}

const Map<String, dynamic> listEnvelope = <String, dynamic>{
  'count': 2,
  'next': 'http://testserver/api/patients/?page=2',
  'previous': null,
  'results': <Map<String, dynamic>>[
    <String, dynamic>{
      'id': 11,
      'client_uuid': null,
      'patient_id': 'PT-AAAAAA',
      'first_name': 'Ana',
      'last_name': 'Costa',
      'date_of_birth': '1990-05-04',
      'sex': 'F',
      'suco': 3,
      'suco_name': 'Comoro',
      'is_active': true,
      'created_at': '2025-03-01T09:00:00Z',
      'updated_at': '2025-04-01T09:00:00Z',
    },
    <String, dynamic>{
      'id': 12,
      'client_uuid': null,
      'patient_id': 'PT-BBBBBB',
      'first_name': 'Bruno',
      'last_name': 'Ximenes',
      'date_of_birth': null,
      'sex': 'M',
      'suco': 4,
      'suco_name': 'Lata',
      'is_active': false,
      'created_at': '2025-03-02T09:00:00Z',
      'updated_at': '2025-04-02T09:00:00Z',
    },
  ],
};

const Map<String, dynamic> detailJson = <String, dynamic>{
  'id': 11,
  'client_uuid': null,
  'patient_id': 'PT-AAAAAA',
  'first_name': 'Ana',
  'last_name': 'Costa',
  'date_of_birth': '1990-05-04',
  'sex': 'F',
  'suco': 3,
  'suco_name': 'Comoro',
  'is_active': true,
  'created_at': '2025-03-01T09:00:00Z',
  'updated_at': '2025-04-01T09:00:00Z',
  'phone': '772111111',
  'address': 'Rua X',
  'emergency_contact': 'Fulano 772333444',
};

const Map<String, dynamic> monitoringEnvelope = <String, dynamic>{
  'count': 1,
  'next': null,
  'previous': null,
  'results': <Map<String, dynamic>>[
    <String, dynamic>{
      'id': 5,
      'client_uuid': null,
      'patient': 11,
      'recorded_by': 'hw',
      'recorded_at': '2026-01-05T10:30:00Z',
      'temperature': 36.6,
      'heart_rate': 72,
      'respiratory_rate': 16,
      'blood_pressure_systolic': 120,
      'blood_pressure_diastolic': 80,
      'oxygen_saturation': 98,
      'symptoms': 'Tuse',
      'notes': 'Leve liu',
      'created_at': '2026-01-05T10:31:00Z',
    },
  ],
};

void main() {
  late MemoryTokenStore tokenStore;
  late _FakeAdapter adapter;

  PatientRepository buildRepository(_AdapterHandler handler) {
    adapter = _FakeAdapter(handler);
    final dio = Dio()..httpClientAdapter = adapter;
    final client = ApiClient(tokenStore: tokenStore, dio: dio);
    return PatientRepository(client);
  }

  setUp(() {
    tokenStore = MemoryTokenStore();
  });

  group('search', () {
    test('parses the paginated envelope and sends the q param', () async {
      final repository = buildRepository((options) async {
        expect(options.path, '/api/patients/');
        expect(options.queryParameters['q'], 'Bruno');
        expect(options.queryParameters['page'], 1);
        return jsonResponse(listEnvelope);
      });

      final page = await repository.search(q: 'Bruno');

      expect(page.results, hasLength(2));
      expect(page.next, 'http://testserver/api/patients/?page=2');

      final first = page.results.first;
      expect(first.id, 11);
      expect(first.patientId, 'PT-AAAAAA');
      expect(first.fullName, 'Ana Costa');
      expect(first.sex, 'F');
      expect(first.sexLabel, AppStrings.female);
      expect(first.ageGroup, PatientLabels.age18To64);
      expect(first.sucoName, 'Comoro');
      expect(first.isActive, isTrue);
      expect(first.dateOfBirth, DateTime(1990, 5, 4));

      final second = page.results[1];
      expect(second.patientId, 'PT-BBBBBB');
      expect(second.sexLabel, AppStrings.male);
      expect(second.ageGroup, PatientLabels.ageUnknown);
      expect(second.isActive, isFalse);
      expect(first, isNot(isA<PatientDetail>()));
    });

    test('omits q when the term is blank and keeps the page param', () async {
      final repository = buildRepository((options) async {
        expect(options.queryParameters.containsKey('q'), isFalse);
        expect(options.queryParameters['page'], 2);
        return jsonResponse(listEnvelope);
      });

      final page = await repository.search(q: '   ', page: 2);

      expect(page.results, hasLength(2));
      expect(adapter.requests.single.path, '/api/patients/');
    });

    test('transport failure throws NetworkException', () async {
      final repository = buildRepository((options) async {
        throw Exception('connection refused');
      });

      await expectLater(
        repository.search(),
        throwsA(
          isA<NetworkException>().having(
            (e) => e.message,
            'message',
            AppStrings.connectionError,
          ),
        ),
      );
    });
  });

  group('detail', () {
    test('maps contact fields from the detail payload', () async {
      final repository = buildRepository((options) async {
        expect(options.path, '/api/patients/11/');
        return jsonResponse(detailJson);
      });

      final detail = await repository.detail(11);

      expect(detail.id, 11);
      expect(detail.patientId, 'PT-AAAAAA');
      expect(detail.fullName, 'Ana Costa');
      expect(detail.phone, '772111111');
      expect(detail.address, 'Rua X');
      expect(detail.emergencyContact, 'Fulano 772333444');
      expect(detail.sucoName, 'Comoro');
      expect(detail.isActive, isTrue);
      expect(detail.ageGroup, PatientLabels.age18To64);
    });
  });

  group('monitoring', () {
    test('parses the paginated record list', () async {
      final repository = buildRepository((options) async {
        expect(options.path, '/api/patients/11/monitoring/');
        expect(options.queryParameters.containsKey('q'), isFalse);
        return jsonResponse(monitoringEnvelope);
      });

      final records = await repository.monitoring(11);

      expect(records, hasLength(1));
      final record = records.single;
      expect(record.id, 5);
      expect(record.patient, 11);
      expect(record.recordedBy, 'hw');
      expect(record.recordedAt, isNotNull);
      expect(record.temperature, 36.6);
      expect(record.heartRate, 72);
      expect(record.respiratoryRate, 16);
      expect(record.bloodPressureSystolic, 120);
      expect(record.bloodPressureDiastolic, 80);
      expect(record.oxygenSaturation, 98);
      expect(record.symptoms, 'Tuse');
      expect(record.notes, 'Leve liu');
    });

    test('missing vitals parse as null', () async {
      final repository = buildRepository((options) async => jsonResponse(
        <String, dynamic>{
          'count': 1,
          'next': null,
          'previous': null,
          'results': <Map<String, dynamic>>[
            <String, dynamic>{
              'id': 6,
              'client_uuid': null,
              'patient': 11,
              'recorded_by': null,
              'recorded_at': '2026-01-06T10:30:00Z',
              'temperature': null,
              'heart_rate': null,
              'respiratory_rate': null,
              'blood_pressure_systolic': null,
              'blood_pressure_diastolic': null,
              'oxygen_saturation': null,
              'symptoms': '',
              'notes': '',
              'created_at': '2026-01-06T10:31:00Z',
            },
          ],
        },
      ));

      final record = (await repository.monitoring(11)).single;

      expect(record.recordedBy, isNull);
      expect(record.temperature, isNull);
      expect(record.heartRate, isNull);
      expect(record.symptoms, isNull);
      expect(record.notes, isNull);
    });
  });

  group('errors', () {
    test('4xx throws ApiException with status and DRF body', () async {
      final repository = buildRepository(
        (options) async => jsonResponse(
          <String, dynamic>{'sex': <String>['This field is required.']},
          statusCode: 400,
        ),
      );

      await expectLater(
        repository.search(),
        throwsA(
          isA<ApiException>()
              .having((e) => e.status, 'status', 400)
              .having(
                (e) => e.body?['sex'],
                'body',
                <String>['This field is required.'],
              ),
        ),
      );
    });

    test('404 throws ApiException with the detail body', () async {
      final repository = buildRepository(
        (options) async => jsonResponse(
          <String, dynamic>{'detail': 'No Patient matches the given query.'},
          statusCode: 404,
        ),
      );

      await expectLater(
        repository.detail(99),
        throwsA(
          isA<ApiException>()
              .having((e) => e.status, 'status', 404)
              .having(
                (e) => e.message,
                'message',
                'No Patient matches the given query.',
              ),
        ),
      );
    });
  });
}
