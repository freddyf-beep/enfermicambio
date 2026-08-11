import 'mission_models.dart';

class MissionEngine {
  const MissionEngine();

  MissionEvaluationResult apply({
    required Mission mission,
    required MissionProgressState? previous,
    required double delta,
  }) {
    final rule = mission.rules['metric'] as String? ?? 'steps';
    final target = (mission.rules['target'] as num?)?.toDouble() ?? 0;

    var current = (previous?.progress[rule] as num?)?.toDouble() ?? 0;
    current += delta;

    final completed = current >= target;
    return MissionEvaluationResult(
      progress: {...(previous?.progress ?? const {}), rule: current},
      completed: completed,
    );
  }

  MissionEvaluationResult applyGroup({
    required Mission mission,
    required List<double> memberDeltas,
  }) {
    if (mission.missionType != MissionType.cooperative) {
      throw ArgumentError('applyGroup requires a cooperative mission.');
    }
    final rule = mission.rules['metric'] as String? ?? 'steps';
    final target = (mission.rules['target'] as num?)?.toDouble() ?? 0;
    final total = memberDeltas.fold<double>(0, (sum, value) => sum + value);
    return MissionEvaluationResult(
      progress: {rule: total},
      completed: total >= target,
    );
  }
}
