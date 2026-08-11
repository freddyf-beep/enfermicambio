enum AchievementOperator { gte, gt, lte, lt, eq }

class Achievement {
  const Achievement({
    required this.code,
    required this.name,
    required this.metric,
    required this.operator,
    required this.threshold,
    required this.repeatable,
    required this.hidden,
    required this.seasonPoints,
    this.timeWindow,
    this.icon,
  });

  final String code;
  final String name;
  final String metric;
  final AchievementOperator operator;
  final double threshold;
  final String? timeWindow;
  final bool repeatable;
  final bool hidden;
  final int seasonPoints;
  final String? icon;
}

class AchievementEvaluation {
  const AchievementEvaluation({
    required this.achievement,
    required this.unlocked,
    required this.metricValue,
  });

  final Achievement achievement;
  final bool unlocked;
  final double metricValue;
}

class AchievementEngine {
  const AchievementEngine();

  bool evaluate(Achievement achievement, double metricValue) {
    return switch (achievement.operator) {
      AchievementOperator.gte => metricValue >= achievement.threshold,
      AchievementOperator.gt => metricValue > achievement.threshold,
      AchievementOperator.lte => metricValue <= achievement.threshold,
      AchievementOperator.lt => metricValue < achievement.threshold,
      AchievementOperator.eq => metricValue == achievement.threshold,
    };
  }

  List<AchievementEvaluation> evaluateAll({
    required List<Achievement> achievements,
    required double Function(String metric) valueFor,
  }) {
    return achievements
        .map((achievement) {
          final value = valueFor(achievement.metric);
          return AchievementEvaluation(
            achievement: achievement,
            metricValue: value,
            unlocked: evaluate(achievement, value),
          );
        })
        .toList(growable: false);
  }
}
