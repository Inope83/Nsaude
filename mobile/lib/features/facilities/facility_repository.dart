import 'package:dio/dio.dart';

import '../../core/api/api_client.dart';
import '../../core/l10n/app_strings.dart';
import '../auth/auth_repository.dart';

class Facility {
  const Facility({
    required this.id,
    required this.name,
    this.facilityType,
    this.address,
    this.municipality,
    this.sucoName,
    this.isActive = true,
  });

  final int id;
  final String name;
  final String? facilityType;
  final String? address;
  final String? municipality;
  final String? sucoName;
  final bool isActive;

  String get subtitle {
    final parts = <String>[
      ?municipality,
      ?sucoName,
    ];
    return parts.join(' · ');
  }

  factory Facility.fromJson(Map<String, dynamic> json) => Facility(
        id: json['id'] as int,
        name: json['name'] as String? ?? '',
        facilityType: json['facility_type'] as String?,
        address: json['address'] as String?,
        municipality: json['municipality'] as String?,
        sucoName: json['suco_name'] as String?,
        isActive: json['is_active'] as bool? ?? true,
      );
}

abstract class FacilityService {
  Future<List<Facility>> list();
}

class FacilityRepository implements FacilityService {
  FacilityRepository(this.client);

  final ApiClient client;

  static const String _path = '/api/facilities/';

  @override
  Future<List<Facility>> list() async {
    try {
      final response = await client.dio.get<dynamic>(_path);
      final data = response.data;
      if (data is! Map<String, dynamic>) {
        throw const NetworkException(AppStrings.connectionError);
      }
      final results = data['results'];
      if (results is! List<dynamic>) {
        return <Facility>[];
      }
      return results
          .whereType<Map<String, dynamic>>()
          .map(Facility.fromJson)
          .toList(growable: false);
    } on DioException catch (e) {
      final error = e.error;
      if (error is AuthExpiredException) {
        throw error;
      }
      throw const NetworkException(AppStrings.connectionError);
    }
  }
}