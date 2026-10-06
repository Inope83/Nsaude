import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:saude_konekta/core/api/api_client.dart';
import 'package:saude_konekta/core/api/token_store.dart';
import 'package:saude_konekta/core/l10n/app_strings.dart';
import 'package:saude_konekta/features/auth/auth_repository.dart';

typedef _AdapterHandler = Future<ResponseBody> Function(RequestOptions options);

class _RecordedRequest {
  _RecordedRequest(RequestOptions options)
      : path = options.path,
        headers = Map<String, dynamic>.of(options.headers),
        data = options.data;

  final String path;
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

const Map<String, dynamic> profileJson = <String, dynamic>{
  'id': 7,
  'username': 'maria',
  'role': 'DOCTOR',
  'facility': 3,
  'first_name': 'Maria',
  'last_name': 'Silva',
};

void main() {
  late MemoryTokenStore tokenStore;
  late _FakeAdapter adapter;

  ApiClient buildClient(_AdapterHandler handler) {
    adapter = _FakeAdapter(handler);
    final dio = Dio()..httpClientAdapter = adapter;
    return ApiClient(tokenStore: tokenStore, dio: dio);
  }

  setUp(() {
    tokenStore = MemoryTokenStore();
  });

  group('login', () {
    test('stores tokens and loads profile with bearer header', () async {
      final client = buildClient((options) async {
        if (options.path.endsWith('/auth/login/')) {
          return jsonResponse(<String, dynamic>{
            'access': 'access-1',
            'refresh': 'refresh-1',
          });
        }
        if (options.path.endsWith('/auth/me/')) {
          return jsonResponse(profileJson);
        }
        throw StateError('unexpected path ${options.path}');
      });
      final repository = AuthRepository(client: client, tokenStore: tokenStore);

      final profile = await repository.login('maria', 'secret');

      expect(profile.id, 7);
      expect(profile.username, 'maria');
      expect(profile.role, 'DOCTOR');
      expect(profile.facility, 3);
      expect(profile.firstName, 'Maria');
      expect(profile.lastName, 'Silva');
      expect(repository.currentProfile?.username, 'maria');
      expect(await tokenStore.readAccess(), 'access-1');
      expect(await tokenStore.readRefresh(), 'refresh-1');

      final meRequest =
          adapter.requests.singleWhere((r) => r.path.endsWith('/auth/me/'));
      expect(meRequest.headers['authorization'], 'Bearer access-1');

      final loginRequest =
          adapter.requests.singleWhere((r) => r.path.endsWith('/auth/login/'));
      expect(loginRequest.headers.containsKey('authorization'), isFalse);
      expect(loginRequest.data, <String, dynamic>{
        'username': 'maria',
        'password': 'secret',
      });
    });

    test('401 throws AuthFailedException with Tetum message', () async {
      final client = buildClient((options) async =>
          jsonResponse(<String, dynamic>{'detail': 'nope'}, statusCode: 401));
      final repository = AuthRepository(client: client, tokenStore: tokenStore);

      await expectLater(
        repository.login('maria', 'wrong'),
        throwsA(
          isA<AuthFailedException>().having(
            (e) => e.message,
            'message',
            AppStrings.invalidCredentials,
          ),
        ),
      );
      expect(await tokenStore.readAccess(), isNull);
      expect(adapter.requests, hasLength(1));
    });

    test('transport failure throws NetworkException', () async {
      final client = buildClient((options) async {
        throw Exception('connection refused');
      });
      final repository = AuthRepository(client: client, tokenStore: tokenStore);

      await expectLater(
        repository.login('maria', 'secret'),
        throwsA(
          isA<NetworkException>().having(
            (e) => e.message,
            'message',
            AppStrings.connectionError,
          ),
        ),
      );
      expect(await tokenStore.readAccess(), isNull);
    });
  });

  group('hasSession', () {
    test('is true only when an access token is stored', () async {
      final client = buildClient((options) async => jsonResponse(<String, dynamic>{}));
      final repository = AuthRepository(client: client, tokenStore: tokenStore);

      expect(await repository.hasSession(), isFalse);
      await tokenStore.saveTokens(access: 'a', refresh: 'r');
      expect(await repository.hasSession(), isTrue);
    });
  });

  group('logout', () {
    test('clears the token store and profile', () async {
      final client = buildClient((options) async => jsonResponse(<String, dynamic>{}));
      final repository = AuthRepository(client: client, tokenStore: tokenStore);
      await tokenStore.saveTokens(access: 'a', refresh: 'r');

      await repository.logout();

      expect(await tokenStore.readAccess(), isNull);
      expect(await tokenStore.readRefresh(), isNull);
      expect(repository.currentProfile, isNull);
    });
  });

  group('token refresh', () {
    test('401 on auth/me refreshes once and retries with new token', () async {
      var meCalls = 0;
      final client = buildClient((options) async {
        if (options.path.endsWith('/auth/login/')) {
          return jsonResponse(<String, dynamic>{
            'access': 'access-1',
            'refresh': 'refresh-1',
          });
        }
        if (options.path.endsWith('/api/auth/refresh/')) {
          return jsonResponse(<String, dynamic>{
            'access': 'access-2',
            'refresh': 'refresh-2',
          });
        }
        if (options.path.endsWith('/auth/me/')) {
          meCalls++;
          if (meCalls == 1) {
            return jsonResponse(<String, dynamic>{'detail': 'expired'},
                statusCode: 401);
          }
          return jsonResponse(profileJson);
        }
        throw StateError('unexpected path ${options.path}');
      });
      final repository = AuthRepository(client: client, tokenStore: tokenStore);
      await tokenStore.saveTokens(access: 'access-1', refresh: 'refresh-1');

      final profile = await repository.login('maria', 'secret');

      expect(profile.username, 'maria');
      expect(await tokenStore.readAccess(), 'access-2');
      expect(await tokenStore.readRefresh(), 'refresh-2');
      expect(
        adapter.requests
            .where((r) => r.path.endsWith('/api/auth/refresh/'))
            .toList(),
        hasLength(1),
      );
      final meRequests =
          adapter.requests.where((r) => r.path.endsWith('/auth/me/')).toList();
      expect(meRequests, hasLength(2));
      expect(meRequests.first.headers['authorization'], 'Bearer access-1');
      expect(meRequests.last.headers['authorization'], 'Bearer access-2');
    });

    test('failed refresh clears tokens and throws AuthExpiredException',
        () async {
      var meCalls = 0;
      final client = buildClient((options) async {
        if (options.path.endsWith('/auth/login/')) {
          return jsonResponse(<String, dynamic>{
            'access': 'access-1',
            'refresh': 'refresh-1',
          });
        }
        if (options.path.endsWith('/api/auth/refresh/')) {
          return jsonResponse(<String, dynamic>{'detail': 'invalid'},
              statusCode: 400);
        }
        if (options.path.endsWith('/auth/me/')) {
          meCalls++;
          if (meCalls == 1) {
            return jsonResponse(<String, dynamic>{'detail': 'expired'},
                statusCode: 401);
          }
          return jsonResponse(profileJson);
        }
        throw StateError('unexpected path ${options.path}');
      });
      final repository = AuthRepository(client: client, tokenStore: tokenStore);
      await tokenStore.saveTokens(access: 'access-1', refresh: 'refresh-1');

      await expectLater(
        repository.login('maria', 'secret'),
        throwsA(isA<AuthExpiredException>()),
      );
      expect(await tokenStore.readAccess(), isNull);
      expect(await tokenStore.readRefresh(), isNull);
    });
  });
}
