import 'package:flutter/widgets.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'local_notification_service.dart';

/// Bridges new database notifications to OS-level notifications. When the app
/// is in the foreground the in-app badge and list already signal the event,
/// so nothing is shown (no duplicates); when the app is paused/inactive the
/// local channel delivers the alert.
///
/// FCM-ready: the server-side rows are the single source of truth; this
/// listener is the client delivery path. A future FCM slice replaces this
/// listener with remote push from the Edge Functions.
class NotificationDeliveryCoordinator {
  NotificationDeliveryCoordinator._({required this.service});

  static NotificationDeliveryCoordinator? _instance;

  static NotificationDeliveryCoordinator ensure({
    LocalNotificationService? service,
  }) {
    return _instance ??=
        NotificationDeliveryCoordinator._(
          service: service ?? FlutterLocalNotificationService(),
        );
  }

  final LocalNotificationService service;
  RealtimeChannel? _channel;
  int _lastShownId = 0;

  /// Initializes the OS channel and subscribes to new notification rows.
  Future<void> start() async {
    await service.initialize();
    _subscribe();
  }

  void _subscribe() {
    if (_channel != null) return;
    _channel = Supabase.instance.client
        .channel('notification-delivery')
        .onPostgresChanges(
          event: PostgresChangeEvent.insert,
          schema: 'public',
          table: 'notifications',
          callback: (payload) {
            _deliver(payload.newRecord);
          },
        )
        .subscribe();
  }

  Future<void> _deliver(Map<String, dynamic> record) async {
    final client = Supabase.instance.client;
    final userId = client.auth.currentSession?.user.id;
    if (userId == null) return;
    final recordUserId = record['user_id'] as String?;
    if (recordUserId != userId) return;

    final lifecycle = WidgetsBinding.instance.lifecycleState;
    if (lifecycle == AppLifecycleState.resumed) return;

    final title = (record['title'] as String?) ?? 'Enfermicambio';
    final body = (record['body'] as String?) ?? '';
    if (body.isEmpty) return;
    await service.show(
      id: ++_lastShownId,
      title: title,
      body: body,
    );
  }

  void dispose() {
    final channel = _channel;
    if (channel != null) {
      Supabase.instance.client.removeChannel(channel);
      _channel = null;
    }
  }
}
