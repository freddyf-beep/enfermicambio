import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:enfermicambio/features/activity/presentation/widgets/home_dashboard_widgets.dart';
import 'package:enfermicambio/features/health/domain/health_models.dart';
import 'package:enfermicambio/features/ranking/domain/ranking_models.dart';
import 'package:enfermicambio/shared/ui/app_theme.dart';

void main() {
  testWidgets('hero prioritizes current rank and real daily metrics', (
    tester,
  ) async {
    await tester.pumpWidget(
      _testApp(
        CompetitionDashboardHero(
          date: DateTime(2026, 8, 12),
          activity: _activity,
          currentRanking: _ranking.first,
          notificationButton: const IconButton(
            onPressed: null,
            icon: Icon(Icons.notifications_outlined),
          ),
          onOpenGame: () {},
          onRefresh: () {},
          onShare: () {},
        ),
      ),
    );

    expect(find.text('12 AGO'), findsOneWidget);
    expect(find.text('Tu posición #1'), findsOneWidget);
    expect(find.text('21.171'), findsOneWidget);
    expect(find.text('8.23 km'), findsOneWidget);
    expect(find.text('78 kcal'), findsOneWidget);
    expect(find.text('32 min'), findsOneWidget);
    expect(find.byKey(const Key('share-daily-summary')), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('group card marks the current user and exposes real actions', (
    tester,
  ) async {
    var createPostCalls = 0;
    var openGroupCalls = 0;
    await tester.pumpWidget(
      _testApp(
        GroupRankingCard(
          rows: _ranking,
          currentUserId: 'freddy',
          onCreatePost: () => createPostCalls++,
          onOpenGroup: () => openGroupCalls++,
        ),
      ),
    );

    expect(find.text('Competencia privada · 4 amigos'), findsOneWidget);
    expect(find.text('Tú'), findsOneWidget);
    expect(find.text('Felipe'), findsOneWidget);
    expect(find.text('Cristian'), findsOneWidget);
    expect(find.text('Sami'), findsOneWidget);

    await tester.tap(find.byTooltip('Publicar en el feed'));
    await tester.tap(find.byTooltip('Ver grupo'));
    expect(createPostCalls, 1);
    expect(openGroupCalls, 1);
    expect(tester.takeException(), isNull);
  });

  testWidgets('hero fits a narrow iPhone-sized viewport without overflow', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(320, 720);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      _testApp(
        SingleChildScrollView(
          child: CompetitionDashboardHero(
            date: DateTime(2026, 8, 12),
            activity: _activity,
            currentRanking: _ranking.first,
            notificationButton: const IconButton(
              onPressed: null,
              icon: Icon(Icons.notifications_outlined),
            ),
            onOpenGame: () {},
            onRefresh: () {},
            onShare: () {},
          ),
        ),
      ),
    );

    expect(find.byKey(const Key('competition-dashboard-hero')), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}

Widget _testApp(Widget child) {
  return MaterialApp(
    theme: AppTheme.darkTheme,
    home: Scaffold(
      body: SafeArea(
        child: Padding(padding: const EdgeInsets.all(8), child: child),
      ),
    ),
  );
}

final _activity = DailyActivityAggregate(
  date: DateTime(2026, 8, 12),
  morningSteps: 7000,
  afternoonSteps: 9000,
  nightSteps: 5171,
  dailySteps: 21171,
  activeCalories: 78,
  distanceMeters: 8230,
  exerciseMinutes: 32,
  syncedAt: DateTime.utc(2026, 8, 12, 18),
  manualRecordsExcluded: 0,
  sourcePlatform: 'ios',
);

const _ranking = <RankingRow>[
  RankingRow(
    userId: 'freddy',
    displayName: 'Freddy',
    value: 21171,
    freshness: UserFreshness.fresh,
    rank: 1,
  ),
  RankingRow(
    userId: 'felipe',
    displayName: 'Felipe',
    value: 17520,
    freshness: UserFreshness.fresh,
    rank: 2,
  ),
  RankingRow(
    userId: 'cristian',
    displayName: 'Cristian',
    value: 15041,
    freshness: UserFreshness.stale,
    rank: 3,
  ),
  RankingRow(
    userId: 'sami',
    displayName: 'Sami',
    value: 11002,
    freshness: UserFreshness.missing,
    rank: 4,
  ),
];
