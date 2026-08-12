import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:enfermicambio/features/ranking/domain/ranking_models.dart';
import 'package:enfermicambio/features/ranking/presentation/ranking_tab.dart';
import 'package:enfermicambio/shared/config/app_environment.dart';

void main() {
  test('todayInCompetitionTz returns yyyy-MM-dd', () {
    final date = AppEnvironment.todayInCompetitionTz();
    expect(RegExp(r'^\d{4}-\d{2}-\d{2}$').hasMatch(date), isTrue);
  });

  testWidgets('renders all four users with freshness indicators', (
    tester,
  ) async {
    final now = DateTime.now().toUtc();
    final rows = [
      const RankingRow(
        userId: 'a',
        displayName: 'Diego',
        value: 9800,
        freshness: UserFreshness.fresh,
        rank: 1,
      ),
      const RankingRow(
        userId: 'b',
        displayName: 'Nico',
        value: 8950,
        freshness: UserFreshness.fresh,
        rank: 2,
      ),
      RankingRow(
        userId: 'c',
        displayName: 'Pedro',
        value: 8420,
        freshness: UserFreshness.stale,
        rank: 3,
        lastSyncedAt: now.subtract(const Duration(hours: 3)),
      ),
      const RankingRow(
        userId: 'd',
        displayName: 'Juan',
        value: 0,
        freshness: UserFreshness.missing,
        rank: 4,
      ),
    ];

    await tester.pumpWidget(
      MaterialApp(home: RankingTab(rows: rows, loadFromBackend: false)),
    );

    expect(find.text('Diego'), findsOneWidget);
    expect(find.text('Nico'), findsOneWidget);
    expect(find.text('Pedro'), findsOneWidget);
    expect(find.text('Juan'), findsOneWidget);
    expect(find.textContaining('Desactualizado'), findsOneWidget);
    expect(find.text('Sin datos aún'), findsOneWidget);
    expect(find.text('9.8k'), findsOneWidget);
  });

  testWidgets('shows empty state when the ranking has no rows', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(home: RankingTab(rows: [], loadFromBackend: false)),
    );
    expect(find.textContaining('Las clasificaciones del día'), findsOneWidget);
  });
}
