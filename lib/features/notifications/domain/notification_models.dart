/// Notification categories for per-user preferences. The `dbKey` matches the
/// keys stored in `profiles.notification_preferences` (jsonb); the server maps
/// each notification type to exactly one category.
enum NotificationCategory {
  overtakes,
  rounds,
  achievements,
  workouts,
  feed,
  social,
  missions,
  season,
  personal,
  weight;

  String get dbKey => name;

  String get label => switch (this) {
        NotificationCategory.overtakes => 'Adelantamientos',
        NotificationCategory.rounds => 'Rondas',
        NotificationCategory.achievements => 'Logros',
        NotificationCategory.workouts => 'Entrenamientos',
        NotificationCategory.feed => 'Publicaciones del feed',
        NotificationCategory.social => 'Comentarios y reacciones',
        NotificationCategory.missions => 'Misiones',
        NotificationCategory.season => 'Temporada',
        NotificationCategory.personal => 'Mis metas',
        NotificationCategory.weight => 'Mi peso',
      };
}

class NotificationPreferences {
  const NotificationPreferences({this.enabled = const {}});

  /// Category -> enabled. Categories not present default to enabled (true).
  final Map<NotificationCategory, bool> enabled;

  static const NotificationPreferences allEnabled = NotificationPreferences();

  bool isEnabled(NotificationCategory category) => enabled[category] ?? true;

  NotificationPreferences copyWithEnabled(
    NotificationCategory category,
    bool value,
  ) {
    return NotificationPreferences(
      enabled: {...enabled, category: value},
    );
  }

  factory NotificationPreferences.fromJson(Map<String, dynamic> json) {
    final map = <NotificationCategory, bool>{};
    for (final category in NotificationCategory.values) {
      final value = json[category.dbKey];
      if (value is bool) {
        map[category] = value;
      }
    }
    return NotificationPreferences(enabled: map);
  }

  Map<String, dynamic> toJson() => {
        for (final entry in enabled.entries) entry.key.dbKey: entry.value,
      };
}

class AppNotification {
  const AppNotification({
    required this.id,
    required this.type,
    required this.title,
    required this.body,
    required this.payload,
    required this.isRead,
    required this.createdAt,
  });

  final String id;
  final String type;
  final String title;
  final String body;
  final Map<String, dynamic> payload;
  final bool isRead;
  final DateTime createdAt;

  factory AppNotification.fromJson(Map<String, dynamic> json) {
    return AppNotification(
      id: json['id'] as String,
      type: json['type'] as String,
      title: json['title'] as String,
      body: json['body'] as String,
      payload: (json['payload'] as Map?)?.cast<String, dynamic>() ?? const {},
      isRead: json['is_read'] as bool? ?? false,
      createdAt: DateTime.parse(json['created_at'] as String).toLocal(),
    );
  }

  /// Navigation hint: which app area this notification points to.
  String? get postId => payload['post_id'] as String?;
  String? get competitionDate => payload['competition_date'] as String?;
  String? get seasonId => payload['season_id'] as String?;
}

class NotificationPage {
  const NotificationPage({required this.items, required this.nextCursor});

  final List<AppNotification> items;
  final String? nextCursor;
}

abstract interface class NotificationRepository {
  Future<NotificationPage> loadLatest({required int limit});

  Future<NotificationPage> loadAfter({
    required String cursor,
    required int limit,
  });

  Future<int> unreadCount();

  Future<void> markRead(String id);

  Future<void> markAllRead();

  Future<NotificationPreferences> fetchPreferences();

  Future<void> setPreference(NotificationCategory category, bool enabled);

  /// Emits after any change to the current user's notifications
  /// (new notification, read state). The initial emission is the current
  /// unread count.
  Stream<int> watchUnreadCount();
}
