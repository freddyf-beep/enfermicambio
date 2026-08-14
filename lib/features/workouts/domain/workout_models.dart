class Workout {
  const Workout({
    required this.id,
    required this.userId,
    required this.workoutType,
    required this.startedAt,
    required this.endedAt,
    required this.durationSeconds,
    required this.source,
    this.externalId,
    this.distanceMeters,
    this.activeCalories,
    this.avgPace,
    this.avgSpeed,
    this.routeAvailable = false,
  });

  final String id;
  final String userId;
  final String workoutType;
  final DateTime startedAt;
  final DateTime endedAt;
  final int durationSeconds;
  final String source;
  final String? externalId;
  final double? distanceMeters;
  final double? activeCalories;
  final double? avgPace;
  final double? avgSpeed;
  final bool routeAvailable;

  /// Identity used to de-duplicate against the `(source, external_id)` guard.
  String? get dedupeKey => externalId;

  Workout copyWith({String? id, bool? routeAvailable}) {
    return Workout(
      id: id ?? this.id,
      userId: userId,
      workoutType: workoutType,
      startedAt: startedAt,
      endedAt: endedAt,
      durationSeconds: durationSeconds,
      source: source,
      externalId: externalId,
      distanceMeters: distanceMeters,
      activeCalories: activeCalories,
      avgPace: avgPace,
      avgSpeed: avgSpeed,
      routeAvailable: routeAvailable ?? this.routeAvailable,
    );
  }
}

class RoutePoint {
  const RoutePoint({
    required this.timestamp,
    required this.latitude,
    required this.longitude,
    this.altitude,
    this.accuracy,
    this.bearing,
    this.segmentIndex = 0,
  });

  final DateTime timestamp;
  final double latitude;
  final double longitude;
  final double? altitude;
  final double? accuracy;
  final double? bearing;

  /// Consecutive GPS segments are kept separate when a signal gap is too
  /// large to draw a trustworthy line between two samples.
  final int segmentIndex;
}
