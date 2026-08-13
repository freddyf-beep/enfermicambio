import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../app/data/dashboard_cache.dart';
import '../../app/data/dashboard_repository.dart';
import '../../app/data/health_sync_bootstrap.dart';
import '../../app/data/offline_post_service.dart';
import '../../app/presentation/notification_bell.dart';
import '../../feed/domain/feed_models.dart';
import '../../feed/presentation/feed_list.dart';
import '../../health/data/health_plugin_repository.dart';
import '../../health/domain/health_models.dart';
import '../../health/presentation/health_connection_card.dart';
import '../../health/presentation/health_setup_screen.dart';
import '../../health/presentation/health_auto_export_setup_screen.dart';
import '../../ranking/domain/ranking_models.dart';
import '../../../shared/ui/app_theme.dart';
import '../../../shared/ui/async_state_view.dart';
import '../../../shared/ui/async_view_status.dart';

class HomeTab extends StatefulWidget {
  const HomeTab({super.key});

  @override
  State<HomeTab> createState() => _HomeTabState();
}

class _HomeTabState extends State<HomeTab> {
  late final DashboardRepository _repository;
  late final OfflinePostService _posts;
  AppDashboardData? _data;
  AsyncViewStatus? _status;
  DashboardCache? _cache;
  bool _showingCache = false;
  RealtimeChannel? _realtimeChannel;

  @override
  void initState() {
    super.initState();
    _repository = DashboardRepository(client: Supabase.instance.client);
    _posts = OfflinePostService(client: Supabase.instance.client);
    _init();
  }

  @override
  void dispose() {
    final channel = _realtimeChannel;
    if (channel != null) {
      Supabase.instance.client.removeChannel(channel);
    }
    super.dispose();
  }

  Future<void> _init() async {
    final prefs = await SharedPreferences.getInstance();
    _cache = DashboardCache(prefs);
    final cached = _cache!.readRanking();
    if (cached != null && mounted) {
      setState(() {
        _data ??= AppDashboardData(
          ranking: cached,
          feedPage: const FeedPage(posts: [], nextCursor: null),
          me: null,
        );
        _showingCache = true;
      });
    }
    await _load();
    await _posts.flushPending();
    _subscribeRealtime();
  }

  void _subscribeRealtime() {
    final channel = Supabase.instance.client.channel('feed');
    void refresh(_) {
      if (mounted) _load();
    }

    channel
      ..onPostgresChanges(
        event: PostgresChangeEvent.all,
        schema: 'public',
        table: 'posts',
        callback: refresh,
      )
      ..onPostgresChanges(
        event: PostgresChangeEvent.all,
        schema: 'public',
        table: 'comments',
        callback: refresh,
      )
      ..onPostgresChanges(
        event: PostgresChangeEvent.all,
        schema: 'public',
        table: 'reactions',
        callback: refresh,
      );
    _realtimeChannel = channel.subscribe();
  }

  Future<void> _load() async {
    setState(() {
      _status = null;
    });
    try {
      final data = await _repository.load(now: DateTime.now().toUtc());
      if (!mounted) return;
      await _cache?.writeRanking(data.ranking);
      await _cache?.writeLastSync(DateTime.now().toUtc());
      setState(() {
        _data = data;
        _showingCache = false;
      });
    } on Exception catch (error) {
      if (!mounted) return;
      setState(() {
        _status = _data == null
            ? AsyncViewStatus.backendError(error.toString())
            : AsyncViewStatus.offline(
                'Sin conexión. Mostrando los últimos datos guardados.',
              );
      });
    }
  }

  Future<void> _react(FeedPost post) async {
    final userId = Supabase.instance.client.auth.currentSession?.user.id;
    if (userId == null) return;
    try {
      await _posts.toggleReaction(postId: post.id, userId: userId, emoji: '❤️');
      await _load();
    } on Exception {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('No se pudo reaccionar. Intenta de nuevo.'),
          ),
        );
      }
    }
  }

  Future<void> _comment(FeedPost post) async {
    final userId = Supabase.instance.client.auth.currentSession?.user.id;
    if (userId == null) return;
    final controller = TextEditingController();
    final body = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Agregar Comentario'),
        content: TextField(
          controller: controller,
          maxLines: 3,
          maxLength: 1000,
          decoration: const InputDecoration(
            hintText: 'Escribe un comentario para tus amigos...',
            border: OutlineInputBorder(),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, controller.text.trim()),
            child: const Text('Enviar'),
          ),
        ],
      ),
    );
    if (body == null || body.isEmpty) return;
    try {
      await _posts.addComment(postId: post.id, authorId: userId, body: body);
      await _load();
    } on Exception {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('No se pudo enviar el comentario. Intenta de nuevo.'),
          ),
        );
      }
    }
  }

  Future<void> _openHealthSetup() async {
    if (defaultTargetPlatform == TargetPlatform.iOS) {
      final refresh = await showDialog<bool>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          title: const Text('Configurar puente de salud'),
          content: const Text(
            'En iPhone los datos llegan desde Health Auto Export. '
            'Abre su automatización EnfermiCambio, pulsa Actualizar o ejecútala '
            'manualmente y vuelve aquí para refrescar el resumen.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: const Text('Cerrar'),
            ),
            FilledButton(
              onPressed: () async {
                Navigator.pop(dialogContext);
                await Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => const HealthAutoExportSetupScreen(),
                  ),
                );
                if (mounted) await _load();
              },
              child: const Text('Configurar puente'),
            ),
          ],
        ),
      );
      if (refresh == true && mounted) {
        await _load();
      }
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
    if (mounted) {
      await _load();
    }
  }

  Future<void> _openHealthAutoExportSetup() async {
    await Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => const HealthAutoExportSetupScreen()),
    );
    if (mounted) await _load();
  }

  @override
  Widget build(BuildContext context) {
    if (_data == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('HOY')),
        body: AsyncStateView(
          status: _status ?? const AsyncViewStatus.loading(),
          onRetry: _load,
          child: const SizedBox(),
        ),
      );
    }

    final data = _data!;
    return Scaffold(
      appBar: AppBar(
        title: const Text('HOY'),
        actions: [
          NotificationBell(),
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _load,
            tooltip: 'Actualizar',
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _load,
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(16),
          children: [
            if (_showingCache) ...[
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 8,
                ),
                decoration: BoxDecoration(
                  color: AppColors.darkSurfaceVariant,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    const Icon(
                      Icons.cloud_off_outlined,
                      size: 18,
                      color: AppColors.streakOrange,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Mostrando datos en caché',
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ),
                    TextButton(
                      onPressed: _load,
                      child: const Text('Reintentar'),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
            ],
            if (_status?.state == AsyncState.offline) ...[
              Card(
                color: AppColors.streakOrange.withValues(alpha: 0.15),
                child: ListTile(
                  leading: const Icon(
                    Icons.wifi_off,
                    color: AppColors.streakOrange,
                  ),
                  title: const Text('Estás sin conexión'),
                  subtitle: Text(_status!.message ?? ''),
                  trailing: TextButton(
                    onPressed: _load,
                    child: const Text('Reintentar'),
                  ),
                ),
              ),
              const SizedBox(height: 12),
            ],
            const _SectionHeader(title: 'Resumen de Hoy', icon: Icons.bolt),
            const SizedBox(height: 8),
            _SummaryCard(
              aggregate: data.me,
              needsHealthConnection:
                  data.me == null ||
                  data.me!.sourcePlatform == 'unknown' ||
                  data.me!.syncedAt.millisecondsSinceEpoch == 0,
              useHealthAutoExportBridge:
                  defaultTargetPlatform == TargetPlatform.iOS,
              onConnectHealth: defaultTargetPlatform == TargetPlatform.iOS
                  ? _openHealthAutoExportSetup
                  : _openHealthSetup,
            ),
            const SizedBox(height: 24),
            const _SectionHeader(
              title: 'Posiciones del Grupo',
              icon: Icons.leaderboard,
            ),
            const SizedBox(height: 8),
            for (final row in data.ranking) _RankingRowCard(row: row),
            const SizedBox(height: 24),
            const _SectionHeader(
              title: 'Novedades del Feed',
              icon: Icons.dynamic_feed,
            ),
            const SizedBox(height: 8),
            FeedList(
              posts: data.feedPage.posts,
              errorMessage: data.feedError == null
                  ? null
                  : 'El resumen y ranking siguen disponibles. Detalle: ${data.feedError}',
              onRetry: _load,
              onReact: _react,
              onComment: _comment,
            ),
          ],
        ),
      ),
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
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.bold,
            letterSpacing: -0.3,
          ),
        ),
      ],
    );
  }
}

class _SummaryCard extends StatelessWidget {
  const _SummaryCard({
    required this.aggregate,
    required this.needsHealthConnection,
    required this.useHealthAutoExportBridge,
    required this.onConnectHealth,
  });

  final DailyActivityAggregate? aggregate;
  final bool needsHealthConnection;
  final bool useHealthAutoExportBridge;
  final VoidCallback onConnectHealth;

  @override
  Widget build(BuildContext context) {
    if (needsHealthConnection) {
      if (useHealthAutoExportBridge) {
        return _HealthAutoExportCard(onOpen: onConnectHealth);
      }
      return HealthConnectionCard(onConnect: onConnectHealth);
    }

    final agg = aggregate!;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Row(
              children: [
                Expanded(
                  child: _MetricTile(
                    icon: Icons.directions_walk,
                    label: 'Pasos',
                    value: agg.dailySteps,
                    color: AppColors.primaryLight,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _MetricTile(
                    icon: Icons.local_fire_department,
                    label: 'Calorías Activas',
                    value: agg.activeCalories,
                    unit: 'kcal',
                    color: AppColors.streakOrange,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: _MetricTile(
                    icon: Icons.straighten,
                    label: 'Distancia',
                    value: _formatDistanceValue(agg.distanceMeters),
                    unit: _formatDistanceUnit(agg.distanceMeters),
                    color: AppColors.fitnessGreen,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _MetricTile(
                    icon: Icons.timer,
                    label: 'Ejercicio',
                    value: agg.exerciseMinutes,
                    unit: 'min',
                    color: AppColors.trophyPurple,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

String _formatDistanceValue(double meters) {
  if (!meters.isFinite || meters <= 0) return '0';
  if (meters < 1000) {
    return meters < 100 ? meters.toStringAsFixed(1) : meters.round().toString();
  }
  return (meters / 1000).toStringAsFixed(1);
}

String _formatDistanceUnit(double meters) {
  return meters >= 1000 ? 'km' : 'm';
}

class _HealthAutoExportCard extends StatelessWidget {
  const _HealthAutoExportCard({required this.onOpen});

  final VoidCallback onOpen;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.sync_alt, color: AppColors.primaryLight),
                const SizedBox(width: 8),
                Text(
                  'Salud por puente',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              'Health Auto Export envía tus datos de Apple Salud a la app. '
              'No necesitas activar el permiso nativo de EnfermiCambio en el iPhone.',
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            const SizedBox(height: 12),
            FilledButton.icon(
              onPressed: onOpen,
              icon: const Icon(Icons.refresh),
              label: const Text('Ver pasos y actualizar'),
            ),
          ],
        ),
      ),
    );
  }
}

class _MetricTile extends StatelessWidget {
  const _MetricTile({
    required this.icon,
    required this.label,
    required this.value,
    this.unit,
    required this.color,
  });

  final IconData icon;
  final String label;
  final dynamic value;
  final String? unit;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 16, color: color),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  label,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          RichText(
            text: TextSpan(
              children: [
                TextSpan(
                  text: _formatValue(value),
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Theme.of(context).colorScheme.onSurface,
                  ),
                ),
                if (unit != null)
                  TextSpan(
                    text: ' $unit',
                    style: TextStyle(
                      fontSize: 12,
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _formatValue(dynamic val) {
    if (val is num) {
      if (val >= 10000) {
        return '${(val / 1000).toStringAsFixed(1)}k';
      }
      return val.toString();
    }
    return val.toString();
  }
}

class _RankingRowCard extends StatelessWidget {
  const _RankingRowCard({required this.row});

  final RankingRow row;

  @override
  Widget build(BuildContext context) {
    final rankColor = switch (row.rank) {
      1 => const Color(0xFFFFD700), // Oro
      2 => const Color(0xFFC0C0C0), // Plata
      3 => const Color(0xFFCD7F32), // Bronce
      _ => AppColors.primaryLight,
    };

    final freshnessText = switch (row.freshness) {
      UserFreshness.fresh => 'Sincronizado',
      UserFreshness.stale => 'Desactualizado',
      UserFreshness.missing => 'Sin datos',
      UserFreshness.denied => 'Permiso denegado',
      UserFreshness.unavailable => 'No disponible',
    };

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: rankColor.withValues(alpha: 0.2),
          child: Text(
            '#${row.rank}',
            style: TextStyle(fontWeight: FontWeight.bold, color: rankColor),
          ),
        ),
        title: Text(
          row.displayName,
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        subtitle: Text(
          freshnessText,
          style: TextStyle(
            fontSize: 12,
            color: row.freshness == UserFreshness.fresh
                ? AppColors.fitnessGreen
                : Theme.of(context).colorScheme.onSurfaceVariant,
          ),
        ),
        trailing: Text(
          '${_formatSteps(row.value)} pasos',
          style: const TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 15,
            color: AppColors.primaryLight,
          ),
        ),
      ),
    );
  }

  String _formatSteps(double val) {
    if (val >= 1000) {
      return '${(val / 1000).toStringAsFixed(1)}k';
    }
    return val.toStringAsFixed(0);
  }
}
