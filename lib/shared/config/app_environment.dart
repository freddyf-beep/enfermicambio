import 'package:flutter_dotenv/flutter_dotenv.dart';

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

  static String get supabaseUrl =>
      _firstNonEmpty(_supabaseUrlDefine, dotenv.maybeGet('SUPABASE_URL') ?? '');

  static String get supabaseAnonKey => _firstNonEmpty(
    _supabaseAnonKeyDefine,
    dotenv.maybeGet('SUPABASE_ANON_KEY') ?? '',
  );

  static String get competitionTimezone => _firstNonEmpty(
    _competitionTzDefine,
    dotenv.maybeGet('COMPETITION_TZ') ?? 'America/Santiago',
  );

  static bool get isConfigured =>
      supabaseUrl.isNotEmpty && supabaseAnonKey.isNotEmpty;

  static String _firstNonEmpty(String primary, String fallback) {
    return primary.isNotEmpty ? primary : fallback;
  }
}
