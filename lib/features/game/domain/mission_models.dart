enum MissionType { individual, competitive, cooperative }

class Mission {
  const Mission({
    required this.id,
    required this.name,
    required this.missionType,
    required this.rules,
    required this.rewardPoints,
  });

  final String id;
  final String name;
  final MissionType missionType;
  final Map<String, dynamic> rules;
  final int rewardPoints;
}

class MissionProgressState {
  const MissionProgressState({
    required this.progress,
    required this.completed,
    required this.completedAt,
  });

  final Map<String, dynamic> progress;
  final bool completed;
  final DateTime? completedAt;
}

class MissionEvaluationResult {
  const MissionEvaluationResult({
    required this.progress,
    required this.completed,
  });

  final Map<String, dynamic> progress;
  final bool completed;
}
