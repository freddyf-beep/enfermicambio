import 'package:flutter_test/flutter_test.dart';

import 'package:enfermicambio/features/ranking/domain/ranking_models.dart';
import 'package:enfermicambio/features/ranking/domain/ranking_service.dart';

void main() {
  final now = DateTime.utc(2026, 8, 10, 12);

  UserActivitySnapshot user({
    required String name,
    required int steps,
    DateTime? syncedAt,
    String? message,
  }) {
    return UserActivitySnapshot(
      userId: name,
      displayName: name,
      dailySteps: steps,
      activeCalories: 0,
      distanceMeters: 0,
      exerciseMinutes: 0,
      syncedAt: syncedAt ?? now.subtract(const Duration(minutes: 1)),
      message: message,
    );
  }

  test('ranks all four users by daily steps descending', () {
    final rows = const RankingService().rank(
      users: [
        user(name: 'A', steps: 1000),
        user(name: 'B', steps: 5000),
        user(name: 'C', steps: 300),
        user(name: 'D', steps: 2000),
      ],
      now: now,
    );

    expect(rows.map((r) => r.displayName).toList(), ['B', 'D', 'A', 'C']);
    expect(rows.map((r) => r.rank).toList(), [1, 2, 3, 4]);
  });

  test('assigns the same rank to tied users', () {
    final rows = const RankingService().rank(
      users: [
        user(name: 'A', steps: 1000),
        user(name: 'B', steps: 1000),
        user(name: 'C', steps: 300),
      ],
      now: now,
    );

    expect(rows[0].rank, 1);
    expect(rows[1].rank, 1);
    expect(rows[2].rank, 3);
  });

  test('always includes zero-data and stale users', () {
    final rows = const RankingService().rank(
      users: [
        user(name: 'A', steps: 1000),
        user(
          name: 'B',
          steps: 0,
          syncedAt: now.subtract(const Duration(hours: 5)),
        ),
        user(
          name: 'C',
          steps: 0,
          syncedAt: now.subtract(const Duration(days: 2)),
        ),
        user(name: 'D', steps: 0, syncedAt: now),
      ],
      now: now,
    );

    expect(rows.length, 4);
    final b = rows.firstWhere((r) => r.displayName == 'B');
    expect(b.freshness, UserFreshness.stale);
    final c = rows.firstWhere((r) => r.displayName == 'C');
    expect(c.freshness, UserFreshness.missing);
  });

  test('marks denied and unavailable users distinctly', () {
    final rows = const RankingService().rank(
      users: [
        user(name: 'A', steps: 1000),
        user(name: 'B', steps: 0, message: 'permission_denied'),
        user(name: 'C', steps: 0, message: 'source_unavailable'),
      ],
      now: now,
    );

    final b = rows.firstWhere((r) => r.displayName == 'B');
    final c = rows.firstWhere((r) => r.displayName == 'C');
    expect(b.freshness, UserFreshness.denied);
    expect(c.freshness, UserFreshness.unavailable);
    expect(b.lastSyncedAt, isNull);
  });
}
