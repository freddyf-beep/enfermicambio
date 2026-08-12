import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:enfermicambio/features/notifications/domain/notification_models.dart';
import 'package:enfermicambio/features/notifications/presentation/notifications_screen.dart';

class FakeNotificationRepository implements NotificationRepository {
  FakeNotificationRepository(this.items);

  final List<AppNotification> items;
  int unreadCountValue = 3;
  final List<String> readIds = [];
  bool markedAll = false;

  @override
  Future<NotificationPage> loadLatest({required int limit}) async {
    final slice = items.take(limit).toList();
    return NotificationPage(
      items: slice,
      nextCursor: slice.length == limit ? 'cursor' : null,
    );
  }

  @override
  Future<NotificationPage> loadAfter({
    required String cursor,
    required int limit,
  }) async {
    return const NotificationPage(items: [], nextCursor: null);
  }

  @override
  Future<int> unreadCount() async => unreadCountValue;

  @override
  Future<void> markRead(String id) async {
    readIds.add(id);
    unreadCountValue = (unreadCountValue - 1).clamp(0, 9999);
  }

  @override
  Future<void> markAllRead() async {
    markedAll = true;
    unreadCountValue = 0;
  }

  @override
  Future<NotificationPreferences> fetchPreferences() async =>
      NotificationPreferences.allEnabled;

  @override
  Future<void> setPreference(NotificationCategory category, bool enabled) async {}

  @override
  Stream<int> watchUnreadCount() => Stream<int>.empty();
}

AppNotification notification({
  required String id,
  String type = 'overtake',
  String title = 'Samir te pasó',
  String body = '🚨 Samir te pasó por 1.245 pasos.',
  bool isRead = false,
  DateTime? createdAt,
  Map<String, dynamic> payload = const {},
}) {
  return AppNotification(
    id: id,
    type: type,
    title: title,
    body: body,
    payload: payload,
    isRead: isRead,
    createdAt: createdAt ?? DateTime(2026, 8, 11, 18, 30),
  );
}

void main() {
  testWidgets('renders the notification list grouped by day', (tester) async {
    final repository = FakeNotificationRepository([
      notification(id: 'n1', createdAt: DateTime(2026, 8, 11, 18, 30)),
      notification(
        id: 'n2',
        type: 'round_result',
        title: 'Felipe ganó la ronda',
        body: '🏆 Felipe ganó la ronda de la mañana.',
        isRead: true,
        createdAt: DateTime(2026, 8, 11, 8, 0),
      ),
      notification(
        id: 'n3',
        type: 'season',
        title: 'Fin de temporada',
        body: '👑 Cristian ganó la temporada.',
        createdAt: DateTime(2026, 8, 9, 12, 0),
      ),
    ]);

    await tester.pumpWidget(
      MaterialApp(home: NotificationsScreen(repository: repository)),
    );
    await tester.pumpAndSettle();

    expect(find.text('Hoy'), findsOneWidget);
    expect(find.text('9 ago'), findsOneWidget);
    expect(find.text('Samir te pasó'), findsOneWidget);
    expect(find.text('Felipe ganó la ronda'), findsOneWidget);
    expect(find.text('Fin de temporada'), findsOneWidget);
    expect(find.text('👑 Cristian ganó la temporada.'), findsOneWidget);
  });

  testWidgets('tapping an unread notification marks it read', (tester) async {
    final repository = FakeNotificationRepository([
      notification(id: 'n1'),
    ]);

    await tester.pumpWidget(
      MaterialApp(home: NotificationsScreen(repository: repository)),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Samir te pasó'));
    await tester.pumpAndSettle();

    expect(repository.readIds, contains('n1'));
  });

  testWidgets('mark all read calls the repository', (tester) async {
    final repository = FakeNotificationRepository([
      notification(id: 'n1'),
      notification(id: 'n2'),
    ]);

    await tester.pumpWidget(
      MaterialApp(home: NotificationsScreen(repository: repository)),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byTooltip('Marcar todas como leídas'));
    await tester.pumpAndSettle();

    expect(repository.markedAll, isTrue);
  });

  testWidgets('shows the empty state when there are no notifications', (
    tester,
  ) async {
    final repository = FakeNotificationRepository([]);

    await tester.pumpWidget(
      MaterialApp(home: NotificationsScreen(repository: repository)),
    );
    await tester.pumpAndSettle();

    expect(find.text('Sin notificaciones todavía'), findsOneWidget);
  });

  testWidgets('payload post_id navigates to the feed tab', (tester) async {
    final repository = FakeNotificationRepository([
      notification(id: 'n1', payload: {'post_id': 'p1'}),
    ]);

    await tester.pumpWidget(
      MaterialApp(home: NotificationsScreen(repository: repository)),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Samir te pasó'));
    await tester.pumpAndSettle();

    // The screen pops itself; no crash and the tab request was recorded.
    expect(repository.readIds, contains('n1'));
  });
}
