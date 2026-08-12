import 'dart:async';

import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:timezone/timezone.dart' as tz;

import '../../health/application/health_sync_coordinator.dart';
import '../../health/application/health_sync_service.dart';
import '../../health/data/health_plugin_repository.dart';
import '../../health/data/supabase_daily_activity_sink.dart';
import '../../health/domain/health_models.dart';

/// Wires the health sync trigger set (app open, foreground resume) to the
/// Supabase-backed pipeline. Guarded by the coordinator against concurrent
/// runs; failures are swallowed so the UI is never blocked.
class HealthSyncBootstrap {
  static HealthSyncCoordinator? _coordinator;
  static String? _coordinatorUserId;

  static HealthSyncCoordinator ensureCoordinator() {
    final session = Supabase.instance.client.auth.currentSession;
    final userId = session?.user.id;
    if (userId == null) {
      throw StateError('No authenticated user to sync for.');
    }
    if (_coordinator != null && _coordinatorUserId == userId) {
      return _coordinator!;
    }
    final service = HealthSyncService(
      repository: HealthPluginRepository(),
      sink: SupabaseDailyActivitySink(
        client: Supabase.instance.client,
        userId: userId,
      ),
    );
    _coordinator = HealthSyncCoordinator(syncService: service);
    _coordinatorUserId = userId;
    return _coordinator!;
  }

  static void syncOnResume() {
    unawaited(syncNow());
  }

  static Future<HealthSyncResult?> syncNow() async {
    try {
      final coordinator = ensureCoordinator();
      final result = await coordinator.sync();
      if (result.readStatus == HealthReadStatus.success) {
        await fireGenerateEvents();
      }
      return result;
    } on Exception {
      // Best effort on resume; failures surface on the next manual sync.
      return null;
    }
  }

  /// Asks the server to evaluate competition events (overtakes, milestones,
  /// records, daily goal) for the current user. Fire-and-forget; the server
  /// is authoritative and idempotent, so a missed call only delays events.
  static Future<void> fireGenerateEvents() async {
    try {
      final client = Supabase.instance.client;
      final userId = client.auth.currentSession?.user.id;
      if (userId == null) return;
      final now = tz.TZDateTime.now(tz.getLocation('America/Santiago'));
      final date =
          '${now.year.toString().padLeft(4, '0')}-'
          '${now.month.toString().padLeft(2, '0')}-'
          '${now.day.toString().padLeft(2, '0')}';
      await client.functions.invoke(
        'generate_events',
        body: {'user_id': userId, 'date': date},
      );
    } on Exception {
      // Best effort; generate_events can also be triggered by close_day.
    }
  }
}
