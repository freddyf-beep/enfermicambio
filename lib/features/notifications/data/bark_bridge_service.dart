import 'package:supabase_flutter/supabase_flutter.dart';

class BarkDeviceConfig {
  const BarkDeviceConfig({
    required this.deviceKey,
    required this.serverUrl,
    this.enabled = true,
  });

  final String deviceKey;
  final String serverUrl;
  final bool enabled;

  Uri get endpoint {
    final base = serverUrl.endsWith('/')
        ? serverUrl.substring(0, serverUrl.length - 1)
        : serverUrl;
    return Uri.parse('$base/${Uri.encodeComponent(deviceKey)}');
  }

  String get maskedKey {
    if (deviceKey.length <= 8) return '••••••••';
    return '${deviceKey.substring(0, 4)}••••${deviceKey.substring(deviceKey.length - 4)}';
  }

  /// Accepts the test URL copied from Bark, or the key itself.
  ///
  /// The public Bark service is intentionally the only server accepted in the
  /// first migration step. Self-hosted Bark can be enabled later through one
  /// server-side configuration change without putting a server URL in the app.
  static BarkDeviceConfig? tryParse(String input) {
    final value = input.trim();
    if (value.isEmpty) return null;

    final directKey = RegExp(r'^[A-Za-z0-9_-]{8,128}$');
    if (directKey.hasMatch(value)) {
      return BarkDeviceConfig(
        deviceKey: value,
        serverUrl: 'https://api.day.app',
      );
    }

    final uri = Uri.tryParse(value);
    if (uri == null || uri.scheme != 'https' || uri.host != 'api.day.app') {
      return null;
    }
    final key = uri.pathSegments.isEmpty ? '' : uri.pathSegments.first;
    if (!directKey.hasMatch(key)) return null;
    return BarkDeviceConfig(deviceKey: key, serverUrl: 'https://api.day.app');
  }
}

class BarkBridgeService {
  BarkBridgeService({required this.client});

  final SupabaseClient client;

  Future<BarkDeviceConfig?> load() async {
    if (client.auth.currentSession == null) return null;
    final response = await client.rpc('get_bark_device');
    final row = _firstMap(response);
    if (row == null) return null;
    final key = row['device_key']?.toString() ?? '';
    final serverUrl = row['server_url']?.toString() ?? 'https://api.day.app';
    if (key.isEmpty || serverUrl.isEmpty) return null;
    return BarkDeviceConfig(
      deviceKey: key,
      serverUrl: serverUrl,
      enabled: row['enabled'] == true,
    );
  }

  Future<BarkDeviceConfig> register(String input) async {
    if (client.auth.currentSession == null) {
      throw StateError('Inicia sesión para configurar Bark.');
    }
    final parsed = BarkDeviceConfig.tryParse(input);
    if (parsed == null) {
      throw const FormatException(
        'Pega la URL de prueba de Bark o solamente la clave del dispositivo.',
      );
    }
    final response = await client.rpc(
      'register_bark_device',
      params: {'p_device_key': parsed.deviceKey},
    );
    final row = _firstMap(response);
    if (row == null) {
      throw StateError('El servidor no devolvió la configuración de Bark.');
    }
    final key = row['device_key']?.toString() ?? '';
    final serverUrl = row['server_url']?.toString() ?? parsed.serverUrl;
    if (key.isEmpty) {
      throw StateError('La configuración de Bark está incompleta.');
    }
    return BarkDeviceConfig(
      deviceKey: key,
      serverUrl: serverUrl,
      enabled: row['enabled'] == true,
    );
  }

  Future<void> disable() async {
    if (client.auth.currentSession == null) return;
    await client.rpc('disable_bark_device');
  }

  Map<String, dynamic>? _firstMap(dynamic response) {
    final rows = response is List ? response : [response];
    for (final row in rows) {
      if (row is Map) return Map<String, dynamic>.from(row);
    }
    return null;
  }
}
