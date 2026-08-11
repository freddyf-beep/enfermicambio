import '../domain/health_models.dart';
import 'health_sync_service.dart';

/// Coordinates the sync trigger set: app open, foreground resume, and manual
/// pull-to-refresh. Guards against concurrent syncs; never promises real-time.
class HealthSyncCoordinator {
  HealthSyncCoordinator({required this.syncService});

  final HealthSyncService syncService;

  bool _isSyncing = false;
  DateTime? _lastSyncedAt;
  HealthSyncResult? _lastResult;

  bool get isSyncing => _isSyncing;

  DateTime? get lastSyncedAt => _lastSyncedAt;

  HealthSyncResult? get lastResult => _lastResult;

  Future<HealthSyncResult> sync({DateTime? now}) async {
    if (_isSyncing) {
      return _lastResult ??
          HealthSyncResult(
            readStatus: HealthReadStatus.retryableFailure,
            aggregate: null,
            message: 'A sync is already in progress.',
          );
    }
    _isSyncing = true;
    try {
      final result = await syncService.sync(now: now);
      if (result.readStatus == HealthReadStatus.success ||
          result.readStatus == HealthReadStatus.noData) {
        _lastSyncedAt = DateTime.now().toUtc();
      }
      _lastResult = result;
      return result;
    } finally {
      _isSyncing = false;
    }
  }
}
