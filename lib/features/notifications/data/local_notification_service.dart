import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:permission_handler/permission_handler.dart';

/// Abstraction over OS-level notification delivery. The production
/// implementation uses local notifications; a future FCM slice will add a
/// remote variant. Kept behind an interface so tests and non-mobile targets
/// can use a no-op.
abstract interface class LocalNotificationService {
  Future<void> initialize();

  Future<void> show({
    required int id,
    required String title,
    required String body,
  });
}

/// flutter_local_notifications implementation. Failures are swallowed: a
/// notification that cannot be delivered must never crash the app.
class FlutterLocalNotificationService implements LocalNotificationService {
  final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();

  bool _initialized = false;

  @override
  Future<void> initialize() async {
    if (_initialized || kIsWeb) return;
    const settings = InitializationSettings(
      android: AndroidInitializationSettings('ic_stat_notification'),
      iOS: DarwinInitializationSettings(
        requestAlertPermission: true,
        requestBadgePermission: true,
        requestSoundPermission: true,
      ),
    );
    try {
      await _plugin.initialize(settings);
      if (defaultTargetPlatform == TargetPlatform.android ||
          defaultTargetPlatform == TargetPlatform.iOS) {
        await Permission.notification.request();
      }
      _initialized = true;
    } on Exception {
      // Platform channel unavailable (e.g. desktop tests): stay silent.
    }
  }

  @override
  Future<void> show({
    required int id,
    required String title,
    required String body,
  }) async {
    if (!_initialized) return;
    const details = NotificationDetails(
      android: AndroidNotificationDetails(
        'competencia',
        'Competencia',
        channelDescription:
            'Adelantamientos, rondas, logros y novedades '
            'de la competencia.',
        importance: Importance.high,
        priority: Priority.high,
        icon: 'ic_stat_notification',
        color: Color(0xFFB6FF00),
      ),
      iOS: DarwinNotificationDetails(),
    );
    try {
      await _plugin.show(id, title, body, details);
    } on Exception {
      // Best effort; the in-app center remains the source of truth.
    }
  }
}

/// No-op for tests and environments without a notification channel.
class NoopLocalNotificationService implements LocalNotificationService {
  const NoopLocalNotificationService();

  @override
  Future<void> initialize() async {}

  @override
  Future<void> show({
    required int id,
    required String title,
    required String body,
  }) async {}
}
