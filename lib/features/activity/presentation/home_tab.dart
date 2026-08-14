import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:share_plus/share_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../app/data/dashboard_cache.dart';
import '../../app/data/dashboard_repository.dart';
import '../../app/data/health_sync_bootstrap.dart';
import '../../app/data/offline_post_service.dart';
import '../../app/presentation/notification_bell.dart';
import '../../feed/domain/feed_models.dart';
import '../../feed/presentation/feed_list.dart';
import '../../workouts/presentation/workout_detail_screen.dart';
import '../../health/data/health_plugin_repository.dart';
import '../../health/presentation/health_connection_card.dart';
import '../../health/presentation/health_setup_screen.dart';
import '../../health/presentation/health_auto_export_setup_screen.dart';
import '../../ranking/domain/ranking_models.dart';
import '../../../shared/ui/app_tab_navigator.dart';
import '../../../shared/ui/app_theme.dart';
import '../../../shared/ui/async_state_view.dart';
import '../../../shared/ui/async_view_status.dart';
import 'widgets/home_dashboard_widgets.dart';

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
      )
      ..onPostgresChanges(
        event: PostgresChangeEvent.all,
        schema: 'public',
        table: 'post_media',
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

  Future<void> _openWorkout(FeedPost post) async {
    final workoutId = post.workoutId;
    if (workoutId == null || workoutId.isEmpty) return;
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => WorkoutDetailScreen(workoutId: workoutId),
      ),
    );
    if (mounted) await _load();
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

  Future<void> _shareDailySummary() async {
    final data = _data;
    if (data == null) return;
    final userId = Supabase.instance.client.auth.currentSession?.user.id;
    final currentRanking = userId == null
        ? null
        : data.ranking.cast<RankingRow?>().firstWhere(
            (row) => row?.userId == userId,
            orElse: () => null,
          );
    final steps = data.me?.dailySteps ?? currentRanking?.value.round() ?? 0;
    final distanceMeters = data.me?.distanceMeters ?? 0;
    final distance = distanceMeters >= 1000
        ? '${(distanceMeters / 1000).toStringAsFixed(2)} km'
        : '${distanceMeters.round()} m';
    final rankText = currentRanking == null
        ? ''
        : ' Voy #${currentRanking.rank} en el ranking.';
    final box = context.findRenderObject() as RenderBox?;
    try {
      await SharePlus.instance.share(
        ShareParams(
          title: 'Mi día en EnfermiCambio',
          text: 'Hoy llevo $steps pasos y $distance en EnfermiCambio.$rankText',
          sharePositionOrigin: box == null
              ? null
              : box.localToGlobal(Offset.zero) & box.size,
        ),
      );
    } on Exception {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('No se pudo abrir el menú para compartir.'),
        ),
      );
    }
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
    final currentUserId = Supabase.instance.client.auth.currentSession?.user.id;
    RankingRow? currentRanking;
    if (currentUserId != null) {
      for (final row in data.ranking) {
        if (row.userId == currentUserId) {
          currentRanking = row;
          break;
        }
      }
    }
    final needsHealthConnection =
        data.me == null ||
        data.me!.sourcePlatform == 'unknown' ||
        data.me!.syncedAt.millisecondsSinceEpoch == 0;

    return Scaffold(
      body: SafeArea(
        bottom: false,
        child: RefreshIndicator(
          onRefresh: _load,
          child: ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 28),
            children: [
              CompetitionDashboardHero(
                date: DateTime.now(),
                activity: data.me,
                currentRanking: currentRanking,
                showingCachedData: _showingCache,
                notificationButton: const NotificationBell(),
                onOpenGame: () => AppTabNavigator.goTo(3),
                onRefresh: _load,
                onShare: _shareDailySummary,
              ),
              if (_status?.state == AsyncState.offline) ...[
                const SizedBox(height: 12),
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
              ],
              if (needsHealthConnection) ...[
                const SizedBox(height: 14),
                if (defaultTargetPlatform == TargetPlatform.iOS)
                  _HealthAutoExportCard(onOpen: _openHealthAutoExportSetup)
                else
                  HealthConnectionCard(onConnect: _openHealthSetup),
              ],
              const SizedBox(height: 16),
              GroupRankingCard(
                rows: data.ranking,
                currentUserId: currentUserId,
                onCreatePost: () => AppTabNavigator.goTo(2),
                onOpenGroup: () => AppTabNavigator.goTo(4),
              ),
              const SizedBox(height: 28),
              const DashboardSectionHeader(
                title: 'Novedades del Feed',
                icon: Icons.dynamic_feed_rounded,
              ),
              const SizedBox(height: 10),
              FeedList(
                posts: data.feedPage.posts,
                errorMessage: data.feedError == null
                    ? null
                    : 'El resumen y ranking siguen disponibles. Detalle: ${data.feedError}',
                onRetry: _load,
                onReact: _react,
                onComment: _comment,
                onOpenWorkout: _openWorkout,
              ),
            ],
          ),
        ),
      ),
    );
  }
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
