import 'package:dio/dio.dart';

import '../../core/api/api_client.dart';
import '../../core/l10n/app_strings.dart';
import '../../core/sync/sync_engine.dart';
import '../auth/auth_repository.dart';
import '../patients/patient_repository.dart';
import 'models/emergency_case.dart';

String emergencyErrorMessage(Object error) {
  if (error is NetworkException) {
    return error.message;
  }
  if (error is AuthExpiredException) {
    return error.message;
  }
  if (error is ApiException) {
    return error.message;
  }
  return AppStrings.connectionError;
}

abstract class EmergencyService {
  Future<EmergencyPage> list({String? status, int page = 1});
  Future<EmergencyCase> create(Map<String, dynamic> payload);
}

class EmergencyRepository implements EmergencyService {
  EmergencyRepository(this.client, {this.syncEngine});

  final ApiClient client;
  final SyncEngine? syncEngine;

  static const String _path = '/api/emergencies/';
  static const String _entityType = 'emergencies';

  @override
  Future<EmergencyPage> list({String? status, int page = 1}) async {
    final queryParameters = <String, dynamic>{'page': page};
    if (status != null && status.isNotEmpty) {
      queryParameters['status'] = status;
    }
    try {
      final data = await _get(_path, queryParameters);
      await _cacheResults(_path, data['results']);
      return EmergencyPage(
        _rows<EmergencyCase>(data['results'], EmergencyCase.fromJson),
        data['next'] as String?,
        (data['count'] as num?)?.toInt() ?? 0,
      );
    } on NetworkException {
      final cached = await _cached();
      if (cached.isEmpty) {
        rethrow;
      }
      return EmergencyPage(
        cached.map(EmergencyCase.fromJson).toList(growable: false),
        null,
        cached.length,
      );
    }
  }

  @override
  Future<EmergencyCase> create(Map<String, dynamic> payload) async {
    final engine = syncEngine;
    if (engine == null) {
      final data = await _post(_path, payload);
      return EmergencyCase.fromJson(data);
    }
    final outcome = await engine.submit(
      entityType: _entityType,
      path: _path,
      payload: payload,
    );
    final rejection = outcome.rejection;
    if (rejection != null) {
      throw rejection;
    }
    final serverData = outcome.serverData;
    if (serverData != null) {
      await _cacheOne(serverData);
      return EmergencyCase.fromJson(serverData);
    }
    return EmergencyCase.fromJson(<String, dynamic>{
      ...payload,
      'id': 0,
      'status': payload['status'] ?? 'OPEN',
    });
  }

  Future<void> _cacheResults(String path, Object? results) async {
    final store = syncEngine?.store;
    if (store == null || results is! List<dynamic>) {
      return;
    }
    for (final row in results.whereType<Map<String, dynamic>>()) {
      final id = row['id'];
      if (id is num) {
        await store.cacheUpsert(_entityType, id.toInt(), row);
      }
    }
  }

  Future<void> _cacheOne(Map<String, dynamic> json) async {
    final store = syncEngine?.store;
    final id = json['id'];
    if (store == null || id is! num) {
      return;
    }
    await store.cacheUpsert(_entityType, id.toInt(), json);
  }

  Future<List<Map<String, dynamic>>> _cached() async {
    final store = syncEngine?.store;
    if (store == null) {
      return <Map<String, dynamic>>[];
    }
    return store.cachedList(_entityType);
  }

  Future<Map<String, dynamic>> _post(
    String path,
    Map<String, dynamic> payload,
  ) async {
    try {
      final response = await client.dio.post<dynamic>(path, data: payload);
      final data = response.data;
      if (data is! Map<String, dynamic>) {
        throw const NetworkException(AppStrings.connectionError);
      }
      return data;
    } on DioException catch (e) {
      throw _mapError(e);
    }
  }

  Future<Map<String, dynamic>> _get(
    String path, [
    Map<String, dynamic>? queryParameters,
  ]) async {
    try {
      final response = await client.dio.get<dynamic>(
        path,
        queryParameters: queryParameters,
      );
      final data = response.data;
      if (data is! Map<String, dynamic>) {
        throw const NetworkException(AppStrings.connectionError);
      }
      return data;
    } on DioException catch (e) {
      throw _mapError(e);
    }
  }

  Object _mapError(DioException e) {
    final error = e.error;
    if (error is AuthExpiredException) {
      return error;
    }
    final status = e.response?.statusCode;
    if (status != null && status >= 400 && status < 500) {
      final data = e.response?.data;
      return ApiException(status, data is Map<String, dynamic> ? data : null);
    }
    return const NetworkException(AppStrings.connectionError);
  }

  List<T> _rows<T>(
    Object? results,
    T Function(Map<String, dynamic> json) fromJson,
  ) {
    if (results is! List<dynamic>) {
      return <T>[];
    }
    return results
        .whereType<Map<String, dynamic>>()
        .map(fromJson)
        .toList(growable: false);
  }
}