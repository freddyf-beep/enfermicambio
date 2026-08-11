import 'package:flutter_test/flutter_test.dart';

import 'package:enfermicambio/features/workouts/domain/workout_import_service.dart';
import 'package:enfermicambio/features/workouts/domain/workout_models.dart';

void main() {
  final now = DateTime.utc(2026, 8, 10, 12);

  Workout workout(String externalId) {
    return Workout(
      id: '',
      userId: 'u1',
      workoutType: 'running',
      startedAt: now,
      endedAt: now.add(const Duration(minutes: 30)),
      durationSeconds: 1800,
      source: 'health_kit',
      externalId: externalId,
      distanceMeters: 5000,
    );
  }

  test('imports workouts without an existing external id', () {
    final result = const WorkoutImportService().import(
      incoming: [workout('a'), workout('b')],
      existingKeys: [],
    );

    expect(result.imported.length, 2);
    expect(result.duplicates, isEmpty);
  });

  test('de-duplicates on (source, external_id) using existing keys', () {
    final result = const WorkoutImportService().import(
      incoming: [workout('a'), workout('a'), workout('b')],
      existingKeys: ['a'],
    );

    expect(result.imported.length, 1);
    expect(result.imported.single.externalId, 'b');
    expect(result.duplicates.length, 2);
  });

  test('imports workouts without an external id unconditionally', () {
    final noId = Workout(
      id: '',
      userId: 'u1',
      workoutType: 'walking',
      startedAt: now,
      endedAt: now.add(const Duration(minutes: 10)),
      durationSeconds: 600,
      source: 'health_kit',
    );
    final result = const WorkoutImportService().import(
      incoming: [noId, noId],
      existingKeys: [],
    );

    expect(result.imported.length, 2);
    expect(result.duplicates, isEmpty);
  });
}
