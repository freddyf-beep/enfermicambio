import 'package:flutter_test/flutter_test.dart';
import 'package:timezone/data/latest.dart' as timezone_data;

import 'package:enfermicambio/features/game/domain/streak_engine.dart';

void main() {
  setUpAll(timezone_data.initializeTimeZones);

  const engine = StreakEngine(competitionTimezone: 'America/Santiago');
  final empty = StreakState(
    currentCount: 0,
    longestCount: 0,
    lastQualifiedDate: null,
  );

  DateTime day(int day) => DateTime.utc(2026, 8, day, 12);

  test('qualifies on first qualifying day', () {
    final result = engine.apply(
      previous: empty,
      dayStart: day(10),
      qualified: true,
    );
    expect(result.action, StreakAction.qualified);
    expect(result.state.currentCount, 1);
    expect(result.state.longestCount, 1);
  });

  test('extends on consecutive qualifying days', () {
    final first = engine
        .apply(previous: empty, dayStart: day(10), qualified: true)
        .state;
    final second = engine.apply(
      previous: first,
      dayStart: day(11),
      qualified: true,
    );
    expect(second.action, StreakAction.extended);
    expect(second.state.currentCount, 2);
    expect(second.state.longestCount, 2);
  });

  test('breaks when a day is missed', () {
    final first = engine
        .apply(previous: empty, dayStart: day(10), qualified: true)
        .state;
    final broken = engine.apply(
      previous: first,
      dayStart: day(11),
      qualified: false,
    );
    expect(broken.action, StreakAction.broken);
    expect(broken.state.currentCount, 0);
    expect(broken.state.longestCount, 1);
  });

  test('re-qualifies after a break preserving longest count', () {
    final day10 = engine
        .apply(previous: empty, dayStart: day(10), qualified: true)
        .state;
    final day12 = engine.apply(
      previous: engine
          .apply(previous: day10, dayStart: day(11), qualified: false)
          .state,
      dayStart: day(12),
      qualified: true,
    );
    expect(day12.action, StreakAction.qualified);
    expect(day12.state.currentCount, 1);
    expect(day12.state.longestCount, 1);
  });

  test('same-day re-qualification is a no-op', () {
    final first = engine
        .apply(previous: empty, dayStart: day(10), qualified: true)
        .state;
    final same = engine.apply(
      previous: first,
      dayStart: day(10),
      qualified: true,
    );
    expect(same.action, StreakAction.none);
    expect(same.state.currentCount, 1);
  });

  test('no action when unqualified and already at zero', () {
    final result = engine.apply(
      previous: empty,
      dayStart: day(10),
      qualified: false,
    );
    expect(result.action, StreakAction.none);
  });
}
