import 'package:flutter_test/flutter_test.dart';

import 'package:enfermicambio/features/workouts/domain/workout_recording.dart';

void main() {
  LocationSample sample({
    required DateTime at,
    required double latitude,
    required double longitude,
    double accuracy = 5,
  }) {
    return LocationSample(
      timestamp: at,
      latitude: latitude,
      longitude: longitude,
      accuracy: accuracy,
      altitude: 100,
      bearing: 0,
      speed: 2,
    );
  }

  test('acumula una ruta caminable y calcula distancia', () {
    final route = WorkoutRouteAccumulator(
      activityType: WorkoutActivityType.walking,
    );
    final start = DateTime.utc(2026, 8, 13, 12);

    expect(
      route.add(sample(at: start, latitude: -33.4489, longitude: -70.6693)),
      isTrue,
    );
    expect(
      route.add(
        sample(
          at: start.add(const Duration(seconds: 30)),
          latitude: -33.4480,
          longitude: -70.6693,
        ),
      ),
      isTrue,
    );

    expect(route.points, hasLength(2));
    expect(route.distanceMeters, inInclusiveRange(95, 105));
    expect(route.estimatedCalories(), greaterThan(0));
  });

  test('descarta precisión mala y saltos imposibles', () {
    final route = WorkoutRouteAccumulator(
      activityType: WorkoutActivityType.running,
    );
    final start = DateTime.utc(2026, 8, 13, 12);

    expect(
      route.add(
        sample(
          at: start,
          latitude: -33.4489,
          longitude: -70.6693,
          accuracy: 100,
        ),
      ),
      isFalse,
    );
    expect(
      route.add(sample(at: start, latitude: -33.4489, longitude: -70.6693)),
      isTrue,
    );
    expect(
      route.add(
        sample(
          at: start.add(const Duration(seconds: 1)),
          latitude: -33.40,
          longitude: -70.60,
        ),
      ),
      isFalse,
    );
    expect(route.points, hasLength(1));
    expect(route.distanceMeters, 0);
  });

  test('suaviza el ruido lateral sin inflar la distancia', () {
    final route = WorkoutRouteAccumulator(
      activityType: WorkoutActivityType.walking,
    );
    final start = DateTime.utc(2026, 8, 13, 12);
    const baseLatitude = -33.4489;
    const baseLongitude = -70.6693;

    for (var i = 0; i <= 10; i++) {
      final lateralNoise = i.isEven ? 0.000012 : -0.000012;
      expect(
        route.add(
          sample(
            at: start.add(Duration(seconds: i * 2)),
            latitude: baseLatitude + i * 0.000045,
            longitude: baseLongitude + lateralNoise,
          ),
        ),
        isTrue,
      );
    }

    // The straight path is roughly 50 m. The EMA removes most of the
    // alternating lateral noise instead of accumulating every raw zigzag.
    expect(route.distanceMeters, inInclusiveRange(35, 65));
    expect(route.points.last.longitude, lessThan(baseLongitude + 0.000012));
  });

  test('reinicia el segmento después de perder señal', () {
    final route = WorkoutRouteAccumulator(
      activityType: WorkoutActivityType.walking,
    );
    final start = DateTime.utc(2026, 8, 13, 12);

    expect(
      route.add(sample(at: start, latitude: -33.4489, longitude: -70.6693)),
      isTrue,
    );
    expect(
      route.add(
        sample(
          at: start.add(const Duration(seconds: 4)),
          latitude: -33.4488,
          longitude: -70.6693,
        ),
      ),
      isTrue,
    );
    final beforeGapDistance = route.distanceMeters;
    expect(
      route.add(
        sample(
          at: start.add(const Duration(seconds: 40)),
          latitude: -33.4470,
          longitude: -70.6693,
        ),
      ),
      isTrue,
    );

    expect(route.points.last.segmentIndex, 1);
    expect(route.distanceMeters, closeTo(beforeGapDistance, 0.001));
  });
}
