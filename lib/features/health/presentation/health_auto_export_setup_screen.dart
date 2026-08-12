import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:share_plus/share_plus.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../shared/ui/app_theme.dart';
import '../data/health_auto_export_setup_service.dart';

class HealthAutoExportSetupScreen extends StatefulWidget {
  const HealthAutoExportSetupScreen({this.service, super.key});

  final HealthAutoExportSetupService? service;

  @override
  State<HealthAutoExportSetupScreen> createState() =>
      _HealthAutoExportSetupScreenState();
}

class _HealthAutoExportSetupScreenState
    extends State<HealthAutoExportSetupScreen> {
  late final HealthAutoExportSetupService _service;
  HealthAutoExportSetup? _setup;
  bool _loading = false;

  @override
  void initState() {
    super.initState();
    _service =
        widget.service ??
        HealthAutoExportSetupService(client: Supabase.instance.client);
  }

  Future<void> _prepare() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Preparar puente del iPhone'),
        content: const Text(
          'Se generará un token privado para esta cuenta y se reemplazará el token anterior. '
          'Después abrirás dos automatizaciones en Health Auto Export: métricas y entrenamientos. '
          'No compartas esos enlaces.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Preparar'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    setState(() => _loading = true);
    try {
      final setup = await _service.prepareForCurrentUser();
      if (!mounted) return;
      setState(() => _setup = setup);
      _showMessage('Configuración lista para esta cuenta.');
    } on Exception catch (error) {
      if (!mounted) return;
      _showMessage('No se pudo preparar el puente: $error');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _openLink(Uri link) async {
    final opened = await launchUrl(link, mode: LaunchMode.externalApplication);
    if (!opened && mounted) {
      await _copyLink(link);
      _showMessage('No se pudo abrir Health Auto Export. Enlace copiado.');
    }
  }

  Future<void> _copyLink(Uri link) async {
    await Clipboard.setData(ClipboardData(text: link.toString()));
    if (mounted) _showMessage('Enlace copiado. Ábrelo en Safari.');
  }

  Future<void> _shareConfiguration(HealthAutoExportSetup setup) async {
    final box = context.findRenderObject() as RenderBox?;
    await SharePlus.instance.share(
      ShareParams(
        title: 'Instalador de Health Auto Export',
        text:
            'Guarda este archivo en Archivos o envíalo a la persona que configurará el iPhone. '
            'Contiene enlaces privados de esta cuenta.',
        files: [
          XFile.fromData(
            utf8.encode(setup.shareableFileText),
            mimeType: 'text/html',
          ),
        ],
        fileNameOverrides: [setup.shareableFileName],
        sharePositionOrigin: box == null
            ? null
            : box.localToGlobal(Offset.zero) & box.size,
      ),
    );
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    final setup = _setup;
    return Scaffold(
      appBar: AppBar(title: const Text('Puente de salud del iPhone')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Card(
            color: Theme.of(context).colorScheme.secondaryContainer,
            child: const Padding(
              padding: EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(Icons.favorite_outline, color: AppColors.primaryLight),
                  SizedBox(height: 12),
                  Text(
                    'Health Auto Export será el puente',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 17),
                  ),
                  SizedBox(height: 8),
                  Text(
                    'EnfermiCambio no necesita leer Apple Salud directamente. Esta pantalla prepara las automatizaciones para que Health Auto Export envíe tus datos a tu propia cuenta.',
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          FilledButton.icon(
            onPressed: _loading ? null : _prepare,
            icon: _loading
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.auto_fix_high),
            label: Text(
              _loading ? 'Preparando...' : 'Preparar automatizaciones',
            ),
            style: FilledButton.styleFrom(
              minimumSize: const Size.fromHeight(50),
            ),
          ),
          const SizedBox(height: 10),
          Text(
            'Debes hacerlo con la cuenta que usará este iPhone. Si es para Sammy, Sammy debe iniciar sesión con su propia cuenta y generar su archivo. Al preparar de nuevo, el enlace anterior deja de funcionar.',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
            textAlign: TextAlign.center,
          ),
          if (setup != null) ...[
            const SizedBox(height: 24),
            Text(
              'Listo: token ${setup.tokenPrefix}…',
              style: Theme.of(
                context,
              ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            _AutomationAction(
              title: '1. Métricas de Salud',
              description: 'Pasos, calorías, distancia y minutos de ejercicio.',
              onOpen: () => _openLink(setup.metricsLink),
              onCopy: () => _copyLink(setup.metricsLink),
            ),
            _AutomationAction(
              title: '2. Entrenamientos y rutas',
              description:
                  'Carreras, caminatas, ciclismo y sus recorridos GPS.',
              onOpen: () => _openLink(setup.workoutsLink),
              onCopy: () => _copyLink(setup.workoutsLink),
            ),
            Card(
              child: ListTile(
                leading: const Icon(Icons.ios_share_outlined),
                title: const Text('Compartir instalador para este iPhone'),
                subtitle: const Text(
                  'Guárdalo en Archivos o envíalo a otro dispositivo que use esta misma cuenta. Al abrirlo en Safari, podrá tocar los dos botones privados.',
                ),
                trailing: IconButton(
                  tooltip: 'Compartir instalador',
                  onPressed: () => _shareConfiguration(setup),
                  icon: const Icon(Icons.file_download_outlined),
                ),
              ),
            ),
            const SizedBox(height: 12),
            const Card(
              child: ListTile(
                leading: Icon(Icons.check_circle_outline),
                title: Text('Después de abrir cada enlace'),
                subtitle: Text(
                  'Concede a Health Auto Export los permisos de Apple Salud, revisa la configuración y pulsa Actualizar. Luego vuelve aquí y refresca Hoy.',
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _AutomationAction extends StatelessWidget {
  const _AutomationAction({
    required this.title,
    required this.description,
    required this.onOpen,
    required this.onCopy,
  });

  final String title;
  final String description;
  final VoidCallback onOpen;
  final VoidCallback onCopy;

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 8, 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: const TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 4),
            Text(description),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton.icon(
                  onPressed: onCopy,
                  icon: const Icon(Icons.copy_outlined, size: 18),
                  label: const Text('Copiar'),
                ),
                FilledButton.icon(
                  onPressed: onOpen,
                  icon: const Icon(Icons.open_in_new, size: 18),
                  label: const Text('Abrir'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
