import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

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
            'in $minutes min',
        'workout_id': workout.id,
        'system_generated': false,
      });
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Published to the feed.')));
    } on Exception catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Could not publish: $error')));
    } finally {
      if (mounted) {
        setState(() {
          _publishing = false;
        });
      }
    }
  }

  String _typeLabel(String type) {
    return switch (type) {
      'running' => 'Run',
      'walking' => 'Walk',
      'cycling' => 'Ride',
      'swimming' => 'Swim',
      _ => type.isEmpty ? 'Workout' : type[0].toUpperCase() + type.substring(1),
    };
  }

  @override
  Widget build(BuildContext context) {
    final workout = _workout;
    return Scaffold(
      appBar: AppBar(title: const Text('Workout')),
      body: workout == null
          ? AsyncStateView(
              status: _status ?? const AsyncViewStatus.loading(),
              onRetry: _load,
              child: const SizedBox(),
            )
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                Text(
                  _typeLabel(workout.workoutType),
                  style: Theme.of(context).textTheme.headlineSmall,
                ),
                const SizedBox(height: 8),
                Text(
                  '${workout.startedAt.day}/${workout.startedAt.month} '
                  '${workout.startedAt.hour}:${workout.startedAt.minute.toString().padLeft(2, '0')}',
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
                const SizedBox(height: 16),
                _StatsGrid(workout: workout),
                const SizedBox(height: 16),
                if (workout.routeAvailable) ...[
                  RouteMapView(points: _route ?? const []),
                  const SizedBox(height: 16),
                ],
                FilledButton.icon(
                  onPressed: _publishing ? null : _publishToFeed,
                  icon: const Icon(Icons.public),
                  label: const Text('Publish to feed'),
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
          child: _Stat(label: 'Distance', value: '${km.toStringAsFixed(2)} km'),
        ),
        Expanded(
          child: _Stat(label: 'Duration', value: '$minutes min'),
        ),
        Expanded(
          child: _Stat(label: 'Active kcal', value: kcal.round().toString()),
        ),
      ],
    );
  }
}

class _Stat extends StatelessWidget {
  const _Stat({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          children: [
            Text(value, style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 4),
            Text(label, style: Theme.of(context).textTheme.bodySmall),
          ],
        ),
      ),
    );
  }
}
