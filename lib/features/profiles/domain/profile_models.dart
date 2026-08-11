class UserProfile {
  const UserProfile({
    required this.id,
    required this.displayName,
    this.avatarUrl,
    this.dailyStepTarget = 10000,
    this.dailyCalorieTarget = 2200,
    this.weeklyWorkoutTarget = 3,
    this.timezone = 'UTC',
  });

  final String id;
  final String displayName;
  final String? avatarUrl;
  final int dailyStepTarget;
  final int dailyCalorieTarget;
  final int weeklyWorkoutTarget;
  final String timezone;
}
