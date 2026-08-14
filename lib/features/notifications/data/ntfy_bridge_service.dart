import 'package:supabase_flutter/supabase_flutter.dart';

class NtfySubscription {
  const NtfySubscription({required this.topic, required this.serverUrl});

  final String topic;
  final String serverUrl;

  Uri get url {
    final base = serverUrl.endsWith('/')
        ? serverUrl.substring(0, serverUrl.length - 1)
        : serverUrl;
    return Uri.parse('$base/$topic');
  }
}

/// Creates the private ntfy topic for the current allowlisted user.
///
/// The topic is generated server-side and is returned only through an
/// authenticated RPC. It is a capability, so the app never exposes a list of
/// other users' topics.
class NtfyBridgeService {
  NtfyBridgeService({required this.client});

  final SupabaseClient client;

  Future<NtfySubscription> getOrCreateSubscription() async {
    if (client.auth.currentSession == null) {
      throw StateError('Inicia sesión para configurar los avisos.');
    }
    final response = await client.rpc('get_or_create_ntfy_subscription');
    final rows = response is List ? response : [response];
    Map? first;
    for (final row in rows) {
      if (row is Map) {
        first = row;
        break;
      }
    }
    if (first == null) {
      throw StateError('El servidor no devolvió el canal ntfy.');
    }
    final topic = first['topic']?.toString() ?? '';
    final serverUrl = first['server_url']?.toString() ?? 'https://ntfy.sh';
    if (topic.isEmpty || serverUrl.isEmpty) {
      throw StateError('El canal ntfy está incompleto.');
    }
    return NtfySubscription(topic: topic, serverUrl: serverUrl);
  }
}
