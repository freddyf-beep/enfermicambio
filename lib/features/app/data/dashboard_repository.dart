import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:timezone/timezone.dart' as tz;

import '../../feed/data/supabase_feed_repository.dart';
import '../../feed/domain/feed_models.dart';
import '../../health/domain/health_models.dart';
import '../../ranking/domain/ranking_models.dart';
import '../../ranking/domain/ranking_service.dart';
import '../../../shared/config/app_environment.dart';

class AppDashboardData {
  const AppDashboardData({
    required this.ranking,
    required this.feedPage,
    required this.me,
    this.feedError,
  });

  final List<RankingRow> ranking;
  final FeedPage feedPage;
  final DailyActivityAggregate? me;
  final Object? feedError;
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
    final location = tz.getLocation(AppEnvironment.competitionTimezone);
    final localNow = tz.TZDateTime.from(now.toUtc(), location);
    final activityDate = _dateOnly(localNow);

    final profilesFuture = _client
        .from('profiles')
        .select('id, display_name, avatar_url, timezone');
    final activityFuture = _client
        .from('daily_activity')
        .select(
          'user_id, activity_date, morning_steps, afternoon_steps, '
          'night_steps, daily_steps, active_calories, distance_meters, '
          'exercise_minutes, synced_at, source_platform, source_app, '
          'source_device, recording_method, manual_entry_detected, '
          'source_metadata',
        )
        .eq('activity_date', activityDate);
    final feedFuture = _loadFeedSafely();

    final results = await Future.wait<Object>([
      profilesFuture,
      activityFuture,
      feedFuture,
    ]);

    final profiles = results[0] as List<dynamic>;
    final activityRows = results[1] as List<dynamic>;
    final feedResult = results[2] as _FeedResult;

    final activityByUser = <String, Map<String, dynamic>>{};

    for (final row in activityRows.cast<Map<String, dynamic>>()) {
      final userId = row['user_id'] as String;
      final current = activityByUser[userId];
      if (current == null || _syncedAt(row).isAfter(_syncedAt(current))) {
        activityByUser[userId] = row;
      }
    }

    final users = profiles.cast<Map<String, dynamic>>().map((profile) {
      final userId = profile['id'] as String;
      final activity = activityByUser[userId];
      final synced = activity == null ? null : _syncedAt(activity);
      return UserActivitySnapshot(
        userId: userId,
        displayName: (profile['display_name'] as String?) ?? 'Unknown',
        avatarUrl: profile['avatar_url'] as String?,
        dailySteps: (activity?['daily_steps'] as num?)?.toInt() ?? 0,
        activeCalories: (activity?['active_calories'] as num?)?.toDouble() ?? 0,
        distanceMeters: (activity?['distance_meters'] as num?)?.toDouble() ?? 0,
        exerciseMinutes:
            (activity?['exercise_minutes'] as num?)?.toDouble() ?? 0,
        syncedAt: synced ?? DateTime.fromMillisecondsSinceEpoch(0, isUtc: true),
        message: synced == null ? 'permission_denied' : null,
      );
    }).toList();

    final ranking = const RankingService().rank(users: users, now: now);

    final meRow = meId == null ? null : activityByUser[meId];
    final me = meRow == null
        ? null
        : DailyActivityAggregate(
            date: DateTime.parse(activityDate),
            morningSteps: (meRow['morning_steps'] as num?)?.toInt() ?? 0,
            afternoonSteps: (meRow['afternoon_steps'] as num?)?.toInt() ?? 0,
            nightSteps: (meRow['night_steps'] as num?)?.toInt() ?? 0,
            dailySteps: (meRow['daily_steps'] as num?)?.toInt() ?? 0,
            activeCalories: (meRow['active_calories'] as num?)?.toDouble() ?? 0,
            distanceMeters: (meRow['distance_meters'] as num?)?.toDouble() ?? 0,
            exerciseMinutes:
                (meRow['exercise_minutes'] as num?)?.toDouble() ?? 0,
            syncedAt: _syncedAt(meRow),
            manualRecordsExcluded:
                (meRow['manual_entry_detected'] as bool? ?? false) ? 1 : 0,
            sourcePlatform: (meRow['source_platform'] as String?) ?? 'unknown',
            sourceApp: meRow['source_app'] as String?,
            sourceDevice: meRow['source_device'] as String?,
            recordingMethod:
                (meRow['recording_method'] as String?) ?? 'automatic',
            sourceMetadata:
                (meRow['source_metadata'] as Map?)?.cast<String, dynamic>() ??
                const {},
          );

    return AppDashboardData(
      ranking: ranking,
      feedPage: feedResult.page,
      me: me,
      feedError: feedResult.error,
    );
  }

  Future<_FeedResult> _loadFeedSafely() async {
    try {
      return _FeedResult(page: await _feed.loadLatest(limit: 20));
    } on Object catch (error) {
      return _FeedResult(
        page: const FeedPage(posts: [], nextCursor: null),
        error: error,
      );
    }
  }

  DateTime _syncedAt(Map<String, dynamic> row) {
    final value = row['synced_at'];
    if (value is DateTime) return value.toUtc();
    if (value is String) return DateTime.parse(value).toUtc();
    return DateTime.fromMillisecondsSinceEpoch(0, isUtc: true);
  }

  String _dateOnly(DateTime value) {
    return '${value.year.toString().padLeft(4, '0')}-'
        '${value.month.toString().padLeft(2, '0')}-'
        '${value.day.toString().padLeft(2, '0')}';
  }
}

class _FeedResult {
  const _FeedResult({required this.page, this.error});

  final FeedPage page;
  final Object? error;
}
