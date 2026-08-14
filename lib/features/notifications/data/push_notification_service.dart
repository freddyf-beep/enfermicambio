import 'dart:async';

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../shared/config/app_environment.dart';
import 'local_notification_service.dart';

/// Registers the current device with FCM so the server can deliver a real OS
/// notification while the app is backgrounded or terminated. The database
/// notification remains the source of truth; FCM is only the delivery path.
class PushNotificationService {
  PushNotificationService._({
    required this._client,
    required this._localNotifications,
  });

  static PushNotificationService? _instance;

  static PushNotificationService ensure({
    SupabaseClient? client,
    LocalNotificationService? localNotifications,
  }) {
    return _instance ??= PushNotificationService._(
      client: client ?? Supabase.instance.client,
      localNotifications:
          localNotifications ?? FlutterLocalNotificationService(),
    );
  }

  final SupabaseClient _client;
  final LocalNotificationService _localNotifications;
  StreamSubscription<String>? _tokenSubscription;
  StreamSubscription<RemoteMessage>? _foregroundSubscription;
  StreamSubscription<AuthState>? _authSubscription;
  bool _started = false;
  bool _firebaseReady = false;
  int _localNotificationId = 100000;

  bool get isAvailable => _firebaseReady;

  Future<void> start() async {
    if (_started || kIsWeb || !AppEnvironment.isFirebaseConfigured) return;
    _started = true;
    try {
      final options = AppEnvironment.firebaseOptions;
      if (options == null) return;
      if (Firebase.apps.isEmpty) {
        await Firebase.initializeApp(options: options);
      }
      _firebaseReady = true;

      final messaging = FirebaseMessaging.instance;
      await messaging.setAutoInitEnabled(true);
      await messaging.requestPermission(
        alert: true,
        badge: true,
        sound: true,
        provisional: false,
      );

      _foregroundSubscription = FirebaseMessaging.onMessage.listen(
        _showForegroundNotification,
      );
      _tokenSubscription = messaging.onTokenRefresh.listen(_registerToken);
      _authSubscription = _client.auth.onAuthStateChange.listen((state) {
        if (state.session != null) unawaited(_registerCurrentToken());
      });
      await _registerCurrentToken();
    } on Exception {
      // The app still has the in-app center and the Realtime/local fallback.
      // Missing Firebase/APNs configuration must not block startup.
    }
  }

  Future<void> _registerCurrentToken() async {
    if (!_firebaseReady || _client.auth.currentSession == null) return;
    try {
      final token = await FirebaseMessaging.instance.getToken();
      if (token != null && token.isNotEmpty) await _registerToken(token);
    } on Exception {
      // Token registration is retried on the next token/auth event.
    }
  }

  Future<void> _registerToken(String token) async {
    if (!_firebaseReady || _client.auth.currentSession == null) return;
    try {
      await _client.rpc(
        'register_push_device',
        params: {
          'p_token': token,
          'p_platform': defaultTargetPlatform == TargetPlatform.iOS
              ? 'ios'
              : 'android',
          'p_provider': 'fcm',
          'p_app_id': 'com.enfermicambio.enfermicambio',
        },
      );
    } on Exception {
      // A transient auth/network failure will be retried by token refresh.
    }
  }

  Future<void> _showForegroundNotification(RemoteMessage message) async {
    final title =
        message.notification?.title ??
        message.data['title']?.toString() ??
        'Enfermicambio';
    final body =
        message.notification?.body ?? message.data['body']?.toString() ?? '';
    if (body.isEmpty) return;
    await _localNotifications.show(
      id: _localNotificationId++,
      title: title,
      body: body,
    );
  }

  Future<void> dispose() async {
    await _tokenSubscription?.cancel();
    await _foregroundSubscription?.cancel();
    await _authSubscription?.cancel();
    _tokenSubscription = null;
    _foregroundSubscription = null;
    _authSubscription = null;
    _instance = null;
  }
}
