import 'dart:async';

import 'package:saude_konekta/core/sync/connectivity_service.dart';

class FakeConnectivityService implements ConnectivityService {
FakeConnectivityService({bool initialOnline = true})
      : _online = initialOnline;

  final StreamController<bool> _controller =
      StreamController<bool>.broadcast();
  bool _online;

  set online(bool value) {
    _online = value;
    _controller.add(value);
  }

  void emit(bool value) {
    _online = value;
    _controller.add(value);
  }

  @override
  Future<bool> isOnline() async => _online;

  @override
  Stream<bool> get onStatusChanged => _controller.stream;

  Future<void> dispose() => _controller.close();
}