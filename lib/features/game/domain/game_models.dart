class SeasonStanding {
  const SeasonStanding({
    required this.seasonId,
    required this.userId,
    required this.displayName,
    required this.totalPoints,
    required this.position,
  });

  final String seasonId;
  final String userId;
  final String displayName;
  final double totalPoints;
  final int position;
}

class Season {
  const Season({
    required this.id,
    required this.name,
    required this.startsAt,
    required this.endsAt,
    required this.status,
  });

  final String id;
  final String name;
  final DateTime startsAt;
  final DateTime endsAt;
  final String status;
}

class Mission {
  const Mission({
    required this.id,
    required this.name,
    required this.description,
    required this.missionType,
    required this.rules,
    required this.rewardPoints,
  });

  factory Mission.fromJson(Map<String, dynamic> json) => Mission(
    id: json['id'] as String,
    name: (json['name'] as String?) ?? 'Misión',
    description: (json['description'] as String?) ?? '',
    missionType: (json['mission_type'] as String?) ?? 'individual',
    rules: (json['rules'] as Map<String, dynamic>?) ?? const {},
    rewardPoints: ((json['reward_points'] as num?) ?? 0).toInt(),
  );

  final String id;
  final String name;
  final String description;
  final String missionType;
  final Map<String, dynamic> rules;
  final int rewardPoints;
}

class MissionProgress {
  const MissionProgress({
    required this.missionId,
    this.userId,
    this.progressDate,
    required this.progress,
    required this.completed,
    this.completedAt,
  });

  factory MissionProgress.fromJson(Map<String, dynamic> json) =>
      MissionProgress(
        missionId: json['mission_id'] as String,
        userId: json['user_id'] as String?,
        progressDate: json['progress_date'] as String?,
        progress: (json['progress'] as Map<String, dynamic>?) ?? const {},
        completed: (json['completed'] as bool?) ?? false,
        completedAt: json['completed_at'] == null
            ? null
            : DateTime.parse(json['completed_at'] as String),
      );

  final String missionId;
  final String? userId;
  final String? progressDate;
  final Map<String, dynamic> progress;
  final bool completed;
  final DateTime? completedAt;

  double valueOf(String metric) => (progress[metric] as num?)?.toDouble() ?? 0;
}

class Achievement {
  const Achievement({
    required this.id,
    required this.code,
    required this.name,
    required this.description,
    required this.icon,
    required this.hidden,
    this.metric = '',
    this.operator = 'gte',
    this.threshold = 0,
    this.timeWindow,
    this.seasonPoints = 0,
  });

  factory Achievement.fromJson(Map<String, dynamic> json) => Achievement(
    id: json['id'] as String,
    code: (json['code'] as String?) ?? '',
    name: (json['name'] as String?) ?? 'Logro',
    description: (json['description'] as String?) ?? '',
    icon: (json['icon'] as String?) ?? 'military_tech',
    hidden: (json['hidden'] as bool?) ?? false,
    metric: (json['metric'] as String?) ?? '',
    operator: (json['operator'] as String?) ?? 'gte',
    threshold: ((json['threshold'] as num?) ?? 0).toDouble(),
    timeWindow: json['time_window'] as String?,
    seasonPoints: ((json['season_points'] as num?) ?? 0).toInt(),
  );

  final String id;
  final String code;
  final String name;
  final String description;
  final String icon;
  final bool hidden;
  final String metric;
  final String operator;
  final double threshold;
  final String? timeWindow;
  final int seasonPoints;
}

class UserAchievement {
  const UserAchievement({
    required this.achievementId,
    required this.unlockedAt,
  });

  factory UserAchievement.fromJson(Map<String, dynamic> json) =>
      UserAchievement(
        achievementId: json['achievement_id'] as String,
        unlockedAt: DateTime.parse(json['unlocked_at'] as String),
      );

  final String achievementId;
  final DateTime unlockedAt;
}

class Streak {
  const Streak({
    required this.streakType,
    required this.currentCount,
    required this.longestCount,
    this.lastQualifiedDate,
  });

  factory Streak.fromJson(Map<String, dynamic> json) => Streak(
    streakType: (json['streak_type'] as String?) ?? '',
    currentCount: ((json['current_count'] as num?) ?? 0).toInt(),
    longestCount: ((json['longest_count'] as num?) ?? 0).toInt(),
    lastQualifiedDate: json['last_qualified_date'] == null
        ? null
        : DateTime.parse(json['last_qualified_date'] as String),
  );

  final String streakType;
  final int currentCount;
  final int longestCount;
  final DateTime? lastQualifiedDate;
}

class BattlePassTier {
  const BattlePassTier({
    required this.tier,
    required this.thresholdPoints,
    required this.rewardType,
    required this.rewardKey,
    required this.rewardName,
    required this.rewardIcon,
  });

  factory BattlePassTier.fromJson(Map<String, dynamic> json) => BattlePassTier(
    tier: ((json['tier'] as num?) ?? 0).toInt(),
    thresholdPoints: ((json['threshold_points'] as num?) ?? 0).toInt(),
    rewardType: (json['reward_type'] as String?) ?? 'badge',
    rewardKey: (json['reward_key'] as String?) ?? '',
    rewardName: (json['reward_name'] as String?) ?? '',
    rewardIcon: (json['reward_icon'] as String?) ?? 'military_tech',
  );

  final int tier;
  final int thresholdPoints;
  final String rewardType;
  final String rewardKey;
  final String rewardName;
  final String rewardIcon;
}

class BattlePassClaim {
  const BattlePassClaim({required this.tier, required this.claimedAt});

  factory BattlePassClaim.fromJson(Map<String, dynamic> json) =>
      BattlePassClaim(
        tier: ((json['tier'] as num?) ?? 0).toInt(),
        claimedAt: DateTime.parse(json['claimed_at'] as String),
      );

  final int tier;
  final DateTime claimedAt;
}

class SeasonResult {
  const SeasonResult({
    required this.seasonId,
    required this.seasonName,
    required this.position,
    required this.points,
    this.userId,
    this.displayName,
  });

  factory SeasonResult.fromJson(Map<String, dynamic> json) => SeasonResult(
    seasonId: json['season_id'] as String,
    seasonName: (json['season_name'] as String?) ?? 'Temporada',
    position: ((json['position'] as num?) ?? 0).toInt(),
    points: ((json['points'] as num?) ?? 0).toDouble(),
    userId: json['user_id'] as String?,
    displayName:
        (json['display_name'] as String?) ??
        (json['profiles'] as Map<String, dynamic>?)?['display_name'] as String?,
  );

  final String seasonId;
  final String seasonName;
  final int position;
  final double points;
  final String? userId;
  final String? displayName;
}

class SeasonKm {
  const SeasonKm({
    required this.userId,
    required this.displayName,
    required this.km,
  });

  factory SeasonKm.fromJson(Map<String, dynamic> json) => SeasonKm(
    userId: json['user_id'] as String,
    displayName: (json['display_name'] as String?) ?? 'Desconocido',
    km: ((json['km'] as num?) ?? 0).toDouble(),
  );

  final String userId;
  final String displayName;
  final double km;
}
