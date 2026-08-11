import 'workout_models.dart';

class WorkoutImportResult {
  const WorkoutImportResult({required this.imported, required this.duplicates});

  final List<Workout> imported;
  final List<Workout> duplicates;
}

class WorkoutImportService {
  const WorkoutImportService();

  WorkoutImportResult import({
    required Iterable<Workout> incoming,
    required Iterable<String> existingKeys,
  }) {
    final seen = <String>{...existingKeys};
    final imported = <Workout>[];
    final duplicates = <Workout>[];

    for (final workout in incoming) {
      final key = workout.dedupeKey;
      if (key != null) {
        if (seen.contains(key)) {
          duplicates.add(workout);
          continue;
        }
        seen.add(key);
      }
      imported.add(workout);
    }

    return WorkoutImportResult(imported: imported, duplicates: duplicates);
  }
}
