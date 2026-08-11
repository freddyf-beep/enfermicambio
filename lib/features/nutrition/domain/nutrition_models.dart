enum MealType { breakfast, lunch, dinner, snack, other }

class Food {
  const Food({
    required this.id,
    required this.name,
    required this.servingSize,
    required this.servingUnit,
    required this.calories,
    required this.proteinG,
    required this.carbsG,
    required this.fatG,
    required this.source,
    this.barcode,
    this.brand,
  });

  final String id;
  final String name;
  final String? barcode;
  final String? brand;
  final double servingSize;
  final String servingUnit;
  final double calories;
  final double proteinG;
  final double carbsG;
  final double fatG;
  final String source;
}

class FoodEntry {
  const FoodEntry({
    required this.id,
    required this.foodName,
    required this.mealType,
    required this.quantity,
    required this.unit,
    required this.calories,
    required this.proteinG,
    required this.carbsG,
    required this.fatG,
    required this.loggedAt,
    this.foodId,
    this.photoUrl,
  });

  final String id;
  final String? foodId;
  final String foodName;
  final MealType mealType;
  final double quantity;
  final String unit;
  final double calories;
  final double proteinG;
  final double carbsG;
  final double fatG;
  final String? photoUrl;
  final DateTime loggedAt;
}

class DailyNutritionTotals {
  const DailyNutritionTotals({
    required this.calories,
    required this.proteinG,
    required this.carbsG,
    required this.fatG,
    required this.targetCalories,
  });

  final double calories;
  final double proteinG;
  final double carbsG;
  final double fatG;
  final double targetCalories;

  double get remainingCalories => targetCalories - calories;

  bool get withinCalorieTarget => calories <= targetCalories;
}
