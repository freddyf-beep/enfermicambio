import 'package:supabase_flutter/supabase_flutter.dart';

import '../domain/weight_models.dart';

/// Private weight log. All rows are owner-scoped by RLS; weight is never
/// exposed to the other three users.
class SupabaseWeightRepository {
  SupabaseWeightRepository({required SupabaseClient client, String? userId})
    : _client = client,
      _userId = userId ?? client.auth.currentSession?.user.id;

  final SupabaseClient _client;
  final String? _userId;

  String get _user =>
      _userId ??
      (_client.auth.currentSession?.user.id ??
          (throw StateError('No authenticated user for weight log.')));

  /// Upserts today's (or [date]'s) entry; one row per user and day.
  Future<void> upsert({
    required DateTime date,
    required double weightKg,
  }) async {
    final dateKey =
        '${date.year.toString().padLeft(4, '0')}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
    await _client.from('weight_entries').upsert({
      'user_id': _user,
      'entry_date': dateKey,
      'weight_kg': weightKg,
      'source': 'manual',
    }, onConflict: 'user_id,entry_date');
  }

  Future<WeightEntry?> latest() async {
    final rows = await _client
        .from('weight_entries')
        .select()
        .eq('user_id', _user)
        .order('entry_date', ascending: false)
        .limit(1);
    if (rows.isEmpty) return null;
    return WeightEntry.fromJson(rows.first);
  }

  Future<List<WeightEntry>> history({int limit = 10}) async {
    final rows = await _client
        .from('weight_entries')
        .select()
        .eq('user_id', _user)
        .order('entry_date', ascending: false)
        .limit(limit);
    return rows
        .cast<Map<String, dynamic>>()
        .map(WeightEntry.fromJson)
        .toList(growable: false);
  }

  Future<void> setGoal(double? weightKg) async {
    await _client
        .from('profiles')
        .update({'weight_goal_kg': weightKg})
        .eq('id', _user);
  }

  /// Emits goal/weekly notifications for this user after a successful upsert.
  /// Fire-and-forget: failures are silent (the DB is authoritative).
  Future<void> notifyGoalIfMet() async {
    try {
      await _client.rpc('notify_weight_goal', params: {'p_user_id': _user});
    } on Exception {
      // Best effort; a retry happens on the next weight upsert.
    }
  }
}
