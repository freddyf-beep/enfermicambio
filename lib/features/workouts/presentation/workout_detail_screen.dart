import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../shared/ui/app_theme.dart';
import '../../../shared/ui/async_state_view.dart';
import '../../../shared/ui/async_view_status.dart';
import '../../feed/data/supabase_post_repository.dart';
import '../data/supabase_workout_repository.dart';
import '../data/supabase_workout_route_repository.dart';
import '../data/route_preview_service.dart';
import '../domain/workout_models.dart';
import 'route_map_view.dart';

class WorkoutDetailScreen extends StatefulWidget {
  const WorkoutDetailScreen({required this.workoutId, super.key});

  final String workoutId;

  @override
  State<WorkoutDetailScreen> createState() => _WorkoutDetailScreenState();
}

class _WorkoutDetailScreenState extends State<WorkoutDetailScreen> {
  late final SupabaseWorkoutRepository _workouts;
  late final SupabaseWorkoutRouteRepository _routes;
  late final SupabasePostRepository _posts;
  Workout? _workout;
  List<RoutePoint>? _route;
  AsyncViewStatus? _status;
  bool _publishing = false;

  @override
  void initState() {
    super.initState();
    _workouts = SupabaseWorkoutRepository(client: Supabase.instance.client);
    _routes = SupabaseWorkoutRouteRepository(client: Supabase.instance.client);
    _posts = SupabasePostRepository(client: Supabase.instance.client);
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _status = null;
    });
    try {
      final workout = await _workouts.findById(widget.workoutId);
      final route = (workout?.routeAvailable ?? false)
          ? await _routes.routeFor(workoutId: widget.workoutId)
          : <RoutePoint>[];
      if (!mounted) return;
      setState(() {
        _workout = workout;
        _route = route;
      });
    } on Exception catch (error) {
      if (!mounted) return;
      setState(() {
        _status = AsyncViewStatus.backendError(error.toString());
      });
    }
  }

  Future<void> _publishToFeed() async {
    final workout = _workout;
    if (workout == null) return;
    if (workout.routeAvailable) {
      await _shareRouteToFeed(workout);
      return;
    }
    setState(() {
      _publishing = true;
    });
    try {
      final userId = Supabase.instance.client.auth.currentSession?.user.id;
      if (userId == null) throw StateError('No hay una sesión activa.');
      await _posts.createWorkoutPost(
        authorId: userId,
        workoutId: workout.id,
        caption: _defaultCaption(workout),
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('¡Entrenamiento publicado en el feed!')),
      );
    } on Exception catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('No se pudo publicar: $error')));
    } finally {
      if (mounted) {
        setState(() {
          _publishing = false;
        });
      }
    }
  }

  Future<void> _shareRouteToFeed(Workout workout) async {
    final route = _route ?? const <RoutePoint>[];
    if (route.isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Esta actividad no tiene puntos GPS válidos y no se puede compartir como ruta.',
            ),
          ),
        );
      }
      return;
    }
    final controller = TextEditingController();
    final caption = await showDialog<String>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Compartir recorrido'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              RouteMapView(points: route, height: 210),
              const SizedBox(height: 12),
              Text(_defaultCaption(workout)),
              const SizedBox(height: 4),
              Text(
                'Calorías: ${(workout.activeCalories ?? 0).round()} kcal'
                '${workout.avgPace == null ? '' : ' · Ritmo: ${workout.avgPace!.toStringAsFixed(1)} min/km'}',
              ),
              const SizedBox(height: 12),
              TextField(
                controller: controller,
                maxLength: 300,
                maxLines: 3,
                decoration: const InputDecoration(
                  labelText: 'Texto opcional',
                  hintText: '¿Cómo estuvo el recorrido?',
                  border: OutlineInputBorder(),
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Cancelar'),
          ),
          FilledButton.icon(
            onPressed: () =>
                Navigator.pop(dialogContext, controller.text.trim()),
            icon: const Icon(Icons.public),
            label: const Text('Compartir en el Feed'),
          ),
        ],
      ),
    );
    controller.dispose();
    if (caption == null || !mounted) return;
    setState(() => _publishing = true);
    try {
      final userId = Supabase.instance.client.auth.currentSession?.user.id;
      if (userId == null) throw StateError('No hay una sesión activa.');
      final preview = await const RoutePreviewService().render(route);
      await _posts.shareWorkoutRoute(
        authorId: userId,
        workoutId: workout.id,
        caption: caption.isEmpty
            ? _defaultCaption(workout)
            : '${_defaultCaption(workout)}\n$caption',
        previewBytes: preview,
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Ruta compartida en el Feed.')),
        );
      }
    } on Exception catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('No se pudo compartir la ruta: $error')),
        );
      }
    } finally {
      if (mounted) setState(() => _publishing = false);
    }
  }

  String _defaultCaption(Workout workout) {
    return '${_typeLabel(workout.workoutType)} · ${_distanceLabel(workout.distanceMeters)} '
        '· ${_durationLabel(workout.durationSeconds)}';
  }

  String _distanceLabel(double? meters) {
    final value = meters ?? 0;
    if (value < 1000) return '${value.round()} m';
    return '${(value / 1000).toStringAsFixed(2)} km';
  }

  String _durationLabel(int seconds) {
    if (seconds < 60) return '$seconds s';
    return '${(seconds / 60).round()} min';
  }

  String _typeLabel(String type) {
    return switch (type.toLowerCase()) {
      'running' => 'Carrera',
      'walking' => 'Caminata',
      'cycling' => 'Ciclismo',
      'swimming' => 'Natación',
      _ => type.isEmpty ? 'Entrenamiento' : type,
    };
  }

  @override
  Widget build(BuildContext context) {
    final workout = _workout;
    return Scaffold(
      appBar: AppBar(title: const Text('Detalle del Entrenamiento')),
      body: workout == null
          ? AsyncStateView(
              status: _status ?? const AsyncViewStatus.loading(),
              onRetry: _load,
              child: const SizedBox(),
            )
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: AppColors.fitnessGreen.withValues(alpha: 0.15),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.directions_run,
                        color: AppColors.fitnessGreen,
                        size: 28,
                      ),
                    ),
                    const SizedBox(width: 14),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _typeLabel(workout.workoutType),
                          style: Theme.of(context).textTheme.headlineSmall
                              ?.copyWith(fontWeight: FontWeight.bold),
                        ),
                        Text(
                          '${workout.startedAt.day}/${workout.startedAt.month} ${workout.startedAt.hour}:${workout.startedAt.minute.toString().padLeft(2, '0')}',
                          style: Theme.of(context).textTheme.bodyMedium
                              ?.copyWith(
                                color: Theme.of(
                                  context,
                                ).colorScheme.onSurfaceVariant,
                              ),
                        ),
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: 20),
                _StatsGrid(workout: workout),
                const SizedBox(height: 20),
                if (workout.routeAvailable) ...[
                  const Text(
                    'Ruta del Recorrido',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                  ),
                  const SizedBox(height: 8),
                  RouteMapView(points: _route ?? const []),
                  const SizedBox(height: 20),
                ],
                FilledButton.icon(
                  onPressed: _publishing ? null : _publishToFeed,
                  icon: const Icon(Icons.public),
                  label: Text(
                    _publishing
                        ? 'Publicando...'
                        : workout.routeAvailable
                        ? 'Compartir ruta en el Feed'
                        : 'Publicar en el Feed',
                  ),
                  style: FilledButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 14),
                  ),
                ),
              ],
            ),
    );
  }
}

class _StatsGrid extends StatelessWidget {
  const _StatsGrid({required this.workout});

  final Workout workout;

  @override
  Widget build(BuildContext context) {
    final minutes = (workout.durationSeconds / 60).round();
    final meters = workout.distanceMeters ?? 0;
    final kcal = workout.activeCalories ?? 0;
    return Row(
      children: [
        Expanded(
          child: _Stat(
            label: 'Distancia',
            value: meters < 1000
                ? '${meters.round()} m'
                : '${(meters / 1000).toStringAsFixed(2)} km',
            color: AppColors.fitnessGreen,
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: _Stat(
            label: 'Duración',
            value: '$minutes min',
            color: AppColors.primaryLight,
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: _Stat(
            label: 'Calorías',
            value: '${kcal.round()} kcal',
            color: AppColors.streakOrange,
          ),
        ),
      ],
    );
  }
}

class _Stat extends StatelessWidget {
  const _Stat({required this.label, required this.value, required this.color});

  final String label;
  final String value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          children: [
            Text(
              value,
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 16,
                color: color,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              label,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
