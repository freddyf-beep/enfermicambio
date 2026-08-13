enum NutritionGoal { maintain, lose, gain }

enum ActivityLevel { sedentary, light, moderate, active, veryActive }

enum FormulaSex { female, male }

class NutritionProfile {
  const NutritionProfile({
    required this.userId,
    this.birthDate,
    this.heightCm,
    this.sexForFormula,
    this.activityLevel = ActivityLevel.moderate,
    this.goal = NutritionGoal.maintain,
    this.deficitPercent = 15,
    this.manualCalorieTarget,
  });

  final String userId;
  final DateTime? birthDate;
  final double? heightCm;
  final FormulaSex? sexForFormula;
  final ActivityLevel activityLevel;
  final NutritionGoal goal;
  final double deficitPercent;
  final int? manualCalorieTarget;

  bool get isCompleteForCalculation =>
      birthDate != null && heightCm != null && sexForFormula != null;
}

class CaloriePlan {
  const CaloriePlan({
    this.bmr,
    this.tdee,
    this.suggestedTarget,
    this.target,
    this.missingInputs = const [],
    this.isManual = false,
  });

  final double? bmr;
  final double? tdee;
  final int? suggestedTarget;
  final int? target;
  final List<String> missingInputs;
  final bool isManual;

  bool get canCalculate => target != null;
}

/// An adult-only, orientative Mifflin-St Jeor estimate. It deliberately does
/// not guess sex or missing body data: the caller may still choose a manual
/// daily target instead.
class CaloriePlanner {
  const CaloriePlanner();

  CaloriePlan calculate({
    required NutritionProfile profile,
    required double? weightKg,
    DateTime? today,
  }) {
    if (profile.manualCalorieTarget != null) {
      return CaloriePlan(target: profile.manualCalorieTarget, isManual: true);
    }

    final missing = <String>[];
    if (weightKg == null) missing.add('peso actual');
    if (profile.birthDate == null) missing.add('fecha de nacimiento');
    if (profile.heightCm == null) missing.add('altura');
    if (profile.sexForFormula == null) missing.add('sexo para la ecuación');
    if (missing.isNotEmpty) return CaloriePlan(missingInputs: missing);

    final now = today ?? DateTime.now();
    final age = _ageAt(profile.birthDate!, now);
    final factor = profile.sexForFormula == FormulaSex.male ? 5 : -161;
    final bmr = 10 * weightKg! + 6.25 * profile.heightCm! - 5 * age + factor;
    final tdee = bmr * _activityMultiplier(profile.activityLevel);
    final multiplier = switch (profile.goal) {
      NutritionGoal.maintain => 1.0,
      NutritionGoal.lose => 1 - (profile.deficitPercent / 100),
      NutritionGoal.gain => 1.10,
    };
    final target = (tdee * multiplier).round();
    return CaloriePlan(
      bmr: bmr,
      tdee: tdee,
      suggestedTarget: target,
      target: target,
    );
  }

  int _ageAt(DateTime birthDate, DateTime today) {
    var age = today.year - birthDate.year;
    if (today.month < birthDate.month ||
        (today.month == birthDate.month && today.day < birthDate.day)) {
      age--;
    }
    return age;
  }

  double _activityMultiplier(ActivityLevel level) => switch (level) {
    ActivityLevel.sedentary => 1.2,
    ActivityLevel.light => 1.375,
    ActivityLevel.moderate => 1.55,
    ActivityLevel.active => 1.725,
    ActivityLevel.veryActive => 1.9,
  };
}
