import 'package:connectivity_plus/connectivity_plus.dart';

abstract class ConnectivityService {
  Future<bool> isOnline();

  Stream<bool> get onStatusChanged;
}

class ConnectivityPlusService implements ConnectivityService {
  ConnectivityPlusService([Connectivity? connectivity])
      : _connectivity = connectivity ?? Connectivity();

  final Connectivity _connectivity;

  @override
  Future<bool> isOnline() async {
    return _isOnline(await _connectivity.checkConnectivity());
  }

  @override
  Stream<bool> get onStatusChanged =>
      _connectivity.onConnectivityChanged.map(_isOnline).distinct();

  bool _isOnline(List<ConnectivityResult> results) =>
      results.any((result) => result != ConnectivityResult.none);
}

class AlwaysOnlineConnectivity implements ConnectivityService {
  const AlwaysOnlineConnectivity();

  @override
  Future<bool> isOnline() async => true;

  @override
  Stream<bool> get onStatusChanged => const Stream<bool>.empty();
}