import 'package:flutter/material.dart';

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
              ? 'Health permissions granted.'
              : healthUnavailable
              ? 'The health service is not available on this device. '
                    'Open Health Connect and try again.'
              : 'Health permissions were not granted.',
        ),
      ),
    );
    await _refresh();
  }

  @override
  Widget build(BuildContext context) {
    final snapshot = _snapshot;
    return Scaffold(
      appBar: AppBar(title: const Text('Health settings')),
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
                        'The health service is not available on this device or '
                        'simulator. On a real phone, open Health Connect or '
                        'Apple Health, then return here.',
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
                    _requesting ? 'Requesting...' : 'Request all permissions',
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Steps, active calories, distance, and exercise minutes are '
                  'read automatically. Manual step entries never count.',
                  style: Theme.of(context).textTheme.bodySmall,
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
    final theme = Theme.of(context);
    final healthy = snapshot.healthAvailable;
    return Card(
      child: ListTile(
        leading: Icon(
          healthy ? Icons.check_circle : Icons.error_outline,
          color: healthy ? theme.colorScheme.primary : theme.colorScheme.error,
          size: 32,
        ),
        title: Text(
          snapshot.platform == 'ios' ? 'Apple Health' : 'Health Connect',
        ),
        subtitle: Text(
          healthy
              ? 'Available - ${snapshot.grantedTypes.length} of '
                    '4 permission groups granted'
              : 'Not available: ${snapshot.message ?? 'unknown reason'}',
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
        Text('Permissions', style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 8),
        for (final setting in settings)
          Card(
            margin: const EdgeInsets.only(bottom: 8),
            child: ListTile(
              leading: Icon(
                setting.granted
                    ? Icons.check_circle_outline
                    : Icons.radio_button_unchecked,
                color: setting.granted
                    ? Theme.of(context).colorScheme.primary
                    : Theme.of(context).colorScheme.outline,
              ),
              title: Text(setting.title),
              subtitle: Text(setting.description),
              trailing: setting.granted
                  ? const Text('Granted')
                  : (setting.supported ? const Text('Not granted') : null),
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
        title: 'Steps',
        description: 'Automatic step counting from your device.',
        metric: HealthMetricType.steps,
        granted: granted.contains(HealthMetricType.steps),
      ),
      HealthPermissionSetting(
        id: 'active_calories',
        title: 'Active calories',
        description: 'Energy burned from movement and exercise.',
        metric: HealthMetricType.activeCalories,
        granted: granted.contains(HealthMetricType.activeCalories),
      ),
      HealthPermissionSetting(
        id: 'distance',
        title: 'Distance',
        description: 'Distance walked or run.',
        metric: HealthMetricType.distance,
        granted: granted.contains(HealthMetricType.distance),
      ),
      HealthPermissionSetting(
        id: 'exercise_minutes',
        title: 'Exercise minutes',
        description: 'Minutes of active exercise.',
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
      color: Theme.of(context).colorScheme.surfaceContainerHighest,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Icon(icon),
            const SizedBox(width: 12),
            Expanded(child: Text(message)),
          ],
        ),
      ),
    );
  }
}
