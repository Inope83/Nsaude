import 'dart:async';

import 'package:flutter/material.dart';

import '../../core/l10n/app_strings.dart';
import '../../core/sync/connectivity_service.dart';
import '../../core/sync/sync_engine.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/theme/app_status.dart';

class SyncStatusScreen extends StatefulWidget {
  const SyncStatusScreen({
    super.key,
    required this.syncEngine,
    required this.connectivity,
  });

  final SyncEngine syncEngine;
  final ConnectivityService connectivity;

  @override
  State<SyncStatusScreen> createState() => _SyncStatusScreenState();
}

class _SyncStatusScreenState extends State<SyncStatusScreen> {
  StreamSubscription<bool>? _subscription;
  bool _online = true;
  bool _busy = false;
  int _pending = 0;
  int _failed = 0;
  DateTime? _lastSynced;

  @override
  void initState() {
    super.initState();
    _refresh();
    _subscription = widget.connectivity.onStatusChanged.listen((online) {
      if (!mounted) return;
      setState(() => _online = online);
      if (online) {
        _runSync();
      }
    });
  }

  @override
  void dispose() {
    _subscription?.cancel();
    super.dispose();
  }

  Future<void> _refresh() async {
    final store = widget.syncEngine.store;
    final online = await widget.connectivity.isOnline();
    final pending = await store.pendingCount();
    final failed = await store.failedCount();
    final lastSynced = await store.lastSyncedAt();
    if (!mounted) return;
    setState(() {
      _online = online;
      _pending = pending;
      _failed = failed;
      _lastSynced = lastSynced;
    });
  }

  Future<void> _runSync() async {
    if (_busy) return;
    setState(() => _busy = true);
    String message;
    if (!await widget.connectivity.isOnline()) {
      message = AppStrings.syncOfflineNotice;
    } else {
      final result = await widget.syncEngine.sync();
      message = result.synced == 0 && result.failed == 0
          ? AppStrings.syncEmpty
          : AppStrings.syncComplete;
    }
    await _refresh();
    if (!mounted) return;
    setState(() => _busy = false);
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _retryFailed() async {
    await widget.syncEngine.store.retryFailed();
    await _refresh();
    await _runSync();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(title: const Text(AppStrings.syncTitle)),
      body: ListView(
        padding: const EdgeInsets.all(AppSpacing.s16),
        children: [
          _SyncStatusRow(
            visual: StatusVocabulary.of(
              _online
                  ? ConnectivityStatus.online
                  : ConnectivityStatus.offline,
            ),
          ),
          const SizedBox(height: AppSpacing.s16),
          _MetricTile(
            status: SyncStatus.pending,
            label: AppStrings.syncPendingLabel,
            value: _pending.toString(),
          ),
          const SizedBox(height: AppSpacing.s8),
          _MetricTile(
            status: SyncStatus.failed,
            label: AppStrings.syncFailedLabel,
            value: _failed.toString(),
          ),
          const SizedBox(height: AppSpacing.s16),
          Text(
            '${AppStrings.syncLastSyncedLabel}: '
            '${_lastSynced == null ? AppStrings.syncNeverLabel : _format(_lastSynced!)}',
            style: theme.textTheme.bodyMedium,
          ),
          const SizedBox(height: AppSpacing.s24),
          FilledButton.icon(
            onPressed: _busy ? null : _runSync,
            icon: const Icon(Icons.sync),
            label: Text(
              _busy ? AppStrings.syncInProgress : AppStrings.syncNow,
            ),
          ),
          if (_failed > 0) ...[
            const SizedBox(height: AppSpacing.s8),
            OutlinedButton.icon(
              onPressed: _busy ? null : _retryFailed,
              icon: const Icon(Icons.refresh),
              label: const Text(AppStrings.syncRetryFailed),
            ),
          ],
        ],
      ),
    );
  }

  String _format(DateTime value) {
    final local = value.toLocal();
    final day = local.day.toString().padLeft(2, '0');
    final month = local.month.toString().padLeft(2, '0');
    final hour = local.hour.toString().padLeft(2, '0');
    final minute = local.minute.toString().padLeft(2, '0');
    return '$day/$month/${local.year} $hour:$minute';
  }
}

class _SyncStatusRow extends StatelessWidget {
  const _SyncStatusRow({required this.visual});

  final StatusVisual visual;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.s12),
      decoration: BoxDecoration(
        color: visual.background,
        borderRadius: BorderRadius.circular(AppSpacing.radiusSm),
      ),
      child: Row(
        children: [
          Icon(visual.icon, color: visual.foreground),
          const SizedBox(width: AppSpacing.s8),
          Text(
            visual.label,
            style: Theme.of(context)
                .textTheme
                .titleMedium
                ?.copyWith(color: visual.foreground),
          ),
        ],
      ),
    );
  }
}

class _MetricTile extends StatelessWidget {
  const _MetricTile({
    required this.status,
    required this.label,
    required this.value,
  });

  final SyncStatus status;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final visual = StatusVocabulary.of(status);
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.all(AppSpacing.s12),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(AppSpacing.radiusSm),
        border: Border.all(color: theme.dividerColor),
      ),
      child: Row(
        children: [
          Icon(visual.icon, color: visual.foreground),
          const SizedBox(width: AppSpacing.s8),
          Expanded(child: Text(label, style: theme.textTheme.bodyMedium)),
          Text(value, style: theme.textTheme.titleMedium),
        ],
      ),
    );
  }
}