import 'package:supabase_flutter/supabase_flutter.dart';

import '../../health/application/health_sync_coordinator.dart';
import '../../health/application/health_sync_service.dart';
import '../../health/data/health_plugin_repository.dart';
import '../../health/data/supabase_daily_activity_sink.dart';

/// Wires the health sync trigger set (app open, foreground resume) to the
/// Supabase-backed pipeline. Guarded by the coordinator against concurrent
/// runs; failures are swallowed so the UI is never blocked.
class HealthSyncBootstrap {
  static HealthSyncCoordinator? _coordinator;

  static HealthSyncCoordinator ensureCoordinator() {
    if (_coordinator != null) return _coordinator!;
    final session = Supabase.instance.client.auth.currentSession;
    final userId = session?.user.id;
    if (userId == null) {
      throw StateError('No authenticated user to sync for.');
    }
    final service = HealthSyncService(
      repository: HealthPluginRepository(),
      sink: SupabaseDailyActivitySink(
        client: Supabase.instance.client,
        userId: userId,
      ),
    );
    _coordinator = HealthSyncCoordinator(syncService: service);
    return _coordinator!;
  }

  static void syncOnResume() {
    try {
      final coordinator = ensureCoordinator();
      coordinator.sync();
    } on Exception {
      // Best effort on resume; failures surface on the next manual sync.
    }
  }
}
