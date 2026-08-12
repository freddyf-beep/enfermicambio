import 'package:supabase_flutter/supabase_flutter.dart';

import '../domain/workout_models.dart';

class SupabaseWorkoutRouteRepository {
  const SupabaseWorkoutRouteRepository({required this._client});

  final SupabaseClient _client;

  /// Loads route points for a workout, bounded to the most recent [limit]
  /// points so a very long run never floods the device.
  Future<List<RoutePoint>> routeFor({
    required String workoutId,
    int limit = 2000,
  }) async {
    final rows = await _client
        .from('workout_route_points')
        .select('timestamp, latitude, longitude, altitude, accuracy, bearing')
        .eq('workout_id', workoutId)
        .order('timestamp', ascending: true)
        .limit(limit);
    return rows
        .cast<Map<String, dynamic>>()
        .map((row) {
          return RoutePoint(
            timestamp: DateTime.parse(row['timestamp'] as String),
            latitude: (row['latitude'] as num).toDouble(),
            longitude: (row['longitude'] as num).toDouble(),
            altitude: (row['altitude'] as num?)?.toDouble(),
            accuracy: (row['accuracy'] as num?)?.toDouble(),
            bearing: (row['bearing'] as num?)?.toDouble(),
          );
        })
        .toList(growable: false);
  }

  Future<void> replaceRoute({
    required String workoutId,
    required List<RoutePoint> points,
  }) async {
    await _client
        .from('workout_route_points')
        .delete()
        .eq('workout_id', workoutId);
    if (points.isEmpty) return;
    const chunkSize = 500;
    for (var start = 0; start < points.length; start += chunkSize) {
      final chunk = points.skip(start).take(chunkSize);
      await _client.from('workout_route_points').insert([
        for (final point in chunk)
          {
            'workout_id': workoutId,
            'timestamp': point.timestamp.toUtc().toIso8601String(),
            'latitude': point.latitude,
            'longitude': point.longitude,
            'altitude': point.altitude,
            'accuracy': point.accuracy,
            'bearing': point.bearing,
          },
      ]);
    }
  }
}
