import 'package:flutter_test/flutter_test.dart';
import 'package:saude_konekta/core/sync/app_database.dart';
import 'package:saude_konekta/core/sync/sync_store.dart';

void main() {
  late AppDatabase db;

  setUp(() {
    db = AppDatabase.memory();
  });

  tearDown(() async {
    await db.close();
  });

  Future<QueuedEntry> enqueue() => db.enqueue(
        clientUuid: 'uuid-1',
        entityType: 'patients',
        method: 'POST',
        path: '/api/patients/',
        payload: <String, dynamic>{'first_name': 'Ana'},
      );

  test('enqueue stores a pending operation', () async {
    final entry = await enqueue();
    expect(entry.status, SyncStatus.pending);
    expect(entry.attempts, 0);
    final pending = await db.pending();
    expect(pending, hasLength(1));
    expect(pending.single.payload['first_name'], 'Ana');
  });

  test('markSynced clears pending and records last synced', () async {
    final entry = await enqueue();
    await db.markSynced(entry.id, serverId: 7);
    expect(await db.pendingCount(), 0);
    final stored = await db.entry(entry.id);
    expect(stored!.status, SyncStatus.synced);
    expect(stored.serverId, 7);
    expect(await db.lastSyncedAt(), isNotNull);
  });

  test('markFailed increments attempts and retryFailed resets them', () async {
    final entry = await enqueue();
    await db.markFailed(entry.id, 'boom');
    expect(await db.failedCount(), 1);
    final failed = await db.entry(entry.id);
    expect(failed!.attempts, 1);
    expect(failed.error, 'boom');
    expect(failed.lastAttempt, isNotNull);

    await db.retryFailed();
    expect(await db.failedCount(), 0);
    expect(await db.pendingCount(), 1);
    final retried = await db.entry(entry.id);
    expect(retried!.attempts, 0);
    expect(retried.lastAttempt, isNull);
  });

  test('deleteEntry removes an operation', () async {
    final entry = await enqueue();
    await db.deleteEntry(entry.id);
    expect(await db.pendingCount(), 0);
    expect(await db.entry(entry.id), isNull);
  });

  test('cache round trip upserts by server id', () async {
    await db.cacheUpsert('patients', 5, <String, dynamic>{'id': 5, 'n': 'Ana'});
    expect(await db.cachedOne('patients', 5), isNotNull);
    expect(await db.cachedList('patients'), hasLength(1));
    await db.cacheUpsert('patients', 5, <String, dynamic>{'id': 5, 'n': 'Bea'});
    expect((await db.cachedList('patients')).single['n'], 'Bea');
  });
}