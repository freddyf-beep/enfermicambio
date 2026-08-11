import 'package:supabase_flutter/supabase_flutter.dart';

import '../../feed/data/supabase_feed_repository.dart';
import '../../feed/domain/feed_models.dart';
import '../../health/domain/health_models.dart';
import '../../ranking/domain/ranking_models.dart';
import '../../ranking/domain/ranking_service.dart';

class AppDashboardData {
  const AppDashboardData({
    required this.ranking,
    required this.feedPage,
    required this.me,
  });

  final List<RankingRow> ranking;
  final FeedPage feedPage;
  final DailyActivityAggregate? me;
}

class DashboardRepository {
  DashboardRepository({required SupabaseClient client})
    : _client = client,
      _feed = SupabaseFeedRepository(client: client);

  final SupabaseClient _client;
  final SupabaseFeedRepository _feed;

  Future<AppDashboardData> load({
    required DateTime now,
    DateTime Function()? clock,
  }) async {
    final session = _client.auth.currentSession;
    final meId = session?.user.id;

    final profilesFuture = _client
        .from('profiles')
        .select('id, display_name, avatar_url, timezone');
    final activityFuture = _client
        .from('daily_activity')
        .select(
          'user_id, activity_date, daily_steps, active_calories, '
          'distance_meters, exercise_minutes, synced_at',
        );
    final feedFuture = _feed.loadLatest(limit: 20);

    final results = await Future.wait<Object>([
      profilesFuture,
      activityFuture,
      feedFuture,
    ]);

    final profiles = results[0] as List<dynamic>;
    final activityRows = results[1] as List<dynamic>;
    final feedPage = results[2] as FeedPage;

    final syncedByUser = <String, DateTime>{};
    final stepsByUser = <String, int>{};
    final caloriesByUser = <String, double>{};
    final distanceByUser = <String, double>{};
    final exerciseByUser = <String, double>{};

    for (final row in activityRows.cast<Map<String, dynamic>>()) {
      final userId = row['user_id'] as String;
      final synced = DateTime.parse(row['synced_at'] as String);
      final current = syncedByUser[userId];
      if (current == null || synced.isAfter(current)) {
        syncedByUser[userId] = synced;
        stepsByUser[userId] = (row['daily_steps'] as num).toInt();
        caloriesByUser[userId] =
            (row['active_calories'] as num?)?.toDouble() ?? 0;
        distanceByUser[userId] =
            (row['distance_meters'] as num?)?.toDouble() ?? 0;
        exerciseByUser[userId] =
            (row['exercise_minutes'] as num?)?.toDouble() ?? 0;
      }
    }

    final users = profiles.cast<Map<String, dynamic>>().map((profile) {
      final userId = profile['id'] as String;
      final synced = syncedByUser[userId];
      return UserActivitySnapshot(
        userId: userId,
        displayName: (profile['display_name'] as String?) ?? 'Unknown',
        avatarUrl: profile['avatar_url'] as String?,
        dailySteps: stepsByUser[userId] ?? 0,
        activeCalories: caloriesByUser[userId] ?? 0,
        distanceMeters: distanceByUser[userId] ?? 0,
        exerciseMinutes: exerciseByUser[userId] ?? 0,
        syncedAt: synced ?? DateTime.fromMillisecondsSinceEpoch(0, isUtc: true),
        message: synced == null ? 'permission_denied' : null,
      );
    }).toList();

    final ranking = const RankingService().rank(users: users, now: now);

    final me = meId == null
        ? null
        : users
              .where((user) => user.userId == meId)
              .map(
                (user) => DailyActivityAggregate(
                  date: DateTime.utc(now.year, now.month, now.day),
                  morningSteps: 0,
                  afternoonSteps: 0,
                  nightSteps: 0,
                  dailySteps: user.dailySteps,
                  activeCalories: user.activeCalories,
                  distanceMeters: user.distanceMeters,
                  exerciseMinutes: user.exerciseMinutes,
                  syncedAt: user.syncedAt,
                  manualRecordsExcluded: 0,
                  sourcePlatform: 'unknown',
                ),
              )
              .firstOrNull;

    return AppDashboardData(ranking: ranking, feedPage: feedPage, me: me);
  }
}
