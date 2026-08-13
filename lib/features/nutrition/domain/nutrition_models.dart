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

  FoodEntry copyWith({
    String? id,
    String? foodId,
    String? foodName,
    MealType? mealType,
    double? quantity,
    String? unit,
    double? calories,
    double? proteinG,
    double? carbsG,
    double? fatG,
    String? photoUrl,
    DateTime? loggedAt,
  }) => FoodEntry(
    id: id ?? this.id,
    foodId: foodId ?? this.foodId,
    foodName: foodName ?? this.foodName,
    mealType: mealType ?? this.mealType,
    quantity: quantity ?? this.quantity,
    unit: unit ?? this.unit,
    calories: calories ?? this.calories,
    proteinG: proteinG ?? this.proteinG,
    carbsG: carbsG ?? this.carbsG,
    fatG: fatG ?? this.fatG,
    photoUrl: photoUrl ?? this.photoUrl,
    loggedAt: loggedAt ?? this.loggedAt,
  );
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
