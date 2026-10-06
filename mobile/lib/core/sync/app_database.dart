import 'dart:convert';

import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:drift_flutter/drift_flutter.dart';

import 'sync_store.dart';

part 'app_database.g.dart';

class SyncQueueEntries extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get clientUuid => text().unique()();
  TextColumn get entityType => text()();
  TextColumn get method => text().withDefault(const Constant('POST'))();
  TextColumn get path => text()();
  TextColumn get payload => text()();
  TextColumn get status => text().withDefault(const Constant('PENDING'))();
  IntColumn get attempts => integer().withDefault(const Constant(0))();
  DateTimeColumn get lastAttempt => dateTime().nullable()();
  TextColumn get error => text().nullable()();
  IntColumn get serverId => integer().nullable()();
  DateTimeColumn get createdAt => dateTime()();
  DateTimeColumn get updatedAt => dateTime()();
}

class CachedRecords extends Table {
  TextColumn get entityType => text()();
  IntColumn get serverId => integer()();
  TextColumn get json => text()();
  DateTimeColumn get updatedAt => dateTime().nullable()();

  @override
  Set<Column> get primaryKey => {entityType, serverId};
}

class SyncMetaEntries extends Table {
  TextColumn get key => text()();
  TextColumn get value => text()();

  @override
  Set<Column> get primaryKey => {key};
}

@DriftDatabase(tables: [SyncQueueEntries, CachedRecords, SyncMetaEntries])
class AppDatabase extends _$AppDatabase implements SyncStore {
  AppDatabase(super.executor);

  AppDatabase.memory() : super(NativeDatabase.memory());

  AppDatabase.file() : super(driftDatabase(name: 'saude_konekta'));

  @override
  int get schemaVersion => 1;

  static const String _lastSyncedKey = 'last_synced_at';

  @override
  Future<QueuedEntry> enqueue({
    required String clientUuid,
    required String entityType,
    required String method,
    required String path,
    required Map<String, dynamic> payload,
  }) async {
    final now = DateTime.now();
    final companion = SyncQueueEntriesCompanion.insert(
      clientUuid: clientUuid,
      entityType: entityType,
      method: Value(method),
      path: path,
      payload: jsonEncode(payload),
      status: const Value('PENDING'),
      createdAt: now,
      updatedAt: now,
    );
    final id = await into(syncQueueEntries).insert(companion);
    return QueuedEntry(
      id: id,
      clientUuid: clientUuid,
      entityType: entityType,
      method: method,
      path: path,
      payload: payload,
      status: SyncStatus.pending,
      attempts: 0,
      createdAt: now,
      updatedAt: now,
    );
  }

  @override
  Future<List<QueuedEntry>> pending({int limit = 25}) async {
    final rows = await (select(syncQueueEntries)
          ..where((t) => t.status.isIn(const <String>['PENDING', 'FAILED']))
          ..orderBy([(t) => OrderingTerm(expression: t.createdAt)])
          ..limit(limit))
        .get();
    return rows.map(_toEntry).toList(growable: false);
  }

  @override
  Future<QueuedEntry?> entry(int id) async {
    final row = await (select(syncQueueEntries)
          ..where((t) => t.id.equals(id)))
        .getSingleOrNull();
    return row == null ? null : _toEntry(row);
  }

  @override
  Future<void> markSyncing(int id) async {
    await (update(syncQueueEntries)..where((t) => t.id.equals(id))).write(
      SyncQueueEntriesCompanion(
        status: const Value('SYNCING'),
        updatedAt: Value(DateTime.now()),
      ),
    );
  }

  @override
  Future<void> markSynced(int id, {int? serverId}) async {
    final now = DateTime.now();
    await (update(syncQueueEntries)..where((t) => t.id.equals(id))).write(
      SyncQueueEntriesCompanion(
        status: const Value('SYNCED'),
        serverId: Value(serverId),
        updatedAt: Value(now),
      ),
    );
    await setLastSyncedAt(now);
  }

  @override
  Future<void> markFailed(int id, String error) async {
    final row = await (select(syncQueueEntries)
          ..where((t) => t.id.equals(id)))
        .getSingleOrNull();
    final attempts = (row?.attempts ?? 0) + 1;
    await (update(syncQueueEntries)..where((t) => t.id.equals(id))).write(
      SyncQueueEntriesCompanion(
        status: const Value('FAILED'),
        attempts: Value(attempts),
        lastAttempt: Value(DateTime.now()),
        error: Value(error),
        updatedAt: Value(DateTime.now()),
      ),
    );
  }

  @override
  Future<int> pendingCount() async {
    final count = syncQueueEntries.id.count();
    final query = selectOnly(syncQueueEntries)
      ..addColumns([count])
      ..where(syncQueueEntries.status.equals('PENDING'));
    final row = await query.getSingle();
    return row.read(count) ?? 0;
  }

  @override
  Future<int> failedCount() async {
    final count = syncQueueEntries.id.count();
    final query = selectOnly(syncQueueEntries)
      ..addColumns([count])
      ..where(syncQueueEntries.status.equals('FAILED'));
    final row = await query.getSingle();
    return row.read(count) ?? 0;
  }

  @override
  Future<void> deleteEntry(int id) async {
    await (delete(syncQueueEntries)..where((t) => t.id.equals(id))).go();
  }

  @override
  Future<void> retryFailed() async {
    await (update(syncQueueEntries)
          ..where((t) => t.status.equals('FAILED')))
        .write(
      SyncQueueEntriesCompanion(
        status: const Value('PENDING'),
        attempts: const Value(0),
        lastAttempt: const Value(null),
        error: const Value(null),
        updatedAt: Value(DateTime.now()),
      ),
    );
  }

  @override
  Future<DateTime?> lastSyncedAt() async {
    final row = await (select(syncMetaEntries)
          ..where((t) => t.key.equals(_lastSyncedKey)))
        .getSingleOrNull();
    if (row == null) return null;
    return DateTime.tryParse(row.value);
  }

  @override
  Future<void> setLastSyncedAt(DateTime value) async {
    await into(syncMetaEntries).insertOnConflictUpdate(
      SyncMetaEntriesCompanion.insert(
        key: _lastSyncedKey,
        value: value.toIso8601String(),
      ),
    );
  }

  @override
  Future<void> cacheUpsert(
    String entityType,
    int serverId,
    Map<String, dynamic> json,
  ) async {
    await into(cachedRecords).insertOnConflictUpdate(
      CachedRecordsCompanion.insert(
        entityType: entityType,
        serverId: serverId,
        json: jsonEncode(json),
        updatedAt: Value(DateTime.now()),
      ),
    );
  }

  @override
  Future<List<Map<String, dynamic>>> cachedList(String entityType) async {
    final rows = await (select(cachedRecords)
          ..where((t) => t.entityType.equals(entityType)))
        .get();
    return rows
        .map((row) => jsonDecode(row.json) as Map<String, dynamic>)
        .toList(growable: false);
  }

  @override
  Future<Map<String, dynamic>?> cachedOne(
    String entityType,
    int serverId,
  ) async {
    final row = await (select(cachedRecords)
          ..where((t) =>
              t.entityType.equals(entityType) & t.serverId.equals(serverId)))
        .getSingleOrNull();
    if (row == null) return null;
    return jsonDecode(row.json) as Map<String, dynamic>;
  }

  QueuedEntry _toEntry(SyncQueueEntry row) => QueuedEntry(
        id: row.id,
        clientUuid: row.clientUuid,
        entityType: row.entityType,
        method: row.method,
        path: row.path,
        payload: jsonDecode(row.payload) as Map<String, dynamic>,
        status: SyncStatus.values.firstWhere(
          (value) => value.name.toUpperCase() == row.status,
          orElse: () => SyncStatus.pending,
        ),
        attempts: row.attempts,
        lastAttempt: row.lastAttempt,
        error: row.error,
        serverId: row.serverId,
        createdAt: row.createdAt,
        updatedAt: row.updatedAt,
      );
}