import 'package:supabase_flutter/supabase_flutter.dart';

import '../domain/profile_history_stats.dart';

class SupabaseHistoryRepository {
  const SupabaseHistoryRepository({required this._client});

  final SupabaseClient _client;

  Future<ProfileHistoryStats> statsFor({required String userId}) async {
    final activity = await _client
        .from('daily_activity')
        .select('daily_steps, distance_meters')
        .eq('user_id', userId);
    final workouts = await _client
        .from('workouts')
        .select('id')
        .eq('user_id', userId);
    final seasonResults = await _client
        .from('season_results')
        .select('final_rank')
        .eq('user_id', userId);
    final streaks = await _client
        .from('streaks')
        .select('longest_count')
        .eq('user_id', userId)
        .eq('streak_type', 'step_goal')
        .maybeSingle();

    var lifetimeSteps = 0;
    var lifetimeDistance = 0.0;
    for (final row in activity.cast<Map<String, dynamic>>()) {
      lifetimeSteps += ((row['daily_steps'] as num?) ?? 0).toInt();
      lifetimeDistance += ((row['distance_meters'] as num?) ?? 0).toDouble();
    }

    final seasonWins = seasonResults
        .cast<Map<String, dynamic>>()
        .where((row) => ((row['final_rank'] as num?) ?? 0).toInt() == 1)
        .length;

    return ProfileHistoryStats(
      lifetimeSteps: lifetimeSteps,
      lifetimeDistanceM: lifetimeDistance,
      workoutCount: workouts.length,
      dailyWins: 0,
      roundWins: 0,
      seasonWins: seasonWins,
      longestStepStreak: ((streaks?['longest_count'] as num?) ?? 0).toInt(),
    );
  }
}
