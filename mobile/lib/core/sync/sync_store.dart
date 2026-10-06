enum SyncStatus { pending, syncing, synced, failed }

class QueuedEntry {
  const QueuedEntry({
    required this.id,
    required this.clientUuid,
    required this.entityType,
    required this.method,
    required this.path,
    required this.payload,
    required this.status,
    required this.attempts,
    required this.createdAt,
    required this.updatedAt,
    this.lastAttempt,
    this.error,
    this.serverId,
  });

  final int id;
  final String clientUuid;
  final String entityType;
  final String method;
  final String path;
  final Map<String, dynamic> payload;
  final SyncStatus status;
  final int attempts;
  final DateTime? lastAttempt;
  final String? error;
  final int? serverId;
  final DateTime createdAt;
  final DateTime updatedAt;
}

abstract class SyncStore {
  Future<QueuedEntry> enqueue({
    required String clientUuid,
    required String entityType,
    required String method,
    required String path,
    required Map<String, dynamic> payload,
  });

  Future<List<QueuedEntry>> pending({int limit = 25});

  Future<QueuedEntry?> entry(int id);

  Future<void> markSyncing(int id);

  Future<void> markSynced(int id, {int? serverId});

  Future<void> markFailed(int id, String error);

  Future<void> deleteEntry(int id);

  Future<void> retryFailed();

  Future<int> pendingCount();

  Future<int> failedCount();

  Future<DateTime?> lastSyncedAt();

  Future<void> setLastSyncedAt(DateTime value);

  Future<void> cacheUpsert(
    String entityType,
    int serverId,
    Map<String, dynamic> json,
  );

  Future<List<Map<String, dynamic>>> cachedList(String entityType);

  Future<Map<String, dynamic>?> cachedOne(String entityType, int serverId);
}