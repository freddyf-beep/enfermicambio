class UserProfile {
  const UserProfile({
    required this.id,
    required this.displayName,
    this.avatarUrl,
    this.dailyStepTarget = 10000,
    this.dailyCalorieTarget = 2200,
    this.weeklyWorkoutTarget = 3,
    this.timezone = 'UTC',
    this.notificationPreferences = const {},
    this.weightGoalKg,
  });

  final String id;
  final String displayName;
  final String? avatarUrl;
  final int dailyStepTarget;
  final int dailyCalorieTarget;
  final int weeklyWorkoutTarget;
  final String timezone;

  /// Per-category notification toggles as stored in the DB (jsonb).
  final Map<String, dynamic> notificationPreferences;

  /// Private weight goal in kg; null means no goal set.
  final double? weightGoalKg;
}
