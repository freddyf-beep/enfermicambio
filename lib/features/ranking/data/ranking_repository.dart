import 'package:supabase_flutter/supabase_flutter.dart';

import '../domain/ranking_models.dart';

/// Carga rankings reales por categoría y período desde Supabase.
/// Siempre se muestran los 4 perfiles; quien no tenga datos aparece con cero.
class RankingRepository {
  RankingRepository({required SupabaseClient client}) : _client = client;

  final SupabaseClient _client;

  Future<List<RankingRow>> load({
    required RankingCategory category,
    required RankingTimePeriod period,
    required DateTime now,
  }) async {
    final profiles = await _client
        .from('profiles')
        .select('id, display_name, avatar_url');
    final users = profiles.cast<Map<String, dynamic>>().toList();

    final (start, end) = await _rangeFor(period, now);
    final activity = await _client
        .from('daily_activity')
        .select(
          'user_id, activity_date, daily_steps, morning_steps, afternoon_steps, '
          'night_steps, active_calories, distance_meters, synced_at',
        )
        .gte('activity_date', _date(start))
        .lte('activity_date', _date(end))
        .eq('manual_entry_detected', false);

    final workouts = (category == RankingCategory.entrenamientos)
        ? await _client
            .from('workouts')
            .select('user_id')
            .gte('started_at', start.toUtc().toIso8601String())
            .lte('started_at', end.toUtc().toIso8601String())
        : null;

    final seasonStandings =
        (category == RankingCategory.puntos &&
            period == RankingTimePeriod.temporada)
            ? await _client
                .from('season_standings')
                .select('user_id, total_points, position')
            : null;

    final pointsRows = (category == RankingCategory.puntos &&
            period != RankingTimePeriod.temporada)
        ? await _client
            .from('season_points')
            .select('user_id, points, created_at')
            .gte('created_at', start.toUtc().toIso8601String())
            .lte('created_at', end.toUtc().toIso8601String())
        : null;

    final values = <String, double>{};
    final synced = <String, DateTime>{};
    for (final row in activity.cast<Map<String, dynamic>>()) {
      final userId = row['user_id'] as String;
      final s = DateTime.parse(row['synced_at'] as String);
      final current = synced[userId];
      if (current == null || s.isAfter(current)) synced[userId] = s;
      final metric = switch (category) {
        RankingCategory.pasos => (row['daily_steps'] as num).toDouble(),
        RankingCategory.franjas => _windowSteps(row, now),
        RankingCategory.distancia =>
          (row['distance_meters'] as num?)?.toDouble() ?? 0,
        RankingCategory.entrenamientos => 0,
        RankingCategory.calorias =>
          (row['active_calories'] as num?)?.toDouble() ?? 0,
        RankingCategory.puntos => 0,
      };
      values[userId] = (values[userId] ?? 0) + metric;
    }

    if (workouts != null) {
      for (final row in workouts.cast<Map<String, dynamic>>()) {
        final userId = row['user_id'] as String;
        values[userId] = (values[userId] ?? 0) + 1;
      }
    }
    if (seasonStandings != null) {
      for (final row in seasonStandings.cast<Map<String, dynamic>>()) {
        values[row['user_id'] as String] =
            ((row['total_points'] as num?) ?? 0).toDouble();
      }
    }
    if (pointsRows != null) {
      for (final row in pointsRows.cast<Map<String, dynamic>>()) {
        final userId = row['user_id'] as String;
        values[userId] =
            (values[userId] ?? 0) + ((row['points'] as num?) ?? 0).toDouble();
      }
    }

    final sortedIds = values.keys.toList()
      ..sort((a, b) => values[b]!.compareTo(values[a]!));
    final rankByUser = <String, int>{};
    for (var i = 0; i < sortedIds.length; i++) {
      rankByUser[sortedIds[i]] = i + 1;
    }

    final ranked = users.map((profile) {
      final userId = profile['id'] as String;
      final s = synced[userId];
      return RankingRow(
        userId: userId,
        displayName: (profile['display_name'] as String?) ?? 'Desconocido',
        avatarUrl: profile['avatar_url'] as String?,
        value: values[userId] ?? 0,
        freshness: s == null ? UserFreshness.missing : UserFreshness.fresh,
        rank: rankByUser[userId] ?? values.length + 1,
        lastSyncedAt: s,
      );
    }).toList();
    ranked.sort((a, b) => a.rank.compareTo(b.rank));
    return ranked;
  }

  // Franja en curso según la hora local del host (los 4 dispositivos corren
  // en America/Santiago = competition_timezone). 00-06 usa el total del día.
  double _windowSteps(Map<String, dynamic> row, DateTime now) {
    final hour = now.hour;
    if (hour >= 6 && hour < 12) {
      return (row['morning_steps'] as num?)?.toDouble() ?? 0;
    }
    if (hour >= 12 && hour < 18) {
      return (row['afternoon_steps'] as num?)?.toDouble() ?? 0;
    }
    if (hour >= 18 && hour < 24) {
      return (row['night_steps'] as num?)?.toDouble() ?? 0;
    }
    return (row['daily_steps'] as num?)?.toDouble() ?? 0;
  }

  Future<(DateTime, DateTime)> _rangeFor(
    RankingTimePeriod period,
    DateTime now,
  ) async {
    final today = DateTime(now.year, now.month, now.day);
    switch (period) {
      case RankingTimePeriod.hoy:
        return (today, today);
      case RankingTimePeriod.semana:
        final monday = today.subtract(Duration(days: today.weekday - 1));
        return (monday, today);
      case RankingTimePeriod.temporada:
        final rows = await _client
            .from('seasons')
            .select('starts_at, ends_at')
            .eq('status', 'active')
            .order('starts_at', ascending: false)
            .limit(1);
        if (rows.isEmpty) return (today, today);
        final startsAt =
            DateTime.parse(rows.first['starts_at'] as String).toLocal();
        final endsAt =
            DateTime.parse(rows.first['ends_at'] as String).toLocal();
        return (
          DateTime(startsAt.year, startsAt.month, startsAt.day),
          DateTime(endsAt.year, endsAt.month, endsAt.day),
        );
    }
  }

  String _date(DateTime d) => '${d.year.toString().padLeft(4, '0')}-'
      '${d.month.toString().padLeft(2, '0')}-'
      '${d.day.toString().padLeft(2, '0')}';
}
