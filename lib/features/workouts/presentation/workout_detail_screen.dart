import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../shared/ui/app_theme.dart';
import '../../../shared/ui/async_state_view.dart';
import '../../../shared/ui/async_view_status.dart';
import '../data/supabase_workout_repository.dart';
import '../data/supabase_workout_route_repository.dart';
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
  Workout? _workout;
  List<RoutePoint>? _route;
  AsyncViewStatus? _status;
  bool _publishing = false;

  @override
  void initState() {
    super.initState();
    _workouts = SupabaseWorkoutRepository(client: Supabase.instance.client);
    _routes = SupabaseWorkoutRouteRepository(client: Supabase.instance.client);
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
    setState(() {
      _publishing = true;
    });
    try {
      final userId = Supabase.instance.client.auth.currentSession?.user.id;
      final km = (workout.distanceMeters ?? 0) / 1000;
      final minutes = (workout.durationSeconds / 60).round();
      await Supabase.instance.client.from('posts').insert({
        'author_id': userId,
        'post_type': workout.routeAvailable ? 'route' : 'workout',
        'caption':
            '${_typeLabel(workout.workoutType)} - ${km.toStringAsFixed(1)} km '
            'en $minutes min',
        'workout_id': workout.id,
        'system_generated': false,
      });
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
                    _publishing ? 'Publicando...' : 'Publicar en el Feed',
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
    final km = (workout.distanceMeters ?? 0) / 1000;
    final kcal = workout.activeCalories ?? 0;
    return Row(
      children: [
        Expanded(
          child: _Stat(
            label: 'Distancia',
            value: '${km.toStringAsFixed(2)} km',
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
