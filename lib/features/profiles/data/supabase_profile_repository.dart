import 'package:supabase_flutter/supabase_flutter.dart';

import '../domain/profile_models.dart';

class SupabaseProfileRepository {
  const SupabaseProfileRepository({required this._client});

  final SupabaseClient _client;

  Future<List<UserProfile>> fetchAll() async {
    final rows = await _client
        .from('profiles')
        .select(
          'id, display_name, avatar_url, daily_step_target, '
          'daily_calorie_target, weekly_workout_target, timezone',
        )
        .order('display_name');
    return rows
        .cast<Map<String, dynamic>>()
        .map((row) {
          return UserProfile(
            id: row['id'] as String,
            displayName: (row['display_name'] as String?) ?? 'Unknown',
            avatarUrl: row['avatar_url'] as String?,
            dailyStepTarget: ((row['daily_step_target'] as num?) ?? 10000)
                .toInt(),
            dailyCalorieTarget: ((row['daily_calorie_target'] as num?) ?? 2200)
                .toInt(),
            weeklyWorkoutTarget: ((row['weekly_workout_target'] as num?) ?? 3)
                .toInt(),
            timezone: (row['timezone'] as String?) ?? 'UTC',
          );
        })
        .toList(growable: false);
  }
}
