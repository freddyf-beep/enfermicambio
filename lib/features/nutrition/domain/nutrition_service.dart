import 'nutrition_models.dart';

class NutritionService {
  const NutritionService();

  DailyNutritionTotals totalsForDay({
    required List<FoodEntry> entries,
    required double targetCalories,
  }) {
    var calories = 0.0;
    var protein = 0.0;
    var carbs = 0.0;
    var fat = 0.0;
    for (final entry in entries) {
      calories += entry.calories;
      protein += entry.proteinG;
      carbs += entry.carbsG;
      fat += entry.fatG;
    }
    return DailyNutritionTotals(
      calories: calories,
      proteinG: protein,
      carbsG: carbs,
      fatG: fat,
      targetCalories: targetCalories,
    );
  }

  Food scaledFood(Food food, {required double quantity}) {
    final factor = quantity / food.servingSize;
    return Food(
      id: food.id,
      name: food.name,
      barcode: food.barcode,
      brand: food.brand,
      servingSize: quantity,
      servingUnit: food.servingUnit,
      calories: food.calories * factor,
      proteinG: food.proteinG * factor,
      carbsG: food.carbsG * factor,
      fatG: food.fatG * factor,
      source: food.source,
    );
  }

  FoodEntry entryFromFood({
    required Food food,
    required double quantity,
    required MealType mealType,
    required DateTime loggedAt,
  }) {
    final scaled = scaledFood(food, quantity: quantity);
    return FoodEntry(
      id: '',
      foodId: food.id,
      foodName: food.name,
      mealType: mealType,
      quantity: quantity,
      unit: food.servingUnit,
      calories: scaled.calories,
      proteinG: scaled.proteinG,
      carbsG: scaled.carbsG,
      fatG: scaled.fatG,
      loggedAt: loggedAt,
    );
  }
}
