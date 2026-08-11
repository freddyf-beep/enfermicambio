import 'package:flutter_test/flutter_test.dart';

import 'package:enfermicambio/features/game/domain/achievement_engine.dart';

void main() {
  const engine = AchievementEngine();

  const tenK = Achievement(
    code: '10K_CLUB',
    name: '10K CLUB',
    metric: 'daily_steps',
    operator: AchievementOperator.gte,
    threshold: 10000,
    repeatable: false,
    hidden: false,
    seasonPoints: 0,
  );

  test('unlocks when the metric meets the threshold', () {
    expect(engine.evaluate(tenK, 12000), isTrue);
    expect(engine.evaluate(tenK, 10000), isTrue);
  });

  test('does not unlock below the threshold', () {
    expect(engine.evaluate(tenK, 9999), isFalse);
  });

  test('evaluates all achievements with per-metric values', () {
    final results = engine.evaluateAll(
      achievements: const [tenK],
      valueFor: (metric) => metric == 'daily_steps' ? 15000 : 0,
    );

    expect(results.single.unlocked, isTrue);
    expect(results.single.metricValue, 15000);
  });
}
