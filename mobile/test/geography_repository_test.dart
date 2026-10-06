import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:saude_konekta/core/api/api_client.dart';
import 'package:saude_konekta/core/api/token_store.dart';
import 'package:saude_konekta/features/auth/auth_repository.dart';
import 'package:saude_konekta/features/geography/geography_repository.dart';
import 'package:saude_konekta/features/patients/patient_repository.dart';

import 'support/fake_http.dart';

void main() {
  late MemoryTokenStore tokenStore;
  late FakeAdapter adapter;

  GeographyRepository buildRepository(AdapterHandler handler) {
    adapter = FakeAdapter(handler);
    final dio = Dio()..httpClientAdapter = adapter;
    final client = ApiClient(tokenStore: tokenStore, dio: dio);
    return GeographyRepository(client);
  }

  setUp(() {
    tokenStore = MemoryTokenStore();
  });

  const envelope = <String, dynamic>{
    'count': 2,
    'next': null,
    'previous': null,
    'results': <Map<String, dynamic>>[
      <String, dynamic>{'id': 1, 'name': 'Dili', 'code': 'dili'},
      <String, dynamic>{'id': 2, 'name': 'Manufahi', 'code': 'mfh'},
    ],
  };

  test('municipalities parses the DRF envelope', () async {
    final repository = buildRepository((options) async {
      expect(options.path, '/api/municipalities/');
      return jsonResponse(envelope);
    });

    final items = await repository.municipalities();

    expect(items, hasLength(2));
    expect(items.first.id, 1);
    expect(items.first.name, 'Dili');
    expect(items.first.code, 'dili');
    expect(items.last.name, 'Manufahi');
  });

  test('postsFor sends the municipality code', () async {
    final repository = buildRepository((options) async {
      expect(options.path, '/api/administrative-posts/');
      expect(options.queryParameters['municipality'], 'dili');
      return jsonResponse(envelope);
    });

    final items = await repository.postsFor('dili');

    expect(items, hasLength(2));
  });

  test('sucosFor sends the administrative post code', () async {
    final repository = buildRepository((options) async {
      expect(options.path, '/api/sucos/');
      expect(options.queryParameters['administrative_post'], 'da');
      return jsonResponse(envelope);
    });

    final items = await repository.sucosFor('da');

    expect(items, hasLength(2));
  });

  test('4xx throws ApiException', () async {
    final repository = buildRepository(
      (options) async => jsonResponse(
        <String, dynamic>{'detail': 'Bad request.'},
        statusCode: 400,
      ),
    );

    await expectLater(
      repository.municipalities(),
      throwsA(isA<ApiException>().having((e) => e.status, 'status', 400)),
    );
  });

  test('transport failure throws NetworkException', () async {
    final repository = buildRepository((options) async {
      throw Exception('connection refused');
    });

    await expectLater(
      repository.municipalities(),
      throwsA(isA<NetworkException>()),
    );
  });
}
