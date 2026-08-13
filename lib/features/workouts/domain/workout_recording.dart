import 'dart:math' as math;

import 'workout_models.dart';

enum WorkoutActivityType { running, walking, cycling }

extension WorkoutActivityTypeX on WorkoutActivityType {
  String get storageValue => switch (this) {
    WorkoutActivityType.running => 'running',
    WorkoutActivityType.walking => 'walking',
    WorkoutActivityType.cycling => 'cycling',
  };

  String get label => switch (this) {
    WorkoutActivityType.running => 'Carrera',
    WorkoutActivityType.walking => 'Caminata',
    WorkoutActivityType.cycling => 'Ciclismo',
  };

  double get maximumReasonableSpeed => switch (this) {
    WorkoutActivityType.running => 12,
    WorkoutActivityType.walking => 4.5,
    WorkoutActivityType.cycling => 35,
  };

  double get estimatedCaloriesPerKilometer => switch (this) {
    WorkoutActivityType.running => 60,
    WorkoutActivityType.walking => 45,
    WorkoutActivityType.cycling => 25,
  };
}

class LocationSample {
  const LocationSample({
    required this.timestamp,
    required this.latitude,
    required this.longitude,
    required this.accuracy,
    required this.altitude,
    required this.bearing,
    required this.speed,
  });

  final DateTime timestamp;
  final double latitude;
  final double longitude;
  final double accuracy;
  final double altitude;
  final double bearing;
  final double speed;
}

class WorkoutRouteAccumulator {
  WorkoutRouteAccumulator({required this.activityType});

  final WorkoutActivityType activityType;
  final List<RoutePoint> _points = [];
  double _distanceMeters = 0;
  double _latestSpeed = 0;

  List<RoutePoint> get points => List.unmodifiable(_points);
  double get distanceMeters => _distanceMeters;
  double get latestSpeed => _latestSpeed;

  bool add(LocationSample sample) {
    if (sample.latitude < -90 ||
        sample.latitude > 90 ||
        sample.longitude < -180 ||
        sample.longitude > 180 ||
        !sample.accuracy.isFinite ||
        sample.accuracy <= 0 ||
        sample.accuracy > 65) {
      return false;
    }

    if (_points.isNotEmpty) {
      final previous = _points.last;
      final elapsed = sample.timestamp.difference(previous.timestamp);
      if (elapsed.inMilliseconds <= 0) return false;

      final segment = haversineDistanceMeters(
        previous.latitude,
        previous.longitude,
        sample.latitude,
        sample.longitude,
      );
      final seconds = elapsed.inMilliseconds / 1000;
      final calculatedSpeed = segment / seconds;
      if (!segment.isFinite ||
          calculatedSpeed > activityType.maximumReasonableSpeed) {
        return false;
      }

      // Ignore sub-meter GPS jitter while the user is standing still.
      if (segment < 1.5) {
        _latestSpeed = sample.speed.isFinite && sample.speed > 0
            ? sample.speed
            : 0;
        return false;
      }
      _distanceMeters += segment;
      _latestSpeed = sample.speed.isFinite && sample.speed >= 0
          ? sample.speed
          : calculatedSpeed;
    }

    _points.add(
      RoutePoint(
        timestamp: sample.timestamp,
        latitude: sample.latitude,
        longitude: sample.longitude,
        altitude: sample.altitude.isFinite ? sample.altitude : null,
        accuracy: sample.accuracy,
        bearing: sample.bearing.isFinite && sample.bearing >= 0
            ? sample.bearing
            : null,
      ),
    );
    return true;
  }

  double estimatedCalories() =>
      (_distanceMeters / 1000) * activityType.estimatedCaloriesPerKilometer;

  static double haversineDistanceMeters(
    double latitude1,
    double longitude1,
    double latitude2,
    double longitude2,
  ) {
    const earthRadiusMeters = 6371000.0;
    final lat1 = latitude1 * math.pi / 180;
    final lat2 = latitude2 * math.pi / 180;
    final deltaLat = (latitude2 - latitude1) * math.pi / 180;
    final deltaLon = (longitude2 - longitude1) * math.pi / 180;
    final a =
        math.sin(deltaLat / 2) * math.sin(deltaLat / 2) +
        math.cos(lat1) *
            math.cos(lat2) *
            math.sin(deltaLon / 2) *
            math.sin(deltaLon / 2);
    return earthRadiusMeters * 2 * math.atan2(math.sqrt(a), math.sqrt(1 - a));
  }
}
