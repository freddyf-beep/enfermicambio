import 'package:supabase_flutter/supabase_flutter.dart';

import '../domain/game_models.dart';

class SupabaseGameRepository {
  const SupabaseGameRepository({required this._client});

  final SupabaseClient _client;

  Future<Season?> currentSeason() async {
    final rows = await _client
        .from('seasons')
        .select('id, name, starts_at, ends_at, status')
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
}
