import 'package:flutter_test/flutter_test.dart';

import 'package:enfermicambio/features/nutrition/domain/nutrition_profile.dart';

void main() {
  const planner = CaloriePlanner();
  final profile = NutritionProfile(
    userId: 'freddy',
    birthDate: DateTime(2000, 1, 1),
    heightCm: 175,
    sexForFormula: FormulaSex.male,
    activityLevel: ActivityLevel.moderate,
    goal: NutritionGoal.maintain,
  );

  test(
    'calculates maintenance using Mifflin-St Jeor for a complete profile',
    () {
      final plan = planner.calculate(
        profile: profile,
        weightKg: 70,
        today: DateTime(2026, 8, 13),
      );
      expect(plan.bmr, closeTo(1668.75, 0.1));
      expect(plan.tdee, closeTo(2586.56, 0.1));
      expect(plan.target, 2587);
    },
  );

  test('uses a fifteen percent loss target and a ten percent gain target', () {
    final loss = planner.calculate(
      profile: NutritionProfile(
        userId: profile.userId,
        birthDate: profile.birthDate,
        heightCm: profile.heightCm,
        sexForFormula: profile.sexForFormula,
        activityLevel: profile.activityLevel,
        goal: NutritionGoal.lose,
      ),
      weightKg: 70,
      today: DateTime(2026, 8, 13),
    );
    final gain = planner.calculate(
      profile: NutritionProfile(
        userId: profile.userId,
        birthDate: profile.birthDate,
        heightCm: profile.heightCm,
        sexForFormula: profile.sexForFormula,
        activityLevel: profile.activityLevel,
        goal: NutritionGoal.gain,
      ),
      weightKg: 70,
      today: DateTime(2026, 8, 13),
    );
    expect(loss.target, 2199);
    expect(gain.target, 2845);
  });

  test('does not guess missing data but accepts a manual target', () {
    const incomplete = NutritionProfile(userId: 'sammy');
    final missing = planner.calculate(profile: incomplete, weightKg: null);
    expect(missing.target, isNull);
    expect(missing.missingInputs, containsAll(['peso actual', 'altura']));

    final manual = planner.calculate(
      profile: const NutritionProfile(
        userId: 'sammy',
        manualCalorieTarget: 2100,
      ),
      weightKg: null,
    );
    expect(manual.target, 2100);
    expect(manual.isManual, isTrue);
  });
}
