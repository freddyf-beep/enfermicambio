import 'package:supabase_flutter/supabase_flutter.dart';

import '../domain/nutrition_profile.dart';

class SupabaseNutritionProfileRepository {
  const SupabaseNutritionProfileRepository({required this._client});

  final SupabaseClient _client;

  String get _userId =>
      _client.auth.currentUser?.id ??
      (throw StateError(
        'No hay una sesión para guardar el perfil nutricional.',
      ));

  Future<NutritionProfile?> load() async {
    final row = await _client
        .from('nutrition_profiles')
        .select()
        .eq('user_id', _userId)
        .maybeSingle();
    return row == null ? null : _fromRow(row);
  }

  Future<NutritionProfile> save(NutritionProfile profile) async {
    final row = await _client
        .from('nutrition_profiles')
        .upsert({
          'user_id': _userId,
          'birth_date': profile.birthDate == null
              ? null
              : _dateOnly(profile.birthDate!),
          'height_cm': profile.heightCm,
          'sex_for_formula': profile.sexForFormula?.name,
          'activity_level': _activityToDb(profile.activityLevel),
          'goal': profile.goal.name,
          'deficit_percent': profile.deficitPercent,
          'manual_calorie_target': profile.manualCalorieTarget,
        })
        .select()
        .single();
    return _fromRow(row);
  }

  Future<double?> latestWeightKg() async {
    final row = await _client
        .from('weight_entries')
        .select('weight_kg')
        .eq('user_id', _userId)
        .order('entry_date', ascending: false)
        .limit(1)
        .maybeSingle();
    return (row?['weight_kg'] as num?)?.toDouble();
  }

  Future<void> saveCalculatedDailyTarget(int target) => _client
      .from('profiles')
      .update({'daily_calorie_target': target})
      .eq('id', _userId);

  NutritionProfile _fromRow(Map<String, dynamic> row) => NutritionProfile(
    userId: row['user_id'] as String,
    birthDate: row['birth_date'] == null
        ? null
        : DateTime.parse(row['birth_date'] as String),
    heightCm: (row['height_cm'] as num?)?.toDouble(),
    sexForFormula: switch (row['sex_for_formula']) {
      'female' => FormulaSex.female,
      'male' => FormulaSex.male,
      _ => null,
    },
    activityLevel: switch (row['activity_level']) {
      'sedentary' => ActivityLevel.sedentary,
      'light' => ActivityLevel.light,
      'active' => ActivityLevel.active,
      'very_active' => ActivityLevel.veryActive,
      _ => ActivityLevel.moderate,
    },
    goal: switch (row['goal']) {
      'lose' => NutritionGoal.lose,
      'gain' => NutritionGoal.gain,
      _ => NutritionGoal.maintain,
    },
    deficitPercent: (row['deficit_percent'] as num?)?.toDouble() ?? 15,
    manualCalorieTarget: (row['manual_calorie_target'] as num?)?.toInt(),
  );

  String _activityToDb(ActivityLevel level) => switch (level) {
    ActivityLevel.sedentary => 'sedentary',
    ActivityLevel.light => 'light',
    ActivityLevel.moderate => 'moderate',
    ActivityLevel.active => 'active',
    ActivityLevel.veryActive => 'very_active',
  };

  String _dateOnly(DateTime value) =>
      '${value.year.toString().padLeft(4, '0')}-${value.month.toString().padLeft(2, '0')}-${value.day.toString().padLeft(2, '0')}';
}
