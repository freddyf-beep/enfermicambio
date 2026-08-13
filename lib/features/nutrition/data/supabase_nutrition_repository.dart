import 'package:supabase_flutter/supabase_flutter.dart';

import '../domain/nutrition_models.dart';

/// Persists the food catalogue and the nutrition snapshot used by a meal log.
///
/// The snapshot is written to `food_entries`, so a later change in Open Food
/// Facts cannot rewrite what the user recorded on an earlier day.
class SupabaseNutritionRepository {
  SupabaseNutritionRepository({required this._client});

  final SupabaseClient _client;

  String get _userId =>
      _client.auth.currentSession?.user.id ??
      (throw StateError('No authenticated user for nutrition.'));

  Future<Food> saveFood(Food food) async {
    final values = {
      'barcode': food.barcode,
      'name': food.name,
      'brand': food.brand,
      'serving_size': food.servingSize,
      'serving_unit': food.servingUnit,
      'calories': food.calories,
      'protein_g': food.proteinG,
      'carbs_g': food.carbsG,
      'fat_g': food.fatG,
      'source': food.source,
      'created_by': _userId,
    };

    final Map<String, dynamic> row;
    final barcode = food.barcode?.trim();
    if (barcode != null && barcode.isNotEmpty) {
      // A barcode is shared by the group. Reusing an existing row avoids
      // requiring the current user to update a food created by someone else.
      final existing = await findByBarcode(barcode);
      if (existing != null) return existing;
      try {
        row = await _client.from('foods').insert(values).select().single();
      } on PostgrestException catch (error) {
        // Two friends may scan the same product at the same time. The unique
        // constraint wins the race; return the row that the other friend just
        // created instead of surfacing a false failure to the user.
        if (error.code == '23505') {
          final raced = await findByBarcode(barcode);
          if (raced != null) return raced;
        }
        rethrow;
      }
    } else {
      row = await _client.from('foods').insert(values).select().single();
    }
    return _foodFromRow(row);
  }

  Future<FoodEntry> createEntry(FoodEntry entry) async {
    final row = await _client
        .from('food_entries')
        .insert({
          'user_id': _userId,
          'food_id': entry.foodId,
          'food_name_snapshot': entry.foodName,
          'logged_at': entry.loggedAt.toUtc().toIso8601String(),
          'meal_type': entry.mealType.name,
          'quantity': entry.quantity,
          'unit': entry.unit,
          'calories': entry.calories,
          'protein_g': entry.proteinG,
          'carbs_g': entry.carbsG,
          'fat_g': entry.fatG,
          'source': 'manual',
          'photo_url': entry.photoUrl,
        })
        .select()
        .single();
    return FoodEntry(
      id: row['id'] as String,
      foodId: row['food_id'] as String?,
      foodName: entry.foodName,
      mealType: entry.mealType,
      quantity: (row['quantity'] as num).toDouble(),
      unit: row['unit'] as String,
      calories: (row['calories'] as num).toDouble(),
      proteinG: (row['protein_g'] as num).toDouble(),
      carbsG: (row['carbs_g'] as num).toDouble(),
      fatG: (row['fat_g'] as num).toDouble(),
      loggedAt: DateTime.parse(row['logged_at'] as String),
      photoUrl: row['photo_url'] as String?,
    );
  }

  /// Creates a new meal snapshot or updates an existing personal entry.
  Future<FoodEntry> saveEntry(FoodEntry entry) =>
      entry.id.isEmpty ? createEntry(entry) : updateEntry(entry);

  Future<List<FoodEntry>> listEntriesForDay({DateTime? day}) async {
    final target = day ?? DateTime.now();
    final start = DateTime(target.year, target.month, target.day);
    final end = start.add(const Duration(days: 1));
    final rows = await _client
        .from('food_entries')
        .select()
        .eq('user_id', _userId)
        .gte('logged_at', start.toUtc().toIso8601String())
        .lt('logged_at', end.toUtc().toIso8601String())
        .order('logged_at', ascending: false);
    return rows
        .cast<Map<String, dynamic>>()
        .map(_entryFromRow)
        .toList(growable: false);
  }

  Future<FoodEntry> updateEntry(FoodEntry entry) async {
    final row = await _client
        .from('food_entries')
        .update({
          'meal_type': entry.mealType.name,
          'quantity': entry.quantity,
          'unit': entry.unit,
          'calories': entry.calories,
          'protein_g': entry.proteinG,
          'carbs_g': entry.carbsG,
          'fat_g': entry.fatG,
          'notes': null,
          'food_name_snapshot': entry.foodName,
        })
        .eq('id', entry.id)
        .eq('user_id', _userId)
        .select()
        .single();
    return _entryFromRow(row);
  }

  Future<void> deleteEntry(String id) =>
      _client.from('food_entries').delete().eq('id', id).eq('user_id', _userId);

  Future<List<Food>> searchFoods(String text) async {
    final query = text.trim();
    if (query.isEmpty) return const [];
    final rows = await _client
        .from('foods')
        .select()
        .ilike('name', '%$query%')
        .order('name')
        .limit(20);
    return rows
        .cast<Map<String, dynamic>>()
        .map(_foodFromRow)
        .toList(growable: false);
  }

  Future<Food?> findByBarcode(String barcode) async {
    final value = barcode.trim();
    if (value.isEmpty) return null;
    final row = await _client
        .from('foods')
        .select()
        .eq('barcode', value)
        .maybeSingle();
    return row == null ? null : _foodFromRow(row);
  }

  Food _foodFromRow(Map<String, dynamic> row) {
    return Food(
      id: row['id'] as String,
      name: row['name'] as String,
      barcode: row['barcode'] as String?,
      brand: row['brand'] as String?,
      servingSize: (row['serving_size'] as num).toDouble(),
      servingUnit: row['serving_unit'] as String,
      calories: (row['calories'] as num).toDouble(),
      proteinG: (row['protein_g'] as num).toDouble(),
      carbsG: (row['carbs_g'] as num).toDouble(),
      fatG: (row['fat_g'] as num).toDouble(),
      source: row['source'] as String,
    );
  }

  FoodEntry _entryFromRow(Map<String, dynamic> row) => FoodEntry(
    id: row['id'] as String,
    foodId: row['food_id'] as String?,
    foodName: (row['food_name_snapshot'] as String?)?.trim().isNotEmpty == true
        ? row['food_name_snapshot'] as String
        : 'Alimento',
    mealType: MealType.values.firstWhere(
      (value) => value.name == row['meal_type'],
      orElse: () => MealType.other,
    ),
    quantity: (row['quantity'] as num).toDouble(),
    unit: row['unit'] as String,
    calories: (row['calories'] as num).toDouble(),
    proteinG: (row['protein_g'] as num).toDouble(),
    carbsG: (row['carbs_g'] as num).toDouble(),
    fatG: (row['fat_g'] as num).toDouble(),
    photoUrl: row['photo_url'] as String?,
    loggedAt: DateTime.parse(row['logged_at'] as String).toLocal(),
  );
}
