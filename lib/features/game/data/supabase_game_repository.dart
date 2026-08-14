import 'package:supabase_flutter/supabase_flutter.dart';

import '../domain/game_models.dart';

class SupabaseGameRepository {
  const SupabaseGameRepository({required this._client});

  final SupabaseClient _client;

  Future<Season?> currentSeason() async {
    final rows = await _client
        .from('seasons')
        .select('id, name, starts_at, ends_at, status')
        .eq('status', 'active')
        .order('starts_at', ascending: false)
        .limit(1);
    if (rows.isEmpty) return null;
    final row = rows.first;
    return Season(
      id: row['id'] as String,
      name: (row['name'] as String?) ?? 'Season',
      startsAt: DateTime.parse(row['starts_at'] as String),
      endsAt: DateTime.parse(row['ends_at'] as String),
      status: (row['status'] as String?) ?? 'active',
    );
  }

  Future<List<SeasonStanding>> standingsFor(Season season) async {
    final rows = await _client
        .from('season_standings')
        .select('season_id, user_id, display_name, total_points, position')
        .eq('season_id', season.id)
        .order('position');
    return rows
        .cast<Map<String, dynamic>>()
        .map((row) {
          return SeasonStanding(
            seasonId: row['season_id'] as String,
            userId: row['user_id'] as String,
            displayName: (row['display_name'] as String?) ?? 'Unknown',
            totalPoints: ((row['total_points'] as num?) ?? 0).toDouble(),
            position: ((row['position'] as num?) ?? 0).toInt(),
          );
        })
        .toList(growable: false);
  }

  Future<List<Mission>> dailyMissionsFor(DateTime date) async {
    final rows = await _client.rpc(
      'daily_missions_for_date',
      params: {'p_date': _dateParam(date)},
    );
    return (rows as List<dynamic>)
        .cast<Map<String, dynamic>>()
        .map(Mission.fromJson)
        .toList(growable: false);
  }

  Future<List<MissionProgress>> missionProgressFor(DateTime date) async {
    final rows = await _client
        .from('mission_progress')
        .select(
          'mission_id, user_id, progress_date, progress, completed, completed_at',
        )
        .eq('progress_date', _dateParam(date));
    return rows
        .cast<Map<String, dynamic>>()
        .map(MissionProgress.fromJson)
        .toList(growable: false);
  }

  Future<List<Achievement>> achievements() async {
    final rows = await _client
        .from('achievements')
        .select(
          'id, code, name, description, icon, metric, operator, threshold, '
          'time_window, hidden, season_points',
        )
        .order('threshold');
    return rows
        .cast<Map<String, dynamic>>()
        .map(Achievement.fromJson)
        .toList(growable: false);
  }

  Future<List<UserAchievement>> userAchievements(String userId) async {
    final rows = await _client
        .from('user_achievements')
        .select('achievement_id, unlocked_at')
        .eq('user_id', userId);
    return rows
        .cast<Map<String, dynamic>>()
        .map(UserAchievement.fromJson)
        .toList(growable: false);
  }

  Future<List<Streak>> streaksFor(String userId) async {
    final rows = await _client
        .from('streaks')
        .select(
          'streak_type, current_count, longest_count, last_qualified_date',
        )
        .eq('user_id', userId)
        .order('current_count', ascending: false);
    return rows
        .cast<Map<String, dynamic>>()
        .map(Streak.fromJson)
        .toList(growable: false);
  }

  /// Returns the four users' streaks so the game tab can compare the same
  /// rule for everyone, instead of silently showing only the signed-in user.
  Future<List<Streak>> streaksForAll() async {
    final rows = await _client
        .from('streaks')
        .select(
          'user_id, streak_type, current_count, longest_count, '
          'last_qualified_date, profiles(display_name)',
        )
        .order('streak_type')
        .order('current_count', ascending: false);
    return rows
        .cast<Map<String, dynamic>>()
        .map((row) {
          final profile = _relationObject(row['profiles']);
          return Streak.fromJson({
            ...row,
            'display_name': profile['display_name'],
          });
        })
        .toList(growable: false);
  }

  Future<List<BattlePassTier>> battlePassTiers() async {
    final rows = await _client
        .from('battle_pass_tiers')
        .select(
          'tier, threshold_points, reward_type, reward_key, reward_name, reward_icon',
        )
        .order('tier');
    return rows
        .cast<Map<String, dynamic>>()
        .map(BattlePassTier.fromJson)
        .toList(growable: false);
  }

  Future<List<BattlePassClaim>> battlePassClaims(
    String userId,
    String seasonId,
  ) async {
    final rows = await _client
        .from('battle_pass_claims')
        .select('tier, claimed_at')
        .eq('user_id', userId)
        .eq('season_id', seasonId);
    return rows
        .cast<Map<String, dynamic>>()
        .map(BattlePassClaim.fromJson)
        .toList(growable: false);
  }

  Future<String> claimBattlePassReward(String seasonId, int tier) async {
    final result = await _client.rpc(
      'claim_battle_pass_reward',
      params: {'p_season_id': seasonId, 'p_tier': tier},
    );
    return result as String;
  }

  Future<List<SeasonResult>> seasonHistory() async {
    final rows = await _client
        .from('season_results')
        .select(
          'season_id, user_id, final_rank, final_points, '
          'seasons(name), profiles(display_name)',
        );
    return rows
        .cast<Map<String, dynamic>>()
        .map((row) {
          final season = _relationObject(row['seasons']);
          final profile = _relationObject(row['profiles']);
          return SeasonResult(
            seasonId: row['season_id'] as String,
            seasonName: (season['name'] as String?) ?? 'Temporada',
            position: ((row['final_rank'] as num?) ?? 0).toInt(),
            points: ((row['final_points'] as num?) ?? 0).toDouble(),
            userId: row['user_id'] as String?,
            displayName: (profile['display_name'] as String?) ?? 'Desconocido',
          );
        })
        .toList(growable: false);
  }

  Future<List<SeasonKm>> seasonKm(Season season) async {
    final rows = await _client
        .from('daily_activity')
        .select('user_id, distance_meters')
        .gte('activity_date', _dateParam(season.startsAt))
        .lte('activity_date', _dateParam(season.endsAt))
        .eq('manual_entry_detected', false);
    final aggregated = <String, double>{};
    for (final row in rows.cast<Map<String, dynamic>>()) {
      final userId = row['user_id'] as String;
      aggregated[userId] =
          (aggregated[userId] ?? 0) +
          ((row['distance_meters'] as num?) ?? 0).toDouble();
    }
    if (aggregated.isEmpty) return const [];
    final names = <String, String>{};
    final profileRows = await _client
        .from('profiles')
        .select('id, display_name');
    for (final row in profileRows.cast<Map<String, dynamic>>()) {
      names[row['id'] as String] =
          (row['display_name'] as String?) ?? 'Desconocido';
    }
    final result = aggregated.entries
        .map(
          (entry) => SeasonKm(
            userId: entry.key,
            displayName: names[entry.key] ?? 'Desconocido',
            km: entry.value / 1000,
          ),
        )
        .toList();
    result.sort((a, b) => b.km.compareTo(a.km));
    return result;
  }

  // 'yyyy-MM-dd' del DateTime recibido (ya en TZ de competencia o UTC).
  String _dateParam(DateTime date) {
    final d = date.toUtc();
    return '${d.year.toString().padLeft(4, '0')}-'
        '${d.month.toString().padLeft(2, '0')}-'
        '${d.day.toString().padLeft(2, '0')}';
  }

  Map<String, dynamic> _relationObject(dynamic value) {
    if (value is Map<String, dynamic>) return value;
    if (value is Map) return value.cast<String, dynamic>();
    if (value is List && value.isNotEmpty && value.first is Map) {
      return (value.first as Map).cast<String, dynamic>();
    }
    return const {};
  }
}
