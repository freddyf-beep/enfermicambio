import 'package:supabase_flutter/supabase_flutter.dart';

import '../domain/profile_models.dart';

class SupabaseProfileRepository {
  const SupabaseProfileRepository({required this._client});

  final SupabaseClient _client;

  static const _publicColumns =
      'id, display_name, avatar_url, daily_step_target, '
      'daily_calorie_target, weekly_workout_target, timezone';

  Future<List<UserProfile>> fetchAll() async {
    final rows = await _client
        .from('profiles')
        .select(_publicColumns)
        .order('display_name');
    return rows
        .cast<Map<String, dynamic>>()
        .map(_fromRow)
        .toList(growable: false);
  }

  Future<UserProfile> fetchById(String userId) async {
    final row = await _client
        .from('profiles')
        .select('$_publicColumns, notification_preferences, weight_goal_kg')
        .eq('id', userId)
        .single();
    return _fromRow(row);
  }

  UserProfile _fromRow(Map<String, dynamic> row) {
    return UserProfile(
      id: row['id'] as String,
      displayName: (row['display_name'] as String?) ?? 'Unknown',
      avatarUrl: row['avatar_url'] as String?,
      dailyStepTarget: ((row['daily_step_target'] as num?) ?? 10000).toInt(),
      dailyCalorieTarget: ((row['daily_calorie_target'] as num?) ?? 2200)
          .toInt(),
      weeklyWorkoutTarget: ((row['weekly_workout_target'] as num?) ?? 3)
          .toInt(),
      timezone: (row['timezone'] as String?) ?? 'UTC',
      notificationPreferences:
          (row['notification_preferences'] as Map?)?.cast<String, dynamic>() ??
          const {},
      weightGoalKg: (row['weight_goal_kg'] as num?)?.toDouble(),
    );
  }
}
