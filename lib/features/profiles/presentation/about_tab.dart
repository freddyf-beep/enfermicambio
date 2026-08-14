import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../shared/ui/app_logo.dart';
import '../../../shared/ui/app_theme.dart';
import '../../../shared/ui/async_state_view.dart';
import '../../../shared/ui/async_view_status.dart';
import '../../app/data/health_sync_bootstrap.dart';
import '../../health/data/health_plugin_repository.dart';
import '../../health/presentation/health_setup_screen.dart';
import '../../health/presentation/health_auto_export_setup_screen.dart';
import '../../nutrition/presentation/calorie_plan_screen.dart';
import '../../notifications/data/push_notification_service.dart';
import '../../notifications/data/supabase_notification_repository.dart';
import '../../notifications/domain/notification_models.dart';
import '../../notifications/presentation/bark_bridge_setup_screen.dart';
import '../../weight/presentation/weight_screen.dart';
import '../../workouts/data/supabase_workout_repository.dart';
import '../../workouts/domain/workout_models.dart';
import '../../workouts/presentation/workout_detail_screen.dart';
import '../data/supabase_history_repository.dart';
import '../data/supabase_profile_repository.dart';
import '../domain/profile_history_stats.dart';
import '../domain/profile_models.dart';
import 'logo_settings_screen.dart';

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
  bool _avatarBusy = false;

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

  Future<void> _changeAvatar() async {
    final userId = Supabase.instance.client.auth.currentUser?.id;
    if (userId == null || _avatarBusy) return;
    final source = await showModalBottomSheet<ImageSource>(
      context: context,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.photo_library_outlined),
              title: const Text('Elegir de la galería'),
              onTap: () => Navigator.pop(context, ImageSource.gallery),
            ),
            ListTile(
              leading: const Icon(Icons.photo_camera_outlined),
              title: const Text('Tomar una foto'),
              onTap: () => Navigator.pop(context, ImageSource.camera),
            ),
          ],
        ),
      ),
    );
    if (source == null || !mounted) return;

    final image = await ImagePicker().pickImage(
      source: source,
      maxWidth: 1200,
      maxHeight: 1200,
      imageQuality: 84,
    );
    if (image == null || !mounted) return;

    setState(() {
      _avatarBusy = true;
    });
    try {
      final contentType =
          image.mimeType ??
          (image.path.toLowerCase().endsWith('.png')
              ? 'image/png'
              : 'image/jpeg');
      final updated = await _repository.uploadAvatar(
        userId: userId,
        filePath: image.path,
        contentType: contentType,
      );
      if (!mounted) return;
      final profiles = [...?_profiles];
      final index = profiles.indexWhere((profile) => profile.id == userId);
      if (index >= 0) profiles[index] = updated;
      setState(() {
        _profiles = profiles;
        _avatarBusy = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Foto de perfil actualizada.')),
      );
    } on Exception catch (error) {
      if (!mounted) return;
      setState(() {
        _avatarBusy = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('No se pudo guardar la foto: $error')),
      );
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
    final currentUserId = Supabase.instance.client.auth.currentUser?.id;
    UserProfile? currentProfile;
    for (final profile in _profiles!) {
      if (profile.id == currentUserId) {
        currentProfile = profile;
        break;
      }
    }
    return Scaffold(
      appBar: AppBar(
        title: const Text('NOSOTROS'),
        actions: [
          IconButton(
            tooltip: 'Personalizar logo',
            icon: const Icon(Icons.palette_outlined),
            onPressed: () {
              Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const LogoSettingsScreen()),
              );
            },
          ),
          IconButton(
            tooltip: 'Permisos y Salud',
            icon: const Icon(
              Icons.health_and_safety_outlined,
              color: AppColors.primaryLight,
            ),
            onPressed: defaultTargetPlatform == TargetPlatform.iOS
                ? _openHealthAutoExportSetup
                : _openHealthSetup,
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _load,
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(16),
          children: [
            if (currentProfile != null) ...[
              Card(
                child: ListTile(
                  leading: _ProfileAvatar(
                    name: currentProfile.displayName,
                    imageUrl: currentProfile.avatarUrl,
                    radius: 26,
                  ),
                  title: const Text(
                    'Mi perfil',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                  subtitle: Text(
                    _avatarBusy
                        ? 'Guardando foto…'
                        : 'Añade una foto para que tus amigos te reconozcan.',
                  ),
                  trailing: _avatarBusy
                      ? const SizedBox(
                          width: 22,
                          height: 22,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : IconButton(
                          tooltip: 'Cambiar foto',
                          onPressed: _changeAvatar,
                          icon: const Icon(Icons.camera_alt_outlined),
                        ),
                  onTap: _avatarBusy ? null : _changeAvatar,
                ),
              ),
              const SizedBox(height: 16),
            ],
            const _SectionHeader(title: 'Los 4 Amigos', icon: Icons.group),
            const SizedBox(height: 8),
            for (final profile in _profiles!)
              _ProfileTile(profile: profile, stats: _stats[profile.id]),
            const SizedBox(height: 12),
            Card(
              child: ListTile(
                leading: const AppLogo(size: 48, borderRadius: 12),
                title: const Text(
                  'Personalizar logo',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                subtitle: const Text(
                  'Elige entre los cuatro logos de EnfermiCambio.',
                ),
                trailing: const Icon(Icons.chevron_right),
                onTap: () {
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => const LogoSettingsScreen(),
                    ),
                  );
                },
              ),
            ),
            const SizedBox(height: 8),
            Card(
              child: ListTile(
                leading: const Icon(
                  Icons.local_fire_department_outlined,
                  color: AppColors.macroCarbs,
                ),
                title: const Text(
                  'Plan de calorías',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                subtitle: const Text(
                  'Meta personalizada con altura, peso y actividad.',
                ),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => const CaloriePlanScreen()),
                ),
              ),
            ),
            const SizedBox(height: 24),
            const _SectionHeader(title: 'Mi Peso', icon: Icons.monitor_weight),
            const SizedBox(height: 8),
            Card(
              child: ListTile(
                leading: Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: AppColors.primaryLight.withValues(alpha: 0.15),
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
              title: 'Mis Entrenamientos',
              icon: Icons.fitness_center,
            ),
            const SizedBox(height: 8),
            Card(
              child: ListTile(
                leading: const Icon(
                  Icons.sync_alt,
                  color: AppColors.fitnessGreen,
                ),
                title: const Text(
                  'Importación automática',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                subtitle: Text(
                  defaultTargetPlatform == TargetPlatform.iOS
                      ? 'Health Auto Export envía aquí tus carreras, caminatas, ciclismo y rutas.'
                      : 'Health Connect envía aquí tus carreras, caminatas, ciclismo y rutas.',
                ),
              ),
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
                          'Aún no hay entrenamientos registrados. Sincroniza el puente de salud y aparecerán aquí automáticamente.',
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
                        color: AppColors.fitnessGreen.withValues(alpha: 0.15),
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

  Future<void> _openHealthSetup() async {
    if (defaultTargetPlatform == TargetPlatform.iOS) {
      await showDialog<void>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          title: const Text('Configurar puente de salud'),
          content: const Text(
            'En iPhone la app recibe los datos a través de Health Auto Export. '
            'En esa aplicación abre la automatización EnfermiCambio, pulsa '
            'Actualizar y luego vuelve a EnfermiCambio para refrescar.',
          ),
          actions: [
            FilledButton(
              onPressed: () async {
                Navigator.pop(dialogContext);
                await Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => const HealthAutoExportSetupScreen(),
                  ),
                );
              },
              child: const Text('Configurar puente'),
            ),
          ],
        ),
      );
      return;
    }

    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => HealthSetupScreen(
          repository: HealthPluginRepository(),
          onConnectionVerified: () async {
            await HealthSyncBootstrap.syncNow();
          },
        ),
      ),
    );
  }

  Future<void> _openHealthAutoExportSetup() async {
    await Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => const HealthAutoExportSetupScreen()),
    );
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
                if (defaultTargetPlatform == TargetPlatform.android)
                  const _PushNotificationStatusCard(),
                const Divider(height: 1),
                if (defaultTargetPlatform == TargetPlatform.iOS) ...[
                  ListTile(
                    leading: const Icon(
                      Icons.notifications_active_outlined,
                      color: AppColors.primaryLight,
                    ),
                    title: const Text(
                      'Configurar Bark para iPhone',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                    subtitle: const Text(
                      'Puente externo con aplicación nativa; no crea un marcador web.',
                    ),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: () => Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => const BarkBridgeSetupScreen(),
                      ),
                    ),
                  ),
                  const Divider(height: 1),
                ],
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

class _PushNotificationStatusCard extends StatefulWidget {
  const _PushNotificationStatusCard();

  @override
  State<_PushNotificationStatusCard> createState() =>
      _PushNotificationStatusCardState();
}

class _PushNotificationStatusCardState
    extends State<_PushNotificationStatusCard> {
  late final PushNotificationService _service;

  @override
  void initState() {
    super.initState();
    _service = PushNotificationService.ensure();
    _service.start();
  }

  Future<void> _retry() async {
    await _service.refreshRegistration();
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<PushNotificationStatus>(
      valueListenable: _service.status,
      builder: (context, status, _) {
        final color = switch (status.state) {
          PushRegistrationState.registered => AppColors.fitnessGreen,
          PushRegistrationState.initializing => AppColors.primaryLight,
          PushRegistrationState.idle => AppColors.primaryLight,
          _ => Colors.orangeAccent,
        };
        final icon = switch (status.state) {
          PushRegistrationState.registered => Icons.notifications_active,
          PushRegistrationState.permissionDenied =>
            Icons.notifications_off_outlined,
          PushRegistrationState.apnsUnavailable => Icons.phone_iphone,
          PushRegistrationState.error => Icons.error_outline,
          _ => Icons.notifications_none,
        };
        final title = status.isRegistered
            ? 'Avisos del teléfono activos'
            : 'Avisos del teléfono';
        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(icon, color: color),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      status.detail.isEmpty
                          ? 'Comprobando el registro de este dispositivo…'
                          : status.detail,
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                    if (status.platform != null && status.isRegistered) ...[
                      const SizedBox(height: 2),
                      Text(
                        status.platform!,
                        style: Theme.of(context).textTheme.labelSmall,
                      ),
                    ],
                  ],
                ),
              ),
              IconButton(
                tooltip: 'Reintentar registro',
                onPressed: status.state == PushRegistrationState.initializing
                    ? null
                    : _retry,
                icon: const Icon(Icons.refresh),
              ),
            ],
          ),
        );
      },
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
              backgroundColor: AppColors.primaryLight.withValues(alpha: 0.2),
              backgroundImage: profile.avatarUrl == null
                  ? null
                  : NetworkImage(profile.avatarUrl!),
              child: profile.avatarUrl == null
                  ? Text(
                      profile.displayName.isEmpty
                          ? '?'
                          : profile.displayName[0].toUpperCase(),
                      style: const TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                        color: AppColors.primaryLight,
                      ),
                    )
                  : null,
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

class _ProfileAvatar extends StatelessWidget {
  const _ProfileAvatar({
    required this.name,
    required this.imageUrl,
    required this.radius,
  });

  final String name;
  final String? imageUrl;
  final double radius;

  @override
  Widget build(BuildContext context) {
    return CircleAvatar(
      radius: radius,
      backgroundColor: AppColors.primaryLight.withValues(alpha: 0.2),
      backgroundImage: imageUrl == null ? null : NetworkImage(imageUrl!),
      child: imageUrl == null
          ? Text(
              name.isEmpty ? '?' : name[0].toUpperCase(),
              style: const TextStyle(
                fontWeight: FontWeight.bold,
                color: AppColors.primaryLight,
              ),
            )
          : null,
    );
  }
}
