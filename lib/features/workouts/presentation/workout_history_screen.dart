import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../shared/ui/app_theme.dart';
import '../data/supabase_workout_repository.dart';
import '../domain/workout_models.dart';
import '../domain/workout_recording.dart';
import 'workout_detail_screen.dart';
import 'workout_recorder_screen.dart';

enum _HistoryPeriod { week, month, year }

extension on _HistoryPeriod {
  String get label => switch (this) {
    _HistoryPeriod.week => 'Esta semana',
    _HistoryPeriod.month => 'Este mes',
    _HistoryPeriod.year => 'Este año',
  };
}

class WorkoutHistoryScreen extends StatefulWidget {
  const WorkoutHistoryScreen({super.key});

  @override
  State<WorkoutHistoryScreen> createState() => _WorkoutHistoryScreenState();
}

class _WorkoutHistoryScreenState extends State<WorkoutHistoryScreen> {
  late final SupabaseWorkoutRepository _repository;
  List<Workout> _workouts = const [];
  WorkoutActivityType? _filter;
  _HistoryPeriod _period = _HistoryPeriod.week;
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _repository = SupabaseWorkoutRepository(client: Supabase.instance.client);
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final userId = Supabase.instance.client.auth.currentSession?.user.id;
      final workouts = await _repository.listRecent(
        limit: 100,
        userId: userId,
        workoutType: _filter?.storageValue,
      );
      if (mounted) setState(() => _workouts = workouts);
    } on Exception catch (error) {
      if (mounted) setState(() => _error = error.toString());
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  DateTime _periodStart(DateTime now) => switch (_period) {
    _HistoryPeriod.week => DateTime(
      now.year,
      now.month,
      now.day,
    ).subtract(Duration(days: now.weekday - 1)),
    _HistoryPeriod.month => DateTime(now.year, now.month),
    _HistoryPeriod.year => DateTime(now.year),
  };

  List<Workout> get _periodWorkouts {
    final now = DateTime.now();
    final start = _periodStart(now);
    return _workouts
        .where((workout) => workout.startedAt.isAfter(start))
        .toList();
  }

  @override
  Widget build(BuildContext context) {
    final periodWorkouts = _periodWorkouts;
    final periodDistance = periodWorkouts.fold<double>(
      0,
      (sum, workout) => sum + (workout.distanceMeters ?? 0),
    );
    final periodDuration = periodWorkouts.fold<int>(
      0,
      (sum, workout) => sum + workout.durationSeconds,
    );

    return Scaffold(
      appBar: AppBar(
        title: const Text('Mis entrenamientos'),
        actions: [
          IconButton(
            tooltip: 'Actualizar',
            onPressed: _load,
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () async {
          await Navigator.of(context).push(
            MaterialPageRoute(builder: (_) => const WorkoutRecorderScreen()),
          );
          await _load();
        },
        icon: const Icon(Icons.play_arrow),
        label: const Text('Nuevo'),
      ),
      body: RefreshIndicator(
        onRefresh: _load,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            _PeriodSelector(
              selected: _period,
              onSelected: (period) => setState(() => _period = period),
            ),
            const SizedBox(height: 10),
            _WeeklySummary(
              title: _period.label,
              sessions: periodWorkouts.length,
              distanceMeters: periodDistance,
              durationSeconds: periodDuration,
            ),
            const SizedBox(height: 14),
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  ChoiceChip(
                    label: const Text('Todos'),
                    selected: _filter == null,
                    onSelected: (_) {
                      setState(() => _filter = null);
                      _load();
                    },
                  ),
                  const SizedBox(width: 8),
                  for (final type in WorkoutActivityType.values) ...[
                    ChoiceChip(
                      label: Text(type.label),
                      selected: _filter == type,
                      onSelected: (_) {
                        setState(() => _filter = type);
                        _load();
                      },
                    ),
                    const SizedBox(width: 8),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 14),
            if (_loading)
              const Padding(
                padding: EdgeInsets.all(32),
                child: Center(child: CircularProgressIndicator()),
              )
            else if (_error != null)
              Card(
                child: ListTile(
                  leading: const Icon(
                    Icons.cloud_off_outlined,
                    color: AppColors.streakOrange,
                  ),
                  title: const Text('No se pudo cargar el historial'),
                  subtitle: Text(_error!),
                  trailing: IconButton(
                    onPressed: _load,
                    icon: const Icon(Icons.refresh),
                  ),
                ),
              )
            else if (_workouts.isEmpty)
              const Card(
                child: Padding(
                  padding: EdgeInsets.all(28),
                  child: Column(
                    children: [
                      Icon(Icons.route_outlined, size: 48),
                      SizedBox(height: 12),
                      Text(
                        'Todavía no tienes entrenamientos registrados.',
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ),
                ),
              )
            else
              for (final workout in _workouts)
                _WorkoutHistoryCard(
                  workout: workout,
                  onTap: () => Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) =>
                          WorkoutDetailScreen(workoutId: workout.id),
                    ),
                  ),
                ),
            const SizedBox(height: 80),
          ],
        ),
      ),
    );
  }
}

class _WeeklySummary extends StatelessWidget {
  const _WeeklySummary({
    required this.title,
    required this.sessions,
    required this.distanceMeters,
    required this.durationSeconds,
  });

  final String title;
  final int sessions;
  final double distanceMeters;
  final int durationSeconds;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            AppColors.primaryLight.withValues(alpha: 0.18),
            AppColors.fitnessGreen.withValues(alpha: 0.18),
          ],
        ),
        borderRadius: BorderRadius.circular(22),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              _SummaryValue(label: 'Sesiones', value: '$sessions'),
              _SummaryValue(
                label: 'Distancia',
                value: distanceMeters < 1000
                    ? '${distanceMeters.round()} m'
                    : '${(distanceMeters / 1000).toStringAsFixed(1)} km',
              ),
              _SummaryValue(
                label: 'Tiempo',
                value: '${(durationSeconds / 60).round()} min',
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _PeriodSelector extends StatelessWidget {
  const _PeriodSelector({required this.selected, required this.onSelected});

  final _HistoryPeriod selected;
  final ValueChanged<_HistoryPeriod> onSelected;

  @override
  Widget build(BuildContext context) {
    return SegmentedButton<_HistoryPeriod>(
      segments: const [
        ButtonSegment(value: _HistoryPeriod.week, label: Text('Semana')),
        ButtonSegment(value: _HistoryPeriod.month, label: Text('Mes')),
        ButtonSegment(value: _HistoryPeriod.year, label: Text('Año')),
      ],
      selected: {selected},
      onSelectionChanged: (selection) => onSelected(selection.first),
      showSelectedIcon: false,
    );
  }
}

class _SummaryValue extends StatelessWidget {
  const _SummaryValue({required this.label, required this.value});
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Column(
        children: [
          Text(value, style: const TextStyle(fontWeight: FontWeight.bold)),
          Text(label, style: Theme.of(context).textTheme.bodySmall),
        ],
      ),
    );
  }
}

class _WorkoutHistoryCard extends StatelessWidget {
  const _WorkoutHistoryCard({required this.workout, required this.onTap});

  final Workout workout;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final km = (workout.distanceMeters ?? 0) / 1000;
    final label = switch (workout.workoutType.toLowerCase()) {
      'running' => 'Carrera',
      'walking' => 'Caminata',
      'cycling' => 'Ciclismo',
      _ => workout.workoutType,
    };
    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      child: ListTile(
        onTap: onTap,
        leading: CircleAvatar(
          backgroundColor: AppColors.fitnessGreen.withValues(alpha: 0.18),
          child: Icon(
            workout.routeAvailable ? Icons.route : Icons.fitness_center,
            color: AppColors.fitnessGreen,
          ),
        ),
        title: Text(label, style: const TextStyle(fontWeight: FontWeight.bold)),
        subtitle: Text(
          '${DateFormat('dd MMM · HH:mm', 'es').format(workout.startedAt.toLocal())} · '
          '${(workout.durationSeconds / 60).round()} min',
        ),
        trailing: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Text(
              km < 1
                  ? '${(workout.distanceMeters ?? 0).round()} m'
                  : '${km.toStringAsFixed(2)} km',
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            if (workout.routeAvailable)
              const Text(
                'Ruta GPS',
                style: TextStyle(fontSize: 11, color: AppColors.primaryLight),
              ),
          ],
        ),
      ),
    );
  }
}
