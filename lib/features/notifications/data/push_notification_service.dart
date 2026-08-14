import 'dart:async';

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../shared/config/app_environment.dart';
import 'local_notification_service.dart';

enum PushRegistrationState {
  idle,
  initializing,
  unavailable,
  permissionDenied,
  apnsUnavailable,
  notRegistered,
  registered,
  error,
}

class PushNotificationStatus {
  const PushNotificationStatus({
    this.state = PushRegistrationState.idle,
    this.detail = '',
    this.platform,
    this.lastRegisteredAt,
  });

  final PushRegistrationState state;
  final String detail;
  final String? platform;
  final DateTime? lastRegisteredAt;

  bool get isRegistered => state == PushRegistrationState.registered;
}

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
  final ValueNotifier<PushNotificationStatus> _status = ValueNotifier(
    const PushNotificationStatus(),
  );
  StreamSubscription<String>? _tokenSubscription;
  StreamSubscription<RemoteMessage>? _foregroundSubscription;
  StreamSubscription<AuthState>? _authSubscription;
  bool _started = false;
  bool _firebaseReady = false;
  int _localNotificationId = 100000;

  bool get isAvailable => _firebaseReady;
  ValueListenable<PushNotificationStatus> get status => _status;

  Future<void> start() async {
    if (_started) return;
    _started = true;
    if (kIsWeb ||
        (defaultTargetPlatform != TargetPlatform.iOS &&
            defaultTargetPlatform != TargetPlatform.android)) {
      _setStatus(
        PushRegistrationState.unavailable,
        'Los avisos del sistema solo están disponibles en iPhone y Android.',
      );
      return;
    }
    if (!AppEnvironment.isFirebaseConfigured) {
      _setStatus(
        PushRegistrationState.unavailable,
        'Firebase no está configurado en esta compilación.',
      );
      return;
    }

    _setStatus(
      PushRegistrationState.initializing,
      'Inicializando el dispositivo…',
    );
    try {
      final options = AppEnvironment.firebaseOptions;
      if (options == null) {
        _setStatus(
          PushRegistrationState.unavailable,
          'Faltan los datos de configuración de Firebase.',
        );
        return;
      }
      if (Firebase.apps.isEmpty) {
        await Firebase.initializeApp(options: options);
      }
      _firebaseReady = true;

      final messaging = FirebaseMessaging.instance;
      await _localNotifications.initialize();
      await messaging.setAutoInitEnabled(true);
      _foregroundSubscription ??= FirebaseMessaging.onMessage.listen(
        _showForegroundNotification,
      );
      _tokenSubscription ??= messaging.onTokenRefresh.listen(_registerToken);
      _authSubscription ??= _client.auth.onAuthStateChange.listen((state) {
        if (state.session != null) unawaited(_registerCurrentToken());
      });
      final settings = await messaging.requestPermission(
        alert: true,
        badge: true,
        sound: true,
        provisional: false,
      );
      await messaging.setForegroundNotificationPresentationOptions(
        alert: true,
        badge: true,
        sound: true,
      );
      if (settings.authorizationStatus == AuthorizationStatus.denied) {
        _setStatus(
          PushRegistrationState.permissionDenied,
          'Las notificaciones están bloqueadas. Actívalas en Ajustes del teléfono.',
        );
        return;
      }

      // iOS does not issue an FCM token until APNs has issued its device
      // token. Surface this state instead of silently pretending registration
      // succeeded when an unsigned/sideloaded build lacks the entitlement.
      if (defaultTargetPlatform == TargetPlatform.iOS) {
        final apnsToken = await _waitForApnsToken(messaging);
        if (apnsToken == null || apnsToken.isEmpty) {
          _setStatus(
            PushRegistrationState.apnsUnavailable,
            'iPhone no entregó el token APNs. Revisa la capacidad de notificaciones y la firma de la IPA.',
          );
          return;
        }
      }

      await _registerCurrentToken();
    } on Exception catch (error) {
      _setStatus(PushRegistrationState.error, _shortError(error));
    }
  }

  Future<void> refreshRegistration() async {
    if (!_started) {
      await start();
      return;
    }
    if (!_firebaseReady) return;
    _setStatus(PushRegistrationState.initializing, 'Reintentando el registro…');
    final settings = await FirebaseMessaging.instance.requestPermission(
      alert: true,
      badge: true,
      sound: true,
      provisional: false,
    );
    if (settings.authorizationStatus == AuthorizationStatus.denied) {
      _setStatus(
        PushRegistrationState.permissionDenied,
        'Las notificaciones están bloqueadas. Actívalas en Ajustes del teléfono.',
      );
      return;
    }
    if (defaultTargetPlatform == TargetPlatform.iOS) {
      final apnsToken = await _waitForApnsToken(FirebaseMessaging.instance);
      if (apnsToken == null || apnsToken.isEmpty) {
        _setStatus(
          PushRegistrationState.apnsUnavailable,
          'iPhone no entregó el token APNs. Revisa la capacidad de notificaciones y la firma de la IPA.',
        );
        return;
      }
    }
    await _registerCurrentToken();
  }

  Future<void> _registerCurrentToken() async {
    if (!_firebaseReady) return;
    if (_client.auth.currentSession == null) {
      _setStatus(
        PushRegistrationState.notRegistered,
        'Inicia sesión para registrar este teléfono.',
      );
      return;
    }
    try {
      final token = await _getFcmTokenWithRetry();
      if (token == null || token.isEmpty) {
        _setStatus(
          PushRegistrationState.notRegistered,
          'Firebase todavía no entregó un token para este teléfono.',
        );
        return;
      }
      await _registerToken(token);
    } on Exception catch (error) {
      _setStatus(PushRegistrationState.error, _shortError(error));
    }
  }

  Future<String?> _getFcmTokenWithRetry() async {
    for (var attempt = 0; attempt < 4; attempt++) {
      try {
        final token = await FirebaseMessaging.instance.getToken();
        if (token != null && token.isNotEmpty) return token;
      } on Exception {
        if (attempt == 3) rethrow;
      }
      await Future<void>.delayed(Duration(seconds: attempt + 1));
    }
    return null;
  }

  Future<String?> _waitForApnsToken(FirebaseMessaging messaging) async {
    for (var attempt = 0; attempt < 6; attempt++) {
      try {
        final token = await messaging.getAPNSToken();
        if (token != null && token.isNotEmpty) return token;
      } on Exception {
        // The next attempt can succeed once iOS finishes registering.
      }
      await Future<void>.delayed(Duration(seconds: attempt == 0 ? 1 : 2));
    }
    return null;
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
      _setStatus(
        PushRegistrationState.registered,
        'Este teléfono puede recibir avisos aunque la app esté cerrada.',
        platform: defaultTargetPlatform == TargetPlatform.iOS
            ? 'iPhone'
            : 'Android',
        lastRegisteredAt: DateTime.now(),
      );
    } on Exception catch (error) {
      _setStatus(PushRegistrationState.error, _shortError(error));
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
    _status.dispose();
    _instance = null;
  }

  void _setStatus(
    PushRegistrationState state,
    String detail, {
    String? platform,
    DateTime? lastRegisteredAt,
  }) {
    _status.value = PushNotificationStatus(
      state: state,
      detail: detail,
      platform: platform ?? _status.value.platform,
      lastRegisteredAt: lastRegisteredAt ?? _status.value.lastRegisteredAt,
    );
  }

  String _shortError(Object error) {
    final text = error.toString().replaceFirst('Exception: ', '').trim();
    return text.length <= 220 ? text : '${text.substring(0, 217)}…';
  }
}
