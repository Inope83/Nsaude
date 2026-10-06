import 'package:dio/dio.dart';

import '../../core/api/api_client.dart';
import '../../core/l10n/app_strings.dart';
import '../auth/auth_repository.dart';
import '../patients/patient_repository.dart';

class GeoItem {
  const GeoItem({required this.id, required this.name, required this.code});

  final int id;
  final String name;
  final String code;

  @override
  bool operator ==(Object other) =>
      other is GeoItem && other.id == id && other.name == name && other.code == code;

  @override
  int get hashCode => Object.hash(id, name, code);

  @override
  String toString() => 'GeoItem($id, $name, $code)';
}

abstract class GeographyService {
  Future<List<GeoItem>> municipalities();
  Future<List<GeoItem>> postsFor(String municipalityCode);
  Future<List<GeoItem>> sucosFor(String administrativePostCode);
}

class GeographyRepository implements GeographyService {
  GeographyRepository(this.client);

  final ApiClient client;

  @override
  Future<List<GeoItem>> municipalities() => _get('/api/municipalities/');

  @override
  Future<List<GeoItem>> postsFor(String municipalityCode) =>
      _get('/api/administrative-posts/', {'municipality': municipalityCode});

  @override
  Future<List<GeoItem>> sucosFor(String administrativePostCode) =>
      _get('/api/sucos/', {'administrative_post': administrativePostCode});

  Future<List<GeoItem>> _get(
    String path, [
    Map<String, dynamic>? queryParameters,
  ]) async {
    try {
      final response = await client.dio.get<dynamic>(
        path,
        queryParameters: queryParameters,
      );
      final data = response.data;
      final results = data is Map<String, dynamic> ? data['results'] : data;
      if (results is! List<dynamic>) {
        throw const NetworkException(AppStrings.connectionError);
      }
      return results
          .whereType<Map<String, dynamic>>()
          .map(
            (json) => GeoItem(
              id: json['id'] as int,
              name: json['name'] as String? ?? '',
              code: json['code'] as String? ?? '',
            ),
          )
          .toList(growable: false);
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
}
