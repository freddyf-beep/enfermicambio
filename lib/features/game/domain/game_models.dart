class SeasonStanding {
  const SeasonStanding({
    required this.seasonId,
    required this.userId,
    required this.displayName,
    required this.totalPoints,
    required this.position,
  });

  final String seasonId;
  final String userId;
  final String displayName;
  final double totalPoints;
  final int position;
}

class Season {
  const Season({
    required this.id,
    required this.name,
    required this.startsAt,
    required this.endsAt,
    required this.status,
  });

  final String id;
  final String name;
  final DateTime startsAt;
  final DateTime endsAt;
  final String status;
}
