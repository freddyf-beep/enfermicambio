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
}
