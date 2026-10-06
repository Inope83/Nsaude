import 'dart:math';

import 'package:dio/dio.dart';

import '../../features/auth/auth_repository.dart';
import '../api/api_client.dart';
import '../api/api_exception.dart';
import '../l10n/app_strings.dart';
import 'connectivity_service.dart';
import 'sync_store.dart';

class SyncOutcome {
  const SyncOutcome.synced(this.serverData)
      : queued = false,
        rejection = null;
  const SyncOutcome.queued()
      : serverData = null,
        queued = true,
        rejection = null;
  const SyncOutcome.rejected(this.rejection)
      : serverData = null,
        queued = false;

  final Map<String, dynamic>? serverData;
  final bool queued;
  final ApiException? rejection;
}

class SyncResult {
  const SyncResult({
    required this.synced,
    required this.failed,
    required this.remaining,
  });

  final int synced;
  final int failed;
  final int remaining;
}

class SyncEngine {
  SyncEngine({
    required this.store,
    required this.client,
    required this.connectivity,
    this.heartbeatPath = '/api/sync/heartbeat/',
    this.baseBackoff = const Duration(seconds: 5),
    this.maxBackoff = const Duration(minutes: 10),
  });

  final SyncStore store;
  final ApiClient client;
  final ConnectivityService connectivity;
  final String heartbeatPath;
  final Duration baseBackoff;
  final Duration maxBackoff;

  /// Local-first submit: persist the operation, then try to push it if online.
  Future<SyncOutcome> submit({
    required String entityType,
    required String path,
    required Map<String, dynamic> payload,
    String method = 'POST',
  }) async {
    final clientUuid = payload['client_uuid'] as String? ?? _fallbackUuid();
    final entry = await store.enqueue(
      clientUuid: clientUuid,
      entityType: entityType,
      method: method,
      path: path,
      payload: payload,
    );
    if (!await connectivity.isOnline()) {
      return const SyncOutcome.queued();
    }
    try {
      final data = await _send(entry);
      final serverId = data['id'];
      await store.markSynced(
        entry.id,
        serverId: serverId is num ? serverId.toInt() : null,
      );
      return SyncOutcome.synced(data);
    } on ApiException catch (error) {
      await store.deleteEntry(entry.id);
      return SyncOutcome.rejected(error);
    } on AuthExpiredException {
      return const SyncOutcome.queued();
    } on NetworkException {
      return const SyncOutcome.queued();
    }
  }

  /// Pushes every PENDING operation, honouring per-entry backoff.
  Future<SyncResult> sync() async {
    if (!await connectivity.isOnline()) {
      return SyncResult(
        synced: 0,
        failed: 0,
        remaining: await store.pendingCount(),
      );
    }
    var synced = 0;
    var failed = 0;
    final entries = await store.pending();
    for (final entry in entries) {
      if (!_due(entry)) {
        continue;
      }
      await store.markSyncing(entry.id);
      try {
        final data = await _send(entry);
        final serverId = data['id'];
        await store.markSynced(
          entry.id,
          serverId: serverId is num ? serverId.toInt() : null,
        );
        synced += 1;
      } on ApiException catch (e) {
        await store.markFailed(entry.id, e.message);
        failed += 1;
      } on AuthExpiredException {
        await store.markFailed(entry.id, AppStrings.connectionError);
        failed += 1;
      } on NetworkException {
        await store.markFailed(entry.id, AppStrings.connectionError);
        failed += 1;
      } catch (_) {
        await store.markFailed(entry.id, AppStrings.genericError);
        failed += 1;
      }
    }
    final result = SyncResult(
      synced: synced,
      failed: failed,
      remaining: await store.pendingCount() + await store.failedCount(),
    );
    await _heartbeat();
    return result;
  }

  Future<void> _heartbeat() async {
    try {
      await client.dio.post<dynamic>(heartbeatPath, data: <String, dynamic>{
        'pending_count': await store.pendingCount(),
      });
    } catch (_) {
      // Heartbeat is best-effort telemetry.
    }
  }

  Duration _backoff(int attempts) {
    final seconds = baseBackoff.inSeconds * pow(2, attempts).toInt();
    return Duration(
      seconds: min(seconds, maxBackoff.inSeconds),
    );
  }

  bool _due(QueuedEntry entry) {
    final last = entry.lastAttempt;
    if (last == null) {
      return true;
    }
    return DateTime.now().isAfter(last.add(_backoff(entry.attempts)));
  }

  Future<Map<String, dynamic>> _send(QueuedEntry entry) async {
    try {
      final response = await client.dio.request<dynamic>(
        entry.path,
        data: entry.payload,
        options: Options(method: entry.method),
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

  String _fallbackUuid() =>
      '${DateTime.now().microsecondsSinceEpoch}-${Random().nextInt(1 << 32)}';
}