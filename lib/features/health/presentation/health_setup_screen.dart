import 'package:flutter/material.dart';

import '../../../shared/ui/app_theme.dart';
import '../../../shared/ui/async_state_view.dart';
import '../../../shared/ui/async_view_status.dart';
import '../domain/health_models.dart';
import '../domain/health_setup_models.dart';

class HealthSetupScreen extends StatefulWidget {
  const HealthSetupScreen({required this.repository, super.key});

  final HealthRepository repository;

  @override
  State<HealthSetupScreen> createState() => _HealthSetupScreenState();
}

class _HealthSetupScreenState extends State<HealthSetupScreen> {
  HealthSetupSnapshot? _snapshot;
  AsyncViewStatus? _status;
  bool _requesting = false;

  @override
  void initState() {
    super.initState();
    _refresh();
  }

  Future<void> _refresh() async {
    setState(() {
      _status = null;
    });
    try {
      final snapshot = await widget.repository.readSetupStatus();
      if (!mounted) return;
      setState(() {
        _snapshot = snapshot;
      });
    } on Exception catch (error) {
      if (!mounted) return;
      setState(() {
        _status = AsyncViewStatus.backendError(error.toString());
      });
    }
  }

  Future<void> _requestAll() async {
    setState(() {
      _requesting = true;
    });
    final granted = await widget.repository.requestAllPermissions();
    if (!mounted) return;
    setState(() {
      _requesting = false;
    });
    final healthUnavailable = _snapshot?.healthAvailable == false;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          granted
              ? 'Permisos de salud concedidos exitosamente.'
              : healthUnavailable
              ? 'El servicio de salud no está disponible en este dispositivo. Abre Health Connect o Apple Health e inténtalo de nuevo.'
              : 'Los permisos de salud no fueron concedidos.',
        ),
      ),
    );
    await _refresh();
  }

  @override
  Widget build(BuildContext context) {
    final snapshot = _snapshot;
    return Scaffold(
      appBar: AppBar(title: const Text('Configuración de Salud')),
      body: snapshot == null
          ? AsyncStateView(
              status: _status ?? const AsyncViewStatus.loading(),
              onRetry: _refresh,
              child: const SizedBox(),
            )
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                _PlatformCard(snapshot: snapshot),
                const SizedBox(height: 16),
                if (!snapshot.healthAvailable) ...[
                  const _InfoCard(
                    icon: Icons.info_outline,
                    message:
                        'El servicio de salud no está disponible en este dispositivo o emulador. En un teléfono real, activa Health Connect (Android) o Apple Health (iOS) y regresa aquí.',
                  ),
                  const SizedBox(height: 16),
                ],
                _PermissionList(snapshot: snapshot),
                const SizedBox(height: 16),
                FilledButton.icon(
                  onPressed: _requesting ? null : _requestAll,
                  icon: _requesting
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.health_and_safety_outlined),
                  label: Text(
                    _requesting ? 'Solicitando...' : 'Solicitar todos los permisos',
                  ),
                  style: FilledButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 14),
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  'Los pasos, calorías activas, distancia y minutos de ejercicio se leen automáticamente. Los registros manuales de pasos nunca cuentan.',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
    );
  }
}

class _PlatformCard extends StatelessWidget {
  const _PlatformCard({required this.snapshot});

  final HealthSetupSnapshot snapshot;

  @override
  Widget build(BuildContext context) {
    final healthy = snapshot.healthAvailable;
    return Card(
      child: ListTile(
        leading: Icon(
          healthy ? Icons.check_circle : Icons.error_outline,
          color: healthy ? AppColors.fitnessGreen : AppColors.streakOrange,
          size: 32,
        ),
        title: Text(
          snapshot.platform == 'ios' ? 'Apple Health (iOS)' : 'Health Connect (Android)',
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        subtitle: Text(
          healthy
              ? 'Disponible - ${snapshot.grantedTypes.length} de 4 grupos de permisos concedidos'
              : 'No disponible: ${snapshot.message ?? 'Razón desconocida'}',
        ),
      ),
    );
  }
}

class _PermissionList extends StatelessWidget {
  const _PermissionList({required this.snapshot});

  final HealthSetupSnapshot snapshot;

  @override
  Widget build(BuildContext context) {
    final settings = _buildSettings(snapshot);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Permisos de Salud',
          style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 8),
        for (final setting in settings)
          Card(
            margin: const EdgeInsets.only(bottom: 8),
            child: ListTile(
              leading: Icon(
                setting.granted ? Icons.check_circle_outline : Icons.radio_button_unchecked,
                color: setting.granted ? AppColors.fitnessGreen : Theme.of(context).colorScheme.outline,
              ),
              title: Text(setting.title, style: const TextStyle(fontWeight: FontWeight.bold)),
              subtitle: Text(setting.description),
              trailing: setting.granted
                  ? const Text('Concedido', style: TextStyle(color: AppColors.fitnessGreen, fontWeight: FontWeight.bold))
                  : (setting.supported ? const Text('No concedido') : null),
            ),
          ),
      ],
    );
  }

  List<HealthPermissionSetting> _buildSettings(HealthSetupSnapshot snapshot) {
    final granted = snapshot.grantedTypes;
    return [
      HealthPermissionSetting(
        id: 'steps',
        title: 'Pasos Automáticos',
        description: 'Conteo continuo de pasos desde el sensor de tu dispositivo.',
        metric: HealthMetricType.steps,
        granted: granted.contains(HealthMetricType.steps),
      ),
      HealthPermissionSetting(
        id: 'active_calories',
        title: 'Calorías Activas',
        description: 'Energía quemada por movimiento corporal y ejercicio.',
        metric: HealthMetricType.activeCalories,
        granted: granted.contains(HealthMetricType.activeCalories),
      ),
      HealthPermissionSetting(
        id: 'distance',
        title: 'Distancia Recorrida',
        description: 'Distancia total caminada o corrida en el día.',
        metric: HealthMetricType.distance,
        granted: granted.contains(HealthMetricType.distance),
      ),
      HealthPermissionSetting(
        id: 'exercise_minutes',
        title: 'Minutos de Ejercicio',
        description: 'Tiempo acumulado de entrenamiento activo.',
        metric: HealthMetricType.exerciseMinutes,
        granted: granted.contains(HealthMetricType.exerciseMinutes),
      ),
    ];
  }
}

class _InfoCard extends StatelessWidget {
  const _InfoCard({required this.icon, required this.message});

  final IconData icon;
  final String message;

  @override
  Widget build(BuildContext context) {
    return Card(
      color: AppColors.darkSurfaceVariant,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Icon(icon, color: AppColors.streakOrange),
            const SizedBox(width: 12),
            Expanded(child: Text(message)),
          ],
        ),
      ),
    );
  }
}
