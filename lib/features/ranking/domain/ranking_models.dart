enum UserFreshness { fresh, stale, missing, denied, unavailable }

class UserActivitySnapshot {
  const UserActivitySnapshot({
    required this.userId,
    required this.displayName,
    required this.dailySteps,
    required this.activeCalories,
    required this.distanceMeters,
    required this.exerciseMinutes,
    required this.syncedAt,
    this.avatarUrl,
    this.message,
  });

  final String userId;
  final String displayName;
  final String? avatarUrl;
  final int dailySteps;
  final double activeCalories;
  final double distanceMeters;
  final double exerciseMinutes;
  final DateTime syncedAt;
  final String? message;
}

class RankingRow {
  const RankingRow({
    required this.userId,
    required this.displayName,
    required this.value,
    required this.freshness,
    required this.rank,
    this.avatarUrl,
    this.lastSyncedAt,
  });

  final String userId;
  final String displayName;
  final String? avatarUrl;
  final double value;
  final UserFreshness freshness;
  final int rank;
  final DateTime? lastSyncedAt;
}
