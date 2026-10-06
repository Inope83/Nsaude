import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:saude_konekta/core/api/api_client.dart';
import 'package:saude_konekta/core/api/token_store.dart';
import 'package:saude_konekta/features/patients/patient_repository.dart';
import 'package:saude_konekta/features/referrals/referral_repository.dart';

import 'support/fake_http.dart';

void main() {
  late MemoryTokenStore tokenStore;
  late FakeAdapter adapter;

  ReferralRepository buildRepository(AdapterHandler handler) {
    adapter = FakeAdapter(handler);
    final dio = Dio()..httpClientAdapter = adapter;
    final client = ApiClient(tokenStore: tokenStore, dio: dio);
    return ReferralRepository(client);
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
        'id': 3,
        'client_uuid': null,
        'patient': 8,
        'emergency_case': null,
        'referred_by': 'doc',
        'source_facility': 1,
        'destination_facility': 2,
        'reason': 'Needs surgery',
        'urgency': 'URGENT',
        'status': 'PENDING',
        'notes': '',
        'created_at': '2026-01-03T00:00:00Z',
        'updated_at': '2026-01-03T00:00:00Z',
      },
    ],
  };

  test('list parses the envelope and sends the status filter', () async {
    final repository = buildRepository((options) async {
      expect(options.path, '/api/referrals/');
      expect(options.queryParameters['status'], 'PENDING');
      expect(options.queryParameters['page'], 1);
      return jsonResponse(envelope);
    });

    final page = await repository.list(status: 'PENDING');

    expect(page.results, hasLength(1));
    final referral = page.results.single;
    expect(referral.id, 3);
    expect(referral.patient, 8);
    expect(referral.urgency, 'URGENT');
    expect(referral.status, 'PENDING');
    expect(referral.destinationFacility, 2);
    expect(referral.reason, 'Needs surgery');
    expect(referral.notes, isNull);
  });

  test('create posts the payload', () async {
    final repository = buildRepository((options) async {
      expect(options.method, 'POST');
      expect(options.path, '/api/referrals/');
      expect(options.data, <String, dynamic>{
        'client_uuid': 'uuid-2',
        'patient': 8,
        'destination_facility': 2,
        'urgency': 'ROUTINE',
        'reason': 'Follow-up',
      });
      return jsonResponse(
        <String, dynamic>{
          'id': 4,
          'client_uuid': 'uuid-2',
          'patient': 8,
          'emergency_case': null,
          'referred_by': 'doc',
          'source_facility': 1,
          'destination_facility': 2,
          'reason': 'Follow-up',
          'urgency': 'ROUTINE',
          'status': 'PENDING',
          'notes': '',
          'created_at': '2026-01-04T00:00:00Z',
          'updated_at': '2026-01-04T00:00:00Z',
        },
        statusCode: 201,
      );
    });

    final created = await repository.create(<String, dynamic>{
      'client_uuid': 'uuid-2',
      'patient': 8,
      'destination_facility': 2,
      'urgency': 'ROUTINE',
      'reason': 'Follow-up',
    });

    expect(created.id, 4);
    expect(created.status, 'PENDING');
  });

  test('400 on destination same as source throws ApiException', () async {
    final repository = buildRepository(
      (options) async => jsonResponse(
        <String, dynamic>{
          'destination_facility': <String>['Source and destination must differ.'],
        },
        statusCode: 400,
      ),
    );

    await expectLater(
      repository.create(<String, dynamic>{}),
      throwsA(isA<ApiException>()),
    );
  });
}