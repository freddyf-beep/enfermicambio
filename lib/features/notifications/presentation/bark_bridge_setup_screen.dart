import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../shared/ui/app_theme.dart';
import '../data/bark_bridge_service.dart';

const _barkAppStoreUrl =
    'https://apps.apple.com/us/app/bark-custom-notifications/id1403753865';

class BarkBridgeSetupScreen extends StatefulWidget {
  const BarkBridgeSetupScreen({super.key});

  @override
  State<BarkBridgeSetupScreen> createState() => _BarkBridgeSetupScreenState();
}

class _BarkBridgeSetupScreenState extends State<BarkBridgeSetupScreen> {
  late final BarkBridgeService _service;
  late final TextEditingController _controller;
  BarkDeviceConfig? _config;
  Object? _error;
  bool _loading = true;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _service = BarkBridgeService(client: Supabase.instance.client);
    _controller = TextEditingController();
    _load();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    if (mounted) {
      setState(() {
        _loading = true;
        _error = null;
      });
    }
    try {
      final config = await _service.load();
      if (!mounted) return;
      setState(() {
        _config = config;
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

  Future<void> _save() async {
    FocusManager.instance.primaryFocus?.unfocus();
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      final config = await _service.register(_controller.text);
      if (!mounted) return;
      setState(() {
        _config = config;
        _saving = false;
        _controller.clear();
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Bark quedó activado para este teléfono.'),
        ),
      );
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _error = error;
        _saving = false;
      });
    }
  }

  Future<void> _disable() async {
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      await _service.disable();
      if (!mounted) return;
      setState(() {
        _config = null;
        _saving = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Bark desactivado. El teléfono vuelve al puente anterior.',
          ),
        ),
      );
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _error = error;
        _saving = false;
      });
    }
  }

  Future<void> _openAppStore() async {
    final uri = Uri.parse(_barkAppStoreUrl);
    final opened = await launchUrl(uri, mode: LaunchMode.externalApplication);
    if (!opened && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No se pudo abrir la App Store.')),
      );
    }
  }

  Future<void> _shareToWhatsApp() async {
    final value = _controller.text.trim();
    if (value.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Primero pega la URL de prueba de Bark.')),
      );
      return;
    }
    final message =
        'Configuración de avisos de EnfermiCambio\n\n'
        'Instala Bark desde App Store:\n$_barkAppStoreUrl\n\n'
        'URL de prueba del dispositivo:\n$value\n\n'
        'Envíala a Freddy por WhatsApp para terminar la conexión.';
    final uri = Uri.parse(
      'https://wa.me/?text=${Uri.encodeComponent(message)}',
    );
    final opened = await launchUrl(uri, mode: LaunchMode.externalApplication);
    if (!opened && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No se pudo abrir WhatsApp.')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Avisos fuera de la app')),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null && _config == null
          ? _ErrorState(error: _error!, onRetry: _load)
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                if (_config?.enabled == true)
                  _ActiveState(config: _config!, onDisable: _disable)
                else
                  _SetupState(
                    controller: _controller,
                    saving: _saving,
                    error: _error,
                    onOpenAppStore: _openAppStore,
                    onShareToWhatsApp: _shareToWhatsApp,
                    onSave: _save,
                  ),
              ],
            ),
    );
  }
}

class _SetupState extends StatelessWidget {
  const _SetupState({
    required this.controller,
    required this.saving,
    required this.error,
    required this.onOpenAppStore,
    required this.onShareToWhatsApp,
    required this.onSave,
  });

  final TextEditingController controller;
  final bool saving;
  final Object? error;
  final VoidCallback onOpenAppStore;
  final VoidCallback onShareToWhatsApp;
  final VoidCallback onSave;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Card(
          child: Padding(
            padding: const EdgeInsets.all(18),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(
                  Icons.notifications_active_outlined,
                  size: 36,
                  color: AppColors.primaryLight,
                ),
                const SizedBox(height: 12),
                Text(
                  'Configurar Bark',
                  style: Theme.of(
                    context,
                  ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                const Text(
                  'Bark es una aplicación nativa para iPhone. Recibe los avisos aunque EnfermiCambio esté cerrada y no agrega ningún marcador web a la pantalla de inicio.',
                ),
                const SizedBox(height: 16),
                const _TutorialStep(
                  number: '1',
                  title: 'Instala Bark',
                  body:
                      'Pulsa el botón y acepta los permisos de notificaciones.',
                ),
                OutlinedButton.icon(
                  onPressed: onOpenAppStore,
                  icon: const Icon(Icons.download_outlined),
                  label: const Text('Ir a Bark en App Store'),
                ),
                const _TutorialStep(
                  number: '2',
                  title: 'Copia la URL de prueba',
                  body:
                      'En Bark pulsa +, copia la URL de prueba y vuelve aquí.',
                ),
                const _TutorialStep(
                  number: '3',
                  title: 'Pega y guarda',
                  body: 'Pega esa URL abajo para vincular solo este iPhone.',
                ),
                const SizedBox(height: 14),
                TextField(
                  controller: controller,
                  autocorrect: false,
                  keyboardType: TextInputType.url,
                  decoration: const InputDecoration(
                    labelText: 'URL de prueba de Bark',
                    hintText: 'https://api.day.app/tu_clave',
                    helperText:
                        'En Bark: abre la app → Copiar URL de prueba → pégala aquí.',
                    border: OutlineInputBorder(),
                  ),
                ),
                if (error != null) ...[
                  const SizedBox(height: 10),
                  Text(
                    error.toString().replaceFirst('Exception: ', ''),
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.error,
                    ),
                  ),
                ],
                const SizedBox(height: 14),
                OutlinedButton.icon(
                  onPressed: onShareToWhatsApp,
                  icon: const Icon(Icons.share_outlined),
                  label: const Text('Enviar el enlace a Freddy por WhatsApp'),
                ),
                const SizedBox(height: 10),
                FilledButton.icon(
                  onPressed: saving ? null : onSave,
                  icon: saving
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.check),
                  label: Text(saving ? 'Guardando…' : 'Guardar y activar Bark'),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 14),
        const Text(
          'Después de guardar la URL, este iPhone recibirá los avisos de EnfermiCambio mediante Bark.',
        ),
      ],
    );
  }
}

class _TutorialStep extends StatelessWidget {
  const _TutorialStep({
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
      padding: const EdgeInsets.only(top: 14),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          CircleAvatar(
            radius: 13,
            backgroundColor: AppColors.primaryLight,
            foregroundColor: AppColors.darkBackground,
            child: Text(number),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 2),
                Text(body),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ActiveState extends StatelessWidget {
  const _ActiveState({required this.config, required this.onDisable});

  final BarkDeviceConfig config;
  final VoidCallback onDisable;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Card(
          child: Padding(
            padding: const EdgeInsets.all(18),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(
                  Icons.check_circle_outline,
                  size: 36,
                  color: Colors.greenAccent,
                ),
                const SizedBox(height: 12),
                Text(
                  'Bark está activo',
                  style: Theme.of(
                    context,
                  ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                const Text(
                  'Este iPhone recibirá los avisos fuera de EnfermiCambio. La app Bark debe conservar habilitadas sus notificaciones en Ajustes.',
                ),
                const SizedBox(height: 14),
                Text(
                  'Dispositivo: ${config.maskedKey}',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
                const SizedBox(height: 16),
                OutlinedButton.icon(
                  onPressed: onDisable,
                  icon: const Icon(Icons.notifications_off_outlined),
                  label: const Text('Desactivar Bark en este teléfono'),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 14),
        const Text(
          'Mantén activadas las notificaciones de Bark en Ajustes para recibir avisos con la pantalla bloqueada.',
        ),
      ],
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
            Text(
              error.toString().replaceFirst('Exception: ', ''),
              textAlign: TextAlign.center,
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
