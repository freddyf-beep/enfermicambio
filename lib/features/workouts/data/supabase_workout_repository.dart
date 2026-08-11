import 'package:supabase_flutter/supabase_flutter.dart';

import '../domain/workout_models.dart';

class SupabaseWorkoutRepository {
  const SupabaseWorkoutRepository({required this._client});

  final SupabaseClient _client;

  Future<Workout?> findById(String workoutId) async {
    final rows = await _client
        .from('workouts')
        .select(
          'id, user_id, workout_type, started_at, ended_at, duration_seconds, '
          'source, external_id, distance_meters, active_calories, avg_pace, '
          'avg_speed, route_available',
        )
        .eq('id', workoutId)
        .limit(1);
    if (rows.isEmpty) return null;
    final row = rows.first;
    return Workout(
      id: row['id'] as String,
      userId: row['user_id'] as String,
      workoutType: row['workout_type'] as String,
      startedAt: DateTime.parse(row['started_at'] as String),
      endedAt: DateTime.parse(row['ended_at'] as String),
      durationSeconds: (row['duration_seconds'] as num).toInt(),
      source: row['source'] as String,
      externalId: row['external_id'] as String?,
      distanceMeters: (row['distance_meters'] as num?)?.toDouble(),
      activeCalories: (row['active_calories'] as num?)?.toDouble(),
      avgPace: (row['avg_pace'] as num?)?.toDouble(),
      avgSpeed: (row['avg_speed'] as num?)?.toDouble(),
      routeAvailable: (row['route_available'] as bool?) ?? false,
    );
  }

  Future<List<Workout>> listRecent({required int limit}) async {
    final rows = await _client
        .from('workouts')
        .select(
          'id, user_id, workout_type, started_at, ended_at, duration_seconds, '
          'source, external_id, distance_meters, active_calories, avg_pace, '
          'avg_speed, route_available',
        )
        .order('started_at', ascending: false)
        .limit(limit);
    return rows
        .cast<Map<String, dynamic>>()
        .map((row) {
          return Workout(
            id: row['id'] as String,
            userId: row['user_id'] as String,
            workoutType: row['workout_type'] as String,
            startedAt: DateTime.parse(row['started_at'] as String),
            endedAt: DateTime.parse(row['ended_at'] as String),
            durationSeconds: (row['duration_seconds'] as num).toInt(),
            source: row['source'] as String,
            externalId: row['external_id'] as String?,
            distanceMeters: (row['distance_meters'] as num?)?.toDouble(),
            activeCalories: (row['active_calories'] as num?)?.toDouble(),
            avgPace: (row['avg_pace'] as num?)?.toDouble(),
            avgSpeed: (row['avg_speed'] as num?)?.toDouble(),
            routeAvailable: (row['route_available'] as bool?) ?? false,
          );
        })
        .toList(growable: false);
  }

  Future<void> insertAll(List<Workout> workouts) async {
    if (workouts.isEmpty) return;
    final rows = workouts
        .map((w) {
          return {
            'user_id': w.userId,
            'external_id': w.externalId,
            'source': w.source,
            'workout_type': w.workoutType,
            'started_at': w.startedAt.toUtc().toIso8601String(),
            'ended_at': w.endedAt.toUtc().toIso8601String(),
            'duration_seconds': w.durationSeconds,
            'distance_meters': w.distanceMeters,
            'active_calories': w.activeCalories,
            'avg_pace': w.avgPace,
            'avg_speed': w.avgSpeed,
            'route_available': w.routeAvailable,
          };
        })
        .toList(growable: false);

    await _client
        .from('workouts')
        .upsert(rows, onConflict: 'source,external_id', ignoreDuplicates: true);
  }
}
