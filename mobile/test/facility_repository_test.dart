import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:saude_konekta/core/api/api_client.dart';
import 'package:saude_konekta/core/api/token_store.dart';
import 'package:saude_konekta/features/auth/auth_repository.dart';
import 'package:saude_konekta/features/facilities/facility_repository.dart';

import 'support/fake_http.dart';

void main() {
  late MemoryTokenStore tokenStore;
  late FakeAdapter adapter;

  FacilityRepository buildRepository(AdapterHandler handler) {
    adapter = FakeAdapter(handler);
    final dio = Dio()..httpClientAdapter = adapter;
    final client = ApiClient(tokenStore: tokenStore, dio: dio);
    return FacilityRepository(client);
  }

  setUp(() {
    tokenStore = MemoryTokenStore();
  });

  test('list parses the DRF envelope', () async {
    final repository = buildRepository((options) async {
      expect(options.path, '/api/facilities/');
      return jsonResponse(<String, dynamic>{
        'count': 2,
        'next': null,
        'previous': null,
        'results': <Map<String, dynamic>>[
          <String, dynamic>{
            'id': 1,
            'name': 'CS Comoro',
            'facility_type': 'CHC',
            'municipality': 'Dili',
            'suco_name': 'Comoro',
            'is_active': true,
          },
          <String, dynamic>{
            'id': 2,
            'name': 'Hospital Nacional',
            'facility_type': 'HOSPITAL',
            'municipality': 'Dili',
            'suco_name': 'Bidau',
            'is_active': true,
          },
        ],
      });
    });

    final facilities = await repository.list();

    expect(facilities, hasLength(2));
    expect(facilities.first.id, 1);
    expect(facilities.first.name, 'CS Comoro');
    expect(facilities.first.subtitle, 'Dili · Comoro');
    expect(facilities.last.name, 'Hospital Nacional');
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