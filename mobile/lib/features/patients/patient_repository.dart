import 'package:dio/dio.dart';

import '../../core/api/api_client.dart';
import '../../core/api/api_exception.dart';
import '../../core/l10n/app_strings.dart';
import '../../core/sync/sync_engine.dart';
import '../auth/auth_repository.dart';
import 'models/patient.dart';

export '../../core/api/api_exception.dart';

String patientErrorMessage(Object error) {
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

abstract class PatientService {
  Future<PatientPage> search({String? q, int page = 1});
  Future<PatientDetail> detail(int id);
  Future<List<MonitoringRecord>> monitoring(int patientId);
  Future<PatientDetail> createPatient(Map<String, dynamic> payload);
  Future<MonitoringRecord> createMonitoring(
    int patientId,
    Map<String, dynamic> payload,
  );
}

class PatientRepository implements PatientService {
  PatientRepository(this.client, {this.syncEngine});

  final ApiClient client;
  final SyncEngine? syncEngine;

  static const String _path = '/api/patients/';
  static const String _patientsEntity = 'patients';
  static const String _monitoringEntity = 'monitoring';

  @override
  Future<PatientPage> search({String? q, int page = 1}) async {
    final queryParameters = <String, dynamic>{'page': page};
    final term = q?.trim();
    if (term != null && term.isNotEmpty) {
      queryParameters['q'] = term;
    }
    try {
      final data = await _get(_path, queryParameters);
      final rows = _maps(data['results']);
      await _cacheAll(_patientsEntity, rows);
      return PatientPage(
        _rows<Patient>(data['results'], Patient.fromJson),
        data['next'] as String?,
        (data['count'] as num?)?.toInt() ?? 0,
      );
    } catch (error) {
      final cached = await _cached(_patientsEntity);
      if (cached.isEmpty) {
        rethrow;
      }
      return PatientPage(
        cached.map(Patient.fromJson).toList(growable: false),
        null,
        cached.length,
      );
    }
  }

  @override
  Future<PatientDetail> detail(int id) async {
    try {
      final data = await _get('$_path$id/');
      await syncEngine?.store.cacheUpsert(_patientsEntity, id, data);
      return PatientDetail.fromJson(data);
    } catch (error) {
      final cached = await syncEngine?.store.cachedOne(_patientsEntity, id);
      if (cached == null) {
        rethrow;
      }
      return PatientDetail.fromJson(cached);
    }
  }

  @override
  Future<List<MonitoringRecord>> monitoring(int patientId) async {
    final entity = '$_monitoringEntity:$patientId';
    try {
      final data = await _get('$_path$patientId/monitoring/');
      await _cacheAll(entity, _maps(data['results']));
      return _rows<MonitoringRecord>(data['results'], MonitoringRecord.fromJson);
    } catch (error) {
      final cached = await _cached(entity);
      if (cached.isEmpty) {
        rethrow;
      }
      return cached.map(MonitoringRecord.fromJson).toList(growable: false);
    }
  }

  @override
  Future<PatientDetail> createPatient(Map<String, dynamic> payload) async {
    final engine = syncEngine;
    if (engine == null) {
      final data = await _post(_path, payload);
      return PatientDetail.fromJson(data);
    }
    final outcome = await engine.submit(
      entityType: _patientsEntity,
      path: _path,
      payload: payload,
    );
    final rejection = outcome.rejection;
    if (rejection != null) {
      throw rejection;
    }
    final serverData = outcome.serverData;
    if (serverData != null) {
      final id = serverData['id'];
      if (id is num) {
        await engine.store.cacheUpsert(_patientsEntity, id.toInt(), serverData);
      }
      return PatientDetail.fromJson(serverData);
    }
    return PatientDetail.fromJson(<String, dynamic>{...payload, 'id': 0});
  }

  @override
  Future<MonitoringRecord> createMonitoring(
    int patientId,
    Map<String, dynamic> payload,
  ) async {
    final path = '$_path$patientId/monitoring/';
    final engine = syncEngine;
    if (engine == null) {
      final data = await _post(path, payload);
      return MonitoringRecord.fromJson(data);
    }
    final entity = '$_monitoringEntity:$patientId';
    final outcome = await engine.submit(
      entityType: entity,
      path: path,
      payload: payload,
    );
    final rejection = outcome.rejection;
    if (rejection != null) {
      throw rejection;
    }
    final serverData = outcome.serverData;
    if (serverData != null) {
      final id = serverData['id'];
      if (id is num) {
        await engine.store.cacheUpsert(entity, id.toInt(), serverData);
      }
      return MonitoringRecord.fromJson(serverData);
    }
    return MonitoringRecord.fromJson(
      <String, dynamic>{...payload, 'id': 0, 'patient': patientId},
    );
  }

  Future<void> _cacheAll(String entity, List<Map<String, dynamic>> rows) async {
    final store = syncEngine?.store;
    if (store == null) {
      return;
    }
    for (final row in rows) {
      final id = row['id'];
      if (id is num) {
        await store.cacheUpsert(entity, id.toInt(), row);
      }
    }
  }

  Future<List<Map<String, dynamic>>> _cached(String entity) async {
    final store = syncEngine?.store;
    if (store == null) {
      return const <Map<String, dynamic>>[];
    }
    return store.cachedList(entity);
  }

  List<Map<String, dynamic>> _maps(Object? results) {
    if (results is! List<dynamic>) {
      return const <Map<String, dynamic>>[];
    }
    return results.whereType<Map<String, dynamic>>().toList(growable: false);
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
