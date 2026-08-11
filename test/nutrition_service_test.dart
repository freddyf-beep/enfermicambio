import 'package:flutter_test/flutter_test.dart';

import 'package:enfermicambio/features/nutrition/domain/nutrition_models.dart';
import 'package:enfermicambio/features/nutrition/domain/nutrition_service.dart';

void main() {
  const service = NutritionService();

  test('sums daily nutrition across entries', () {
    final totals = service.totalsForDay(
      entries: [
        FoodEntry(
          id: 'a',
          foodName: 'Rice',
          mealType: MealType.lunch,
          quantity: 1,
          unit: 'serving',
          calories: 300,
          proteinG: 6,
          carbsG: 60,
          fatG: 1,
          loggedAt: DateTime.utc(2026, 8, 10, 13),
        ),
        FoodEntry(
          id: 'b',
          foodName: 'Chicken',
          mealType: MealType.dinner,
          quantity: 1,
          unit: 'serving',
          calories: 400,
          proteinG: 40,
          carbsG: 0,
          fatG: 10,
          loggedAt: DateTime.utc(2026, 8, 10, 20),
        ),
      ],
      targetCalories: 2200,
    );

    expect(totals.calories, 700);
    expect(totals.proteinG, 46);
    expect(totals.carbsG, 60);
    expect(totals.fatG, 11);
    expect(totals.withinCalorieTarget, isTrue);
    expect(totals.remainingCalories, 1500);
  });

  test('is not within calorie target when over', () {
    final totals = service.totalsForDay(
      entries: [
        FoodEntry(
          id: 'a',
          foodName: 'Pizza',
          mealType: MealType.dinner,
          quantity: 1,
          unit: 'serving',
          calories: 2500,
          proteinG: 90,
          carbsG: 250,
          fatG: 90,
          loggedAt: DateTime.utc(2026, 8, 10, 20),
        ),
      ],
      targetCalories: 2200,
    );

    expect(totals.withinCalorieTarget, isFalse);
    expect(totals.remainingCalories, -300);
  });

  test('scales food nutrition by quantity', () {
    final food = Food(
      id: 'f1',
      name: 'Oats',
      servingSize: 40,
      servingUnit: 'g',
      calories: 150,
      proteinG: 5,
      carbsG: 27,
      fatG: 3,
      source: 'offer',
    );

    final scaled = service.scaledFood(food, quantity: 80);

    expect(scaled.calories, 300);
    expect(scaled.proteinG, 10);
    expect(scaled.servingSize, 80);
  });

  test('builds an entry with the nutrition snapshot', () {
    final food = Food(
      id: 'f1',
      name: 'Yogurt',
      servingSize: 100,
      servingUnit: 'g',
      calories: 60,
      proteinG: 4,
      carbsG: 5,
      fatG: 2,
      source: 'offer',
    );

    final entry = service.entryFromFood(
      food: food,
      quantity: 200,
      mealType: MealType.breakfast,
      loggedAt: DateTime.utc(2026, 8, 10, 9),
    );

    expect(entry.calories, 120);
    expect(entry.mealType, MealType.breakfast);
    expect(entry.foodId, 'f1');
  });
}
