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

  static const _emaAlpha = 0.45;
  static const _maximumSignalGap = Duration(seconds: 30);

  final WorkoutActivityType activityType;
  final List<RoutePoint> _points = [];
  double _distanceMeters = 0;
  double _latestSpeed = 0;
  DateTime? _lastValidTimestamp;
  double? _lastRawLatitude;
  double? _lastRawLongitude;
  double? _smoothedLatitude;
  double? _smoothedLongitude;
  int _segmentIndex = 0;

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

    var outputLatitude = sample.latitude;
    var outputLongitude = sample.longitude;

    if (_points.isNotEmpty) {
      final previousTimestamp = _lastValidTimestamp;
      final previousRawLatitude = _lastRawLatitude;
      final previousRawLongitude = _lastRawLongitude;
      final previousSmoothedLatitude = _smoothedLatitude;
      final previousSmoothedLongitude = _smoothedLongitude;
      if (previousTimestamp == null ||
          previousRawLatitude == null ||
          previousRawLongitude == null ||
          previousSmoothedLatitude == null ||
          previousSmoothedLongitude == null) {
        return false;
      }

      final elapsed = sample.timestamp.difference(previousTimestamp);
      if (elapsed.inMilliseconds <= 0) return false;

      if (elapsed > _maximumSignalGap) {
        // Start a new segment after a pause/lost signal. Keeping the segment
        // marker prevents the map from drawing a fabricated straight line
        // across the missing GPS interval.
        _segmentIndex++;
        _smoothedLatitude = sample.latitude;
        _smoothedLongitude = sample.longitude;
        _lastRawLatitude = sample.latitude;
        _lastRawLongitude = sample.longitude;
        _lastValidTimestamp = sample.timestamp;
        _latestSpeed = 0;
        _points.add(
          RoutePoint(
            timestamp: sample.timestamp,
            latitude: outputLatitude,
            longitude: outputLongitude,
            altitude: sample.altitude.isFinite ? sample.altitude : null,
            accuracy: sample.accuracy,
            bearing: sample.bearing.isFinite && sample.bearing >= 0
                ? sample.bearing
                : null,
            segmentIndex: _segmentIndex,
          ),
        );
        return true;
      }

      final segment = haversineDistanceMeters(
        previousRawLatitude,
        previousRawLongitude,
        sample.latitude,
        sample.longitude,
      );
      final seconds = elapsed.inMilliseconds / 1000;
      final calculatedSpeed = segment / seconds;
      if (!segment.isFinite ||
          calculatedSpeed > activityType.maximumReasonableSpeed) {
        return false;
      }

      final nextSmoothedLatitude = _points.length == 1
          ? sample.latitude
          : previousSmoothedLatitude +
                _emaAlpha * (sample.latitude - previousSmoothedLatitude);
      final nextSmoothedLongitude = _points.length == 1
          ? sample.longitude
          : previousSmoothedLongitude +
                _emaAlpha * (sample.longitude - previousSmoothedLongitude);
      final smoothedSegment = haversineDistanceMeters(
        previousSmoothedLatitude,
        previousSmoothedLongitude,
        nextSmoothedLatitude,
        nextSmoothedLongitude,
      );

      // Advance the filter even when this sample is only GPS jitter. This
      // lets the EMA settle without adding false distance to the route.
      _smoothedLatitude = nextSmoothedLatitude;
      _smoothedLongitude = nextSmoothedLongitude;
      outputLatitude = nextSmoothedLatitude;
      outputLongitude = nextSmoothedLongitude;
      _lastRawLatitude = sample.latitude;
      _lastRawLongitude = sample.longitude;
      _lastValidTimestamp = sample.timestamp;
      if (smoothedSegment < 1.5) {
        _latestSpeed = sample.speed.isFinite && sample.speed > 0
            ? sample.speed
            : 0;
        return false;
      }

      _distanceMeters += smoothedSegment;
      _latestSpeed = sample.speed.isFinite && sample.speed >= 0
          ? sample.speed
          : smoothedSegment / seconds;
    } else {
      _smoothedLatitude = sample.latitude;
      _smoothedLongitude = sample.longitude;
      _lastRawLatitude = sample.latitude;
      _lastRawLongitude = sample.longitude;
      _lastValidTimestamp = sample.timestamp;
    }

    _points.add(
      RoutePoint(
        timestamp: sample.timestamp,
        latitude: outputLatitude,
        longitude: outputLongitude,
        altitude: sample.altitude.isFinite ? sample.altitude : null,
        accuracy: sample.accuracy,
        bearing: sample.bearing.isFinite && sample.bearing >= 0
            ? sample.bearing
            : null,
        segmentIndex: _segmentIndex,
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
