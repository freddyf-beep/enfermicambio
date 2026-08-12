import 'package:flutter/material.dart';

import '../../../shared/config/app_environment.dart';
import '../../../shared/ui/app_theme.dart';
import '../../../shared/ui/async_state_view.dart';
import '../../../shared/ui/async_view_status.dart';
import '../domain/health_models.dart';
import '../domain/health_setup_models.dart';

class HealthSetupScreen extends StatefulWidget {
  const HealthSetupScreen({
    required this.repository,
    this.onConnectionVerified,
    super.key,
  });

  final HealthRepository repository;
  final Future<void> Function()? onConnectionVerified;

  @override
  State<HealthSetupScreen> createState() => _HealthSetupScreenState();
}

class _HealthSetupScreenState extends State<HealthSetupScreen>
    with WidgetsBindingObserver {
  HealthSetupSnapshot? _snapshot;
  AsyncViewStatus? _status;
  bool _requesting = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _refresh();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed && !_requesting) {
      _refresh();
    }
  }

  Future<void> _refresh() async {
    if (mounted) {
      setState(() {
        _status = null;
      });
    }
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

    var requested = false;
    HealthReadResult? verification;
    String? errorMessage;
    try {
      requested = await widget.repository.requestAllPermissions();
      if (requested) {
        // On iOS the request result only means that the system sheet completed.
        // A real read is the honest way to verify the connection.
        verification = await widget.repository.readToday(
          now: DateTime.now().toUtc(),
          competitionTimezone: AppEnvironment.competitionTimezone,
        );
        if (verification.status == HealthReadStatus.success) {
          await widget.onConnectionVerified?.call();
        }
      }
    } on Exception catch (error) {
      errorMessage = error.toString();
    }

    if (!mounted) return;
    setState(() {
      _requesting = false;
    });
    await _refresh();
    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          _requestMessage(
            requested: requested,
            verification: verification,
            errorMessage: errorMessage,
          ),
        ),
      ),
    );
  }

  Future<void> _verifyRead() async {
    setState(() {
      _requesting = true;
    });
    HealthReadResult? result;
    String? errorMessage;
    try {
      result = await widget.repository.readToday(
        now: DateTime.now().toUtc(),
        competitionTimezone: AppEnvironment.competitionTimezone,
      );
      if (result.status == HealthReadStatus.success) {
        await widget.onConnectionVerified?.call();
      }
    } on Exception catch (error) {
      errorMessage = error.toString();
    }
    if (!mounted) return;
    setState(() {
      _requesting = false;
    });
    await _refresh();
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(errorMessage ?? _verificationMessage(result))),
    );
  }

  String _requestMessage({
    required bool requested,
    required HealthReadResult? verification,
    required String? errorMessage,
  }) {
    if (errorMessage != null) {
      return 'No se pudo conectar con salud: $errorMessage';
    }
    if (!requested) {
      return _snapshot?.state == HealthSetupState.unavailable
          ? 'El servicio de salud no está disponible en este dispositivo.'
          : 'No se concedieron los permisos de salud.';
    }
    return _verificationMessage(verification);
  }

  String _verificationMessage(HealthReadResult? result) {
    return switch (result?.status) {
      HealthReadStatus.success =>
        'Salud conectada. Se encontraron datos automáticos y se pueden sincronizar.',
      HealthReadStatus.noData =>
        'La lectura terminó, pero no hay datos automáticos visibles para hoy. En iOS, revisa Apple Health si esperabas encontrar actividad.',
      HealthReadStatus.permissionDenied =>
        'Faltan permisos de lectura. Revísalos en la app de salud e inténtalo de nuevo.',
      HealthReadStatus.sourceUnavailable =>
        'La fuente de salud no respondió. Comprueba Apple Health o Health Connect.',
      HealthReadStatus.retryableFailure =>
        'La lectura tardó demasiado. Inténtalo de nuevo.',
      _ =>
        'La solicitud terminó. Apple Health protege el detalle del permiso; se verificará con la próxima lectura.',
    };
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
                if (_messageFor(snapshot) != null) ...[
                  _InfoCard(
                    icon: _iconFor(snapshot.state),
                    message: _messageFor(snapshot)!,
                  ),
                  const SizedBox(height: 16),
                ],
                _PermissionList(snapshot: snapshot),
                const SizedBox(height: 16),
                FilledButton.icon(
                  onPressed: _requesting
                      ? null
                      : _isReadVerified(snapshot.state)
                      ? _verifyRead
                      : _requestAll,
                  icon: _requesting
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : Icon(
                          _isReadVerified(snapshot.state)
                              ? Icons.sync
                              : Icons.health_and_safety_outlined,
                        ),
                  label: Text(
                    _requesting
                        ? 'Comprobando...'
                        : _isReadVerified(snapshot.state)
                        ? 'Leer salud ahora'
                        : snapshot.state == HealthSetupState.unavailable
                        ? 'Intentar de nuevo'
                        : 'Conectar salud',
                  ),
                  style: FilledButton.styleFrom(
                    minimumSize: const Size.fromHeight(48),
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  'Solo leemos pasos, calorías activas, distancia y minutos de ejercicio. Los registros manuales de pasos nunca cuentan.',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
    );
  }

  bool _isReadVerified(HealthSetupState state) =>
      state == HealthSetupState.connected || state == HealthSetupState.noData;

  String? _messageFor(HealthSetupSnapshot snapshot) {
    return switch (snapshot.state) {
      HealthSetupState.unavailable =>
        snapshot.message ??
            'La fuente de salud no está disponible. Usa un iPhone real con Apple Health o instala Health Connect en Android.',
      HealthSetupState.notGranted =>
        'El ranking necesita acceso de lectura automático. Puedes volver a solicitarlo desde aquí.',
      HealthSetupState.partial =>
        'Hay permisos parciales. Conecta los grupos que faltan para sincronizar todas las métricas.',
      HealthSetupState.requested => snapshot.message,
      HealthSetupState.retryable =>
        snapshot.message ??
            'No pudimos comprobar el estado. Inténtalo de nuevo.',
      HealthSetupState.noData =>
        snapshot.platform == 'ios'
            ? 'Apple Health no devolvió datos. Por privacidad, iOS no permite distinguir entre permisos no concedidos y un día sin registros; revisa Salud > Apps > Enfermicambio si esperabas actividad.'
            : 'La conexión funciona, pero la fuente todavía no tiene registros automáticos para hoy.',
      HealthSetupState.connected =>
        'La última lectura fue correcta. Puedes actualizarla cuando quieras.',
      HealthSetupState.available => null,
    };
  }
}

class _PlatformCard extends StatelessWidget {
  const _PlatformCard({required this.snapshot});

  final HealthSetupSnapshot snapshot;

  @override
  Widget build(BuildContext context) {
    final color = _colorFor(snapshot.state);
    final platformName = snapshot.platform == 'ios'
        ? 'Apple Health (iOS)'
        : 'Health Connect (Android)';
    return Card(
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        leading: Icon(_iconFor(snapshot.state), color: color, size: 32),
        title: Text(
          platformName,
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        subtitle: Text(
          '${_labelFor(snapshot.state)}${snapshot.platform == 'android' && snapshot.healthAvailable ? ' · ${snapshot.grantedTypes.length} de 4 grupos' : ''}',
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
          style: Theme.of(
            context,
          ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 8),
        for (final setting in settings)
          Card(
            margin: const EdgeInsets.only(bottom: 8),
            child: ListTile(
              leading: Icon(
                setting.granted == true
                    ? Icons.check_circle_outline
                    : setting.granted == false
                    ? Icons.radio_button_unchecked
                    : Icons.help_outline,
                color: setting.granted == true
                    ? AppColors.fitnessGreen
                    : Theme.of(context).colorScheme.outline,
              ),
              title: Text(
                setting.title,
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
              subtitle: Text(setting.description),
              trailing: Text(
                _permissionLabel(snapshot, setting),
                style: TextStyle(
                  color: setting.granted == true
                      ? AppColors.fitnessGreen
                      : Theme.of(context).colorScheme.onSurfaceVariant,
                  fontWeight: FontWeight.bold,
                  fontSize: 12,
                ),
                textAlign: TextAlign.end,
              ),
            ),
          ),
      ],
    );
  }

  List<HealthPermissionSetting> _buildSettings(HealthSetupSnapshot snapshot) {
    final granted = snapshot.grantedTypes;
    final iOSReadStateIsPrivate = snapshot.platform == 'ios';
    return [
      HealthPermissionSetting(
        id: 'steps',
        title: 'Pasos automáticos',
        description:
            'Conteo de pasos desde el sensor y las fuentes conectadas.',
        metric: HealthMetricType.steps,
        granted: iOSReadStateIsPrivate
            ? null
            : granted.contains(HealthMetricType.steps),
        supported: snapshot.healthAvailable,
      ),
      HealthPermissionSetting(
        id: 'active_calories',
        title: 'Calorías activas',
        description: 'Energía quemada por movimiento y ejercicio.',
        metric: HealthMetricType.activeCalories,
        granted: iOSReadStateIsPrivate
            ? null
            : granted.contains(HealthMetricType.activeCalories),
        supported: snapshot.healthAvailable,
      ),
      HealthPermissionSetting(
        id: 'distance',
        title: 'Distancia recorrida',
        description: 'Distancia total caminada o corrida en el día.',
        metric: HealthMetricType.distance,
        granted: iOSReadStateIsPrivate
            ? null
            : granted.contains(HealthMetricType.distance),
        supported: snapshot.healthAvailable,
      ),
      HealthPermissionSetting(
        id: 'exercise_minutes',
        title: 'Minutos de ejercicio',
        description: 'Tiempo acumulado de entrenamiento activo.',
        metric: HealthMetricType.exerciseMinutes,
        granted: iOSReadStateIsPrivate
            ? null
            : granted.contains(HealthMetricType.exerciseMinutes),
        supported: snapshot.healthAvailable,
      ),
    ];
  }

  String _permissionLabel(
    HealthSetupSnapshot snapshot,
    HealthPermissionSetting setting,
  ) {
    if (!setting.supported) return 'No disponible';
    if (setting.granted == true) return 'Concedido';
    if (setting.granted == false) return 'Falta';
    if (snapshot.state == HealthSetupState.connected) {
      return 'Validado por lectura';
    }
    if (snapshot.state == HealthSetupState.noData &&
        snapshot.platform == 'ios') {
      return 'Sin datos visibles';
    }
    if (snapshot.state == HealthSetupState.noData) {
      return 'Sin datos hoy';
    }
    return 'Apple protege este estado';
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

String _labelFor(HealthSetupState state) {
  return switch (state) {
    HealthSetupState.available => 'Listo para conectar',
    HealthSetupState.unavailable => 'No disponible',
    HealthSetupState.notGranted => 'Faltan permisos',
    HealthSetupState.partial => 'Permisos parciales',
    HealthSetupState.requested => 'Solicitud completada; falta validar',
    HealthSetupState.connected => 'Conectado',
    HealthSetupState.noData => 'Lectura sin datos',
    HealthSetupState.retryable => 'Requiere reintento',
  };
}

IconData _iconFor(HealthSetupState state) {
  return switch (state) {
    HealthSetupState.connected || HealthSetupState.noData => Icons.check_circle,
    HealthSetupState.unavailable ||
    HealthSetupState.retryable => Icons.error_outline,
    HealthSetupState.requested => Icons.hourglass_top,
    _ => Icons.health_and_safety_outlined,
  };
}

Color _colorFor(HealthSetupState state) {
  return switch (state) {
    HealthSetupState.connected ||
    HealthSetupState.noData => AppColors.fitnessGreen,
    HealthSetupState.unavailable ||
    HealthSetupState.retryable => AppColors.streakOrange,
    _ => AppColors.primaryLight,
  };
}
