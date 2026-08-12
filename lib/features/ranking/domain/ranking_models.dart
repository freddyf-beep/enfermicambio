enum UserFreshness { fresh, stale, missing, denied, unavailable }

enum RankingTimePeriod { hoy, semana, temporada }

enum RankingCategory {
  pasos,
  franjas,
  distancia,
  entrenamientos,
  calorias,
  puntos,
}

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

  factory RankingRow.fromJson(Map<String, dynamic> json) {
    return RankingRow(
      userId: json['userId'] as String,
      displayName: json['displayName'] as String,
      avatarUrl: json['avatarUrl'] as String?,
      value: (json['value'] as num).toDouble(),
      freshness: UserFreshness.values.byName(json['freshness'] as String),
      rank: (json['rank'] as num).toInt(),
      lastSyncedAt: json['lastSyncedAt'] == null
          ? null
          : DateTime.parse(json['lastSyncedAt'] as String),
    );
  }

  final String userId;
  final String displayName;
  final String? avatarUrl;
  final double value;
  final UserFreshness freshness;
  final int rank;
  final DateTime? lastSyncedAt;

  Map<String, dynamic> toJson() {
    return {
      'userId': userId,
      'displayName': displayName,
      'avatarUrl': avatarUrl,
      'value': value,
      'freshness': freshness.name,
      'rank': rank,
      'lastSyncedAt': lastSyncedAt?.toUtc().toIso8601String(),
    };
  }
}
