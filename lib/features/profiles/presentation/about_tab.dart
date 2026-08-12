import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../shared/ui/app_theme.dart';
import '../../../shared/ui/async_state_view.dart';
import '../../../shared/ui/async_view_status.dart';
import '../../app/data/health_sync_bootstrap.dart';
import '../../health/data/health_plugin_repository.dart';
import '../../health/presentation/health_setup_screen.dart';
import '../../notifications/data/supabase_notification_repository.dart';
import '../../notifications/domain/notification_models.dart';
import '../../weight/presentation/weight_screen.dart';
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
            : AsyncViewStatus.offline('No se pudieron cargar los perfiles.');
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
            tooltip: 'Permisos y Salud',
            icon: const Icon(
              Icons.health_and_safety_outlined,
              color: AppColors.primaryLight,
            ),
            onPressed: () {
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => HealthSetupScreen(
                    repository: HealthPluginRepository(),
                    onConnectionVerified: () async {
                      await HealthSyncBootstrap.syncNow();
                    },
                  ),
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
          padding: const EdgeInsets.all(16),
          children: [
            const _SectionHeader(title: 'Los 4 Amigos', icon: Icons.group),
            const SizedBox(height: 8),
            for (final profile in _profiles!)
              _ProfileTile(profile: profile, stats: _stats[profile.id]),
            const SizedBox(height: 24),
            const _SectionHeader(title: 'Mi Peso', icon: Icons.monitor_weight),
            const SizedBox(height: 8),
            Card(
              child: ListTile(
                leading: Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: AppColors.primaryLight.withOpacity(0.15),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.monitor_weight_outlined,
                    color: AppColors.primaryLight,
                  ),
                ),
                title: const Text(
                  'Registrar y ver mi peso',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                subtitle: const Text('Solo tú ves esta información.'),
                trailing: const Icon(Icons.chevron_right),
                onTap: () {
                  Navigator.of(context).push(
                    MaterialPageRoute(builder: (_) => const WeightScreen()),
                  );
                },
              ),
            ),
            const SizedBox(height: 24),
            const _SectionHeader(
              title: 'Notificaciones',
              icon: Icons.notifications_outlined,
            ),
            const SizedBox(height: 8),
            const _NotificationPreferencesSection(),
            const SizedBox(height: 24),
            const _SectionHeader(
              title: 'Entrenamientos Recientes',
              icon: Icons.fitness_center,
            ),
            const SizedBox(height: 8),
            if (_recentWorkouts == null || _recentWorkouts!.isEmpty)
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Row(
                    children: [
                      const Icon(
                        Icons.info_outline,
                        color: AppColors.primaryLight,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          'Aún no hay entrenamientos registrados. Tus actividades de running, caminata o ciclismo aparecerán aquí automáticamente.',
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                      ),
                    ],
                  ),
                ),
              )
            else
              for (final workout in _recentWorkouts!)
                Card(
                  margin: const EdgeInsets.only(bottom: 8),
                  child: ListTile(
                    leading: Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: AppColors.fitnessGreen.withOpacity(0.15),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        _workoutIcon(workout.workoutType),
                        color: AppColors.fitnessGreen,
                      ),
                    ),
                    title: Text(
                      _workoutType(workout.workoutType),
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                    subtitle: Text(
                      '${workout.startedAt.day}/${workout.startedAt.month} ${workout.startedAt.hour}:${workout.startedAt.minute.toString().padLeft(2, '0')} - ${((workout.distanceMeters ?? 0) / 1000).toStringAsFixed(1)} km',
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
                ),
          ],
        ),
      ),
    );
  }

  String _workoutType(String type) {
    return switch (type.toLowerCase()) {
      'running' => 'Carrera',
      'walking' => 'Caminata',
      'cycling' => 'Ciclismo',
      _ => type.isEmpty ? 'Entrenamiento' : type,
    };
  }

  IconData _workoutIcon(String type) {
    return switch (type.toLowerCase()) {
      'running' => Icons.directions_run,
      'walking' => Icons.directions_walk,
      'cycling' => Icons.directions_bike,
      _ => Icons.fitness_center,
    };
  }
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({required this.title, required this.icon});

  final String title;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 20, color: AppColors.primaryLight),
        const SizedBox(width: 8),
        Text(
          title,
          style: Theme.of(
            context,
          ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
        ),
      ],
    );
  }
}

class _NotificationPreferencesSection extends StatefulWidget {
  const _NotificationPreferencesSection();

  @override
  State<_NotificationPreferencesSection> createState() =>
      _NotificationPreferencesSectionState();
}

class _NotificationPreferencesSectionState
    extends State<_NotificationPreferencesSection> {
  late final SupabaseNotificationRepository _repository;
  NotificationPreferences? _preferences;

  @override
  void initState() {
    super.initState();
    _repository = SupabaseNotificationRepository(
      client: Supabase.instance.client,
    );
    _load();
  }

  @override
  void dispose() {
    _repository.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    final preferences = await _repository.fetchPreferences();
    if (!mounted) return;
    setState(() {
      _preferences = preferences;
    });
  }

  Future<void> _toggle(NotificationCategory category, bool value) async {
    setState(() {
      _preferences = _preferences?.copyWithEnabled(category, value);
    });
    await _repository.setPreference(category, value);
  }

  @override
  Widget build(BuildContext context) {
    final preferences = _preferences;
    return Card(
      child: preferences == null
          ? const Padding(
              padding: EdgeInsets.all(16),
              child: Center(
                child: SizedBox(
                  width: 24,
                  height: 24,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
              ),
            )
          : Column(
              children: [
                for (final category in NotificationCategory.values)
                  SwitchListTile(
                    dense: true,
                    title: Text(category.label),
                    value: preferences.isEnabled(category),
                    onChanged: (value) => _toggle(category, value),
                  ),
              ],
            ),
    );
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
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            CircleAvatar(
              radius: 28,
              backgroundColor: AppColors.primaryLight.withOpacity(0.2),
              child: Text(
                profile.displayName.isEmpty
                    ? '?'
                    : profile.displayName[0].toUpperCase(),
                style: const TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                  color: AppColors.primaryLight,
                ),
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    profile.displayName,
                    style: const TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Meta: ${_format(profile.dailyStepTarget)} pasos | ${profile.dailyCalorieTarget} kcal',
                    style: TextStyle(
                      fontSize: 12,
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                  if (stats != null) ...[
                    const SizedBox(height: 8),
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: AppColors.darkSurfaceVariant,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        'Histórico: ${_format(stats.lifetimeSteps)} pasos • ${_formatKm(stats.lifetimeDistanceM)} km • ${stats.workoutCount} ent. • ${stats.seasonWins} victorias temp.',
                        style: TextStyle(
                          fontSize: 11,
                          color: theme.colorScheme.onSurface,
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
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
