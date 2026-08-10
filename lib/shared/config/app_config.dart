class AppConfig {
  const AppConfig({
    required this.competitionTimezone,
    required this.morningStartHour,
    required this.afternoonStartHour,
    required this.nightStartHour,
  });

  const AppConfig.defaults()
    : competitionTimezone = 'America/Santiago',
      morningStartHour = 6,
      afternoonStartHour = 12,
      nightStartHour = 18;

  final String competitionTimezone;
  final int morningStartHour;
  final int afternoonStartHour;
  final int nightStartHour;

  CompetitionWindows get windows => CompetitionWindows(
    morning: CompetitionWindow(
      name: 'morning',
      startHour: morningStartHour,
      endHour: afternoonStartHour,
    ),
    afternoon: CompetitionWindow(
      name: 'afternoon',
      startHour: afternoonStartHour,
      endHour: nightStartHour,
    ),
    night: CompetitionWindow(
      name: 'night',
      startHour: nightStartHour,
      endHour: 24,
    ),
  );
}

class CompetitionWindows {
  const CompetitionWindows({
    required this.morning,
    required this.afternoon,
    required this.night,
  });

  final CompetitionWindow morning;
  final CompetitionWindow afternoon;
  final CompetitionWindow night;

  List<CompetitionWindow> get all => [morning, afternoon, night];
}

class CompetitionWindow {
  const CompetitionWindow({
    required this.name,
    required this.startHour,
    required this.endHour,
  });

  final String name;
  final int startHour;
  final int endHour;
}
