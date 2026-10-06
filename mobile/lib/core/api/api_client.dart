import 'package:dio/dio.dart';

import '../config/app_config.dart';
import 'token_store.dart';

class AuthExpiredException implements Exception {
  const AuthExpiredException([this.message = 'Session expired.']);

  final String message;

  @override
  String toString() => message;
}

class ApiClient {
  ApiClient({required TokenStore tokenStore, Dio? dio})
      : dio = _create(tokenStore, dio ?? Dio());

  final Dio dio;

  static Dio _create(TokenStore tokenStore, Dio instance) {
    instance.options
      ..baseUrl = AppConfig.baseUrl
      ..connectTimeout = const Duration(seconds: 15)
      ..receiveTimeout = const Duration(seconds: 20)
      ..responseType = ResponseType.json
      ..headers[Headers.contentTypeHeader] = Headers.jsonContentType;
    instance.interceptors.add(_AuthInterceptor(tokenStore: tokenStore, dio: instance));
    return instance;
  }
}

class _AuthInterceptor extends Interceptor {
  _AuthInterceptor({required this.tokenStore, required this.dio});

  final TokenStore tokenStore;
  final Dio dio;

  static const String _authorizationHeader = 'authorization';
  static const String _retriedKey = 'auth_retried';
  static const String _refreshPath = '/api/auth/refresh/';
  static const String _loginPathSuffix = '/auth/login/';
  static const String _refreshPathSuffix = '/auth/refresh/';

  Future<String?>? _pendingRefresh;

  @override
  Future<void> onRequest(
    RequestOptions options,
    RequestInterceptorHandler handler,
  ) async {
    final access = await tokenStore.readAccess();
    if (access != null && access.isNotEmpty) {
      options.headers[_authorizationHeader] = 'Bearer $access';
    }
    handler.next(options);
  }

  @override
  Future<void> onError(
    DioException err,
    ErrorInterceptorHandler handler,
  ) async {
    if (!_shouldRefresh(err)) {
      handler.next(err);
      return;
    }
    final access = await _refreshAccess();
    if (access == null) {
      await tokenStore.clear();
      handler.reject(
        DioException(
          requestOptions: err.requestOptions,
          response: err.response,
          type: err.type,
          error: const AuthExpiredException(),
        ),
      );
      return;
    }
    final options = err.requestOptions;
    options.extra[_retriedKey] = true;
    options.headers[_authorizationHeader] = 'Bearer $access';
    try {
      final response = await dio.fetch<dynamic>(options);
      handler.resolve(response);
    } on DioException catch (e) {
      handler.next(e);
    }
  }

  bool _shouldRefresh(DioException err) {
    if (err.response?.statusCode != 401) {
      return false;
    }
    final options = err.requestOptions;
    if (options.extra[_retriedKey] == true) {
      return false;
    }
    final path = options.path;
    return !path.endsWith(_loginPathSuffix) &&
        !path.endsWith(_refreshPathSuffix);
  }

  Future<String?> _refreshAccess() {
    return _pendingRefresh ??= _refresh().whenComplete(() {
      _pendingRefresh = null;
    });
  }

  Future<String?> _refresh() async {
    try {
      final refresh = await tokenStore.readRefresh();
      if (refresh == null || refresh.isEmpty) {
        return null;
      }
      final response = await dio.post<Map<String, dynamic>>(
        _refreshPath,
        data: <String, dynamic>{'refresh': refresh},
      );
      final body = response.data;
      final access = body?['access'];
      if (access is! String || access.isEmpty) {
        return null;
      }
      final nextRefresh = body?['refresh'];
      await tokenStore.saveTokens(
        access: access,
        refresh: nextRefresh is String && nextRefresh.isNotEmpty
            ? nextRefresh
            : refresh,
      );
      return access;
    } catch (_) {
      return null;
    }
  }
}
