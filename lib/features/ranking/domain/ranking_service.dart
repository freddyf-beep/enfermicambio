import 'ranking_models.dart';

enum RankingMetric { steps, distance, calories, workoutCount, gamePoints }

class RankingService {
  const RankingService({this.stalenessThreshold = const Duration(hours: 3)});

  final Duration stalenessThreshold;

  List<RankingRow> rank({
    required List<UserActivitySnapshot> users,
    RankingMetric metric = RankingMetric.steps,
    DateTime? now,
  }) {
    final currentTime = now ?? DateTime.now().toUtc();
    final rows = users
        .map(
          (user) => RankingRow(
            userId: user.userId,
            displayName: user.displayName,
            avatarUrl: user.avatarUrl,
            value: _valueFor(user, metric),
            freshness: _freshness(user, currentTime),
            rank: 0,
            lastSyncedAt: _hasSyncTime(user) ? user.syncedAt : null,
          ),
        )
        .toList();

    rows.sort((a, b) {
      if (a.freshness == UserFreshness.missing) return 1;
      if (b.freshness == UserFreshness.missing) return -1;
      if (a.freshness == UserFreshness.denied) return 1;
      if (b.freshness == UserFreshness.denied) return -1;
      return b.value.compareTo(a.value);
    });

    return _assignTies(rows);
  }

  double _valueFor(UserActivitySnapshot user, RankingMetric metric) {
    return switch (metric) {
      RankingMetric.steps => user.dailySteps.toDouble(),
      RankingMetric.distance => user.distanceMeters,
      RankingMetric.calories => user.activeCalories,
      RankingMetric.workoutCount => 0,
      RankingMetric.gamePoints => 0,
    };
  }

  UserFreshness _freshness(UserActivitySnapshot user, DateTime now) {
    if (user.message != null) {
      return switch (user.message!) {
        'permission_denied' => UserFreshness.denied,
        'source_unavailable' => UserFreshness.unavailable,
        _ => UserFreshness.unavailable,
      };
    }
    if (user.syncedAt.isBefore(now.subtract(const Duration(days: 1)))) {
      return UserFreshness.missing;
    }
    if (now.difference(user.syncedAt) > stalenessThreshold) {
      return UserFreshness.stale;
    }
    return UserFreshness.fresh;
  }

  bool _hasSyncTime(UserActivitySnapshot user) {
    return user.message == null;
  }

  List<RankingRow> _assignTies(List<RankingRow> rows) {
    final result = <RankingRow>[];
    var i = 0;
    while (i < rows.length) {
      var j = i;
      while (j < rows.length &&
          rows[j].value == rows[i].value &&
          rows[j].freshness == rows[i].freshness) {
        j++;
      }
      final rank = i + 1;
      for (var k = i; k < j; k++) {
        result.add(
          RankingRow(
            userId: rows[k].userId,
            displayName: rows[k].displayName,
            avatarUrl: rows[k].avatarUrl,
            value: rows[k].value,
            freshness: rows[k].freshness,
            rank: rank,
            lastSyncedAt: rows[k].lastSyncedAt,
          ),
        );
      }
      i = j;
    }
    return result;
  }
}
