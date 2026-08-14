import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'local_notification_service.dart';
import 'push_notification_service.dart';

/// Fallback bridge for database notifications while the app process is alive.
/// When the app is in the foreground the in-app badge and list already signal
/// the event, so nothing is shown here; when the app is paused/inactive the
/// local channel can deliver the alert. FCM/APNs is the reliable path when the
/// app is terminated; this Realtime listener remains useful offline and when
/// Firebase has not been configured yet.
class NotificationDeliveryCoordinator {
  NotificationDeliveryCoordinator._({required this.service});

  static NotificationDeliveryCoordinator? _instance;

  static NotificationDeliveryCoordinator ensure({
    LocalNotificationService? service,
  }) {
    return _instance ??= NotificationDeliveryCoordinator._(
      service: service ?? FlutterLocalNotificationService(),
    );
  }

  final LocalNotificationService service;
  RealtimeChannel? _channel;
  StreamSubscription<AuthState>? _authSubscription;
  String? _subscribedUserId;
  Future<void> _subscriptionQueue = Future<void>.value();
  int _lastShownId = 0;

  /// Initializes the OS channel and subscribes to new notification rows.
  Future<void> start() async {
    await service.initialize();
    _authSubscription ??= Supabase.instance.client.auth.onAuthStateChange
        .listen((state) => _queueSubscription(state.session));
    _queueSubscription(Supabase.instance.client.auth.currentSession);
  }

  void _queueSubscription(Session? session) {
    _subscriptionQueue = _subscriptionQueue
        .then((_) => _setSubscription(session))
        .catchError((_) {
          // A failed channel is retried when the next auth/lifecycle event
          // arrives; notification delivery must never affect app startup.
        });
  }

  Future<void> _setSubscription(Session? session) async {
    final userId = session?.user.id;
    if (_channel != null && _subscribedUserId == userId) return;

    final previous = _channel;
    _channel = null;
    _subscribedUserId = userId;
    if (previous != null) {
      await Supabase.instance.client.removeChannel(previous);
    }
    if (userId == null) return;

    _channel = Supabase.instance.client
        .channel('notification-delivery-$userId')
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

    // Once FCM has registered this device, the remote notification is the
    // delivery path. Realtime remains the fallback for builds without a
    // usable push token; using both paths would show duplicate alerts while
    // the app is in the background.
    if (PushNotificationService.ensure().status.value.isRegistered) return;

    final title = (record['title'] as String?) ?? 'Enfermicambio';
    final body = (record['body'] as String?) ?? '';
    if (body.isEmpty) return;
    await service.show(id: ++_lastShownId, title: title, body: body);
  }

  void dispose() {
    _authSubscription?.cancel();
    _authSubscription = null;
    final channel = _channel;
    if (channel != null) {
      Supabase.instance.client.removeChannel(channel);
      _channel = null;
    }
    _subscribedUserId = null;
  }
}
