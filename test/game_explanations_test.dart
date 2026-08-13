import 'package:flutter_test/flutter_test.dart';

import 'package:enfermicambio/features/game/domain/game_explanations.dart';
import 'package:enfermicambio/features/game/domain/game_models.dart';

void main() {
  test('competitive missions do not present target 1 as one step', () {
    const mission = Mission(
      id: 'night',
      name: 'Reto nocturno',
      description: 'Gana quien tenga más pasos.',
      missionType: 'competitive',
      rules: {'metric': 'night_steps', 'target': 1},
      rewardPoints: 10,
    );

    final explanation = missionTargetText(mission);

    expect(explanation, contains('gana quien consiga más pasos'));
    expect(explanation, isNot(contains('1 pasos')));
  });

  test('average mission explains the twenty percent rule', () {
    const mission = Mission(
      id: 'average',
      name: 'Supérate',
      description: 'Supera tu promedio.',
      missionType: 'individual',
      rules: {'metric': 'vs_14d_avg', 'target': 1.2},
      rewardPoints: 15,
    );

    expect(missionTargetText(mission), contains('20% más'));
    expect(formatGameValue('vs_14d_avg', 1.2), '120%');
  });
}

