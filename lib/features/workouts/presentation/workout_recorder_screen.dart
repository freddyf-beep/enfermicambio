import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../shared/ui/app_theme.dart';
import '../data/supabase_workout_repository.dart';
import '../data/supabase_workout_route_repository.dart';
import '../domain/workout_models.dart';
import '../domain/workout_recording.dart';
import 'route_map_view.dart';
import 'workout_detail_screen.dart';

class WorkoutRecorderScreen extends StatefulWidget {
  const WorkoutRecorderScreen({super.key});

  @override
  State<WorkoutRecorderScreen> createState() => _WorkoutRecorderScreenState();
}

class _WorkoutRecorderScreenState extends State<WorkoutRecorderScreen> {
  WorkoutActivityType _type = WorkoutActivityType.running;
  late WorkoutRouteAccumulator _route;
  StreamSubscription<Position>? _positionSubscription;
  Timer? _timer;
  DateTime? _startedAt;
  DateTime? _activeSegmentStartedAt;
  Duration _accumulated = Duration.zero;
  bool _recording = false;
  bool _paused = false;
  bool _saving = false;
  String? _statusMessage;

  Duration get _elapsed {
    final segmentStart = _activeSegmentStartedAt;
    if (!_recording || _paused || segmentStart == null) return _accumulated;
    return _accumulated + DateTime.now().difference(segmentStart);
  }

  @override
  void initState() {
    super.initState();
    _route = WorkoutRouteAccumulator(activityType: _type);
  }

  @override
  void dispose() {
    _timer?.cancel();
    unawaited(_positionSubscription?.cancel());
    super.dispose();
  }

  Future<bool> _ensureLocationAccess() async {
    if (!await Geolocator.isLocationServiceEnabled()) {
      setState(() => _statusMessage = 'Activa la ubicación del teléfono.');
      return false;
    }

    var permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }
    if (permission == LocationPermission.denied ||
        permission == LocationPermission.deniedForever) {
      setState(() {
        _statusMessage = permission == LocationPermission.deniedForever
            ? 'El permiso de ubicación está bloqueado. Ábrelo en Ajustes.'
            : 'Se necesita ubicación para registrar la ruta.';
      });
      return false;
    }
    if (Platform.isIOS && permission == LocationPermission.whileInUse) {
      setState(() {
        _statusMessage =
            'GPS listo. Para bloquear la pantalla sin cortar la ruta, permite ubicación “Siempre” en Ajustes.';
      });
    }
    return true;
  }

  LocationSettings _locationSettings(LocationPermission permission) {
    if (Platform.isAndroid) {
      return AndroidSettings(
        accuracy: LocationAccuracy.bestForNavigation,
        distanceFilter: 3,
        intervalDuration: const Duration(seconds: 2),
        foregroundNotificationConfig: const ForegroundNotificationConfig(
          notificationTitle: 'EnfermiCambio está registrando tu ruta',
          notificationText: 'Toca para volver al entrenamiento activo.',
          notificationChannelName: 'Entrenamientos con GPS',
          enableWakeLock: true,
          setOngoing: true,
        ),
      );
    }
    if (Platform.isIOS) {
      return AppleSettings(
        accuracy: LocationAccuracy.bestForNavigation,
        activityType: ActivityType.fitness,
        distanceFilter: 3,
        pauseLocationUpdatesAutomatically: false,
        showBackgroundLocationIndicator:
            permission == LocationPermission.always,
        allowBackgroundLocationUpdates: permission == LocationPermission.always,
      );
    }
    return const LocationSettings(
      accuracy: LocationAccuracy.high,
      distanceFilter: 3,
    );
  }

  Future<void> _start() async {
    if (!await _ensureLocationAccess() || !mounted) return;
    final permission = await Geolocator.checkPermission();
    final now = DateTime.now();
    setState(() {
      _route = WorkoutRouteAccumulator(activityType: _type);
      _startedAt = now;
      _activeSegmentStartedAt = now;
      _accumulated = Duration.zero;
      _recording = true;
      _paused = false;
      _statusMessage = 'Buscando señal GPS precisa…';
    });
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() {});
    });
    _listenForPositions(_locationSettings(permission));
  }

  void _listenForPositions(LocationSettings settings) {
    _positionSubscription =
        Geolocator.getPositionStream(locationSettings: settings).listen(
          (position) {
            if (!_recording || _paused) return;
            final accepted = _route.add(
              LocationSample(
                timestamp: position.timestamp,
                latitude: position.latitude,
                longitude: position.longitude,
                accuracy: position.accuracy,
                altitude: position.altitude,
                bearing: position.heading,
                speed: position.speed,
              ),
            );
            if (accepted && mounted) {
              setState(() {
                _statusMessage = position.accuracy <= 20
                    ? 'GPS preciso · ±${position.accuracy.round()} m'
                    : 'Mejorando precisión · ±${position.accuracy.round()} m';
              });
            }
          },
          onError: (Object error) {
            if (mounted) {
              setState(() => _statusMessage = 'GPS interrumpido: $error');
            }
          },
        );
  }

  Future<void> _pause() async {
    final segmentStart = _activeSegmentStartedAt;
    if (segmentStart != null) {
      _accumulated += DateTime.now().difference(segmentStart);
    }
    _activeSegmentStartedAt = null;
    await _positionSubscription?.cancel();
    _positionSubscription = null;
    if (mounted) setState(() => _paused = true);
  }

  Future<void> _resume() async {
    final permission = await Geolocator.checkPermission();
    setState(() {
      _paused = false;
      _activeSegmentStartedAt = DateTime.now();
    });
    _listenForPositions(_locationSettings(permission));
  }

  Future<void> _finish() async {
    if (_saving) return;
    if (!_paused) await _pause();
    final startedAt = _startedAt;
    final userId = Supabase.instance.client.auth.currentSession?.user.id;
    if (startedAt == null || userId == null) return;
    final durationSeconds = _elapsed.inSeconds.clamp(1, 86400 * 3);
    final endedAt = DateTime.now();
    final distance = _route.distanceMeters;
    final pace = distance >= 10 ? durationSeconds / (distance / 1000) : null;
    final avgSpeed = durationSeconds > 0 ? distance / durationSeconds : null;

    setState(() => _saving = true);
    try {
      final workouts = SupabaseWorkoutRepository(
        client: Supabase.instance.client,
      );
      final routes = SupabaseWorkoutRouteRepository(
        client: Supabase.instance.client,
      );
      var saved = await workouts.create(
        Workout(
          id: '',
          userId: userId,
          workoutType: _type.storageValue,
          startedAt: startedAt,
          endedAt: endedAt.isAfter(startedAt)
              ? endedAt
              : startedAt.add(const Duration(seconds: 1)),
          durationSeconds: durationSeconds,
          source: 'enfermicambio_gps',
          externalId: 'gps:$userId:${startedAt.toUtc().microsecondsSinceEpoch}',
          distanceMeters: distance,
          activeCalories: _route.estimatedCalories(),
          avgPace: pace,
          avgSpeed: avgSpeed,
        ),
      );
      if (_route.points.length >= 2) {
        await routes.replaceRoute(workoutId: saved.id, points: _route.points);
        await workouts.setRouteAvailable(workoutId: saved.id, available: true);
        saved = saved.copyWith(routeAvailable: true);
      }
      _timer?.cancel();
      if (!mounted) return;
      setState(() {
        _recording = false;
        _saving = false;
      });
      await Navigator.of(context).pushReplacement(
        MaterialPageRoute(
          builder: (_) => WorkoutDetailScreen(workoutId: saved.id),
        ),
      );
    } on Exception catch (error) {
      if (mounted) {
        setState(() {
          _saving = false;
          _statusMessage = 'No se pudo guardar: $error';
        });
      }
    }
  }

  String _durationLabel(Duration duration) {
    final hours = duration.inHours.toString().padLeft(2, '0');
    final minutes = (duration.inMinutes % 60).toString().padLeft(2, '0');
    final seconds = (duration.inSeconds % 60).toString().padLeft(2, '0');
    return '$hours:$minutes:$seconds';
  }

  String _distanceLabel(double meters) {
    if (meters < 1000) return '${meters.round()} m';
    return '${(meters / 1000).toStringAsFixed(2)} km';
  }

  String _paceLabel() {
    if (_route.distanceMeters < 10) return '--:--';
    final secondsPerKm = _elapsed.inSeconds / (_route.distanceMeters / 1000);
    final minutes = secondsPerKm ~/ 60;
    final seconds = (secondsPerKm % 60).round().toString().padLeft(2, '0');
    return '$minutes:$seconds /km';
  }

  @override
  Widget build(BuildContext context) {
    final points = _route.points;
    return Scaffold(
      appBar: AppBar(
        title: Text(_recording ? _type.label : 'Entrenamiento con GPS'),
        actions: [
          if (_statusMessage?.contains('Ajustes') == true)
            IconButton(
              tooltip: 'Abrir Ajustes',
              onPressed: Geolocator.openAppSettings,
              icon: const Icon(Icons.settings_outlined),
            ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          if (!_recording) ...[
            Text(
              'Elige tu actividad',
              style: Theme.of(
                context,
              ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                for (final type in WorkoutActivityType.values)
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 4),
                      child: _ActivityChoice(
                        type: type,
                        selected: type == _type,
                        onTap: () {
                          setState(() {
                            _type = type;
                            _route = WorkoutRouteAccumulator(
                              activityType: type,
                            );
                          });
                        },
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 16),
          ],
          _MetricPanel(
            duration: _durationLabel(_elapsed),
            distance: _distanceLabel(_route.distanceMeters),
            pace: _paceLabel(),
            calories: _route.estimatedCalories().round(),
          ),
          const SizedBox(height: 16),
          RouteMapView(
            key: ValueKey('live-route-${points.length ~/ 5}'),
            points: points,
            height: 300,
          ),
          const SizedBox(height: 12),
          if (_statusMessage != null)
            Text(
              _statusMessage!,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodySmall,
            ),
          const SizedBox(height: 16),
          if (!_recording)
            FilledButton.icon(
              onPressed: _start,
              icon: const Icon(Icons.play_arrow),
              label: Text('Iniciar ${_type.label.toLowerCase()}'),
              style: FilledButton.styleFrom(
                minimumSize: const Size.fromHeight(56),
              ),
            )
          else ...[
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: _paused ? _resume : _pause,
                    icon: Icon(_paused ? Icons.play_arrow : Icons.pause),
                    label: Text(_paused ? 'Reanudar' : 'Pausar'),
                    style: OutlinedButton.styleFrom(
                      minimumSize: const Size.fromHeight(52),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: FilledButton.icon(
                    onPressed: _saving ? null : _finish,
                    icon: _saving
                        ? const SizedBox.square(
                            dimension: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.stop),
                    label: Text(_saving ? 'Guardando…' : 'Finalizar'),
                    style: FilledButton.styleFrom(
                      minimumSize: const Size.fromHeight(52),
                      backgroundColor: AppColors.streakOrange,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

class _ActivityChoice extends StatelessWidget {
  const _ActivityChoice({
    required this.type,
    required this.selected,
    required this.onTap,
  });

  final WorkoutActivityType type;
  final bool selected;
  final VoidCallback onTap;

  IconData get _icon => switch (type) {
    WorkoutActivityType.running => Icons.directions_run,
    WorkoutActivityType.walking => Icons.directions_walk,
    WorkoutActivityType.cycling => Icons.directions_bike,
  };

  @override
  Widget build(BuildContext context) {
    return Material(
      color: selected
          ? AppColors.fitnessGreen.withValues(alpha: 0.2)
          : AppColors.darkSurfaceVariant,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 18, horizontal: 4),
          child: Column(
            children: [
              Icon(
                _icon,
                color: selected
                    ? AppColors.fitnessGreen
                    : Theme.of(context).colorScheme.onSurfaceVariant,
              ),
              const SizedBox(height: 6),
              Text(
                type.label,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: selected ? FontWeight.bold : FontWeight.normal,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _MetricPanel extends StatelessWidget {
  const _MetricPanel({
    required this.duration,
    required this.distance,
    required this.pace,
    required this.calories,
  });

  final String duration;
  final String distance;
  final String pace;
  final int calories;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            AppColors.fitnessGreen.withValues(alpha: 0.22),
            AppColors.primaryLight.withValues(alpha: 0.10),
          ],
        ),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: AppColors.fitnessGreen.withValues(alpha: 0.4),
        ),
      ),
      child: Column(
        children: [
          Text(
            duration,
            style: Theme.of(context).textTheme.displaySmall?.copyWith(
              fontWeight: FontWeight.w800,
              fontFeatures: const [FontFeature.tabularFigures()],
            ),
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              _LiveMetric(label: 'Distancia', value: distance),
              _LiveMetric(label: 'Ritmo', value: pace),
              _LiveMetric(label: 'Estimación', value: '$calories kcal'),
            ],
          ),
        ],
      ),
    );
  }
}

class _LiveMetric extends StatelessWidget {
  const _LiveMetric({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Column(
        children: [
          Text(value, style: const TextStyle(fontWeight: FontWeight.bold)),
          const SizedBox(height: 3),
          Text(label, style: Theme.of(context).textTheme.bodySmall),
        ],
      ),
    );
  }
}
