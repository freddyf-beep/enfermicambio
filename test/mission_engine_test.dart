import 'package:flutter_test/flutter_test.dart';

import 'package:enfermicambio/features/game/domain/mission_engine.dart';
import 'package:enfermicambio/features/game/domain/mission_models.dart';

void main() {
  const engine = MissionEngine();

  const earlyBird = Mission(
    id: 'm1',
    name: 'EARLY BIRD',
    missionType: MissionType.individual,
    rules: {'metric': 'steps', 'target': 2500},
    rewardPoints: 10,
  );

  test('tracks progress toward an individual target', () {
    final first = engine.apply(mission: earlyBird, previous: null, delta: 1000);
    expect(first.completed, isFalse);
    expect(first.progress['steps'], 1000);

    final second = engine.apply(
      mission: earlyBird,
      previous: MissionProgressState(
        progress: first.progress,
        completed: first.completed,
        completedAt: null,
      ),
      delta: 2000,
    );
    expect(second.completed, isTrue);
    expect(second.progress['steps'], 3000);
  });

  test('marks complete exactly at the target', () {
    final result = engine.apply(
      mission: earlyBird,
      previous: null,
      delta: 2500,
    );
    expect(result.completed, isTrue);
  });

  test('cooperative mission sums all member deltas', () {
    const group = Mission(
      id: 'm2',
      name: 'THE FOUR',
      missionType: MissionType.cooperative,
      rules: {'metric': 'steps', 'target': 40000},
      rewardPoints: 20,
    );

    final result = engine.applyGroup(
      mission: group,
      memberDeltas: [10000, 10000, 10000, 10000],
    );
    expect(result.progress['steps'], 40000);
    expect(result.completed, isTrue);
  });

  test('competitive mission applies individually', () {
    const duel = Mission(
      id: 'm3',
      name: 'DUEL',
      missionType: MissionType.competitive,
      rules: {'metric': 'steps', 'target': 1000},
      rewardPoints: 5,
    );

    final result = engine.apply(mission: duel, previous: null, delta: 1500);
    expect(result.completed, isTrue);
  });
}
