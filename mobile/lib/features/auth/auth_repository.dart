import 'package:dio/dio.dart';

import '../../core/api/api_client.dart';
import '../../core/api/token_store.dart';
import '../../core/l10n/app_strings.dart';
import 'user_profile.dart';

class AuthFailedException implements Exception {
  const AuthFailedException(this.message);

  final String message;

  @override
  String toString() => message;
}

class NetworkException implements Exception {
  const NetworkException(this.message);

  final String message;

  @override
  String toString() => message;
}

abstract class AuthService {
  Future<UserProfile> login(String username, String password);
  Future<bool> hasSession();
  Future<void> logout();
  UserProfile? get currentProfile;
}

class AuthRepository implements AuthService {
  AuthRepository({required this.client, required this.tokenStore});

  final ApiClient client;
  final TokenStore tokenStore;

  @override
  UserProfile? currentProfile;

  @override
  Future<UserProfile> login(String username, String password) async {
    final Map<String, dynamic> body;
    try {
      final response = await client.dio.post<dynamic>(
        '/auth/login/',
        data: <String, dynamic>{'username': username, 'password': password},
      );
      final data = response.data;
      if (data is! Map<String, dynamic> ||
          data['access'] is! String ||
          data['refresh'] is! String) {
        throw const NetworkException(AppStrings.connectionError);
      }
      body = data;
    } on DioException catch (e) {
      if (e.response?.statusCode == 401) {
        throw const AuthFailedException(AppStrings.invalidCredentials);
      }
      throw const NetworkException(AppStrings.connectionError);
    }
    await tokenStore.saveTokens(
      access: body['access'] as String,
      refresh: body['refresh'] as String,
    );
    final profile = await _fetchProfile();
    currentProfile = profile;
    return profile;
  }

  @override
  Future<bool> hasSession() async {
    final access = await tokenStore.readAccess();
    return access != null && access.isNotEmpty;
  }

  @override
  Future<void> logout() async {
    currentProfile = null;
    await tokenStore.clear();
  }

  Future<UserProfile> _fetchProfile() async {
    try {
      final response = await client.dio.get<dynamic>('/auth/me/');
      final data = response.data;
      if (data is! Map<String, dynamic>) {
        throw const NetworkException(AppStrings.connectionError);
      }
      return UserProfile.fromJson(data);
    } on DioException catch (e) {
      final error = e.error;
      if (error is AuthExpiredException) {
        throw error;
      }
      throw const NetworkException(AppStrings.connectionError);
    }
  }
}
