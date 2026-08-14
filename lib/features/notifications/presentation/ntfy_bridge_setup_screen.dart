import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../shared/ui/app_theme.dart';
import '../data/ntfy_bridge_service.dart';

class NtfyBridgeSetupScreen extends StatefulWidget {
  const NtfyBridgeSetupScreen({super.key});

  @override
  State<NtfyBridgeSetupScreen> createState() => _NtfyBridgeSetupScreenState();
}

class _NtfyBridgeSetupScreenState extends State<NtfyBridgeSetupScreen> {
  late final NtfyBridgeService _service;
  NtfySubscription? _subscription;
  Object? _error;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _service = NtfyBridgeService(client: Supabase.instance.client);
    _load();
  }

  Future<void> _load() async {
    if (mounted) {
      setState(() {
        _loading = true;
        _error = null;
      });
    }
    try {
      final subscription = await _service.getOrCreateSubscription();
      if (!mounted) return;
      setState(() {
        _subscription = subscription;
        _loading = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _error = error;
        _loading = false;
      });
    }
  }

  Future<void> _copy(String value, String message) async {
    await Clipboard.setData(ClipboardData(text: value));
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _openChannel() async {
    final url = _subscription?.url;
    if (url == null) return;
    final opened = await launchUrl(url, mode: LaunchMode.externalApplication);
    if (!opened && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No se pudo abrir el canal ntfy.')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Avisos fuera de la app')),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
          ? _ErrorState(error: _error!, onRetry: _load)
          : _subscription == null
          ? _ErrorState(
              error: StateError('No se pudo preparar el canal ntfy.'),
              onRetry: _load,
            )
          : _ReadyState(
              subscription: _subscription!,
              onOpenChannel: _openChannel,
              onCopyTopic: () => _copy(
                _subscription!.topic,
                'Tópico copiado. Pégalo en la app ntfy.',
              ),
              onCopyUrl: () => _copy(
                _subscription!.url.toString(),
                'Enlace copiado.',
              ),
            ),
    );
  }
}

class _ReadyState extends StatelessWidget {
  const _ReadyState({
    required this.subscription,
    required this.onOpenChannel,
    required this.onCopyTopic,
    required this.onCopyUrl,
  });

  final NtfySubscription subscription;
  final VoidCallback onOpenChannel;
  final VoidCallback onCopyTopic;
  final VoidCallback onCopyUrl;

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Card(
          child: Padding(
            padding: const EdgeInsets.all(18),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(
                  Icons.notifications_active_outlined,
                  size: 34,
                  color: AppColors.primaryLight,
                ),
                const SizedBox(height: 12),
                Text(
                  'Puente ntfy listo',
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 8),
                const Text(
                  'Este canal es individual y permite recibir avisos aunque EnfermiCambio esté cerrada. No necesitas agregar una página a la pantalla de inicio.',
                ),
                const SizedBox(height: 16),
                SelectableText(
                  subscription.topic,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    fontFamily: 'monospace',
                  ),
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    OutlinedButton.icon(
                      onPressed: onCopyTopic,
                      icon: const Icon(Icons.copy, size: 18),
                      label: const Text('Copiar tópico'),
                    ),
                    OutlinedButton.icon(
                      onPressed: onCopyUrl,
                      icon: const Icon(Icons.link, size: 18),
                      label: const Text('Copiar enlace'),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 16),
        const _Instruction(
          number: '1',
          title: 'Instala ntfy',
          body: 'Descarga ntfy gratis desde la App Store y acepta sus notificaciones.',
        ),
        const _Instruction(
          number: '2',
          title: 'Abre tu canal',
          body: 'Pulsa el botón de abajo. Si se abre Safari, copia el tópico y agrégalo desde la app ntfy.',
        ),
        const _Instruction(
          number: '3',
          title: 'Terminado',
          body: 'Desde ese momento los avisos del feed, rondas, logros y mensajes llegarán al iPhone bloqueado.',
        ),
        const SizedBox(height: 12),
        FilledButton.icon(
          onPressed: onOpenChannel,
          icon: const Icon(Icons.open_in_new),
          label: const Text('Abrir mi canal en ntfy'),
        ),
        const SizedBox(height: 8),
        Text(
          'No compartas este tópico: quien lo tenga puede suscribirse al canal.',
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
            color: Colors.orangeAccent,
          ),
        ),
      ],
    );
  }
}

class _Instruction extends StatelessWidget {
  const _Instruction({
    required this.number,
    required this.title,
    required this.body,
  });

  final String number;
  final String title;
  final String body;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          CircleAvatar(
            radius: 14,
            backgroundColor: AppColors.primaryLight,
            child: Text(
              number,
              style: const TextStyle(
                color: Colors.black,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: const TextStyle(fontWeight: FontWeight.bold)),
                const SizedBox(height: 3),
                Text(body),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ErrorState extends StatelessWidget {
  const _ErrorState({required this.error, required this.onRetry});

  final Object error;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.cloud_off_outlined, size: 48),
            const SizedBox(height: 12),
            const Text(
              'No se pudo preparar el puente ntfy.',
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              error.toString().replaceFirst('Exception: ', ''),
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodySmall,
            ),
            const SizedBox(height: 16),
            OutlinedButton.icon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh),
              label: const Text('Reintentar'),
            ),
          ],
        ),
      ),
    );
  }
}
