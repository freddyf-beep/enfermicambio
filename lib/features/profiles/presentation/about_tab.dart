import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../shared/ui/async_state_view.dart';
import '../../../shared/ui/async_view_status.dart';
import '../../health/data/health_plugin_repository.dart';
import '../../health/presentation/health_setup_screen.dart';
import '../../workouts/data/supabase_workout_repository.dart';
import '../../workouts/domain/workout_models.dart';
import '../../workouts/presentation/workout_detail_screen.dart';
import '../data/supabase_history_repository.dart';
import '../data/supabase_profile_repository.dart';
import '../domain/profile_history_stats.dart';
import '../domain/profile_models.dart';

class AboutTab extends StatefulWidget {
  const AboutTab({super.key});

  @override
  State<AboutTab> createState() => _AboutTabState();
}

class _AboutTabState extends State<AboutTab> {
  late final SupabaseProfileRepository _repository;
  late final SupabaseHistoryRepository _history;
  late final SupabaseWorkoutRepository _workouts;
  List<UserProfile>? _profiles;
  final Map<String, ProfileHistoryStats> _stats = {};
  List<Workout>? _recentWorkouts;
  AsyncViewStatus? _status;

  @override
  void initState() {
    super.initState();
    _repository = SupabaseProfileRepository(client: Supabase.instance.client);
    _history = SupabaseHistoryRepository(client: Supabase.instance.client);
    _workouts = SupabaseWorkoutRepository(client: Supabase.instance.client);
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _status = null;
    });
    try {
      final profiles = await _repository.fetchAll();
      for (final profile in profiles) {
        final stats = await _history.statsFor(userId: profile.id);
        _stats[profile.id] = stats;
      }
      final workouts = await _workouts.listRecent(limit: 20);
      if (!mounted) return;
      setState(() {
        _profiles = profiles;
        _recentWorkouts = workouts;
      });
    } on Exception catch (error) {
      if (!mounted) return;
      setState(() {
        _status = _profiles == null
            ? AsyncViewStatus.backendError(error.toString())
            : AsyncViewStatus.offline('Could not refresh profiles.');
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_profiles == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('NOSOTROS')),
        body: AsyncStateView(
          status: _status ?? const AsyncViewStatus.loading(),
          onRetry: _load,
          child: const SizedBox(),
        ),
      );
    }
    return Scaffold(
      appBar: AppBar(
        title: const Text('NOSOTROS'),
        actions: [
          IconButton(
            tooltip: 'Health settings',
            icon: const Icon(Icons.health_and_safety_outlined),
            onPressed: () {
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) =>
                      HealthSetupScreen(repository: HealthPluginRepository()),
                ),
              );
            },
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _load,
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.symmetric(vertical: 8),
          children: [
            for (final profile in _profiles!)
              _ProfileTile(profile: profile, stats: _stats[profile.id]),
            const SizedBox(height: 8),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Text(
                'Recent workouts',
                style: Theme.of(context).textTheme.titleLarge,
              ),
            ),
            const SizedBox(height: 4),
            if (_recentWorkouts == null || _recentWorkouts!.isEmpty)
              const Padding(
                padding: EdgeInsets.all(16),
                child: Text('No workouts synced yet.'),
              )
            else
              for (final workout in _recentWorkouts!)
                ListTile(
                  leading: const Icon(Icons.directions_run),
                  title: Text(_workoutType(workout.workoutType)),
                  subtitle: Text(
                    '${workout.startedAt.day}/${workout.startedAt.month} '
                    '${workout.startedAt.hour}:'
                    '${workout.startedAt.minute.toString().padLeft(2, '0')} - '
                    '${((workout.distanceMeters ?? 0) / 1000).toStringAsFixed(1)} km',
                  ),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () {
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) =>
                            WorkoutDetailScreen(workoutId: workout.id),
                      ),
                    );
                  },
                ),
          ],
        ),
      ),
    );
  }

  String _workoutType(String type) {
    return switch (type) {
      'running' => 'Run',
      'walking' => 'Walk',
      'cycling' => 'Ride',
      _ => type.isEmpty ? 'Workout' : type[0].toUpperCase() + type.substring(1),
    };
  }
}

class _ProfileTile extends StatelessWidget {
  const _ProfileTile({required this.profile, this.stats});

  final UserProfile profile;
  final ProfileHistoryStats? stats;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final stats = this.stats;
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      child: ListTile(
        leading: CircleAvatar(
          radius: 24,
          backgroundColor: theme.colorScheme.primaryContainer,
          child: Text(
            profile.displayName.isEmpty
                ? '?'
                : profile.displayName[0].toUpperCase(),
          ),
        ),
        title: Text(profile.displayName),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Step goal ${profile.dailyStepTarget} - '
              'Calorie target ${profile.dailyCalorieTarget}',
              style: theme.textTheme.bodySmall,
            ),
            if (stats != null) ...[
              const SizedBox(height: 6),
              Text(
                'Lifetime: ${_format(stats.lifetimeSteps)} steps - '
                '${_formatKm(stats.lifetimeDistanceM)} km - '
                '${stats.workoutCount} workouts - '
                '${stats.seasonWins} season wins',
                style: theme.textTheme.bodySmall,
              ),
            ],
          ],
        ),
      ),
    );
  }

  String _format(int value) {
    if (value >= 1000) return '${(value / 1000).toStringAsFixed(1)}k';
    return value.toString();
  }

  String _formatKm(double meters) {
    final km = meters / 1000;
    if (km >= 100) return km.round().toString();
    return km.toStringAsFixed(1);
  }
}
