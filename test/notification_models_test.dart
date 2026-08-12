import 'package:flutter_test/flutter_test.dart';

import 'package:enfermicambio/features/notifications/domain/notification_models.dart';

void main() {
  group('AppNotification parses rows', () {
    test('fromJson maps all fields', () {
      final notification = AppNotification.fromJson({
        'id': 'n1',
        'type': 'overtake',
        'title': 'Samir te pasó',
        'body': '🚨 Samir te pasó por 1.245 pasos.',
        'payload': {'key': 'overtake:2026-08-11:a:b'},
        'is_read': false,
        'created_at': '2026-08-11T18:30:00Z',
      });
      expect(notification.id, 'n1');
      expect(notification.type, 'overtake');
      expect(notification.body, contains('1.245'));
      expect(notification.payload['key'], 'overtake:2026-08-11:a:b');
      expect(notification.isRead, isFalse);
      expect(notification.createdAt.isUtc, isFalse);
    });

    test('navigation hints come from the payload', () {
      final post = AppNotification.fromJson({
        'id': 'n1',
        'type': 'feed_post',
        'title': 'x',
        'body': 'y',
        'payload': {'post_id': 'p1', 'actor_id': 'a'},
        'is_read': false,
        'created_at': '2026-08-11T18:30:00Z',
      });
      expect(post.postId, 'p1');
      expect(post.competitionDate, isNull);
      expect(post.seasonId, isNull);

      final season = AppNotification.fromJson({
        'id': 'n2',
        'type': 'season',
        'title': 'x',
        'body': 'y',
        'payload': {'season_id': 's1'},
        'is_read': false,
        'created_at': '2026-08-11T18:30:00Z',
      });
      expect(season.seasonId, 's1');
    });
  });

  group('NotificationPreferences', () {
    test('absent categories default to enabled', () {
      const preferences = NotificationPreferences.allEnabled;
      expect(preferences.isEnabled(NotificationCategory.feed), isTrue);
      expect(preferences.isEnabled(NotificationCategory.weight), isTrue);
    });

    test('fromJson reads only booleans', () {
      final preferences = NotificationPreferences.fromJson({
        'feed': false,
        'rounds': true,
        'weird': 'value',
      });
      expect(preferences.isEnabled(NotificationCategory.feed), isFalse);
      expect(preferences.isEnabled(NotificationCategory.rounds), isTrue);
      expect(preferences.isEnabled(NotificationCategory.weight), isTrue);
    });

    test('toJson round-trips disabled categories', () {
      const base = NotificationPreferences.allEnabled;
      final updated = base.copyWithEnabled(
        NotificationCategory.overtakes,
        false,
      );
      final json = updated.toJson();
      expect(json['overtakes'], isFalse);
      expect(json.containsKey('feed'), isFalse);
    });

    test('labels are in Spanish', () {
      expect(NotificationCategory.overtakes.label, 'Adelantamientos');
      expect(NotificationCategory.feed.label, 'Publicaciones del feed');
      expect(NotificationCategory.weight.label, 'Mi peso');
    });
  });
}
