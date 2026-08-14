import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';
import 'package:timezone/data/latest.dart' as timezone_data;
import 'package:timezone/timezone.dart' as tz;

import '../../firebase_options.dart';

/// Resolves app configuration with a safe fallback chain:
///   1. --dart-define values (used in release builds via CI)
///   2. .env file (local development)
///   3. fallback default or empty string (UI surfaces a setup state)
class AppEnvironment {
  static const String _supabaseUrlDefine = String.fromEnvironment(
    'SUPABASE_URL',
  );
  static const String _supabaseAnonKeyDefine = String.fromEnvironment(
    'SUPABASE_ANON_KEY',
  );
  static const String _competitionTzDefine = String.fromEnvironment(
    'COMPETITION_TZ',
  );
  static const String _firebaseApiKeyDefine = String.fromEnvironment(
    'FIREBASE_API_KEY',
  );
  static const String _firebaseAppIdAndroidDefine = String.fromEnvironment(
    'FIREBASE_APP_ID_ANDROID',
  );
  static const String _firebaseAppIdIosDefine = String.fromEnvironment(
    'FIREBASE_APP_ID_IOS',
  );
  static const String _firebaseMessagingSenderIdDefine = String.fromEnvironment(
    'FIREBASE_MESSAGING_SENDER_ID',
  );
  static const String _firebaseProjectIdDefine = String.fromEnvironment(
    'FIREBASE_PROJECT_ID',
  );
  static const String _firebaseStorageBucketDefine = String.fromEnvironment(
    'FIREBASE_STORAGE_BUCKET',
  );
  static const String _firebaseIosBundleIdDefine = String.fromEnvironment(
    'FIREBASE_IOS_BUNDLE_ID',
  );
  static const String _firebaseAuthEnabledDefine = String.fromEnvironment(
    'FIREBASE_AUTH_ENABLED',
    defaultValue: 'false',
  );
  static const String _appVersionDefine = String.fromEnvironment(
    'APP_VERSION',
    defaultValue: '1.2.4',
  );
  static const int _appBuildDefine = int.fromEnvironment(
    'APP_BUILD',
    defaultValue: 11,
  );
  static const String _releaseManifestUrlDefine = String.fromEnvironment(
    'RELEASE_MANIFEST_URL',
  );
  static const String _webPushBridgeUrlDefine = String.fromEnvironment(
    'WEB_PUSH_BRIDGE_URL',
  );

  static String get supabaseUrl =>
      _firstNonEmpty(_supabaseUrlDefine, _dotenvValue('SUPABASE_URL'));

  static String get supabaseAnonKey =>
      _firstNonEmpty(_supabaseAnonKeyDefine, _dotenvValue('SUPABASE_ANON_KEY'));

  static String get competitionTimezone => _firstNonEmpty(
    _competitionTzDefine,
    _dotenvValue('COMPETITION_TZ').isEmpty
        ? 'America/Santiago'
        : _dotenvValue('COMPETITION_TZ'),
  );

  static bool get isConfigured =>
      supabaseUrl.isNotEmpty && supabaseAnonKey.isNotEmpty;

  static String get firebaseApiKey =>
      _firstNonEmpty(_firebaseApiKeyDefine, _dotenvValue('FIREBASE_API_KEY'));

  static String get firebaseMessagingSenderId => _firstNonEmpty(
    _firebaseMessagingSenderIdDefine,
    _dotenvValue('FIREBASE_MESSAGING_SENDER_ID'),
  );

  static String get firebaseProjectId => _firstNonEmpty(
    _firebaseProjectIdDefine,
    _firstNonEmpty(
      _dotenvValue('FIREBASE_PROJECT_ID'),
      _generatedFirebaseProjectId,
    ),
  );

  static String get firebaseStorageBucket => _firstNonEmpty(
    _firebaseStorageBucketDefine,
    _dotenvValue('FIREBASE_STORAGE_BUCKET'),
  );

  static String get firebaseIosBundleId => _firstNonEmpty(
    _firebaseIosBundleIdDefine,
    _dotenvValue('FIREBASE_IOS_BUNDLE_ID'),
  );

  /// Enables the Firebase Authentication surface without silently replacing
  /// the existing Supabase data session. The complete data migration is a
  /// separate step because the current feature repositories still use
  /// Supabase RLS and RPCs.
  static bool get firebaseAuthEnabled => _isTrue(
    _firstNonEmpty(
      _firebaseAuthEnabledDefine,
      _dotenvValue('FIREBASE_AUTH_ENABLED'),
    ),
  );

  static String get appVersion => _appVersionDefine;

  static int get appBuild => _appBuildDefine;

  static String get releaseManifestUrl => _firstNonEmpty(
    _releaseManifestUrlDefine,
    _dotenvValue('RELEASE_MANIFEST_URL'),
  );

  static String get webPushBridgeUrl => _firstNonEmpty(
    _webPushBridgeUrlDefine,
    _dotenvValue('WEB_PUSH_BRIDGE_URL'),
  );

  static String get firebaseAppId {
    final define = defaultTargetPlatform == TargetPlatform.iOS
        ? _firebaseAppIdIosDefine
        : _firebaseAppIdAndroidDefine;
    final name = defaultTargetPlatform == TargetPlatform.iOS
        ? 'FIREBASE_APP_ID_IOS'
        : 'FIREBASE_APP_ID_ANDROID';
    return _firstNonEmpty(define, _dotenvValue(name));
  }

  static bool get isFirebaseConfigured => firebaseOptions != null;

  static FirebaseOptions? get firebaseOptions {
    if (_hasManualFirebaseConfig) {
      return FirebaseOptions(
        apiKey: firebaseApiKey,
        appId: firebaseAppId,
        messagingSenderId: firebaseMessagingSenderId,
        projectId: firebaseProjectId,
        storageBucket: firebaseStorageBucket.isEmpty
            ? null
            : firebaseStorageBucket,
        iosBundleId: defaultTargetPlatform == TargetPlatform.iOS
            ? (firebaseIosBundleId.isEmpty
                  ? 'com.enfermicambio.enfermicambio'
                  : firebaseIosBundleId)
            : null,
      );
    }
    try {
      return DefaultFirebaseOptions.currentPlatform;
    } on UnsupportedError {
      return null;
    }
  }

  static bool get _hasManualFirebaseConfig =>
      firebaseApiKey.isNotEmpty &&
      firebaseAppId.isNotEmpty &&
      firebaseMessagingSenderId.isNotEmpty &&
      _firstNonEmpty(
        _firebaseProjectIdDefine,
        _dotenvValue('FIREBASE_PROJECT_ID'),
      ).isNotEmpty;

  static String get _generatedFirebaseProjectId {
    try {
      return DefaultFirebaseOptions.currentPlatform.projectId;
    } on UnsupportedError {
      return '';
    }
  }

  /// Fecha de competencia de hoy como 'yyyy-MM-dd'. Los 4 dispositivos del
  /// grupo usan la zona de competencia, aunque el dispositivo o el host estén
  /// configurados con otra zona horaria.
  static String todayInCompetitionTz() {
    timezone_data.initializeTimeZones();
    final now = tz.TZDateTime.now(tz.getLocation(competitionTimezone));
    return _dateOnly(now);
  }

  static String _dateOnly(DateTime value) {
    return '${value.year.toString().padLeft(4, '0')}-'
        '${value.month.toString().padLeft(2, '0')}-'
        '${value.day.toString().padLeft(2, '0')}';
  }

  static String _firstNonEmpty(String primary, String fallback) {
    return primary.isNotEmpty ? primary : fallback;
  }

  static bool _isTrue(String value) {
    return value.trim().toLowerCase() == 'true' || value.trim() == '1';
  }

  static String _dotenvValue(String name) {
    if (!dotenv.isInitialized) return '';
    return dotenv.maybeGet(name) ?? '';
  }
}
