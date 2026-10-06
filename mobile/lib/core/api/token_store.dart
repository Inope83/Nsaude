import 'package:flutter_secure_storage/flutter_secure_storage.dart';

const String _accessTokenKey = 'access_token';
const String _refreshTokenKey = 'refresh_token';

abstract class TokenStore {
  Future<void> saveTokens({required String access, required String refresh});
  Future<String?> readAccess();
  Future<String?> readRefresh();
  Future<void> clear();
}

class SecureTokenStore implements TokenStore {
  SecureTokenStore({FlutterSecureStorage? storage})
      : _storage = storage ?? const FlutterSecureStorage();

  final FlutterSecureStorage _storage;

  @override
  Future<void> saveTokens({
    required String access,
    required String refresh,
  }) async {
    await _storage.write(key: _accessTokenKey, value: access);
    await _storage.write(key: _refreshTokenKey, value: refresh);
  }

  @override
  Future<String?> readAccess() => _storage.read(key: _accessTokenKey);

  @override
  Future<String?> readRefresh() => _storage.read(key: _refreshTokenKey);

  @override
  Future<void> clear() async {
    await _storage.delete(key: _accessTokenKey);
    await _storage.delete(key: _refreshTokenKey);
  }
}

class MemoryTokenStore implements TokenStore {
  final Map<String, String> _values = <String, String>{};

  @override
  Future<void> saveTokens({
    required String access,
    required String refresh,
  }) async {
    _values[_accessTokenKey] = access;
    _values[_refreshTokenKey] = refresh;
  }

  @override
  Future<String?> readAccess() async => _values[_accessTokenKey];

  @override
  Future<String?> readRefresh() async => _values[_refreshTokenKey];

  @override
  Future<void> clear() async {
    _values.clear();
  }
}
