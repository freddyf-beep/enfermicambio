import '../../lib/features/profiles/domain/profile_models.dart';
import '../../lib/features/ranking/domain/ranking_models.dart';
import '../../lib/features/game/domain/game_models.dart';

class UserMocks {
  static const String idFreddy = 'user-freddy-001';
  static const String idFelipe = 'user-felipe-002';
  static const String idCristian = 'user-cristian-003';
  static const String idSamir = 'user-samir-004';

  static const String emailFreddy = 'udefret12@gmail.com';
  static const String emailFelipe = 'felipe@gmail.com';
  static const String emailCristian = 'cristiancarrillo262@gmail.com';
  static const String emailSamir = 'Samineiror123@gmail.com';

  static final List<UserProfile> fourProfiles = [
    UserProfile(
      id: idFreddy,
      displayName: 'Freddy',
      timezone: 'America/Santiago',
      dailyCalorieTarget: 2200,
      dailyStepTarget: 10000,
      weeklyWorkoutTarget: 4,
    ),
    UserProfile(
      id: idFelipe,
      displayName: 'Felipe',
      timezone: 'America/Santiago',
      dailyCalorieTarget: 2300,
      dailyStepTarget: 10000,
      weeklyWorkoutTarget: 3,
    ),
    UserProfile(
      id: idCristian,
      displayName: 'Cristian',
      timezone: 'America/Santiago',
      dailyCalorieTarget: 2400,
      dailyStepTarget: 12000,
      weeklyWorkoutTarget: 4,
    ),
    UserProfile(
      id: idSamir,
      displayName: 'Samir',
      timezone: 'America/Santiago',
      dailyCalorieTarget: 2100,
      dailyStepTarget: 10000,
      weeklyWorkoutTarget: 3,
    ),
  ];

  static final List<RankingRow> mockStepRankings = [
    RankingRow(
      userId: idFreddy,
      displayName: 'Freddy',
      value: 11450,
      rank: 1,
      freshness: UserFreshness.fresh,
    ),
    RankingRow(
      userId: idCristian,
      displayName: 'Cristian',
      value: 10200,
      rank: 2,
      freshness: UserFreshness.fresh,
    ),
    RankingRow(
      userId: idFelipe,
      displayName: 'Felipe',
      value: 8900,
      rank: 3,
      freshness: UserFreshness.stale,
    ),
    RankingRow(
      userId: idSamir,
      displayName: 'Samir',
      value: 7800,
      rank: 4,
      freshness: UserFreshness.fresh,
    ),
  ];

  static final List<SeasonStanding> mockSeasonStandings = [
    SeasonStanding(
      seasonId: 'season-001',
      userId: idFreddy,
      displayName: 'Freddy',
      totalPoints: 48,
      position: 1,
    ),
    SeasonStanding(
      seasonId: 'season-001',
      userId: idCristian,
      displayName: 'Cristian',
      totalPoints: 42,
      position: 2,
    ),
    SeasonStanding(
      seasonId: 'season-001',
      userId: idFelipe,
      displayName: 'Felipe',
      totalPoints: 36,
      position: 3,
    ),
    SeasonStanding(
      seasonId: 'season-001',
      userId: idSamir,
      displayName: 'Samir',
      totalPoints: 30,
      position: 4,
    ),
  ];
}
