import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:enfermicambio/features/game/domain/game_models.dart';
import 'package:enfermicambio/features/game/presentation/game_tab.dart';

void main() {
  group('Game models parse backend rows', () {
    test('Mission parses rules and rewards', () {
      final mission = Mission.fromJson({
        'id': 'm1',
        'name': 'Madrugador',
        'description': '2.500 pasos antes del mediodía',
        'mission_type': 'individual',
        'rules': {'metric': 'morning_steps', 'target': 2500},
        'reward_points': 10,
      });
      expect(mission.name, 'Madrugador');
      expect(mission.rules['metric'], 'morning_steps');
      expect(mission.rewardPoints, 10);
    });

    test('MissionProgress exposes metric values', () {
      final progress = MissionProgress.fromJson({
        'mission_id': 'm1',
        'progress_date': '2026-08-11',
        'progress': {'morning_steps': 1250},
        'completed': false,
      });
      expect(progress.valueOf('morning_steps'), 1250);
      expect(progress.completed, isFalse);
    });

    test('Achievement parses hidden flag', () {
      final secret = Achievement.fromJson({
        'id': 'a3',
        'code': 'SECRETA',
        'name': 'Logro secreto',
        'description': 'Solo se ve al desbloquearlo',
        'icon': 'lock',
        'hidden': true,
      });
      expect(secret.hidden, isTrue);
      expect(secret.name, 'Logro secreto');
    });

    test('Streak parses counts', () {
      final streak = Streak.fromJson({
        'streak_type': 'step_goal',
        'current_count': 3,
        'longest_count': 7,
      });
      expect(streak.currentCount, 3);
      expect(streak.longestCount, 7);
    });

    test('BattlePassTier parses rewards', () {
      final tier = BattlePassTier.fromJson({
        'tier': 1,
        'threshold_points': 10,
        'reward_type': 'badge',
        'reward_key': 'badge_1',
        'reward_name': 'Iniciado del mes',
        'reward_icon': 'military_tech',
      });
      expect(tier.rewardName, 'Iniciado del mes');
      expect(tier.thresholdPoints, 10);
    });

    test('SeasonKm parses km', () {
      final km = SeasonKm.fromJson({
        'user_id': 'u1',
        'display_name': 'Freddy',
        'km': 42.5,
      });
      expect(km.km, 42.5);
      expect(km.displayName, 'Freddy');
    });
  });

  group('GameTab widget', () {
    testWidgets('JUEGO muestra misiones reales con progreso', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: GameTab(loadFromBackend: false, snapshot: buildSnapshot()),
        ),
      );
      expect(find.text('Misiones del Día'), findsOneWidget);
      expect(find.text('Madrugador'), findsOneWidget);
      expect(find.textContaining('1.250'), findsOneWidget);
    });

    testWidgets('JUEGO muestra logros, pase, rachas y km', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: GameTab(loadFromBackend: false, snapshot: buildSnapshot()),
        ),
      );
      expect(find.text('Pase de Batalla'), findsOneWidget);
      expect(find.text('Iniciado del mes'), findsOneWidget);

      await tester.scrollUntilVisible(
        find.text('Club 5K'),
        300,
        scrollable: find.byType(Scrollable).first,
      );
      expect(find.text('Club 5K'), findsOneWidget);
      expect(find.text('Piernas de maratón'), findsOneWidget);

      await tester.scrollUntilVisible(
        find.textContaining('3 días seguidos'),
        300,
        scrollable: find.byType(Scrollable).first,
      );
      expect(find.textContaining('3 días seguidos'), findsOneWidget);

      await tester.scrollUntilVisible(
        find.textContaining('42.5'),
        300,
        scrollable: find.byType(Scrollable).first,
      );
      expect(find.textContaining('42.5'), findsOneWidget);
    });
  });
}

GameSnapshot buildSnapshot() => const GameSnapshot(
  seasonName: 'Temporada Agosto 2026',
  seasonStatus: 'active',
  standings: [
    SeasonStanding(
      seasonId: 's1',
      userId: 'u1',
      displayName: 'Freddy',
      totalPoints: 120,
      position: 1,
    ),
    SeasonStanding(
      seasonId: 's1',
      userId: 'u2',
      displayName: 'Felipe',
      totalPoints: 90,
      position: 2,
    ),
  ],
  missions: [
    Mission(
      id: 'm1',
      name: 'Madrugador',
      description: '2.500 pasos antes del mediodía',
      missionType: 'individual',
      rules: {'metric': 'morning_steps', 'target': 2500},
      rewardPoints: 10,
    ),
  ],
  missionProgress: {
    'm1': MissionProgress(
      missionId: 'm1',
      progressDate: '2026-08-11',
      progress: {'morning_steps': 1250},
      completed: false,
    ),
  },
  achievements: [
    Achievement(
      id: 'a1',
      code: '5K_CLUB',
      name: 'Club 5K',
      description: '5.000 pasos en un día',
      icon: 'directions_walk',
      hidden: false,
    ),
    Achievement(
      id: 'a2',
      code: 'MARATHON_LEGS',
      name: 'Piernas de maratón',
      description: '25.000 pasos en un día',
      icon: 'directions_run',
      hidden: false,
    ),
    Achievement(
      id: 'a3',
      code: 'SECRETA',
      name: 'Logro secreto',
      description: 'Solo se ve al desbloquearlo',
      icon: 'lock',
      hidden: true,
    ),
  ],
  unlockedAchievements: {'a1'},
  streaks: [Streak(streakType: 'step_goal', currentCount: 3, longestCount: 7)],
  battlePassTiers: [
    BattlePassTier(
      tier: 1,
      thresholdPoints: 10,
      rewardType: 'badge',
      rewardKey: 'badge_1',
      rewardName: 'Iniciado del mes',
      rewardIcon: 'military_tech',
    ),
  ],
  battlePassClaims: {1},
  seasonKm: [SeasonKm(userId: 'u1', displayName: 'Freddy', km: 42.5)],
);
