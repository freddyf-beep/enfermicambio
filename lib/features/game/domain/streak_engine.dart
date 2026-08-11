import 'package:timezone/timezone.dart' as timezone;

enum StreakType { stepGoal, workout, calorieTarget }

class StreakState {
  const StreakState({
    required this.currentCount,
    required this.longestCount,
    required this.lastQualifiedDate,
  });

  final int currentCount;
  final int longestCount;
  final DateTime? lastQualifiedDate;

  bool get isActive => lastQualifiedDate != null && currentCount > 0;
}

class StreakTransitionResult {
  const StreakTransitionResult({required this.state, required this.action});

  final StreakState state;
  final StreakAction action;
}

enum StreakAction { none, qualified, extended, broken }

class StreakEngine {
  const StreakEngine({required this.competitionTimezone});

  final String competitionTimezone;

  /// Applies one day's qualification. [dayStart] is a DateTime whose date
  /// represents the competition day (timezone-aware by the caller).
  StreakTransitionResult apply({
    required StreakState previous,
    required DateTime dayStart,
    required bool qualified,
  }) {
    if (!qualified) {
      if (previous.currentCount == 0) {
        return StreakTransitionResult(
          state: previous,
          action: StreakAction.none,
        );
      }
      return StreakTransitionResult(
        state: StreakState(
          currentCount: 0,
          longestCount: previous.longestCount,
          lastQualifiedDate: null,
        ),
        action: StreakAction.broken,
      );
    }

    final location = timezone.getLocation(competitionTimezone);
    final day = timezone.TZDateTime(
      location,
      dayStart.year,
      dayStart.month,
      dayStart.day,
    ).toUtc();

    final last = previous.lastQualifiedDate?.toUtc();
    if (last == null) {
      return StreakTransitionResult(
        state: StreakState(
          currentCount: 1,
          longestCount: 1,
          lastQualifiedDate: day,
        ),
        action: StreakAction.qualified,
      );
    }

    final dayDiff = day.difference(last).inDays;
    if (dayDiff == 0) {
      // Same day re-qualified; state unchanged.
      return StreakTransitionResult(state: previous, action: StreakAction.none);
    }

    final isConsecutive = dayDiff == 1;
    final nextCount = isConsecutive ? previous.currentCount + 1 : 1;
    final nextLongest = nextCount > previous.longestCount
        ? nextCount
        : previous.longestCount;

    return StreakTransitionResult(
      state: StreakState(
        currentCount: nextCount,
        longestCount: nextLongest,
        lastQualifiedDate: day,
      ),
      action: isConsecutive ? StreakAction.extended : StreakAction.qualified,
    );
  }
}
