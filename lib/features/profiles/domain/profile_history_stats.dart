class ProfileHistoryStats {
  const ProfileHistoryStats({
    required this.lifetimeSteps,
    required this.lifetimeDistanceM,
    required this.workoutCount,
    required this.dailyWins,
    required this.roundWins,
    required this.seasonWins,
    required this.longestStepStreak,
  });

  final int lifetimeSteps;
  final double lifetimeDistanceM;
  final int workoutCount;
  final int dailyWins;
  final int roundWins;
  final int seasonWins;
  final int longestStepStreak;
}
