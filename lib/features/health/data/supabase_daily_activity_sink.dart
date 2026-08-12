import 'package:supabase_flutter/supabase_flutter.dart';

import '../domain/health_models.dart';

class SupabaseDailyActivitySink implements DailyActivitySink {
  const SupabaseDailyActivitySink({
    required this._client,
    required this._userId,
  });

  final SupabaseClient _client;
  final String _userId;

  @override
  Future<void> upsert(DailyActivityAggregate aggregate) async {
    final sourcePlatform = aggregate.sourcePlatform;
    if (sourcePlatform != 'ios' && sourcePlatform != 'android') {
      throw StateError(
        'A supported source platform is required before persisting activity.',
      );
    }

    await _client.from('daily_activity').upsert({
      'user_id': _userId,
      'activity_date': _dateOnly(aggregate.date),
      'morning_steps': aggregate.morningSteps,
      'afternoon_steps': aggregate.afternoonSteps,
      'night_steps': aggregate.nightSteps,
      'daily_steps': aggregate.dailySteps,
      'active_calories': aggregate.activeCalories,
      'distance_meters': aggregate.distanceMeters,
      'exercise_minutes': aggregate.exerciseMinutes,
      'synced_at': aggregate.syncedAt.toUtc().toIso8601String(),
      'source_platform': sourcePlatform,
      'source_app': aggregate.sourceApp,
      'source_device': aggregate.sourceDevice,
      'recording_method': aggregate.recordingMethod,
      'manual_entry_detected': aggregate.manualRecordsExcluded > 0,
      'source_metadata': aggregate.sourceMetadata,
    }, onConflict: 'user_id,activity_date');
  }

  String _dateOnly(DateTime value) {
    // [aggregate.date] is already a competition-calendar date, not an
    // instant. Converting it to UTC can move it to the previous day for
    // positive-offset zones such as Android devices in India or Australia.
    return '${value.year.toString().padLeft(4, '0')}-'
        '${value.month.toString().padLeft(2, '0')}-'
        '${value.day.toString().padLeft(2, '0')}';
  }
}
