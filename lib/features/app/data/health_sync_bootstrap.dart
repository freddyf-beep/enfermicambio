import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:timezone/timezone.dart' as tz;

import '../../health/application/health_sync_coordinator.dart';
import '../../health/application/health_sync_service.dart';
import '../../health/data/health_plugin_repository.dart';
import '../../health/data/supabase_daily_activity_sink.dart';
import '../../health/domain/health_models.dart';
import '../../../shared/config/app_environment.dart';
import '../../workouts/data/supabase_workout_repository.dart';
import '../../workouts/data/supabase_workout_route_repository.dart';
import '../../workouts/domain/workout_models.dart';

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
    // The iPhone build uses Health Auto Export as the health bridge. Reading
    // HealthKit again here would either fail under a free-signed IPA or
    // overwrite the bridge's authoritative daily row with an empty result.
    if (defaultTargetPlatform == TargetPlatform.iOS) return null;
    try {
      final coordinator = ensureCoordinator();
      final result = await coordinator.sync();
      if (result.readStatus == HealthReadStatus.success) {
        await _persistWorkouts(result.workouts);
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
      final now = tz.TZDateTime.now(
        tz.getLocation(AppEnvironment.competitionTimezone),
      );
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

  static Future<void> _persistWorkouts(
    List<HealthWorkoutRecord> records,
  ) async {
    if (records.isEmpty) return;
    try {
      final client = Supabase.instance.client;
      final userId = client.auth.currentSession?.user.id;
      if (userId == null) return;
      const source = 'health_connect';
      final workouts = records
          .map(
            (record) => Workout(
              id: '',
              userId: userId,
              workoutType: record.workoutType,
              startedAt: record.startedAt,
              endedAt: record.endedAt,
              durationSeconds: record.durationSeconds,
              source: source,
              externalId: record.externalId,
              distanceMeters: record.distanceMeters,
              activeCalories: record.activeCalories,
              avgSpeed: record.avgSpeed,
              avgPace:
                  record.distanceMeters == null || record.distanceMeters == 0
                  ? null
                  : record.durationSeconds / (record.distanceMeters! / 1000),
              routeAvailable: record.routePoints.isNotEmpty,
            ),
          )
          .toList(growable: false);
      final workoutRepository = SupabaseWorkoutRepository(client: client);
      final routeRepository = SupabaseWorkoutRouteRepository(client: client);
      await workoutRepository.insertAll(workouts);
      for (final record in records) {
        if (record.routePoints.isEmpty) continue;
        final saved = await workoutRepository.findByExternalId(
          source: source,
          externalId: record.externalId,
        );
        if (saved == null) continue;
        await routeRepository.replaceRoute(
          workoutId: saved.id,
          points: record.routePoints
              .map(
                (point) => RoutePoint(
                  timestamp: point.timestamp,
                  latitude: point.latitude,
                  longitude: point.longitude,
                  altitude: point.altitude,
                  accuracy: point.accuracy,
                  bearing: point.bearing,
                ),
              )
              .toList(growable: false),
        );
      }
    } on Exception {
      // Activity already reached daily_activity. A workout import failure is
      // retried on the next foreground sync and must not blank the dashboard.
    }
  }
}
