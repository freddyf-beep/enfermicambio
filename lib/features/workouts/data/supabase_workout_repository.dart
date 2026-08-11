import 'package:supabase_flutter/supabase_flutter.dart';

import '../domain/workout_models.dart';

class SupabaseWorkoutRepository {
  const SupabaseWorkoutRepository({required this._client});

  final SupabaseClient _client;

  Future<List<String>> existingExternalIds({required String userId}) async {
    final rows = await _client
        .from('workouts')
        .select('external_id')
        .eq('user_id', userId)
        .not('external_id', 'is', null);
    return rows
        .cast<Map<String, dynamic>>()
        .map((row) => row['external_id'] as String)
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
